import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_app/Models/field_definition.dart';
import 'package:my_app/Screens/pdf_preview.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfium/flutter_pdfium.dart'; // Hypothetical pdfium plugin

class PdfCoordinateEditor extends StatefulWidget {
  final String pdfPath;
  final Function(Map<String, Map<String, double>>, Map<String, FieldDefinition>)
  onSave;

  const PdfCoordinateEditor({
    super.key,
    required this.pdfPath,
    required this.onSave,
  });

  @override
  State<PdfCoordinateEditor> createState() => _PdfCoordinateEditorState();
}

class _PdfCoordinateEditorState extends State<PdfCoordinateEditor> {
  PdfDocument? _pdfDocument;
  int _currentPage = 1;
  String? _selectedField;
  ExpectedType? _selectedExpectedType;
  final Map<String, Map<String, double>> _coordinates = {};
  final Map<String, FieldDefinition> _fieldDefinitions = {};
  List<Map<String, dynamic>> _suggestedFields = [];
  final List<String> _fields = [
    'name',
    'email',
    'phone',
    'age',
    'spouse_age',
    'children_count',
    'health_condition',
    'custom_field',
  ];
  static const String layoutLmApiUrl = 'your-layoutlmv3-api-url-here';
  static const String openAiApiKey = 'your-openai-api-key-here';

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final file = File(widget.pdfPath);
      final bytes = await file.readAsBytes();
      _pdfDocument = await PdfDocument.openData(bytes);
      setState(() {});
    } catch (e) {
      print('Error loading PDF: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load PDF: $e')));
    }
  }

  Future<void> _extractFieldsWithAI() async {
    try {
      final directory = await getTemporaryDirectory();
      final pdfImages = <String>[];
      for (int i = 1; i <= _pdfDocument!.pageCount; i++) {
        final page = _pdfDocument!.getPage(i);
        final pageContent = await page.render();
        final imagePath = '${directory.path}/page_$i.png';
        await File(imagePath).writeAsBytes(pageContent.bytes);
        pdfImages.add(imagePath);
      }

      final response = await http.post(
        Uri.parse(layoutLmApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'images':
              pdfImages
                  .map((path) => base64Encode(File(path).readAsBytesSync()))
                  .toList(),
          'task': 'form_field_detection',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final suggestedFields = List<Map<String, dynamic>>.from(
          data['predictions'],
        );
        setState(() {
          _suggestedFields = suggestedFields;
          _fieldDefinitions.addAll({
            for (var field in suggestedFields)
              field['name']: FieldDefinition(
                expectedType: ExpectedType.values.firstWhere(
                  (e) => e.toString().split('.').last == field['type'],
                  orElse: () => ExpectedType.custom,
                ),
                validator: _getValidator(
                  ExpectedType.values.firstWhere(
                    (e) => e.toString().split('.').last == field['type'],
                    orElse: () => ExpectedType.custom,
                  ),
                ),
                isSuggested: true,
                confidence: field['confidence'].toDouble(),
                boundingBox: {
                  'x': field['x'].toDouble(),
                  'y': field['y'].toDouble(),
                  'width': field['width'].toDouble(),
                  'height': field['height'].toDouble(),
                  'page': field['page'].toDouble(),
                },
              ),
          });
          _coordinates.addAll({
            for (var field in suggestedFields)
              field['name']: {
                'page': field['page'].toDouble(),
                'x': field['x'].toDouble(),
                'y': field['y'].toDouble(),
              },
          });
          _fields.addAll(
            suggestedFields
                .map((f) => f['name'])
                .where((name) => !_fields.contains(name)),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOTA AI field and coordinate extraction completed'),
          ),
        );
      } else {
        await _extractFieldsWithGpt();
      }
    } catch (e) {
      print('SOTA AI extraction error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('SOTA AI extraction failed: $e')));
      await _extractFieldsWithGpt();
    }
  }

  Future<void> _extractFieldsWithGpt() async {
    try {
      // Initialize pdfium for text extraction with bounding boxes
      final pdfiumDoc = await PdfiumDocument.open(widget.pdfPath);
      final textWithPositions = <Map<String, dynamic>>[];

      for (int i = 1; i <= pdfiumDoc.pageCount; i++) {
        final page = await pdfiumDoc.getPage(
          i - 1,
        ); // pdfium uses 0-based indexing
        final textElements =
            await page
                .getTextWithBounds(); // Hypothetical method from flutter_pdfium

        for (var element in textElements) {
          textWithPositions.add({
            'page': i,
            'text': element.text,
            'x': element.bounds.left.toDouble(),
            'y': element.bounds.top.toDouble(),
            'width': (element.bounds.right - element.bounds.left).toDouble(),
            'height': (element.bounds.bottom - element.bounds.top).toDouble(),
          });
        }
        page.close();
      }
      pdfiumDoc.close();

      // Send accurate text and bounding box data to OpenAI API
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $openAiApiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4-vision-preview',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are an expert at analyzing PDF forms. Given text and precise positional data (page, x, y, width, height), identify form fields, their names, types (text, number, email, phone, date, custom), and coordinates. Return a JSON array of objects with "name", "type", "confidence", "page", "x", "y". Example: [{"name": "ClientName", "type": "text", "confidence": 0.9, "page": 1, "x": 100, "y": 700}]',
            },
            {
              'role': 'user',
              'content':
                  'Analyze this PDF data:\n\n${jsonEncode(textWithPositions)}',
            },
          ],
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final suggestedFields = List<Map<String, dynamic>>.from(
          jsonDecode(data['choices'][0]['message']['content']),
        );
        setState(() {
          _suggestedFields = suggestedFields;
          _fieldDefinitions.addAll({
            for (var field in suggestedFields)
              field['name']: FieldDefinition(
                expectedType: ExpectedType.values.firstWhere(
                  (e) => e.toString().split('.').last == field['type'],
                  orElse: () => ExpectedType.custom,
                ),
                validator: _getValidator(
                  ExpectedType.values.firstWhere(
                    (e) => e.toString().split('.').last == field['type'],
                    orElse: () => ExpectedType.custom,
                  ),
                ),
                isSuggested: true,
                confidence: field['confidence'].toDouble(),
                boundingBox: {
                  'x': field['x'].toDouble(),
                  'y': field['y'].toDouble(),
                  'width':
                      200.0, // Width/height may be adjusted based on GPT output
                  'height': 20.0,
                  'page': field['page'].toDouble(),
                },
              ),
          });
          _coordinates.addAll({
            for (var field in suggestedFields)
              field['name']: {
                'page': field['page'].toDouble(),
                'x': field['x'].toDouble(),
                'y': field['y'].toDouble(),
              },
          });
          _fields.addAll(
            suggestedFields
                .map((f) => f['name'])
                .where((name) => !_fields.contains(name)),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'GPT-based field and coordinate extraction completed',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPT extraction failed: ${response.body}')),
        );
      }
    } catch (e) {
      print('GPT extraction error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('GPT extraction failed: $e')));
    }
  }

  void _onTap(Offset position) {
    if (_selectedField != null && _selectedExpectedType != null) {
      setState(() {
        _coordinates[_selectedField!] = {
          'page': _currentPage.toDouble(),
          'x': position.dx,
          'y': position.dy,
        };
        _fieldDefinitions[_selectedField!] = FieldDefinition(
          expectedType: _selectedExpectedType!,
          validator: _getValidator(_selectedExpectedType!),
          isSuggested: _fieldDefinitions[_selectedField!]?.isSuggested ?? false,
          confidence: _fieldDefinitions[_selectedField!]?.confidence ?? 0.0,
          boundingBox: _fieldDefinitions[_selectedField!]?.boundingBox,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Coordinates and type set for $_selectedField on page $_currentPage',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a field and field type')),
      );
    }
  }

  String? Function(String) _getValidator(ExpectedType type) {
    switch (type) {
      case ExpectedType.text:
        return (value) =>
            value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
                ? null
                : 'Invalid text';
      case ExpectedType.number:
        return (value) {
          if (value.isEmpty) return null;
          return double.tryParse(value) != null ? null : 'Invalid number';
        };
      case ExpectedType.email:
        return (value) =>
            value.isEmpty ||
                    RegExp(
                      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                    ).hasMatch(value)
                ? null
                : 'Invalid email';
      case ExpectedType.phone:
        return (value) =>
            value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)
                ? null
                : 'Invalid phone number';
      case ExpectedType.date:
        return (value) {
          if (value.isEmpty) return null;
          try {
            DateTime.parse(value);
            return null;
          } catch (e) {
            return 'Invalid date (use YYYY-MM-DD)';
          }
        };
      case ExpectedType.custom:
        return (value) => null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit PDF Coordinates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _extractFieldsWithAI,
            tooltip: 'Extract Fields and Coordinates with SOTA AI',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              widget.onSave(_coordinates, _fieldDefinitions);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  hint: const Text('Select Field'),
                  value: _selectedField,
                  items:
                      _fields
                          .map(
                            (field) => DropdownMenuItem(
                              value: field,
                              child: Text(
                                field +
                                    (_fieldDefinitions[field]?.isSuggested ==
                                            true
                                        ? ' (AI)'
                                        : ''),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedField = value;
                      if (value != null && _fieldDefinitions[value] != null) {
                        _selectedExpectedType =
                            _fieldDefinitions[value]!.expectedType;
                        if (_coordinates[value] != null) {
                          _currentPage = _coordinates[value]!['page']!.toInt();
                        }
                      } else if (value == 'name') {
                        _selectedExpectedType = ExpectedType.text;
                      } else if (value == 'email') {
                        _selectedExpectedType = ExpectedType.email;
                      } else if (value == 'phone') {
                        _selectedExpectedType = ExpectedType.phone;
                      } else if (value == 'age' ||
                          value == 'spouse_age' ||
                          value == 'children_count') {
                        _selectedExpectedType = ExpectedType.number;
                      } else if (value == 'health_condition') {
                        _selectedExpectedType = ExpectedType.text;
                      } else {
                        _selectedExpectedType = null;
                      }
                    });
                  },
                ),
              ),
              Expanded(
                child: DropdownButton<ExpectedType>(
                  hint: const Text('Select Field Type'),
                  value: _selectedExpectedType,
                  items:
                      ExpectedType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.toString().split('.').last),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedExpectedType = value;
                    });
                  },
                ),
              ),
            ],
          ),
          if (_suggestedFields.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'AI-Suggested Fields',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestedFields.length,
                itemBuilder: (context, index) {
                  final field = _suggestedFields[index];
                  return ListTile(
                    title: Text('${field['name']} (${field['type']})'),
                    subtitle: Text(
                      'Confidence: ${(field['confidence'] * 100).toStringAsFixed(1)}%, Page: ${field['page']}, X: ${field['x']}, Y: ${field['y']}',
                    ),
                    onTap: () {
                      setState(() {
                        _selectedField = field['name'];
                        _selectedExpectedType = ExpectedType.values.firstWhere(
                          (e) => e.toString().split('.').last == field['type'],
                          orElse: () => ExpectedType.custom,
                        );
                        _currentPage = field['page'];
                      });
                    },
                  );
                },
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_left),
                onPressed:
                    _currentPage > 1
                        ? () {
                          setState(() {
                            _currentPage--;
                          });
                        }
                        : null,
              ),
              Text('Page $_currentPage'),
              IconButton(
                icon: const Icon(Icons.arrow_right),
                onPressed:
                    _pdfDocument != null &&
                            _currentPage < _pdfDocument!.pageCount
                        ? () {
                          setState(() {
                            _currentPage++;
                          });
                        }
                        : null,
              ),
            ],
          ),
          Expanded(
            child:
                _pdfDocument == null
                    ? const Center(child: CircularProgressIndicator())
                    : GestureDetector(
                      onTapUp: (details) => _onTap(details.localPosition),
                      child: PdfPreview(
                        file: File(widget.pdfPath),
                        initialPage: _currentPage,
                        allowPinchZoom: true,
                        allowSwipeNavigation: false,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

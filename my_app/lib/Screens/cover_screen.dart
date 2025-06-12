import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:my_app/Models/Insured_item.dart';
import 'package:my_app/Models/field_definition.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class GenericDialog extends StatelessWidget {
  final String title;
  final Map<String, String> extractedData;
  final Function(Map<String, String>) onConfirm;

  const GenericDialog({
    super.key,
    required this.title,
    required this.extractedData,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out 'insurer' to avoid premature company selection
    final filteredData = Map<String, String>.from(extractedData)..remove('insurer');

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          children: filteredData.entries.map((entry) {
            return ListTile(
              title: Text('${entry.key}: ${entry.value}'),
              onTap: () => onConfirm({entry.key: entry.value}),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => onConfirm(filteredData),
          child: const Text('Apply All'),
        ),
      ],
    );
  }
}

// Dialog for selecting insurance company
class CompanySelectionDialog extends StatelessWidget {
  final String? previousCompany;
  final List<String> availableCompanies;
  final Function(String?) onConfirm;

  const CompanySelectionDialog({
    super.key,
    this.previousCompany,
    required this.availableCompanies,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    String? selectedCompany = previousCompany;
    return AlertDialog(
      title: Text(previousCompany != null
          ? 'Previous Insurer Detected: $previousCompany'
          : 'Select Insurance Company'),
      content: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (previousCompany != null)
                Text(
                    'Do you want to proceed with $previousCompany or choose another?'),
              DropdownButton<String>(
                value: selectedCompany,
                hint: const Text('Select Company'),
                items: [
                  if (previousCompany != null)
                    DropdownMenuItem(
                      value: previousCompany,
                      child: Text(previousCompany!),
                    ),
                  ...availableCompanies
                      .where((company) => company != previousCompany)
                      .map((company) => DropdownMenuItem(
                            value: company,
                            child: Text(company),
                          )),
                ],
                onChanged: (value) => setState(() => selectedCompany = value),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            onConfirm(selectedCompany);
            Navigator.pop(context);
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class CoverDetailScreen extends StatefulWidget {
  final String type;
  final String subtype;
  final String coverageType;
  final InsuredItem? insuredItem;
  final Function(Map<String, String>) onSubmit;
  final Function(File, Map<String, String>?, String?) onAutofillPreviousPolicy;
  final Function(File, Map<String, String>?) onAutofillLogbook;
  final Map<String, FieldDefinition> fields;

  const CoverDetailScreen({
    super.key,
    required this.type,
    required this.subtype,
    required this.coverageType,
    this.insuredItem,
    required this.onSubmit,
    required this.onAutofillPreviousPolicy,
    required this.onAutofillLogbook,
    required this.fields,
  });

  @override
  State<CoverDetailScreen> createState() => _CoverDetailScreenState();
}

class _CoverDetailScreenState extends State<CoverDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _kraPinController = TextEditingController();
  final _vehicleValueController = TextEditingController();
  final _regnoController = TextEditingController();
  final _propertyValueController = TextEditingController();
  final _chassisNumberController = TextEditingController();
  final _healthConditionController = TextEditingController();
  final _travelDestinationController = TextEditingController();
  final _employeeCountController = TextEditingController();
  File? _logbookFile;
  File? _previousPolicyFile;
  String? _selectedCompany;
  final List<String> _availableCompanies = [
    'Company A',
    'Company B',
    'Jubilee Insurance',
    'CIC Insurance',
    'APA Insurance',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.insuredItem != null) {
      _nameController.text = widget.insuredItem!.details['name'] ?? '';
      _emailController.text = widget.insuredItem!.details['email'] ?? '';
      _phoneController.text = widget.insuredItem!.details['phone'] ?? '';
      _idNumberController.text = widget.insuredItem!.details['id_number'] ?? '';
      _kraPinController.text = widget.insuredItem!.kraPin ?? '';
      _vehicleValueController.text = widget.insuredItem!.vehicleValue ?? '';
      _regnoController.text = widget.insuredItem!.regno ?? '';
      _propertyValueController.text = widget.insuredItem!.propertyValue ?? '';
      _chassisNumberController.text = widget.insuredItem!.chassisNumber ?? '';
      _healthConditionController.text =
          widget.insuredItem!.details['health_condition'] ?? '';
      _travelDestinationController.text =
          widget.insuredItem!.details['travel_destination'] ?? '';
      _employeeCountController.text =
          widget.insuredItem!.details['employee_count'] ?? '';
      _logbookFile = widget.insuredItem!.logbookPath != null
          ? File(widget.insuredItem!.logbookPath!)
          : null;
      _previousPolicyFile = widget.insuredItem!.previousPolicyPath != null
          ? File(widget.insuredItem!.previousPolicyPath!)
          : null;
      _selectedCompany = widget.insuredItem!.details['insurer'];
    }
  }

  Future<Map<String, String>?> _performOCR(File file) async {
    try {
      // Encode file to base64 for OpenAI API
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Prepare OpenAI API request
      final requestBody = {
        'model': 'gpt-4o',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text':
                    'Extract the following fields from the provided document (logbook or insurance policy): name, email, phone, id_number, kra_pin, vehicle_value, regno, chassis_number, health_condition, travel_destination, employee_count, insurer. Return as a JSON object.'
              },
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
              }
            ]
          }
        ],
        'max_tokens': 300
      };

      // Send to OpenAI API
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_OPENAI_API_KEY',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final extracted = jsonDecode(data['choices'][0]['message']['content'])
            as Map<String, dynamic>;
        return extracted.map((key, value) => MapEntry(key, value.toString()));
      }
      return null;
    } catch (e) {
      print('OpenAI OCR Error: $e');
      return null;
    }
  }

  void _autofillFields(Map<String, String> extractedData) {
    for (var entry in extractedData.entries) {
      if (widget.fields.containsKey(entry.key)) {
        switch (entry.key) {
          case 'name':
            _nameController.text = entry.value;
            break;
          case 'email':
            _emailController.text = entry.value;
            break;
          case 'phone':
            _phoneController.text = entry.value;
            break;
          case 'id_number':
            _idNumberController.text = entry.value;
            break;
          case 'kra_pin':
            _kraPinController.text = entry.value;
            break;
          case 'vehicle_value':
            _vehicleValueController.text = entry.value;
            break;
          case 'regno':
            _regnoController.text = entry.value;
            break;
          case 'property_value':
            _propertyValueController.text = entry.value;
            break;
          case 'chassis_number':
            _chassisNumberController.text = entry.value;
            break;
          case 'health_condition':
            _healthConditionController.text = entry.value;
            break;
          case 'travel_destination':
            _travelDestinationController.text = entry.value;
            break;
          case 'employee_count':
            _employeeCountController.text = entry.value;
            break;
        }
      }
    }
  }

  Future<void> _uploadLogbook() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _logbookFile = File(result.files.single.path!);
      });

      final extractedData = await _performOCR(_logbookFile!);
      if (extractedData != null && extractedData.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => GenericDialog(
            title: 'Select Logbook Data',
            extractedData: extractedData,
            onConfirm: (selectedData) {
              _autofillFields(selectedData);
              widget.onAutofillLogbook(_logbookFile!, selectedData);
              Navigator.pop(context);
            },
          ),
        );
      } else {
        widget.onAutofillLogbook(_logbookFile!, null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data extracted from the logbook')),
        );
      }
    }
  }

  Future<void> _uploadPreviousPolicy() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _previousPolicyFile = File(result.files.single.path!);
      });

      final extractedData = await _performOCR(_previousPolicyFile!);
      if (extractedData != null && extractedData.isNotEmpty) {
        final previousCompany = extractedData['insurer'];
        showDialog(
          context: context,
          builder: (context) => GenericDialog(
            title: 'Select Previous Policy Data',
            extractedData: extractedData,
            onConfirm: (selectedData) {
              _autofillFields(selectedData);
              showDialog(
                context: context,
                builder: (context) => CompanySelectionDialog(
                  previousCompany: previousCompany,
                  availableCompanies: _availableCompanies,
                  onConfirm: (selectedCompany) {
                    setState(() => _selectedCompany = selectedCompany);
                    widget.onAutofillPreviousPolicy(
                        _previousPolicyFile!, selectedData, selectedCompany);
                    FirebaseFirestore.instance
                        .collection('autofilled_forms')
                        .add({
                      'user_id': widget.insuredItem?.id ?? 'unknown',
                      'fields': selectedData,
                      'insurer': selectedCompany,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                  },
                ),
              );
            },
          ),
        );
      } else {
        widget.onAutofillPreviousPolicy(_previousPolicyFile!, null, null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data extracted from the document')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.type.toUpperCase()} Cover Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Personal Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                  ),
                  validator: widget.fields['name']?.validator != null
                      ? (String? value) => value != null
                          ? widget.fields['name']!.validator!(value)
                          : 'Required'
                      : (String? value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                  ),
                  validator: widget.fields['email']?.validator != null
                      ? (String? value) => value != null
                          ? widget.fields['email']!.validator!(value)
                          : 'Required'
                      : (String? value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (!RegExp(
                                  r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                              .hasMatch(value)) {
                            return 'Invalid email';
                          }
                          return null;
                        },
                ),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                  ),
                  validator: widget.fields['phone']?.validator != null
                      ? (String? value) => value != null
                          ? widget.fields['phone']!.validator!(value)
                          : 'Required'
                      : (String? value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (!RegExp(r'^[+\d\s\-\(\)]{8,15}$')
                              .hasMatch(value)) {
                            return 'Invalid phone number';
                          }
                          return null;
                        },
                ),
                TextFormField(
                  controller: _idNumberController,
                  decoration: const InputDecoration(
                    labelText: 'ID Number',
                  ),
                  validator: widget.fields['id_number']?.validator != null
                      ? (String? value) => value != null
                          ? widget.fields['id_number']!.validator!(value)
                          : 'Required'
                      : (String? value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (!RegExp(r'^\d{8,}$').hasMatch(value)) {
                            return 'Invalid ID number';
                          }
                          return null;
                        },
                ),
                TextFormField(
                  controller: _kraPinController,
                  decoration: const InputDecoration(
                    labelText: 'KRA PIN',
                  ),
                  validator: widget.fields['kra_pin']?.validator != null
                      ? (String? value) => value != null
                          ? widget.fields['kra_pin']!.validator!(value)
                          : 'Required'
                      : (String? value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (!RegExp(r'^[A-Z]\d{9}[A-Z]$').hasMatch(value)) {
                            return 'Invalid KRA PIN';
                          }
                          return null;
                        },
                ),
                if (widget.type == 'motor') ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Vehicle Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextFormField(
                    controller: _vehicleValueController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Value',
                    ),
                    validator: widget.fields['vehicle_value']?.validator != null
                        ? (String? value) => value != null
                            ? widget.fields['vehicle_value']!.validator!(value)
                            : 'Required'
                        : (String? value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Invalid value';
                            }
                            return null;
                          },
                  ),
                  TextFormField(
                    controller: _regnoController,
                    decoration: const InputDecoration(
                      labelText: 'Registration Number',
                    ),
                    validator: widget.fields['regno']?.validator != null
                        ? (String? value) => value != null
                            ? widget.fields['regno']!.validator!(value)
                            : 'Required'
                        : (String? value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _chassisNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Chassis Number',
                    ),
                    validator: widget.fields['chassis_number']?.validator !=
                            null
                        ? (String? value) => value != null
                            ? widget.fields['chassis_number']!.validator!(value)
                            : 'Required'
                        : (String? value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                  ),
                  ElevatedButton(
                    onPressed: _uploadLogbook,
                    child: Text(
                      _logbookFile == null
                          ? 'Upload Logbook'
                          : 'Logbook Uploaded',
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _uploadPreviousPolicy,
                    child: Text(
                      _previousPolicyFile == null
                          ? 'Upload Previous Policy'
                          : 'Previous Policy Uploaded',
                    ),
                  ),
                  if (_selectedCompany != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Selected Insurer: $_selectedCompany',
                      ),
                    ),
                ],
                if (widget.type == 'medical') ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Medical Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextFormField(
                    controller: _healthConditionController,
                    decoration: const InputDecoration(
                      labelText: 'Health Conditions (if any)',
                    ),
                    validator:
                        widget.fields['health_condition']?.validator != null
                            ? (String? value) => value != null
                                ? widget.fields['health_condition']!
                                    .validator!(value)
                                : null
                            : null,
                  ),
                ],
                if (widget.type == 'travel') ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Travel Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextFormField(
                    controller: _travelDestinationController,
                    decoration: const InputDecoration(
                      labelText: 'Travel Destination',
                    ),
                    validator: widget.fields['travel_destination']?.validator !=
                            null
                        ? (String? value) => value != null
                            ? widget
                                .fields['travel_destination']!.validator!(value)
                            : 'Required'
                        : (String? value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                  ),
                ],
                if (widget.type == 'property') ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Property Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextFormField(
                    controller: _propertyValueController,
                    decoration: const InputDecoration(
                      labelText: 'Property Value',
                    ),
                    validator: widget.fields['property_value']?.validator !=
                            null
                        ? (String? value) => value != null
                            ? widget.fields['property_value']!.validator!(value)
                            : 'Required'
                        : (String? value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Invalid value';
                            }
                            return null;
                          },
                  ),
                ],
                if (widget.type == 'wiba') ...[
                  const SizedBox(height: 16),
                  const Text(
                    'WIBA Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextFormField(
                    controller: _employeeCountController,
                    decoration: const InputDecoration(
                      labelText: 'Number of Employees',
                    ),
                    validator: widget.fields['employee_count']?.validator !=
                            null
                        ? (String? value) => value != null
                            ? widget.fields['employee_count']!.validator!(value)
                            : 'Required'
                        : (String? value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Invalid number';
                            }
                            return null;
                          },
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final details = {
                        if (widget.insuredItem != null)
                          'insured_item_id': widget.insuredItem!.id,
                        'name': _nameController.text,
                        'email': _emailController.text,
                        'phone': _phoneController.text,
                        'id_number': _idNumberController.text,
                        'kra_pin': _kraPinController.text,
                        'insurer': _selectedCompany ?? '',
                        if (widget.type == 'motor') ...{
                          'vehicle_value': _vehicleValueController.text,
                          'regno': _regnoController.text,
                          'chassis_number': _chassisNumberController.text,
                          'logbook_path': _logbookFile?.path ?? '',
                          'previous_policy_path':
                              _previousPolicyFile?.path ?? '',
                        },
                        if (widget.type == 'medical')
                          'health_condition': _healthConditionController.text,
                        if (widget.type == 'travel')
                          'travel_destination':
                              _travelDestinationController.text,
                        if (widget.type == 'property')
                          'property_value': _propertyValueController.text,
                        if (widget.type == 'wiba')
                          'employee_count': _employeeCountController.text,
                      };
                      widget.onSubmit(details);
                      FirebaseFirestore.instance
                          .collection('form_submissions')
                          .add({
                        'user_id': widget.insuredItem?.id ?? 'unknown',
                        'type': widget.type,
                        'subtype': widget.subtype,
                        'coverage_type': widget.coverageType,
                        'details': details,
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _idNumberController.dispose();
    _kraPinController.dispose();
    _vehicleValueController.dispose();
    _regnoController.dispose();
    _propertyValueController.dispose();
    _chassisNumberController.dispose();
    _healthConditionController.dispose();
    _travelDestinationController.dispose();
    _employeeCountController.dispose();
    super.dispose();
  }
}

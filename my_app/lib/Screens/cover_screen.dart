import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_app/Models/Insured_item.dart';
import 'package:my_app/Models/company.dart';
import 'package:my_app/Models/field_definition.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/insurance_app.dart';


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


class CompanySelectionDialog extends StatelessWidget {
  final String? previousCompany;
  final String subtypeId;
  final String coverageTypeId;
  final Function(String?) onConfirm;

  const CompanySelectionDialog({
    super.key,
    this.previousCompany,
    required this.subtypeId,
    required this.coverageTypeId,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        previousCompany != null
            ? 'Previous Insurer Detected: $previousCompany'
            : 'Select Insurance Company',
        style: GoogleFonts.lora(
          color: const Color(0xFF1B263B),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: FutureBuilder<List<Company>>(
        future: InsuranceHomeScreen.getCompanies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading companies'));
          }
          if (snapshot.hasError) {
            if (kDebugMode) print('Error loading companies: ${snapshot.error}');
            return const Text('Failed to load companies');
          }

          final companies = snapshot.data ?? [];
          final eligibleCompanies = companies.where((c) {
            final matchesSubtype = c.policySubtype?.id == subtypeId;
            final matchesCoverage = c.coverageType?.id == coverageTypeId;
            return matchesSubtype || matchesCoverage;
          }).toList();

          if (eligibleCompanies.isEmpty) {
            return const Text('No eligible companies available for this policy');
          }

          final companyNames = eligibleCompanies.map((c) => c.name).toList();
          String? selectedCompany = previousCompany != null && companyNames.contains(previousCompany)
              ? previousCompany
              : null;

          return StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (previousCompany != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Proceed with $previousCompany or choose another?',
                        style: GoogleFonts.roboto(color: const Color(0xFF1B263B)),
                      ),
                    ),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Company',
                      labelStyle: GoogleFonts.roboto(color: const Color(0xFFD3D3D3)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF8B0000)),
                      ),
                    ),
                    value: selectedCompany,
                    hint: Text('Select Company', style: GoogleFonts.roboto()),
                    items: companyNames
                        .map((company) => DropdownMenuItem(
                              value: company,
                              child: Text(
                                company,
                                style: GoogleFonts.roboto(color: const Color(0xFF1B263B)),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => selectedCompany = value),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.roboto(color: const Color(0xFFD3D3D3)),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          onConfirm(selectedCompany);
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Confirm',
                          style: GoogleFonts.roboto(color: const Color(0xFF8B0000)),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class CoverDetailScreen extends StatefulWidget {
  final String type;
  final String subtype;
  final String coverageType;
  final InsuredItem? insuredItem;
  final Function(Map<String, String>) onSubmit; // Not used directly
  final Function(File, Map<String, String>?, String?) onAutofillPreviousPolicy;
  final Function(File, Map<String, String>?) onAutofillLogbook;
  final Map<String, FieldDefinition> fields;
  final Future<void> Function(
    BuildContext context,
    String type,
    String subtype,
    String coverageType,
    Map<String, String> details, {
    String? preSelectedCompany,
    required String subtypeId,
    required String coverageTypeId,
  }) showCompanyDialog; // Kept for compatibility
  final String? preSelectedCompany; // Added

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
    required this.showCompanyDialog,
    this.preSelectedCompany, // Added
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
  String? _subtypeId;
  String? _coverageTypeId;

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
      _healthConditionController.text = widget.insuredItem!.details['health_condition'] ?? '';
      _travelDestinationController.text = widget.insuredItem!.details['travel_destination'] ?? '';
      _employeeCountController.text = widget.insuredItem!.details['employee_count'] ?? '';
      _logbookFile = widget.insuredItem!.logbookPath != null ? File(widget.insuredItem!.logbookPath!) : null;
      _previousPolicyFile = widget.insuredItem!.previousPolicyPath != null ? File(widget.insuredItem!.previousPolicyPath!) : null;
      _selectedCompany = widget.insuredItem!.details['insurer'] ?? widget.preSelectedCompany;
    } else {
      _selectedCompany = widget.preSelectedCompany;
    }

    _initializeIds();
  }

  Future<void> _initializeIds() async {
    try {
      final subtype = Company.allPolicySubtypes.firstWhere(
        (s) => s.name.toLowerCase() == widget.subtype.toLowerCase(),
        orElse: () => Company.allPolicySubtypes.first,
      );
      final coverageType = Company.allCoverageTypes.firstWhere(
        (c) => c.name.toLowerCase() == widget.coverageType.toLowerCase(),
        orElse: () => Company.allCoverageTypes.first,
      );

      setState(() {
        _subtypeId = subtype.id;
        _coverageTypeId = coverageType.id;
      });
    } catch (e, stackTrace) {
      if (kDebugMode) print('Error initializing IDs: $e\n$stackTrace');
    }
  }

  Future<Map<String, String>?> _performOCR(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      final requestBody = {
        'model': 'gpt-4o',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text':
                    'Extract the following fields from the provided document (logbook or insurance policy): name, email, phone, id_number, kra_pin, vehicle_value, regno, chassis_number, health_condition, travel_destination, employee_count, insurer. Return as a JSON object.',
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
        final extracted = jsonDecode(data['choices'][0]['message']['content']) as Map<String, dynamic>;
        return extracted.map((key, value) => MapEntry(key, value.toString()));
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('OpenAI OCR Error: $e');
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
              if (_subtypeId != null && _coverageTypeId != null) {
                showDialog(
                  context: context,
                  builder: (context) => CompanySelectionDialog(
                    previousCompany: previousCompany,
                    subtypeId: _subtypeId!,
                    coverageTypeId: _coverageTypeId!,
                    onConfirm: (selectedCompany) {
                      setState(() => _selectedCompany = selectedCompany ?? _selectedCompany);
                      widget.onAutofillPreviousPolicy(_previousPolicyFile!, selectedData, selectedCompany);
                      FirebaseFirestore.instance.collection('autofilled_forms').add({
                        'user_id': widget.insuredItem?.id ?? 'unknown',
                        'fields': selectedData,
                        'insurer': selectedCompany ?? 'none',
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                    },
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Policy details not loaded yet')),
                );
              }
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
    final InsuranceHomeScreen insuranceHomeScreen;
    // Ensure insuredItem is not null before proceeding
    final String? insuredItemId = widget.insuredItem?.id;
    if (insuredItemId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.type.toUpperCase()} Cover Details'),
        ),
        body: const Center(child: Text('No insured item selected')),
      );
    }

    final String? preSelectedCompany = widget.preSelectedCompany;
      if (preSelectedCompany != null && _selectedCompany == null) {
        _selectedCompany = preSelectedCompany;
      }
      // Ensure subtypeId and coverageTypeId are initialized before building the form
      if (_subtypeId == null && _coverageTypeId == null) {
        _initializeIds();
      }

      if (_subtypeId == null || _coverageTypeId == null) {
        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.type.toUpperCase()} Cover Details'),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: widget.fields['name']?.validator != null
                      ? (String? value) => value != null ? widget.fields['name']!.validator!(value) : 'Required'
                      : (String? value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: widget.fields['email']?.validator != null
                      ? (String? value) => value != null ? widget.fields['email']!.validator!(value) : 'Required'
                      : (String? value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (!RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(value)) return 'Invalid email';
                          return null;
                        },
                ),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  validator: widget.fields['phone']?.validator != null
                      ? (String? value) => value != null ? widget.fields['phone']!.validator!(value) : 'Required'
                      : (String? value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (!RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)) return 'Invalid phone number';
                          return null;
                        },
                ),
                TextFormField(
                  controller: _idNumberController,
                  decoration: const InputDecoration(labelText: 'ID Number'),
                  validator: widget.fields['id_number']?.validator != null
                      ? (String? value) => value != null ? widget.fields['id_number']!.validator!(value) : 'Required'
                      : (String? value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (!RegExp(r'^\d{8,}$').hasMatch(value)) return 'Invalid ID number';
                          return null;
                        },
                ),
                TextFormField(
                  controller: _kraPinController,
                  decoration: const InputDecoration(labelText: 'KRA PIN'),
                  validator: widget.fields['kra_pin']?.validator != null
                      ? (String? value) => value != null ? widget.fields['kra_pin']!.validator!(value) : 'Required'
                      : (String? value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (!RegExp(r'^[A-Z]\d{9}[A-Z]$').hasMatch(value)) return 'Invalid KRA PIN';
                          return null;
                        },
                ),
                if (widget.type == 'motor') ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Vehicle Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextFormField(
                    controller: _vehicleValueController,
                    decoration: const InputDecoration(labelText: 'Vehicle Value'),
                    validator: widget.fields['vehicle_value']?.validator != null
                        ? (String? value) => value != null ? widget.fields['vehicle_value']!.validator!(value) : 'Required'
                        : (String? value) {
                            if (value == null || value.isEmpty) return 'Required';
                            if (double.tryParse(value) == null) return 'Invalid value';
                            return null;
                          },
                  ),
                  TextFormField(
                    controller: _regnoController,
                    decoration: const InputDecoration(labelText: 'Registration Number'),
                    validator: widget.fields['regno']?.validator != null
                        ? (String? value) => value != null ? widget.fields['regno']!.validator!(value) : 'Required'
                        : (String? value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _chassisNumberController,
                    decoration: const InputDecoration(labelText: 'Chassis Number'),
                    validator: widget.fields['chassis_number']?.validator != null
                        ? (String? value) => value != null ? widget.fields['chassis_number']!.validator!(value) : 'Required'
                        : (String? value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                  ElevatedButton(
                    onPressed: _uploadLogbook,
                    child: Text(_logbookFile == null ? 'Upload Logbook' : 'Logbook Uploaded'),
                  ),
                  ElevatedButton(
                    onPressed: _uploadPreviousPolicy,
                    child: Text(_previousPolicyFile == null ? 'Upload Previous Policy' : 'Previous Policy Uploaded'),
                  ),
                  if (_selectedCompany != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Selected Insurer: $_selectedCompany',
                        style: GoogleFonts.roboto(color: const Color(0xFF1B263B)),
                      ),
                    ),
                ],
                if (widget.type == 'medical') ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Medical Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextFormField(
                    controller: _healthConditionController,
                    decoration: const InputDecoration(labelText: 'Health Conditions (if any)'),
                    validator: widget.fields['health_condition']?.validator != null
                        ? (String? value) => value != null ? widget.fields['health_condition']!.validator!(value) : null
                        : null,
                  ),
                ],
                if (widget.type == 'travel') ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Travel Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextFormField(
                    controller: _travelDestinationController,
                    decoration: const InputDecoration(labelText: 'Travel Destination'),
                    validator: widget.fields['travel_destination']?.validator != null
                        ? (String? value) => value != null ? widget.fields['travel_destination']!.validator!(value) : 'Required'
                        : (String? value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                ],
                if (widget.type == 'property') ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Property Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextFormField(
                    controller: _propertyValueController,
                    decoration: const InputDecoration(labelText: 'Property Value'),
                    validator: widget.fields['property_value']?.validator != null
                        ? (String? value) => value != null ? widget.fields['property_value']!.validator!(value) : 'Required'
                        : (String? value) {
                            if (value == null || value.isEmpty) return 'Required';
                            if (double.tryParse(value) == null) return 'Invalid value';
                            return null;
                          },
                  ),
                ],
                if (widget.type == 'wiba') ...[
                  const SizedBox(height: 16),
                  const Text(
                    'WIBA Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextFormField(
                    controller: _employeeCountController,
                    decoration: const InputDecoration(labelText: 'Number of Employees'),
                    validator: widget.fields['employee_count']?.validator != null
                        ? (String? value) => value != null ? widget.fields['employee_count']!.validator!(value) : 'Required'
                        : (String? value) {
                            if (value == null || value.isEmpty) return 'Required';
                            if (int.tryParse(value) == null) return 'Invalid number';
                            return null;
                          },
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    if (kDebugMode) print('CoverDetailScreen submit pressed');
                    if (_formKey.currentState!.validate()) {
                      final details = {
                        if (widget.insuredItem != null) 'insured_item_id': widget.insuredItem!.id,
                        'name': _nameController.text,
                        'email': _emailController.text,
                        'phone': _phoneController.text,
                        'id_number': _idNumberController.text,
                        'kra_pin': _kraPinController.text,
                        if (widget.type == 'motor') ...{
                          'vehicle_value': _vehicleValueController.text,
                          'regno': _regnoController.text,
                          'chassis_number': _chassisNumberController.text,
                          'logbook_path': _logbookFile?.path ?? '',
                          'previous_policy_path': _previousPolicyFile?.path ?? '',
                        },
                        if (widget.type == 'medical') 'health_condition': _healthConditionController.text,
                        if (widget.type == 'travel') 'travel_destination': _travelDestinationController.text,
                        if (widget.type == 'property') 'property_value': _propertyValueController.text,
                        if (widget.type == 'wiba') 'employee_count': _employeeCountController.text,
                      };

                      if (_selectedCompany == null) {
                        if (kDebugMode) print('No company selected');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select an insurance company')),
                        );
                        return;
                      }

                      if (_subtypeId != null && _coverageTypeId != null) {
                        try {
                          // Fetch company ID and PDF template
                          final companies = await InsuranceHomeScreen.getCompanies();
                          final company = companies.firstWhere(
                            (c) => c.name == _selectedCompany,
                            orElse: () => throw Exception('Company not found'),
                          );
                          final cachedPdfTemplates = await InsuranceHomeScreen.getCachedPdfTemplates();
                          final pdfTemplateKey = company.pdfTemplateKey.firstWhere(
                            (key) => cachedPdfTemplates.containsKey(key),
                            orElse: () => 'default',
                          );

                          // Submit to Firestore
                          await FirebaseFirestore.instance.collection('form_submissions').add({
                            'user_id': widget.insuredItem?.id ?? 'unknown',
                            'type': widget.type,
                            'subtype': widget.subtype,
                            'coverage_type': widget.coverageType,
                            'company_id': company.id,
                            'pdf_template_key': pdfTemplateKey,
                            'details': details,
                            'timestamp': FieldValue.serverTimestamp(),
                          });

                          if (kDebugMode) print('Form submitted successfully');

                          // Guard context usage after async gap
                          if (!mounted) return;

                            final insuranceHomeScreenState = context.findAncestorStateOfType<InsuranceHomeScreenState>();
                            if (insuranceHomeScreenState != null) {
                              await insuranceHomeScreenState.handleCoverSubmission(
                              context,
                              widget.type,
                              widget.subtype,
                              widget.coverageType,
                              company.id,
                              pdfTemplateKey,
                              details,
                              );
                            }
                              // No additional code needed here for InsuranceHomeScreenState usage.
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        } catch (e, stackTrace) {
                          if (kDebugMode) print('Error submitting form: $e\n$stackTrace');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to submit form')),
                            );
                          }
                        }
                      } else {
                        if (kDebugMode) print('Policy details not loaded: subtypeId=$_subtypeId, coverageTypeId=$_coverageTypeId');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Policy details not loaded yet')),
                        );
                      }
                    } else {
                      if (kDebugMode) print('Form validation failed in CoverDetailScreen');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B0000),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Submit',
                    style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
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
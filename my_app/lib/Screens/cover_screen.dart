import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:my_app/Models/Insured_item.dart';
import 'package:pdf_text/pdf_text.dart';

class CoverDetailScreen extends StatefulWidget {
  final String type;
  final String subtype;
  final String coverageType;
  final InsuredItem? insuredItem;
  final Function(Map<String, String>) onSubmit;

  const CoverDetailScreen({
    super.key,
    required this.type,
    required this.subtype,
    required this.coverageType,
    this.insuredItem,
    required this.onSubmit,
  });

  @override
  State<CoverDetailScreen> createState() => _CoverDetailScreenState();
}

class _CoverDetailScreenState extends State<CoverDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleValueController = TextEditingController();
  final _regnoController = TextEditingController();
  final _propertyValueController = TextEditingController();
  final _chassisNumberController = TextEditingController();
  final _kraPinController = TextEditingController();
  final _healthConditionController = TextEditingController();
  final _travelDestinationController = TextEditingController();
  final _employeeCountController = TextEditingController();
  File? _logbookFile;
  File? _previousPolicyFile;

  @override
  void initState() {
    super.initState();
    if (widget.insuredItem != null) {
      _nameController.text = widget.insuredItem!.details['name'] ?? '';
      _emailController.text = widget.insuredItem!.details['email'] ?? '';
      _phoneController.text = widget.insuredItem!.details['phone'] ?? '';
      _vehicleValueController.text = widget.insuredItem!.vehicleValue ?? '';
      _regnoController.text = widget.insuredItem!.regno ?? '';
      _propertyValueController.text = widget.insuredItem!.propertyValue ?? '';
      _chassisNumberController.text = widget.insuredItem!.chassisNumber ?? '';
      _kraPinController.text = widget.insuredItem!.kraPin ?? '';
      _healthConditionController.text =
          widget.insuredItem!.details['health_condition'] ?? '';
      _travelDestinationController.text =
          widget.insuredItem!.details['travel_destination'] ?? '';
      _employeeCountController.text =
          widget.insuredItem!.details['employee_count'] ?? '';
      _logbookFile =
          widget.insuredItem!.logbookPath != null
              ? File(widget.insuredItem!.logbookPath!)
              : null;
      _previousPolicyFile =
          widget.insuredItem!.previousPolicyPath != null
              ? File(widget.insuredItem!.previousPolicyPath!)
              : null;
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
        _autofillFromPreviousPolicy(_previousPolicyFile!);
      });
    }
  }

  Future<void> _autofillFromPreviousPolicy(File pdfFile) async {
    try {
      PDFDoc doc = await PDFDoc.fromPath(pdfFile.path);
      String text = await doc.text;
      // Simulate extracting data from PDF (in practice, use regex or NLP)
      // For demo, assume text contains key-value pairs like "Name: John Doe"
      final lines = text.split('\n');
      final extracted = <String, String>{};
      for (var line in lines) {
        if (line.contains('Name:')) {
          extracted['name'] = line.split(':').last.trim();
        }
        if (line.contains('Email:')) {
          extracted['email'] = line.split(':').last.trim();
        }
        if (line.contains('Phone:')) {
          extracted['phone'] = line.split(':').last.trim();
        }
        if (line.contains('Registration Number:')) {
          extracted['regno'] = line.split(':').last.trim();
        }
        if (line.contains('Vehicle Value:')) {
          extracted['vehicle_value'] = line.split(':').last.trim();
        }
        if (line.contains('Chassis Number:')) {
          extracted['chassis_number'] = line.split(':').last.trim();
        }
        if (line.contains('KRA Pin:')) {
          extracted['kra_pin'] = line.split(':').last.trim();
        }
      }
      setState(() {
        _nameController.text = extracted['name'] ?? _nameController.text;
        _emailController.text = extracted['email'] ?? _emailController.text;
        _phoneController.text = extracted['phone'] ?? _phoneController.text;
        _chassisNumberController.text =
            extracted['chassis_number'] ?? _chassisNumberController.text;
        _kraPinController.text = extracted['kra_pin'] ?? _kraPinController.text;
        if (extracted['regno'] != null) {
          formResponses['regno'] = extracted['regno']!;
        }
        if (extracted['vehicle_value'] != null) {
          formResponses['vehicle_value'] = extracted['vehicle_value']!;
        }
      });
    } catch (e) {
      print('Error autofilling from previous policy: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.type.toUpperCase()} Cover Details')),
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
                  validator:
                      (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator:
                      (value) =>
                          value?.isEmpty ??
                                  true ||
                                      !RegExp(
                                        r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                                      ).hasMatch(value!)
                              ? 'Invalid email'
                              : null,
                ),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  validator:
                      (value) =>
                          value?.isEmpty ??
                                  true ||
                                      !RegExp(
                                        r'^[+\d\s\-\(\)]{8,15}$',
                                      ).hasMatch(value!)
                              ? 'Invalid phone number'
                              : null,
                ),
                if (widget.type == 'motor') ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Vehicle Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextFormField(
                    controller: _vehicleValueController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Value',
                    ),
                    validator:
                        (value) =>
                            value?.isEmpty ??
                                    true || double.tryParse(value!) == null
                                ? 'Invalid value'
                                : null,
                  ),
                  TextFormField(
                    controller: _regnoController,
                    decoration: const InputDecoration(
                      labelText: 'Registration Number',
                    ),
                  ),
                  TextFormField(
                    controller: _chassisNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Chassis Number',
                    ),
                  ),
                  TextFormField(
                    controller: _kraPinController,
                    decoration: const InputDecoration(labelText: 'KRA Pin'),
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
                ],
                if (widget.type == 'medical') ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Medical Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextFormField(
                    controller: _healthConditionController,
                    decoration: const InputDecoration(
                      labelText: 'Health Conditions (if any)',
                    ),
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
                    decoration: const InputDecoration(
                      labelText: 'Travel Destination',
                    ),
                    validator:
                        (value) => value?.isEmpty ?? true ? 'Required' : null,
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
                    decoration: const InputDecoration(
                      labelText: 'Property Value',
                    ),
                    validator:
                        (value) =>
                            value?.isEmpty ??
                                    true || double.tryParse(value!) == null
                                ? 'Invalid value'
                                : null,
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
                    decoration: const InputDecoration(
                      labelText: 'Number of Employees',
                    ),
                    validator:
                        (value) =>
                            value?.isEmpty ??
                                    true || int.tryParse(value!) == null
                                ? 'Invalid number'
                                : null,
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
                        if (widget.type == 'motor') ...{
                          'vehicle_value': _vehicleValueController.text,
                          'regno': _regnoController.text,
                          'chassis_number': _chassisNumberController.text,
                          'kra_pin': _kraPinController.text,
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
}

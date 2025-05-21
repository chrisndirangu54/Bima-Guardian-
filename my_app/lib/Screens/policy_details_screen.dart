import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class PolicyDetailScreen extends StatefulWidget {
  final String type;
  final String subtype;
  final String coverageType;
  final Function(Map<String, String>) onSubmit;

  const PolicyDetailScreen({
    super.key,
    required this.type,
    required this.subtype,
    required this.coverageType,
    required this.onSubmit,
  });

  @override
  State<PolicyDetailScreen> createState() => _PolicyDetailScreenState();
}

class _PolicyDetailScreenState extends State<PolicyDetailScreen> {
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

  Future<void> _uploadLogbook() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.type.toUpperCase()} Policy Details'),
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
                  child: const Text('Submit Details'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

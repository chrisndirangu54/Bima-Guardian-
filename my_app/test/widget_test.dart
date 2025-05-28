// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}

/*
final policies = Provider.of<PolicyProvider>(context).policies;

class Policy {
  final String id;
  final String type;
  final String subtype;
  final String companyId;
  final CoverStatus status;
  final String? insuredItemId;
  final String? coverageType;
  final String? pdfTemplateKey;
  final DateTime? endDate;
  final Map<String, FieldDefinition> fieldDefinitions; // Added field mapping
  final List<String> coverageTypes; // Added coverage types

  Policy({
    required this.id,
    required this.type,
    required this.subtype,
    required this.companyId,
    required this.status,
    this.insuredItemId,
    this.coverageType,
    this.pdfTemplateKey,
    this.endDate,
    required this.fieldDefinitions, // Required field definitions
    required this.coverageTypes, // Required coverage types
  });

  factory Policy.fromJson(Map<String, dynamic> json) {
    return Policy(
      id: json['id'] as String,
      type: json['type'] as String,
      subtype: json['subtype'] as String,
      companyId: json['companyId'] as String,
      status: CoverStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => CoverStatus.active,
      ),
      insuredItemId: json['insuredItemId'] as String? ?? '',
      coverageType: json['coverageType'] as String? ?? '',
      pdfTemplateKey: json['pdfTemplateKey'] as String? ?? '',
      endDate: json['endDate'] != null
          ? (json['endDate'] as Timestamp).toDate()
          : null,
      fieldDefinitions: (json['fieldDefinitions'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(
                key,
                FieldDefinition.fromJson(value),
              )),
      coverageTypes: List<String>.from(
          json['coverageTypes'] as List<dynamic>? ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'subtype': subtype,
        'companyId': companyId,
        'status': status.toString(),
        'insuredItemId': insuredItemId,
        'coverageType': coverageType,
        'pdfTemplateKey': pdfTemplateKey,
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'fieldDefinitions': fieldDefinitions.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'coverageTypes': coverageTypes,
      };
}
Map<String, FieldDefinition> _getFieldMap(Policy policy) {
  return policy.fieldDefinitions.isNotEmpty
      ? policy.fieldDefinitions
      : <String, FieldDefinition>{}; // fallback to empty map
}
  
Widget _buildHomeScreen(BuildContext context, List<Policy> policies) {
  final Map<String, Set<String>> policyTypesMap = {};

  for (final policy in policies) {
    if (!policyTypesMap.containsKey(policy.type)) {
      policyTypesMap[policy.type] = {};
    }
    policyTypesMap[policy.type]!.add(policy.subtype);
  }

  // Convert Set<String> to List<String> for UI usage
  final policyTypes = policyTypesMap.map(
    (key, value) => MapEntry(key, value.toList()),
  );
change the below functions to dynamically get mappings from:



class Policy {
  final String id;
  final String type;
  final String subtype;
  final String companyId;
  final CoverStatus status;
  final String? insuredItemId;
  final String? coverageType;
  final String? pdfTemplateKey;
  final DateTime? endDate;
  final Map<String, FieldDefinition> fieldDefinitions; // Added field mapping
  final List<String> coverageTypes; // Added coverage types

  Policy({
    required this.id,
    required this.type,
    required this.subtype,
    required this.companyId,
    required this.status,
    this.insuredItemId,
    this.coverageType,
    this.pdfTemplateKey,
    this.endDate,
    required this.fieldDefinitions, // Required field definitions
    required this.coverageTypes, // Required coverage types
  });

  factory Policy.fromJson(Map<String, dynamic> json) {
    return Policy(
      id: json['id'] as String,
      type: json['type'] as String,
      subtype: json['subtype'] as String,
      companyId: json['companyId'] as String,
      status: CoverStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => CoverStatus.active,
      ),
      insuredItemId: json['insuredItemId'] as String? ?? '',
      coverageType: json['coverageType'] as String? ?? '',
      pdfTemplateKey: json['pdfTemplateKey'] as String? ?? '',
      endDate: json['endDate'] != null
          ? (json['endDate'] as Timestamp).toDate()
          : null,
      fieldDefinitions: (json['fieldDefinitions'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(
                key,
                FieldDefinition.fromJson(value),
              )),
      coverageTypes: List<String>.from(
          json['coverageTypes'] as List<dynamic>? ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'subtype': subtype,
        'companyId': companyId,
        'status': status.toString(),
        'insuredItemId': insuredItemId,
        'coverageType': coverageType,
        'pdfTemplateKey': pdfTemplateKey,
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'fieldDefinitions': fieldDefinitions.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'coverageTypes': coverageTypes,
      };
}




now update:
  Future<void> _handleChatInput(String input) async {
    setState(() {
      chatMessages.add({'sender': 'user', 'text': input});
    });

    var currentStateData = chatbotTemplate['states'][currentState];
    Map<String, FieldDefinition> fields;
    String? insuranceType = formResponses['insurance_type'];
    switch (insuranceType) {
      case 'Motor':
        fields = motorFields;
        break;
      case 'Medical':
        fields = medicalFields;
        break;
      case 'Property':
        fields = propertyFields;
        break;
      default:
        fields = motorFields; // Fallback for initial states
    }

    if (currentState == 'start') {
      int? choice = int.tryParse(input);
      if (choice != null &&
          choice >= 1 &&
          choice <= currentStateData['options'].length) {
        setState(() {
          currentState = currentStateData['options'][choice - 1]['next'];
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                (chatbotTemplate['states'][currentState]['options']
                        ?.asMap()
                        .entries
                        .map((e) => '${e.key + 1}. ${e.value['text']}')
                        .join('\n') ??
                    ''),
          });
        });
      } else {
        _showError(
          'Please select a valid option (1-${currentStateData['options'].length}).',
        );
      }
    } else if (currentState == 'insurance_type') {
      int? choice = int.tryParse(input);
      if (choice != null && choice >= 1 && choice <= 3) {
        setState(() {
          formResponses['insurance_type'] =
              ['Motor', 'Medical', 'Property'][choice - 1];
          currentState = [
            'vehicle_type',
            'medical_policy_type',
            'property_type'
          ][choice - 1];
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                (chatbotTemplate['states'][currentState]['options']
                        ?.asMap()
                        .entries
                        .map((e) => '${e.key + 1}. ${e.value['text']}')
                        .join('\n') ??
                    ''),
          });
        });
      } else {
        _showError(
          'Please select 1 for Motor, 2 for Medical, or 3 for Property.',
        );
      }
    } else if (currentState == 'vehicle_type' && insuranceType == 'Motor') {
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= _vehicleTypes.length) {
        setState(() {
          formResponses['vehicle_type'] = _vehicleTypes[choice - 1];
          currentState = 'quote_type';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                currentStateData['options'][choice - 1]['next']['options']
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value['text']}')
                    .join('\n'),
          });
        });
      } else {
        _showError(
          'Please select a valid vehicle type (1-${_vehicleTypes.length}).',
        );
      }
    } else if (currentState == 'property_type' && insuranceType == 'Property') {
      int? choice = int.tryParse(input);
      List<String> propertyTypes = [
        'residential',
        'commercial',
        'industrial',
        'landlord',
      ];
      if (choice != null && choice > 0 && choice <= propertyTypes.length) {
        setState(() {
          formResponses['property_type'] = propertyTypes[choice - 1];
          currentState = 'quote_type';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                chatbotTemplate['states'][currentState]['options']
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value['text']}')
                    .join('\n'),
          });
        });
      } else {
        _showError(
          'Please select a valid property type (1-${propertyTypes.length}).',
        );
      }
    } else if (currentState == 'quote_type') {
      int? choice = int.tryParse(input);
      if (choice != null && choice >= 1 && choice <= 3) {
        setState(() {
          formResponses['quote_type'] = [
            'Auto Insurance',
            'Home Insurance',
            'Health Insurance'
          ][choice - 1];
          currentState = [
            'quote_auto_subtype',
            'quote_home_subtype',
            'health_inpatient_limit',
          ][choice - 1];
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                (chatbotTemplate['states'][currentState]['options']
                        ?.asMap()
                        .entries
                        .map((e) => '${e.key + 1}. ${e.value['text']}')
                        .join('\n') ??
                    ''),
          });
        });
      } else {
        _showError(
          'Please select 1 for Auto, 2 for Home, or 3 for Health Insurance.',
        );
      }
    } else if (currentState == 'quote_auto_subtype' &&
        insuranceType == 'Motor') {
      List<String> subtypes = [
        'commercial',
        'psv',
        'psv_uber',
        'private',
        'tuk_tuk',
        'special_classes',
      ];
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= subtypes.length) {
        setState(() {
          formResponses['subtype'] = subtypes[choice - 1];
          currentState = 'quote_filling';
          currentStateData = chatbotTemplate['states'][currentState];
          currentStateData['fields'] = motorFields.keys
              .where((key) => !['vehicle_type'].contains(key))
              .map(
                (key) => {
                  'name': key,
                  'prompt': 'Please enter your $key for motor quote:',
                },
              )
              .toList();
          currentFieldIndex = 0;
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['fields'][0]['prompt'],
          });
        });
      } else {
        _showError(
          'Please select a valid motor subtype (1-${subtypes.length}).',
        );
      }
    } else if (currentState == 'quote_home_subtype' &&
        insuranceType == 'Property') {
      List<String> subtypes = [
        'residential',
        'commercial',
        'industrial',
        'landlord',
      ];
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= subtypes.length) {
        setState(() {
          formResponses['subtype'] = subtypes[choice - 1];
          currentState = 'quote_filling';
          currentStateData = chatbotTemplate['states'][currentState];
          currentStateData['fields'] = propertyFields.keys
              .where((key) => !['property_type'].contains(key))
              .map(
                (key) => {
                  'name': key,
                  'prompt': 'Please enter your $key for property quote:',
                },
              )
              .toList();
          currentFieldIndex = 0;
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['fields'][0]['prompt'],
          });
        });
      } else {
        _showError(
          'Please select a valid property subtype (1-${subtypes.length}).',
        );
      }
    } else if (currentState == 'quote_filling') {
      var fieldsList = currentStateData['fields'];
      if (currentFieldIndex < fieldsList.length) {
        var field = fieldsList[currentFieldIndex];
        String fieldName = field['name'];
        String? error = fields[fieldName]!.validator!(input);

        if (error == null) {
          formResponses[fieldName] = input;
          currentFieldIndex++;
          if (currentFieldIndex < fieldsList.length) {
            setState(() {
              chatMessages.add({
                'sender': 'bot',
                'text': fieldsList[currentFieldIndex]['prompt'],
              });
            });
          } else {
            String summary = formResponses.entries
                .map((e) => '${e.key}: ${e.value}')
                .join('\n');
            setState(() {
              currentState = 'quote_summary';
              chatMessages.add({
                'sender': 'bot',
                'text':
                    'Here’s what you’ve entered:\n$summary\nIs this correct?\n1. Yes\n2. No',
              });
            });
          }
        } else {
          setState(() {
            chatMessages.add({
              'sender': 'bot',
              'text': 'Error: $error. Please try again.',
            });
            chatMessages.add({'sender': 'bot', 'text': field['prompt']});
          });
        }
      }
    } else if (currentState == 'quote_summary') {
      int? choice = int.tryParse(input);
      if (choice == 1) {
        double premium = await _calculatePremium(
          formResponses['insurance_type']!.toLowerCase(),
          formResponses['subtype']!,
          formResponses,
        );
        Quote quote = Quote(
          id: Uuid().v4(),
          type: formResponses['insurance_type']!.toLowerCase(),
          subtype: formResponses['subtype']!,
          company: _selectedUnderwriters.isNotEmpty
              ? _selectedUnderwriters[0]
              : 'default',
          premium: premium,
          formData: Map<String, String>.from(formResponses),
          generatedAt: DateTime.now(),
        );
        setState(() {
          quotes.add(quote);
          currentState = 'quote_process';
          chatMessages.add({
            'sender': 'bot',
            'text': 'Your quote has been generated and sent for processing.',
          });
        });
        await _saveQuotes();
        File? quotePdf = await _generateQuotePdf(quote);
        if (quotePdf != null) {
          await _sendEmail(
            quote.company,
            quote.type,
            quote.subtype,
            quote.formData,
            quotePdf,
            quote.formData['regno'] ?? '', // Provide registrationNumber if available
            quote.formData['vehicle_type'] ?? '', // Provide vehicleType if available
          );
        }
      } else if (choice == 2) {
        setState(() {
          currentState = 'quote_filling';
          currentFieldIndex = 0;
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['fields'][0]['prompt'],
          });
        });
      } else {
        _showError('Please select 1 for Yes or 2 for No.');
      }
    } else if (currentState == 'medical_policy_type' &&
        insuranceType == 'Medical') {
      int? choice = int.tryParse(input);
      if (choice != null && choice >= 1 && choice <= 2) {
        setState(() {
          formResponses['policy_type'] =
              choice == 1 ? 'Individual' : 'Corporate';
          currentState =
              choice == 1 ? 'health_inpatient_limit' : 'health_beneficiaries';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                (chatbotTemplate['states'][currentState]['options']
                        ?.asMap()
                        .entries
                        .map((e) => '${e.key + 1}. ${e.value['text']}')
                        .join('\n') ??
                    ''),
          });
        });
      } else {
        _showError('Please select 1 for Individual or 2 for Corporate.');
      }
    } else if (currentState == 'health_beneficiaries' &&
        insuranceType == 'Medical') {
      String? error = medicalFields['beneficiaries']!.validator!(input);
      if (error == null) {
        setState(() {
          formResponses['beneficiaries'] = input;
          currentState = 'health_inpatient_limit';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                chatbotTemplate['states'][currentState]['options']
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value['text']}')
                    .join('\n'),
          });
        });
      } else {
        setState(() {
          chatMessages.add({
            'sender': 'bot',
            'text': 'Error: $error. Please try again.',
          });
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['message'],
          });
        });
      }
    } else if (currentState == 'health_inpatient_limit' &&
        insuranceType == 'Medical') {
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= _inpatientLimits.length) {
        setState(() {
          formResponses['inpatient_limit'] = _inpatientLimits[choice - 1];
          currentState = 'health_outpatient_limit';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'],
          });
        });
      } else {
        _showError(
          'Please select a valid inpatient limit (1-${_inpatientLimits.length}).',
        );
      }
    } else if (currentState == 'health_outpatient_limit' &&
        insuranceType == 'Medical') {
      String? error = medicalFields['outpatient_limit']!.validator!(input);
      if (error == null) {
        setState(() {
          formResponses['outpatient_limit'] = input;
          currentState = 'health_dental_limit';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'],
          });
        });
      } else {
        setState(() {
          chatMessages.add({
            'sender': 'bot',
            'text': 'Error: $error. Please try again.',
          });
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['message'],
          });
        });
      }
    } else if (currentState == 'health_dental_limit' &&
        insuranceType == 'Medical') {
      String? error = medicalFields['dental_limit']!.validator!(input);
      if (error == null) {
        setState(() {
          formResponses['dental_limit'] = input;
          currentState = 'health_optical_limit';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'],
          });
        });
      } else {
        setState(() {
          chatMessages.add({
            'sender': 'bot',
            'text': 'Error: $error. Please try again.',
          });
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['message'],
          });
        });
      }
    } else if (currentState == 'health_optical_limit' &&
        insuranceType == 'Medical') {
      String? error = medicalFields['optical_limit']!.validator!(input);
      if (error == null) {
        setState(() {
          formResponses['optical_limit'] = input;
          currentState = 'health_maternity_limit';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'],
          });
        });
      } else {
        setState(() {
          chatMessages.add({
            'sender': 'bot',
            'text': 'Error: $error. Please try again.',
          });
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['message'],
          });
        });
      }
    } else if (currentState == 'health_maternity_limit' &&
        insuranceType == 'Medical') {
      String? error = medicalFields['maternity_limit']!.validator!(input);
      if (error == null) {
        setState(() {
          formResponses['maternity_limit'] = input;
          currentState = 'health_medical_services';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'],
          });
        });
      } else {
        setState(() {
          chatMessages.add({
            'sender': 'bot',
            'text': 'Error: $error. Please try again.',
          });
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['message'],
          });
        });
      }
    } else if (currentState == 'health_medical_services' &&
        insuranceType == 'Medical') {
      final choices = input
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .where((e) => e != null)
          .toList();
      if (choices.every((c) => c! > 0 && c <= _medicalServices.length)) {
        setState(() {
          _selectedMedicalServices =
              choices.map((c) => _medicalServices[c! - 1]).toList();
          formResponses['medical_services'] = _selectedMedicalServices.join(
            ', ',
          );
          currentState = 'health_personal_info';
          currentStateData = chatbotTemplate['states'][currentState];
          currentFieldIndex = 0;
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['fields'][0]['prompt'],
          });
        });
      } else {
        _showError('Please select valid medical services (e.g., 1,2).');
      }
    } else if (currentState == 'health_personal_info' &&
        insuranceType == 'Medical') {
      var fieldsList = currentStateData['fields'];
      if (currentFieldIndex < fieldsList.length) {
        var field = fieldsList[currentFieldIndex];
        String fieldName = field['name'];
        String? error;

        if (fieldName == 'has_spouse' || fieldName == 'has_children') {
          if (input == '1' || input == '2') {
            formResponses[fieldName] = input == '1' ? 'Yes' : 'No';
            if (fieldName == 'has_spouse' && input == '2') {
              currentFieldIndex += 2;
            } else if (fieldName == 'has_children' && input == '2') {
              currentFieldIndex += 2;
            } else {
              currentFieldIndex++;
            }
          } else {
            error = 'Please select 1 for Yes or 2 for No';
          }
        } else {
          error = medicalFields[fieldName]!.validator!(input);
          if (error == null) {
            formResponses[fieldName] = input;
            currentFieldIndex++;
          }
        }

        if (currentFieldIndex < fieldsList.length) {
          setState(() {
            chatMessages.add({
              'sender': 'bot',
              'text': fieldsList[currentFieldIndex]['prompt'],
            });
          });
        } else {
          setState(() {
            currentState = 'health_underwriters';
            chatMessages.add({
              'sender': 'bot',
              'text': currentStateData['next']['message'],
            });
          });
        }
        if (error != null) {
          setState(() {
            chatMessages.add({
              'sender': 'bot',
              'text': 'Error: $error. Please try again.',
            });
            chatMessages.add({'sender': 'bot', 'text': field['prompt']});
          });
        }
      }
    } else if (currentState == 'health_underwriters' &&
        insuranceType == 'Medical') {
      final choices = input
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .where((e) => e != null)
          .toList();
      if (choices.length <= 3 &&
          choices.every((c) => c! > 0 && c <= _underwriters.length)) {
        setState(() {
          _selectedUnderwriters =
              choices.map((c) => _underwriters[c! - 1]).toList();
          formResponses['underwriters'] = _selectedUnderwriters.join(', ');
          currentState = 'health_summary';
          String summary = formResponses.entries
              .map((e) => '${e.key}: ${e.value}')
              .join('\n');
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['next']['message'].replaceAll(
                  '{fields}',
                  summary,
                ) +
                '\n' +
                currentStateData['next']['options']
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value['text']}')
                    .join('\n'),
          });
        });
      } else {
        _showError('Select up to 3 valid underwriters (e.g., 1,2,3).');
      }
    } else if (currentState == 'health_summary' && insuranceType == 'Medical') {
      int? choice = int.tryParse(input);
      if (choice == 1) {
        double premium = await _calculatePremium(
          'medical',
          formResponses['policy_type'] == 'Corporate'
              ? 'corporate'
              : 'individual',
          formResponses,
        );
        Quote quote = Quote(
          id: Uuid().v4(),
          type: 'medical',
          subtype: formResponses['policy_type'] == 'Corporate'
              ? 'corporate'
              : 'individual',
          company: _selectedUnderwriters.isNotEmpty
              ? _selectedUnderwriters[0]
              : 'default',
          premium: premium,
          formData: Map<String, String>.from(formResponses),
          generatedAt: DateTime.now(),
        );
        setState(() {
          quotes.add(quote);
          currentState = 'health_process';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'],
          });
        });
        await _saveQuotes();
        File? quotePdf = await _generateQuotePdf(quote);
        if (quotePdf != null) {
          await _sendEmail(
            quote.company,
            quote.type,
            quote.subtype,
            quote.formData,
            quotePdf,
            quote.formData['regno'] ?? '', // Provide registrationNumber if available
            quote.formData['vehicle_type'] ?? '', // Provide vehicleType if available
          );
        }
      } else if (choice == 2) {
        setState(() {
          currentState = 'health_personal_info';
          currentFieldIndex = 0;
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['fields'][0]['prompt'],
          });
        });
      } else {
        _showError('Please select 1 for Yes or 2 for No.');
      }
    } else if (currentState == 'add_item') {
      int? choice = int.tryParse(input);
      List<String> itemTypes = ['car', 'home', 'medical'];
      if (choice != null && choice > 0 && choice <= itemTypes.length) {
        setState(() {
          formResponses['item_type'] = itemTypes[choice - 1];
          formResponses['insurance_type'] = itemTypes[choice - 1] == 'car'
              ? 'Motor'
              : itemTypes[choice - 1] == 'home'
                  ? 'Property'
                  : 'Medical';
          currentState = itemTypes[choice - 1] == 'car'
              ? 'add_vehicle_type'
              : itemTypes[choice - 1] == 'home'
                  ? 'add_property_type'
                  : 'add_medical_type';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                (chatbotTemplate['states'][currentState]['options']
                        ?.asMap()
                        .entries
                        .map((e) => '${e.key + 1}. ${e.value['text']}')
                        .join('\n') ??
                    ''),
          });
        });
      } else {
        _showError('Please select 1 for car, 2 for home, or 3 for medical.');
      }
    } else if (currentState == 'add_vehicle_type' && insuranceType == 'Motor') {
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= _vehicleTypes.length) {
        setState(() {
          formResponses['vehicle_type'] = _vehicleTypes[choice - 1];
          currentState = 'add_item_details';
          currentStateData = chatbotTemplate['states'][currentState];
          currentStateData['fields'] = motorFields.keys
              .map(
                (key) => {
                  'name': key,
                  'prompt': 'Please enter your $key for the vehicle:',
                },
              )
              .toList();
          currentFieldIndex = 0;
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['fields'][0]['prompt'],
          });
        });
      } else {
        _showError(
          'Please select a valid vehicle type (1-${_vehicleTypes.length}).',
        );
      }
    } else if (currentState == 'add_property_type' &&
        insuranceType == 'Property') {
      List<String> propertyTypes = [
        'residential',
        'commercial',
        'industrial',
        'landlord',
      ];
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= propertyTypes.length) {
        setState(() {
          formResponses['property_type'] = propertyTypes[choice - 1];
          currentState = 'add_item_details';
          currentStateData = chatbotTemplate['states'][currentState];
          currentStateData['fields'] = propertyFields.keys
              .map(
                (key) => {
                  'name': key,
                  'prompt': 'Please enter your $key for the property:',
                },
              )
              .toList();
          currentFieldIndex = 0;
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['fields'][0]['prompt'],
          });
        });
      } else {
        _showError(
          'Please select a valid property type (1-${propertyTypes.length}).',
        );
      }
    } else if (currentState == 'add_medical_type' &&
        insuranceType == 'Medical') {
      int? choice = int.tryParse(input);
      List<String> medicalTypes = ['individual', 'corporate'];
      if (choice != null && choice > 0 && choice <= medicalTypes.length) {
        setState(() {
          formResponses['policy_type'] = medicalTypes[choice - 1];
          currentState = medicalTypes[choice - 1] == 'corporate'
              ? 'health_beneficiaries'
              : 'add_item_details';
          currentStateData = chatbotTemplate['states'][currentState];
          if (currentState == 'add_item_details') {
            currentStateData['fields'] = medicalFields.keys
                .where(
                  (key) => ![
                    'inpatient_limit',
                    'outpatient_limit',
                    'dental_limit',
                    'optical_limit',
                    'maternity_limit',
                    'medical_services',
                    'underwriters',
                    'beneficiaries',
                  ].contains(key),
                )
                .map(
                  (key) => {
                    'name': key,
                    'prompt': 'Please enter your $key for medical item:',
                  },
                )
                .toList();
            currentFieldIndex = 0;
          }
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['message'] +
                '\n' +
                (currentStateData['options']
                        ?.asMap()
                        .entries
                        .map((e) => '${e.key + 1}. ${e.value['text']}')
                        .join('\n') ??
                    currentStateData['fields']?[0]['prompt'] ??
                    ''),
          });
        });
      } else {
        _showError('Please select 1 for Individual or 2 for Corporate.');
      }
    } else if (currentState == 'add_item_details') {
      var fieldsList = currentStateData['fields'];
      if (currentFieldIndex < fieldsList.length) {
        var field = fieldsList[currentFieldIndex];
        String fieldName = field['name'];
        String? error = fields[fieldName]!.validator!(input);

        if (error == null) {
          formResponses[fieldName] = input;
          currentFieldIndex++;
          if (currentFieldIndex < fieldsList.length) {
            setState(() {
              chatMessages.add({
                'sender': 'bot',
                'text': fieldsList[currentFieldIndex]['prompt'],
              });
            });
          } else {
            setState(() {
              currentState = 'add_item_upload';
              chatMessages.add({
                'sender': 'bot',
                'text': currentStateData['next']['message'] +
                    '\n' +
                    currentStateData['next']['options']
                        .asMap()
                        .entries
                        .map((e) => '${e.key + 1}. ${e.value['text']}')
                        .join('\n'),
              });
            });
          }
        } else {
          setState(() {
            chatMessages.add({
              'sender': 'bot',
              'text': 'Error: $error. Please try again.',
            });
            chatMessages.add({'sender': 'bot', 'text': field['prompt']});
          });
        }
      }
    } else if (currentState == 'add_item_upload') {
      int? choice = int.tryParse(input);
      if (choice != null && choice >= 1 && choice <= 3) {
        if (choice == 1) {
          await _uploadLogbook();
          setState(() {
            currentState = 'add_item_logbook';
            chatMessages.add({
              'sender': 'bot',
              'text': chatbotTemplate['states'][currentState]['message'] +
                  '\n' +
                  chatbotTemplate['states'][currentState]['options']
                      .asMap()
                      .entries
                      .map((e) => '${e.key + 1}. ${e.value['text']}')
                      .join('\n'),
            });
          });
        } else if (choice == 2) {
          await _uploadPreviousPolicy();
          setState(() {
            currentState = 'add_item_policy';
            chatMessages.add({
              'sender': 'bot',
              'text': chatbotTemplate['states'][currentState]['message'],
            });
          });
        } else {
          setState(() {
            currentState = 'add_item_summary';
            String summary = formResponses.entries
                .map((e) => '${e.key}: ${e.value}')
                .join('\n');
            chatMessages.add({
              'sender': 'bot',
              'text':
                  chatbotTemplate['states'][currentState]['message'].replaceAll(
                        '{fields}',
                        summary,
                      ) +
                      '\n' +
                      chatbotTemplate['states'][currentState]['options']
                          .asMap()
                          .entries
                          .map((e) => '${e.key + 1}. ${e.value['text']}')
                          .join('\n'),
            });
          });
        }
      } else {
        _showError(
          'Please select 1 to upload logbook, 2 for previous policy, or 3 to skip.',
        );
      }
    } else if (currentState == 'add_item_logbook') {
      int? choice = int.tryParse(input);
      if (choice != null && choice >= 1 && choice <= 2) {
        if (choice == 1) {
          await _uploadPreviousPolicy();
          setState(() {
            currentState = 'add_item_policy';
            chatMessages.add({
              'sender': 'bot',
              'text': chatbotTemplate['states'][currentState]['message'],
            });
          });
        } else {
          setState(() {
            currentState = 'add_item_summary';
            String summary = formResponses.entries
                .map((e) => '${e.key}: ${e.value}')
                .join('\n');
            chatMessages.add({
              'sender': 'bot',
              'text':
                  chatbotTemplate['states'][currentState]['message'].replaceAll(
                        '{fields}',
                        summary,
                      ) +
                      '\n' +
                      chatbotTemplate['states'][currentState]['options']
                          .asMap()
                          .entries
                          .map((e) => '${e.key + 1}. ${e.value['text']}')
                          .join('\n'),
            });
          });
        }
      } else {
        _showError('Please select 1 to upload previous policy or 2 to skip.');
      }
    } else if (currentState == 'add_item_policy') {
      setState(() {
        currentState = 'add_item_summary';
        String summary =
            formResponses.entries.map((e) => '${e.key}: ${e.value}').join('\n');
        chatMessages.add({
          'sender': 'bot',
          'text': chatbotTemplate['states'][currentState]['message'].replaceAll(
                '{fields}',
                summary,
              ) +
              '\n' +
              chatbotTemplate['states'][currentState]['options']
                  .asMap()
                  .entries
                  .map((e) => '${e.key + 1}. ${e.value['text']}')
                  .join('\n'),
        });
      });
    } else if (currentState == 'add_item_summary') {
      int? choice = int.tryParse(input);
      if (choice == 1) {
        insuredItems.add(
          InsuredItem(
            id: Uuid().v4(),
            type: formResponses['insurance_type']!.toLowerCase(),
            vehicleType: insuranceType == 'Motor'
                ? formResponses['vehicle_type'] ?? ''
                : '',
            details: Map<String, String>.from(formResponses)
              ..removeWhere(
                (key, _) => [
                  'vehicle_value',
                  'regno',
                  'property_value',
                  'chassis_number',
                  'kra_pin',
                ].contains(key),
              ),
            vehicleValue: formResponses['vehicle_value'],
            regno: formResponses['regno'],
            propertyValue: formResponses['property_value'],
            chassisNumber: formResponses['chassis_number'],
            kraPin: formResponses['kra_pin'],
            logbookPath: _logbookFile?.path,
            previousPolicyPath: _previousPolicyFile?.path,
          ),
        );
        await _saveInsuredItems();
        setState(() {
          currentState = 'select_item';
          formResponses.clear();
          _logbookFile = null;
          _previousPolicyFile = null;
          chatMessages.add({
            'sender': 'bot',
            'text': _buildSelectItemMessage(),
          });
        });
      } else if (choice == 2) {
        setState(() {
          currentState = 'start';
          formResponses.clear();
          _logbookFile = null;
          _previousPolicyFile = null;
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                chatbotTemplate['states'][currentState]['options']
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value['text']}')
                    .join('\n'),
          });
        });
      } else {
        _showError('Please select 1 to confirm or 2 to cancel.');
      }
    } else if (currentState == 'select_item') {
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= insuredItems.length + 1) {
        if (choice <= insuredItems.length) {
          setState(() {
            selectedInsuredItemId = insuredItems[choice - 1].id;
            currentState = 'pdf_filling';
            currentStateData = chatbotTemplate['states'][currentState];
            currentStateData['fields'] = fields.keys
                .map(
                  (key) => {
                    'name': key,
                    'prompt': 'Please enter your $key for the form:',
                  },
                )
                .toList();
            currentFieldIndex = 0;
            chatMessages.add({
              'sender': 'bot',
              'text': currentStateData['fields'][0]['prompt'],
            });
          });
        } else {
          setState(() {
            currentState = 'add_item';
            chatMessages.add({
              'sender': 'bot',
              'text': chatbotTemplate['states'][currentState]['message'] +
                  '\n' +
                  chatbotTemplate['states'][currentState]['options']
                      .asMap()
                      .entries
                      .map((e) => '${e.key + 1}. ${e.value['text']}')
                      .join('\n'),
            });
          });
        }
      } else {
        _showError(
          'Please select a valid item or ${insuredItems.length + 1} for new details.',
        );
      }
    } else if (currentState == 'pdf_filling') {
      if (currentFieldIndex == 0) {
        setState(() {
          currentState = 'pdf_upload';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                chatbotTemplate['states'][currentState]['options']
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value['text']}')
                    .join('\n'),
          });
        });
      } else {
        var fieldsList = currentStateData['fields'];
        if (currentFieldIndex < fieldsList.length) {
          var field = fieldsList[currentFieldIndex];
          String fieldName = field['name'];
          String? error = fields[fieldName]!.validator!(input);

          if (error == null) {
            formResponses[fieldName] = input;
            currentFieldIndex++;
            if (currentFieldIndex < fieldsList.length) {
              setState(() {
                chatMessages.add({
                  'sender': 'bot',
                  'text': fieldsList[currentFieldIndex]['prompt'],
                });
              });
            } else {
              String summary = formResponses.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join('\n');
              setState(() {
                currentState = 'pdf_summary';
                chatMessages.add({
                  'sender': 'bot',
                  'text': currentStateData['next']['message'].replaceAll(
                        '{fields}',
                        summary,
                      ) +
                      '\n' +
                      currentStateData['next']['options']
                          .asMap()
                          .entries
                          .map((e) => '${e.key + 1}. ${e.value['text']}')
                          .join('\n'),
                });
              });
            }
          } else {
            setState(() {
              chatMessages.add({
                'sender': 'bot',
                'text': 'Error: $error. Please try again.',
              });
              chatMessages.add({'sender': 'bot', 'text': field['prompt']});
            });
          }
        }
      }
    } else if (currentState == 'pdf_upload') {
      int? choice = int.tryParse(input);
      if (choice != null && choice >= 1 && choice <= 3) {
        if (choice == 1) {
          await _uploadLogbook();
          setState(() {
            currentState = 'pdf_logbook';
            chatMessages.add({
              'sender': 'bot',
              'text': chatbotTemplate['states'][currentState]['message'] +
                  '\n' +
                  chatbotTemplate['states'][currentState]['options']
                      .asMap()
                      .entries
                      .map((e) => '${e.key + 1}. ${e.value['text']}')
                      .join('\n'),
            });
          });
        } else if (choice == 2) {
          await _uploadPreviousPolicy();
          setState(() {
            currentState = 'pdf_policy';
            chatMessages.add({
              'sender': 'bot',
              'text': chatbotTemplate['states'][currentState]['message'],
            });
          });
        } else {
          setState(() {
            currentState = 'pdf_filling_continue';
            currentStateData = chatbotTemplate['states'][currentState];
            currentStateData['fields'] = fields.keys
                .map(
                  (key) => {
                    'name': key,
                    'prompt': 'Please enter your $key for the form:',
                  },
                )
                .toList();
            currentFieldIndex = 0;
            chatMessages.add({
              'sender': 'bot',
              'text': currentStateData['fields'][0]['prompt'],
            });
          });
        }
      } else {
        _showError(
          'Please select 1 to upload logbook, 2 for previous policy, or 3 to skip.',
        );
      }
    } else if (currentState == 'pdf_logbook') {
      int? choice = int.tryParse(input);
      if (choice != null && choice >= 1 && choice <= 2) {
        if (choice == 1) {
          await _uploadPreviousPolicy();
          setState(() {
            currentState = 'pdf_policy';
            chatMessages.add({
              'sender': 'bot',
              'text': chatbotTemplate['states'][currentState]['message'],
            });
          });
        } else {
          setState(() {
            currentState = 'pdf_filling_continue';
            currentStateData = chatbotTemplate['states'][currentState];
            currentStateData['fields'] = fields.keys
                .map(
                  (key) => {
                    'name': key,
                    'prompt': 'Please enter your $key for the form:',
                  },
                )
                .toList();
            currentFieldIndex = 0;
            chatMessages.add({
              'sender': 'bot',
              'text': currentStateData['fields'][0]['prompt'],
            });
          });
        }
      } else {
        _showError('Please select 1 to upload previous policy or 2 to skip.');
      }
    } else if (currentState == 'pdf_policy') {
      setState(() {
        currentState = 'pdf_filling_continue';
        currentStateData = chatbotTemplate['states'][currentState];
        currentStateData['fields'] = fields.keys
            .map(
              (key) => {
                'name': key,
                'prompt': 'Please enter your $key for the form:',
              },
            )
            .toList();
        currentFieldIndex = 0;
        chatMessages.add({
          'sender': 'bot',
          'text': currentStateData['fields'][0]['prompt'],
        });
      });
    } else if (currentState == 'pdf_filling_continue') {
      var fieldsList = currentStateData['fields'];
      if (currentFieldIndex < fieldsList.length) {
        var field = fieldsList[currentFieldIndex];
        String fieldName = field['name'];
        String? error = fields[fieldName]!.validator!(input);

        if (error == null) {
          formResponses[fieldName] = input;
          currentFieldIndex++;
          if (currentFieldIndex < fieldsList.length) {
            setState(() {
              chatMessages.add({
                'sender': 'bot',
                'text': fieldsList[currentFieldIndex]['prompt'],
              });
            });
          } else {
            String summary = formResponses.entries
                .map((e) => '${e.key}: ${e.value}')
                .join('\n');
            setState(() {
              currentState = 'pdf_summary';
              chatMessages.add({
                'sender': 'bot',
                'text': currentStateData['next']['message'].replaceAll(
                      '{fields}',
                      summary,
                    ) +
                    '\n' +
                    currentStateData['next']['options']
                        .asMap()
                        .entries
                        .map((e) => '${e.key + 1}. ${e.value['text']}')
                        .join('\n'),
              });
            });
          }
        } else {
          setState(() {
            chatMessages.add({
              'sender': 'bot',
              'text': 'Error: $error. Please try again.',
            });
            chatMessages.add({'sender': 'bot', 'text': field['prompt']});
          });
        }
      }
    } else if (currentState == 'pdf_missing_fields') {
      final missingFields = formResponses['missing_fields']!.split(',');
      final currentIndex = int.parse(
        formResponses['current_missing_field_index']!,
      );
      final templateKey = 'default';
      final template = cachedPdfTemplates[templateKey];
      final fieldDef = template!.fields[missingFields[currentIndex]]!;
      final error = fieldDef.validator!(input);

      if (error == null) {
        formResponses[missingFields[currentIndex]] = input;
        if (currentIndex + 1 < missingFields.length) {
          setState(() {
            formResponses['current_missing_field_index'] =
                (currentIndex + 1).toString();
            chatMessages.add({
              'sender': 'bot',
              'text':
                  'Please provide the value for ${missingFields[currentIndex + 1]} (Type: ${template.fields[missingFields[currentIndex + 1]]!.expectedType.toString().split('.').last}${template.fields[missingFields[currentIndex + 1]]!.isSuggested ? ', AI-Suggested' : ''}):',
            });
          });
        } else {
          formResponses.remove('missing_fields');
          formResponses.remove('current_missing_field_index');
          File? filledPdf = await _fillPdfTemplate(
            templateKey,
            formResponses,
            cachedPdfTemplates,
            insuranceType!,
            context,
          );
          if (filledPdf != null && await _previewPdf(filledPdf)) {
            await _sendEmail(
              'companyA',
              formResponses['insurance_type']?.toLowerCase() ?? 'auto',
              formResponses['subtype'] ?? 'comprehensive',
              formResponses,
              filledPdf,
              formResponses['regno'] ?? '', // Provide registrationNumber if available
              formResponses['vehicle_type'] ?? '', // Provide vehicleType if available
            );
          }
          setState(() {
            currentState = 'pdf_process';
            chatMessages.add({
              'sender': 'bot',
              'text': chatbotTemplate['states'][currentState]['message'],
            });
          });
        }
      } else {
        setState(() {
          chatMessages.add({
            'sender': 'bot',
            'text':
                'Error: $error. Please provide a valid value for ${missingFields[currentIndex]} (Type: ${fieldDef.expectedType.toString().split('.').last}${fieldDef.isSuggested ? ', AI-Suggested' : ''}):',
          });
        });
      }
    } else if (currentState == 'pdf_summary') {
      int? choice = int.tryParse(input);
      if (choice == 1) {
        File? filledPdf = await _fillPdfTemplate(
          'default',
          formResponses,
          cachedPdfTemplates,
          insuranceType!,
          context,
        );
        if (filledPdf != null && await _previewPdf(filledPdf)) {
          await _sendEmail(
            'companyA',
            formResponses['insurance_type']?.toLowerCase() ?? 'auto',
            formResponses['subtype'] ?? 'comprehensive',
            formResponses,
            filledPdf,
            formResponses['regno'] ?? '', // Provide registrationNumber if available
            formResponses['vehicle_type'] ?? '', // Provide vehicleType if available
          );
        }
        setState(() {
          currentState = 'pdf_process';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'],
          });
        });
      } else if (choice == 2) {
        setState(() {
          currentState = 'pdf_filling';
          currentStateData = chatbotTemplate['states'][currentState];
          currentStateData['fields'] = fields.keys
              .map(
                (key) => {
                  'name': key,
                  'prompt': 'Please enter your $key for the form:',
                },
              )
              .toList();
          currentFieldIndex = 0;
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['fields'][0]['prompt'],
          });
        });
      } else {
        _showError('Please select 1 for Yes or 2 for No.');
      }
    } else if (currentState == 'view_policies') {
      String policiesSummary = policies.isEmpty
          ? 'No policies found.'
          : policies
              .asMap()
              .entries
              .map(
                (e) =>
                    '${e.key + 1}. ${e.value.type} (${e.value.subtype}) - ${e.value.status}',
              )
              .join('\n');
      setState(() {
        currentState = 'start';
        chatMessages.add({
          'sender': 'bot',
          'text': 'Your policies:\n$policiesSummary\n\n' +
              chatbotTemplate['states'][currentState]['message'] +
              '\n' +
              chatbotTemplate['states'][currentState]['options']
                  .asMap()
                  .entries
                  .map((e) => '${e.key + 1}. ${e.value['text']}')
                  .join('\n'),
        });
      });
    } else {
      _showError('Invalid state or input. Please try again.');
    }

    chatController.clear();
  }

  void _showError(String message) {
    setState(() {
      chatMessages.add({'sender': 'bot', 'text': message});
    });
  }

and;

  void _loadChatbotTemplate() {
    chatbotTemplate = {
      'states': {
        'start': {
          'message': 'Hi! 😊 Let’s assist you. What would you like to do?',
          'options': [
            {'text': 'Generate a quote', 'next': 'insurance_type'},
            {'text': 'Fill a form', 'next': 'select_item'},
            {'text': 'Explore insurance', 'next': 'insurance'},
            {'text': 'Add insured item', 'next': 'add_item'},
            {'text': 'View policies', 'next': 'view_policies'},
          ],
        },
        'insurance_type': {
          'message':
              'What type of insurance would you like?\n1. Motor\n2. Medical\n3. Travel\n4. Property\n5. WIBA',
          'options': [
            {'text': 'Motor', 'next': 'vehicle_type'},
            {'text': 'Medical', 'next': 'medical_policy_type'},
            {'text': 'Travel', 'next': 'travel_subtype'},
            {'text': 'Property', 'next': 'property_type'},
            {'text': 'WIBA', 'next': 'wiba_subtype'},
          ],
        },
        // Motor States
        'vehicle_type': {
          'message':
              'Please select your vehicle type:\n${_vehicleTypes.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
          'options': _vehicleTypes
              .map((type) => {'text': type, 'next': 'quote_auto_subtype'})
              .toList(),
        },
        'quote_auto_subtype': {
          'message': 'Please select the motor insurance subtype:\n${[
            'commercial',
            'psv',
            'psv_uber',
            'private',
            'tuk_tuk',
            'special_classes'
          ].asMap().entries.map((e) => '${e.key + 1}. ${e.value.replaceAll('_', ' ')}').join('\n')}',
          'options': [
            'commercial',
            'psv',
            'psv_uber',
            'private',
            'tuk_tuk',
            'special_classes',
          ]
              .map((type) => {'text': type, 'next': 'quote_motor_coverage'})
              .toList(),
        },
        'quote_motor_coverage': {
          'message':
              'Please select the coverage type:\n1. Comprehensive\n2. Third Party',
          'options': [
            {'text': 'Comprehensive', 'next': 'quote_filling'},
            {'text': 'Third Party', 'next': 'quote_filling'},
          ],
        },
        // Medical States
        'medical_policy_type': {
          'message':
              'Is this an Individual or Corporate medical policy?\n1. Individual\n2. Corporate',
          'options': [
            {'text': 'Individual', 'next': 'health_inpatient_limit'},
            {'text': 'Corporate', 'next': 'health_beneficiaries'},
          ],
        },
        'health_beneficiaries': {
          'message':
              'How many beneficiaries will be covered? (Minimum 3 for Corporate)',
          'next': 'health_inpatient_limit',
        },
        'health_inpatient_limit': {
          'message':
              'Please select your preferred Inpatient Limit:\n${_inpatientLimits.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
          'options': _inpatientLimits
              .map(
                (limit) => {
                  'text': limit,
                  'next': 'health_outpatient_limit',
                },
              )
              .toList(),
        },
        'health_outpatient_limit': {
          'message':
              'Please enter your preferred Outpatient Limit (KES, e.g., 100000):',
          'next': 'health_dental_limit',
        },
        'health_dental_limit': {
          'message':
              'Please enter your preferred Dental Limit (KES, e.g., 50000):',
          'next': 'health_optical_limit',
        },
        'health_optical_limit': {
          'message':
              'Please enter your preferred Optical Limit (KES, e.g., 30000):',
          'next': 'health_maternity_limit',
        },
        'health_maternity_limit': {
          'message':
              'Please enter your preferred Maternity Limit (KES, e.g., 150000):',
          'next': 'health_medical_services',
        },
        'health_medical_services': {
          'message':
              'Which medical services would you like included? (Select numbers, e.g., 1,2):\n${_medicalServices.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
          'next': 'health_personal_info',
        },
        'health_personal_info': {
          'fields': [
            {'name': 'name', 'prompt': 'What is your name?'},
            {'name': 'email', 'prompt': 'What is your email?'},
            {'name': 'phone', 'prompt': 'What is your phone number?'},
            {'name': 'age', 'prompt': 'What is the client’s age?'},
            {
              'name': 'has_spouse',
              'prompt': 'Do you have a spouse? (1. Yes, 2. No)',
            },
            {
              'name': 'spouse_age',
              'prompt': 'Please provide the spouse’s age:',
            },
            {
              'name': 'has_children',
              'prompt': 'Do you have children? (1. Yes, 2. No)',
            },
            {
              'name': 'children_count',
              'prompt': 'How many children would be covered under this policy?',
            },
            {
              'name': 'pre_existing_conditions',
              'prompt':
                  'Any pre-existing medical conditions? (Enter none if none):',
            },
          ],
          'next': 'health_underwriters',
        },
        'health_underwriters': {
          'message':
              'Select up to three preferred insurance underwriters (e.g., 1,2,3):\n${_underwriters.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
          'next': 'health_summary',
        },
        'health_summary': {
          'message':
              'Here’s what you’ve entered:\n{fields}\nIs this correct?\n1. Yes\n2. No',
          'options': [
            {'text': 'Yes', 'next': 'health_process'},
            {'text': 'No', 'next': 'health_personal_info'},
          ],
        },
        'health_process': {
          'message':
              'Great! Your medical insurance request is being processed.',
          'next': 'start',
        },
        // Travel States
        'travel_subtype': {
          'message': 'Please select the travel insurance subtype:\n${[
            'single_trip',
            'multi_trip',
            'student',
            'senior_citizen'
          ].asMap().entries.map((e) => '${e.key + 1}. ${e.value.replaceAll('_', ' ')}').join('\n')}',
          'options': ['single_trip', 'multi_trip', 'student', 'senior_citizen']
              .map((type) => {'text': type, 'next': 'travel_details'})
              .toList(),
        },
        'travel_details': {
          'fields': [
            {'name': 'name', 'prompt': 'What is your name?'},
            {'name': 'email', 'prompt': 'What is your email?'},
            {'name': 'phone', 'prompt': 'What is your phone number?'},
            {
              'name': 'destination',
              'prompt': 'What is your travel destination?',
            },
            {
              'name': 'travel_start_date',
              'prompt': 'Enter travel start date (YYYY-MM-DD):',
            },
            {
              'name': 'travel_end_date',
              'prompt': 'Enter travel end date (YYYY-MM-DD):',
            },
            {
              'name': 'number_of_travelers',
              'prompt': 'How many travelers are covered?',
            },
            {
              'name': 'coverage_limit',
              'prompt': 'Enter preferred coverage limit (KES):',
            },
          ],
          'next': 'travel_summary',
        },
        'travel_summary': {
          'message':
              'Here’s what you’ve entered:\n{fields}\nIs this correct?\n1. Yes\n2. No',
          'options': [
            {'text': 'Yes', 'next': 'travel_process'},
            {'text': 'No', 'next': 'travel_details'},
          ],
        },
        'travel_process': {
          'message': 'Great! Your travel insurance request is being processed.',
          'next': 'start',
        },
        // Property States
        'property_type': {
          'message': 'Please select the property type:\n${[
            'residential',
            'commercial',
            'industrial',
            'landlord'
          ].asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
          'options': ['residential', 'commercial', 'industrial', 'landlord']
              .map((type) => {'text': type, 'next': 'quote_home_subtype'})
              .toList(),
        },
        'quote_home_subtype': {
          'message': 'Please select the property insurance subtype:\n${[
            'residential',
            'commercial',
            'industrial',
            'landlord'
          ].asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
          'options': [
            'residential',
            'commercial',
            'industrial',
            'landlord',
          ].map((type) => {'text': type, 'next': 'quote_filling'}).toList(),
        },
        // WIBA States
        'wiba_subtype': {
          'message': 'Please select the WIBA subtype:\n${[
            'standard',
            'enhanced',
            'contractor',
            'small_business'
          ].asMap().entries.map((e) => '${e.key + 1}. ${e.value.replaceAll('_', ' ')}').join('\n')}',
          'options': [
            'standard',
            'enhanced',
            'contractor',
            'small_business',
          ].map((type) => {'text': type, 'next': 'wiba_details'}).toList(),
        },
        'wiba_details': {
          'fields': [
            {'name': 'name', 'prompt': 'What is your name?'},
            {'name': 'email', 'prompt': 'What is your email?'},
            {'name': 'phone', 'prompt': 'What is your phone number?'},
            {'name': 'business_name', 'prompt': 'What is the business name?'},
            {
              'name': 'number_of_employees',
              'prompt': 'How many employees are covered?',
            },
            {
              'name': 'coverage_limit',
              'prompt': 'Enter preferred coverage limit (KES):',
            },
            {
              'name': 'industry_type',
              'prompt':
                  'Select industry type (construction, manufacturing, services, retail):',
            },
          ],
          'next': 'wiba_summary',
        },
        'wiba_summary': {
          'message':
              'Here’s what you’ve entered:\n{fields}\nIs this correct?\n1. Yes\n2. No',
          'options': [
            {'text': 'Yes', 'next': 'wiba_process'},
            {'text': 'No', 'next': 'wiba_details'},
          ],
        },
        'wiba_process': {
          'message': 'Great! Your WIBA insurance request is being processed.',
          'next': 'start',
        },
        // Quote Filling
        'quote_filling': {
          'fields':
              [], // Dynamically set in _handleChatInput based on insurance type
          'next': 'quote_summary',
        },
        'quote_summary': {
          'message':
              'Here’s what you’ve entered:\n{fields}\nIs this correct?\n1. Yes\n2. No',
          'options': [
            {'text': 'Yes', 'next': 'quote_process'},
            {'text': 'No', 'next': 'quote_filling'},
          ],
        },
        'quote_process': {
          'message': 'Your quote has been generated and sent for processing.',
          'next': 'start',
        },
        // Add Item States
        'add_item': {
          'message':
              'What type of item to insure?\n1. Car\n2. Property\n3. Medical\n4. Travel\n5. WIBA',
          'options': [
            {'text': 'Car', 'next': 'add_vehicle_type'},
            {'text': 'Property', 'next': 'add_property_type'},
            {'text': 'Medical', 'next': 'add_medical_type'},
            {'text': 'Travel', 'next': 'add_travel_type'},
            {'text': 'WIBA', 'next': 'add_wiba_type'},
          ],
        },
        'add_vehicle_type': {
          'message':
              'Please select the vehicle type:\n${_vehicleTypes.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
          'options': _vehicleTypes
              .map((type) => {'text': type, 'next': 'add_item_details'})
              .toList(),
        },
        'add_property_type': {
          'message': 'Please select the property type:\n${[
            'residential',
            'commercial',
            'industrial',
            'landlord'
          ].asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
          'options': ['residential', 'commercial', 'industrial', 'landlord']
              .map((type) => {'text': type, 'next': 'add_item_details'})
              .toList(),
        },
        'add_medical_type': {
          'message':
              'Is this an Individual or Corporate medical policy?\n1. Individual\n2. Corporate',
          'options': [
            {'text': 'Individual', 'next': 'add_item_details'},
            {'text': 'Corporate', 'next': 'health_beneficiaries'},
          ],
        },
        'add_travel_type': {
          'message': 'Please select the travel insurance subtype:\n${[
            'single_trip',
            'multi_trip',
            'student',
            'senior_citizen'
          ].asMap().entries.map((e) => '${e.key + 1}. ${e.value.replaceAll('_', ' ')}').join('\n')}',
          'options': ['single_trip', 'multi_trip', 'student', 'senior_citizen']
              .map((type) => {'text': type, 'next': 'add_item_details'})
              .toList(),
        },
        'add_wiba_type': {
          'message': 'Please select the WIBA subtype:\n${[
            'standard',
            'enhanced',
            'contractor',
            'small_business'
          ].asMap().entries.map((e) => '${e.key + 1}. ${e.value.replaceAll('_', ' ')}').join('\n')}',
          'options': ['standard', 'enhanced', 'contractor', 'small_business']
              .map((type) => {'text': type, 'next': 'add_item_details'})
              .toList(),
        },
        'add_item_details': {
          'fields':
              [], // Dynamically set in _handleChatInput based on insurance type
          'next': 'add_item_upload',
        },
        'add_item_upload': {
          'message':
              'Please upload relevant documents (if any):\n1. Upload Logbook (Motor)\n2. Upload Previous Policy\n3. Skip',
          'options': [
            {'text': 'Upload Logbook', 'next': 'add_item_logbook'},
            {'text': 'Upload Previous Policy', 'next': 'add_item_policy'},
            {'text': 'Skip', 'next': 'add_item_summary'},
          ],
        },
        'add_item_logbook': {
          'message':
              'Logbook uploaded. Proceed to upload previous policy or skip?\n1. Upload Previous Policy\n2. Skip',
          'options': [
            {'text': 'Upload Previous Policy', 'next': 'add_item_policy'},
            {'text': 'Skip', 'next': 'add_item_summary'},
          ],
        },
        'add_item_policy': {
          'message': 'Previous policy uploaded. Proceed to summary?',
          'next': 'add_item_summary',
        },
        'add_item_summary': {
          'message':
              'Here’s what you’ve entered:\n{fields}\nIs this correct?\n1. Yes\n2. No',
          'options': [
            {'text': 'Yes', 'next': 'add_item_process'},
            {'text': 'No', 'next': 'add_item_details'},
          ],
        },
        'add_item_process': {
          'message': 'Your insured item has been added successfully.',
          'next': 'start',
        },
        // PDF Filling States
        'select_item': {
          'message':
              'Please select an insured item or add a new one:\n{items}\n{new_option}',
          'options': [], // Dynamically set in _handleChatInput
        },
        'pdf_filling': {
          'fields': [], // Dynamically set in _handleChatInput
          'next': 'pdf_upload',
        },
        'pdf_upload': {
          'message':
              'Before filling the PDF, please upload relevant documents (if any):\n1. Upload Logbook (Motor)\n2. Upload Previous Policy\n3. Skip',
          'options': [
            {'text': 'Upload Logbook', 'next': 'pdf_logbook'},
            {'text': 'Upload Previous Policy', 'next': 'pdf_policy'},
            {'text': 'Skip', 'next': 'pdf_filling_continue'},
          ],
        },
        'pdf_logbook': {
          'message':
              'Logbook uploaded. Upload previous policy or skip?\n1. Upload Previous Policy\n2. Skip',
          'options': [
            {'text': 'Upload Previous Policy', 'next': 'pdf_policy'},
            {'text': 'Skip', 'next': 'pdf_filling_continue'},
          ],
        },
        'pdf_policy': {
          'message': 'Previous policy uploaded. Proceed?',
          'next': 'pdf_filling_continue',
        },
        'pdf_filling_continue': {
          'fields': [], // Dynamically set in _handleChatInput
          'next': 'pdf_summary',
        },
        'pdf_missing_fields': {
          'message': 'Please provide the value for the missing field:',
          'next': 'pdf_summary',
        },
        'pdf_summary': {
          'message':
              'Here’s what you’ve entered:\n{fields}\nIs this correct?\n1. Yes\n2. No',
          'options': [
            {'text': 'Yes', 'next': 'pdf_process'},
            {'text': 'No', 'next': 'pdf_filling'},
          ],
        },
        'pdf_process': {
          'message':
              'Great! Your form is being processed. You’ll hear back soon.',
          'next': 'start',
        },
        // View Policies
        'view_policies': {
          'message':
              'Here are your policies:\n{policies}\nWhat would you like to do next?',
          'next': 'start',
        },
      },
    };
  }
I'll update the code to dynamically get field mappings from the Policy class instead of using hardcoded field definitions. Here are the changes:

First, let's modify the _handleChatInput function to use the policy's field definitions:

dart
Future<void> _handleChatInput(String input) async {
  setState(() {
    chatMessages.add({'sender': 'user', 'text': input});
  });

  var currentStateData = chatbotTemplate['states'][currentState];
  Map<String, FieldDefinition> fields = {};
  String? insuranceType = formResponses['insurance_type'];
  
  // Get fields from the current policy if available
  if (currentPolicy != null) {
    fields = currentPolicy!.fieldDefinitions;
  } else {
    // Fallback to default fields based on insurance type
    switch (insuranceType) {
      case 'Motor':
        fields = motorPolicyTemplate.fieldDefinitions;
        break;
      case 'Medical':
        fields = medicalPolicyTemplate.fieldDefinitions;
        break;
      case 'Property':
        fields = propertyPolicyTemplate.fieldDefinitions;
        break;
      default:
        fields = motorPolicyTemplate.fieldDefinitions; // Fallback
    }
  }

  // Rest of the function remains similar but uses the dynamic fields
  if (currentState == 'start') {
    int? choice = int.tryParse(input);
    if (choice != null && choice >= 1 && choice <= currentStateData['options'].length) {
      setState(() {
        currentState = currentStateData['options'][choice - 1]['next'];
        chatMessages.add({
          'sender': 'bot',
          'text': chatbotTemplate['states'][currentState]['message'] +
              '\n' +
              (chatbotTemplate['states'][currentState]['options']
                      ?.asMap()
                      .entries
                      .map((e) => '${e.key + 1}. ${e.value['text']}')
                      .join('\n') ??
                  ''),
        });
      });
    } else {
      _showError(
        'Please select a valid option (1-${currentStateData['options'].length}).',
      );
    }
  }
  // ... rest of the state handling remains similar but uses the dynamic fields
}
Update the field definitions in states to use the policy's field definitions:

dart
} else if (currentState == 'quote_filling') {
  setState(() {
    currentStateData['fields'] = fields.keys
        .where((key) => !['vehicle_type', 'property_type'].contains(key))
        .map(
          (key) => {
            'name': key,
            'prompt': fields[key]?.prompt ?? 'Please enter your $key:',
          },
        )
        .toList();
    currentFieldIndex = 0;
    chatMessages.add({
      'sender': 'bot',
      'text': currentStateData['fields'][0]['prompt'],
    });
  });
}
Update the _loadChatbotTemplate function to remove hardcoded fields and use dynamic prompts:

dart
void _loadChatbotTemplate() {
  chatbotTemplate = {
    'states': {
      'start': {
        'message': 'Hi! 😊 Let's assist you. What would you like to do?',
        'options': [
          {'text': 'Generate a quote', 'next': 'insurance_type'},
          {'text': 'Fill a form', 'next': 'select_item'},
          {'text': 'Explore insurance', 'next': 'insurance'},
          {'text': 'Add insured item', 'next': 'add_item'},
          {'text': 'View policies', 'next': 'view_policies'},
        ],
      },
      // ... other states remain similar but remove hardcoded field definitions
      'quote_filling': {
        'fields': [], // Will be populated dynamically
        'next': 'quote_summary',
      },
      'health_personal_info': {
        'fields': [], // Will be populated dynamically from medical policy fields
        'next': 'health_underwriters',
      },
      // ... rest of the template
    },
  };
}
Create policy templates that will be used as fallbacks:

dart
// Define these as class variables
final Policy motorPolicyTemplate = Policy(
  id: 'motor_template',
  type: 'motor',
  subtype: 'private',
  companyId: 'default',
  status: CoverStatus.active,
  fieldDefinitions: {
    'regno': FieldDefinition(
      expectedType: FieldType.text,
      isRequired: true,
      validator: (value) => value.isEmpty ? 'Registration number is required' : null,
      prompt: 'Please enter vehicle registration number:',
    ),
    // ... other motor fields
  },
  coverageTypes: ['comprehensive', 'third_party'],
);

final Policy medicalPolicyTemplate = Policy(
  id: 'medical_template',
  type: 'medical',
  subtype: 'individual',
  companyId: 'default',
  status: CoverStatus.active,
  fieldDefinitions: {
    'name': FieldDefinition(
      expectedType: FieldType.text,
      isRequired: true,
      validator: (value) => value.isEmpty ? 'Name is required' : null,
      prompt: 'Please enter your full name:',
    ),
    // ... other medical fields
  },
  coverageTypes: ['inpatient', 'outpatient'],
);

// Similarly for property and other types
When loading a policy, update the current policy:

dart
void _loadPolicies() async {
  // Load policies from storage/API
  // For each policy, the fieldDefinitions will be available
  if (policies.isNotEmpty) {
    currentPolicy = policies.first;
  }
}
Key changes made:

Removed hardcoded field mappings (motorFields, medicalFields, etc.)

Using Policy.fieldDefinitions for dynamic field configuration

Added policy templates as fallbacks when no specific policy is selected

Updated state handling to use dynamic fields from the policy

Field prompts and validations now come from the FieldDefinition objects

The main benefits of this approach:

Field definitions are centralized in the Policy class

Easier to maintain as field changes only need to be made in one place

More flexible as different policies can have different field sets

Better separation of concerns

You'll need to ensure that:

All your policies have proper fieldDefinitions populated

The FieldDefinition class has all necessary properties (validator, prompt, etc.)

The templates cover all required fields for each insurance type

Would you like me to elaborate on any specific part of these changes?

NO, do not create individual policies because there's

import 'package:my_app/Models/field_definition.dart';

class PDFTemplate {
  final Map<String, FieldDefinition> fields;
  final Map<String, String> fieldMappings;
  final Map<String, Map<String, double>> coordinates;
  final String policyType; // e.g., 'auto', 'health', 'home'
  final String policySubtype; // e.g., 'comprehensive', 'third_party'
  String? coverageType;
  final String templateKey; // Unique identifier for the template

  PDFTemplate({
    required this.fields,
    required this.fieldMappings,
    required this.coordinates,
    required this.policyType,
    required this.policySubtype,
    required this.templateKey, String? coverageType,
  });

  Map<String, dynamic> toJson() => {
    'fields': fields.map((key, value) => MapEntry(key, value.toJson())),
    'fieldMappings': fieldMappings,
    'coordinates': coordinates,
    'policyType': policyType,
    'policySubtype': policySubtype,
    'templateKey': templateKey,
    'coverageType': coverageType,
  };

  factory PDFTemplate.fromJson(Map<String, dynamic> json) => PDFTemplate(
    fields: (json['fields'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, FieldDefinition.fromJson(value)),
    ),
    fieldMappings: Map<String, String>.from(json['fieldMappings']),
    coordinates: (json['coordinates'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, Map<String, double>.from(value)),
    ),
    policyType: json['policyType'],
    policySubtype: json['policySubtype'],
    templateKey: json['templateKey'],
    coverageType: json['coverageType'] as String? ?? '', // Handle nullable coverageType
  );
}
Based on your requirements, I'll modify the code to use dynamic field mappings from the PDFTemplate class instead of hardcoded field definitions. Here's how we can update the code:

First, let's update the _handleChatInput function to use dynamic field mappings from PDFTemplate:

dart
Future<void> _handleChatInput(String input) async {
  setState(() {
    chatMessages.add({'sender': 'user', 'text': input});
  });

  var currentStateData = chatbotTemplate['states'][currentState];
  String? insuranceType = formResponses['insurance_type'];
  String? subtype = formResponses['subtype'];
  
  // Get the appropriate PDF template based on policy type and subtype
  PDFTemplate? template = _getTemplateForPolicy(insuranceType, subtype);
  
  if (template == null) {
    _showError('No template found for this policy type');
    return;
  }

  Map<String, FieldDefinition> fields = template.fields;

  // Rest of the state handling remains similar but uses the dynamic fields from template
  if (currentState == 'start') {
    int? choice = int.tryParse(input);
    if (choice != null && choice >= 1 && choice <= currentStateData['options'].length) {
      setState(() {
        currentState = currentStateData['options'][choice - 1]['next'];
        chatMessages.add({
          'sender': 'bot',
          'text': chatbotTemplate['states'][currentState]['message'] +
              '\n' +
              (chatbotTemplate['states'][currentState]['options']
                      ?.asMap()
                      .entries
                      .map((e) => '${e.key + 1}. ${e.value['text']}')
                      .join('\n') ??
                  ''),
        });
      });
    } else {
      _showError(
        'Please select a valid option (1-${currentStateData['options'].length}).',
      );
    }
  }
  // ... rest of the state handling
}

PDFTemplate? _getTemplateForPolicy(String? type, String? subtype) {
  if (type == null) return null;
  
  // This would typically come from your database or API
  // Here's a simplified version - you'd want to cache these templates
  switch (type.toLowerCase()) {
    case 'motor':
      return PDFTemplate(
        fields: {
          'regno': FieldDefinition(
            expectedType: FieldType.text,
            isRequired: true,
            validator: (value) => value.isEmpty ? 'Registration number is required' : null,
            prompt: 'Please enter vehicle registration number:',
          ),
          // ... other motor fields
        },
        fieldMappings: {
          'regno': 'vehicle_registration',
          // ... other mappings
        },
        coordinates: {
          'regno': {'x': 100, 'y': 200},
          // ... other coordinates
        },
        policyType: 'motor',
        policySubtype: subtype ?? 'private',
        templateKey: 'motor_${subtype ?? 'default'}',
      );
    case 'medical':
      return PDFTemplate(
        fields: {
          'name': FieldDefinition(
            expectedType: FieldType.text,
            isRequired: true,
            validator: (value) => value.isEmpty ? 'Name is required' : null,
            prompt: 'Please enter your full name:',
          ),
          // ... other medical fields
        },
        fieldMappings: {
          'name': 'policy_holder_name',
          // ... other mappings
        },
        coordinates: {
          'name': {'x': 100, 'y': 150},
          // ... other coordinates
        },
        policyType: 'medical',
        policySubtype: subtype ?? 'individual',
        templateKey: 'medical_${subtype ?? 'default'}',
      );
    // ... other policy types
    default:
      return null;
  }
}
Update the field definitions in states to use the template's field definitions:

dart
} else if (currentState == 'quote_filling') {
  setState(() {
    currentStateData['fields'] = template.fields.entries
        .where((entry) => !['vehicle_type', 'property_type'].contains(entry.key))
        .map(
          (entry) => {
            'name': entry.key,
            'prompt': entry.value.prompt ?? 'Please enter your ${entry.key}:',
          },
        )
        .toList();
    currentFieldIndex = 0;
    chatMessages.add({
      'sender': 'bot',
      'text': currentStateData['fields'][0]['prompt'],
    });
  });
}
Update the _loadChatbotTemplate function to remove hardcoded fields:

dart
void _loadChatbotTemplate() {
  chatbotTemplate = {
    'states': {
      'start': {
        'message': 'Hi! 😊 Let's assist you. What would you like to do?',
        'options': [
          {'text': 'Generate a quote', 'next': 'insurance_type'},
          {'text': 'Fill a form', 'next': 'select_item'},
          {'text': 'Explore insurance', 'next': 'insurance'},
          {'text': 'Add insured item', 'next': 'add_item'},
          {'text': 'View policies', 'next': 'view_policies'},
        ],
      },
      // ... other states remain similar but remove hardcoded field definitions
      'quote_filling': {
        'fields': [], // Will be populated dynamically from template
        'next': 'quote_summary',
      },
      'health_personal_info': {
        'fields': [], // Will be populated dynamically from template
        'next': 'health_underwriters',
      },
      // ... rest of the template
    },
  };
}
Update the PDF filling logic to use the template's field mappings and coordinates:

dart
Future<File?> _fillPdfTemplate(
  String templateKey,
  Map<String, dynamic> formData,
  Map<String, PDFTemplate> templates,
  String insuranceType,
  BuildContext context,
) async {
  final template = templates[templateKey];
  if (template == null) {
    _showError('Template not found');
    return null;
  }

  try {
    // Use the template's field mappings and coordinates
    for (var entry in template.fieldMappings.entries) {
      String formField = entry.key;
      String pdfField = entry.value;
      dynamic value = formData[formField];
      
      if (value != null) {
        // Use the coordinates from the template
        var coords = template.coordinates[pdfField];
        if (coords != null) {
          // Fill the PDF field using the coordinates
          // pdf.fillField(pdfField, value, coords['x'], coords['y']);
        }
      }
    }
    
    // ... rest of the PDF filling logic
  } catch (e) {
    _showError('Error filling PDF: ${e.toString()}');
    return null;
  }
}
Key changes made:

Replaced hardcoded field mappings with dynamic templates from PDFTemplate

Added a helper function _getTemplateForPolicy to get the appropriate template

Updated state handling to use dynamic fields from the template

Modified PDF filling to use template's field mappings and coordinates

Field prompts and validations now come from the FieldDefinition objects in the template

Benefits of this approach:

Centralized template management through PDFTemplate class

Dynamic field definitions based on policy type and subtype

Field mappings and coordinates are part of the template

Easier to maintain as changes only need to be made in the template

More flexible for different types of policies

The templates would typically be loaded from a database or API, but I've included a simplified version that creates them locally. In a production app, you'd want to:

Cache the templates for better performance

Possibly create a template service to manage them

Handle template versioning

Provide fallback templates when specific ones aren't available

Would you like me to elaborate on any specific part of these changes?

use the folowing instead of _getTemplateForPolicy

  Future<void> _loadCachedPdfTemplates() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('pdf_templates').get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          cachedPdfTemplates = Map.fromEntries(
            snapshot.docs.map(
              (doc) => MapEntry(
                doc.id,
                PDFTemplate.fromJson(doc.data()),
              ),
            ),
          );
        });
        if (kDebugMode) {
          print('PDF templates loaded from Firestore.');
        }
      } else {
        // Initialize default template
        final defaultTemplate = PDFTemplate(
          templateKey: 'default',
          policyType: 'motor',
          policySubtype: 'comprehensive',
          coordinates: {
            'name': {'page': 1.0, 'x': 50.0, 'y': 50.0},
            'email': {'page': 1.0, 'x': 50.0, 'y': 70.0},
            'phone': {'page': 1.0, 'x': 50.0, 'y': 90.0},
          },
          fields: {
            'name': FieldDefinition(
                expectedType: ExpectedType.name,
                validator: (String) {
                  return null;
                }),
            'email': FieldDefinition(
                expectedType: ExpectedType.email,
                validator: (String) {
                  return null;
                }),
            'phone': FieldDefinition(
                expectedType: ExpectedType.phone,
                validator: (String) {
                  return null;
                }),
          },
          fieldMappings: {},
        );
        await FirebaseFirestore.instance
            .collection('pdf_templates')
            .doc('default')
            .set(defaultTemplate.toJson());
        setState(() {
          cachedPdfTemplates['default'] = defaultTemplate;
        });
        if (kDebugMode) {
          print('Initialized default PDF template in Firestore.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading cached PDF templates: $e');
      }
      setState(() {
        cachedPdfTemplates = {};
      });
    }
  }
map  them using template key from policy.templatekeys
I'll update the code to use the cachedPdfTemplates loaded from Firestore and map them using the template key from the policy. Here's how we can modify the implementation:

First, update the _handleChatInput function to use the cached templates:

dart
Future<void> _handleChatInput(String input) async {
  setState(() {
    chatMessages.add({'sender': 'user', 'text': input});
  });

  var currentStateData = chatbotTemplate['states'][currentState];
  
  // Get the appropriate PDF template based on current policy
  PDFTemplate? template;
  if (currentPolicy != null && currentPolicy!.pdfTemplateKey != null) {
    template = cachedPdfTemplates[currentPolicy!.pdfTemplateKey!];
  } else {
    // Fallback to default template based on insurance type
    String? insuranceType = formResponses['insurance_type']?.toLowerCase();
    String? subtype = formResponses['subtype'] ?? 'default';
    String templateKey = '${insuranceType}_$subtype';
    template = cachedPdfTemplates[templateKey] ?? cachedPdfTemplates['default'];
  }

  if (template == null) {
    _showError('No template found for this policy');
    return;
  }

  Map<String, FieldDefinition> fields = template.fields;

  // Rest of the state handling remains similar but uses the dynamic fields from template
  if (currentState == 'start') {
    // ... existing start state handling
  }
  // ... rest of the state handling
}
Update the field definitions in states to use the template's field definitions:

dart
} else if (currentState == 'quote_filling') {
  setState(() {
    currentStateData['fields'] = template.fields.entries
        .where((entry) => !['vehicle_type', 'property_type'].contains(entry.key))
        .map(
          (entry) => {
            'name': entry.key,
            'prompt': entry.value.prompt ?? 'Please enter your ${entry.key}:',
          },
        )
        .toList();
    currentFieldIndex = 0;
    chatMessages.add({
      'sender': 'bot',
      'text': currentStateData['fields'][0]['prompt'],
    });
  });
}
Update the PDF filling logic to use the template's field mappings:

dart
Future<File?> _fillPdfTemplate(
  String templateKey,
  Map<String, dynamic> formData,
  String insuranceType,
  BuildContext context,
) async {
  final template = cachedPdfTemplates[templateKey];
  if (template == null) {
    _showError('Template not found');
    return null;
  }

  try {
    // Use the template's field mappings and coordinates
    for (var entry in template.fields.entries) {
      String formField = entry.key;
      FieldDefinition fieldDef = entry.value;
      dynamic value = formData[formField];
      
      // Validate the field
      String? error = fieldDef.validator(value);
      if (error != null) {
        _showError('Invalid value for $formField: $error');
        return null;
      }

      // If there's a field mapping, use it, otherwise use the field name directly
      String pdfField = template.fieldMappings[formField] ?? formField;
      var coords = template.coordinates[pdfField];
      
      if (value != null && coords != null) {
        // Fill the PDF field using the coordinates
        // pdf.fillField(
        //   pdfField, 
        //   value, 
        //   coords['page'] ?? 1,
        //   coords['x'] ?? 0,
        //   coords['y'] ?? 0
        // );
      }
    }
    
    // ... rest of the PDF filling logic
    return File('path/to/filled.pdf'); // Replace with actual file
  } catch (e) {
    _showError('Error filling PDF: ${e.toString()}');
    return null;
  }
}
Update the policy summary and processing to use the correct template:

dart
} else if (currentState == 'quote_summary') {
  int? choice = int.tryParse(input);
  if (choice == 1) {
    double premium = await _calculatePremium(
      formResponses['insurance_type']!.toLowerCase(),
      formResponses['subtype']!,
      formResponses,
    );
    
    // Get the template key from policy or fallback
    String templateKey = currentPolicy?.pdfTemplateKey ?? 
      '${formResponses['insurance_type']?.toLowerCase()}_${formResponses['subtype']}' ??
      'default';

    Quote quote = Quote(
      id: Uuid().v4(),
      type: formResponses['insurance_type']!.toLowerCase(),
      subtype: formResponses['subtype']!,
      company: _selectedUnderwriters.isNotEmpty
          ? _selectedUnderwriters[0]
          : 'default',
      premium: premium,
      formData: Map<String, String>.from(formResponses),
      generatedAt: DateTime.now(),
      templateKey: templateKey, // Store the template key with the quote
    );

    setState(() {
      quotes.add(quote);
      currentState = 'quote_process';
      chatMessages.add({
        'sender': 'bot',
        'text': 'Your quote has been generated and sent for processing.',
      });
    });

    await _saveQuotes();
    File? quotePdf = await _generateQuotePdf(quote);
    if (quotePdf != null) {
      await _sendEmail(
        quote.company,
        quote.type,
        quote.subtype,
        quote.formData,
        quotePdf,
        quote.formData['regno'] ?? '',
        quote.formData['vehicle_type'] ?? '',
      );
    }
  }
  // ... rest of the summary handling
}
Update the _generateQuotePdf function to use the template from the quote:

dart
Future<File?> _generateQuotePdf(Quote quote) async {
  try {
    // Get the template for this quote
    PDFTemplate? template = cachedPdfTemplates[quote.templateKey] ?? 
      cachedPdfTemplates['default'];
    
    if (template == null) {
      _showError('No template available for generating PDF');
      return null;
    }

    // Fill the PDF using the template
    return await _fillPdfTemplate(
      quote.templateKey,
      quote.formData,
      quote.type,
      context,
    );
  } catch (e) {
    _showError('Error generating PDF: ${e.toString()}');
    return null;
  }
}
Key improvements in this implementation:

Dynamic Template Selection: Uses the policy's pdfTemplateKey to find the appropriate template from cached templates

Fallback Mechanism: Falls back to type-specific or default template if no specific template is found

Field Validation: Uses the field definitions from the template for validation

PDF Generation: Uses template coordinates and mappings for accurate PDF filling

Template Caching: Leverages the pre-loaded cached templates for better performance

The system now:

Loads templates from Firestore during initialization

Maps them by their template keys

Uses the appropriate template based on the policy's template key

Falls back gracefully when specific templates aren't available

Uses template-defined fields, mappings, and coordinates for all operations

This provides a more robust and flexible system that can handle different document templates for different policy types and subtypes while maintaining clean separation of concerns.


  
*/
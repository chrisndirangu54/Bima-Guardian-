import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_app/Providers/theme_provider.dart';
import 'package:my_app/insurance_app.dart';
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
  testWidgets('MyApp builds with required providers', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => ColorProvider()),
          ChangeNotifierProvider(create: (_) => DialogState()),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);


    expect(find.byType(MaterialApp), findsOneWidget);


    expect(find.byType(MaterialApp), findsOneWidget);


    expect(find.byType(MaterialApp), findsOneWidget);


    expect(find.byType(MaterialApp), findsOneWidget);

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
    expect(find.byType(MaterialApp), findsOneWidget);

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
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Bima Guardian');
  });
}
*/

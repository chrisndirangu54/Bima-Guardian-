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

  
*/
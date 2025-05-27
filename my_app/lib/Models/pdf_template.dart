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
    required this.templateKey,
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

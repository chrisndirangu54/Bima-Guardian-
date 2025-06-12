import 'package:my_app/Models/policy.dart';

class Company {
  final String id;
  final String name;
  final List<String> pdfTemplateKey; // e.g., ['default', 'health_template']
  final CoverageType coverageType; // e.g., 'vehicle', 'property'
  final String? icon; // Optional icon field

  Company({
    required this.id,
    required this.name,
    required this.pdfTemplateKey,
    required this.coverageType,
    this.icon,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pdfTemplateKeys': pdfTemplateKey,
        'coverageType': coverageType.toString(),
        'icon': icon,
      };

  factory Company.fromJson(Map<String, dynamic> json) => Company(
        id: json['id'],
        name: json['name'],
        pdfTemplateKey: List<String>.from(json['pdfTemplateKeys']),
        coverageType: CoverageType.values.firstWhere(
          (e) => e.toString() == json['coverageType'],
          orElse: () => CoverageType.values.first,
        ),
        icon: json['icon'],
      );

  /// Add this method to support Firestore data conversion
  static Company fromFirestore(Map<String, dynamic> data) {
    return Company(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      pdfTemplateKey: List<String>.from(data['pdfTemplateKeys'] ?? []),
      coverageType: CoverageType.values.firstWhere(
        (e) => e.toString() == data['coverageType'],
        orElse: () => CoverageType.values.first,
      ),
      icon: data['icon'],
    );
  }
}

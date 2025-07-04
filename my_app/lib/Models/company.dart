import 'package:my_app/Models/policy.dart';

class Company {
  final String id;
  final String name;
  final List<String> pdfTemplateKey; // e.g., ['default', 'health_template']
  final CoverageType? coverageType; // Add this line
  final PolicySubtype? policySubtype; // Added missing field
  final bool? isClaim = false; // Added isClaim field
  final bool? isExtention = false; // Added isExtension field
  final bool? isCancellation = false; // Added isCancellation field

  /// Static lists of all coverage types and policy subtypes
  static final List<CoverageType> allCoverageTypes = [
    CoverageType(
        id: 'vehicle', name: 'Vehicle', description: 'Covers vehicles'),
    CoverageType(
        id: 'property', name: 'Property', description: 'Covers properties'),
    // Add more as needed
  ];

  static final List<PolicySubtype> allPolicySubtypes = [
    PolicySubtype(
        id: 'vehicle',
        name: 'Vehicle',
        description: 'Covers vehicles',
        policyTypeId: 'vehicle'),
    PolicySubtype(
        id: 'property',
        name: 'Property',
        description: 'Covers properties',
        policyTypeId: 'property'),
    // Add more as needed
  ];
    static List<PolicyType> allPolicyTypes = [
    PolicyType(id: '1', name: 'motor', description: ''),
    PolicyType(id: '2', name: 'medical', description: ''),
    PolicyType(id: '3', name: 'travel', description: ''),
    PolicyType(id: '4', name: 'property', description: ''),
    PolicyType(id: '5', name: 'wiba', description: ''),
    // Add more as needed
  ];
  final String? icon; // Optional icon field
  final String? logoUrl; // URL for the company logo

  Company({
    required this.id,
    required this.name,
    required this.pdfTemplateKey,
    this.coverageType,
    this.policySubtype,
    this.icon, 
    this.logoUrl,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pdfTemplateKeys': pdfTemplateKey,
        'coverageType': coverageType.toString(),
        'policySubtype': policySubtype?.toString(),
        'icon': icon,
      };
// Helper to find a CoverageType by string
  static PolicySubtype? policySubtypesFromString(String? value) {
    if (value == null) return null;
    return allPolicySubtypes.firstWhere(
      (e) => e.toString() == value,
      orElse: () => allPolicySubtypes.first,
    );
  }

// Helper to find a CoverageType by string
  static CoverageType? coverageTypeFromString(String? value) {
    if (value == null) return null;
    return allCoverageTypes.firstWhere(
      (e) => e.toString() == value,
      orElse: () => allCoverageTypes.first,
    );
  }

  factory Company.fromJson(Map<String, dynamic> json) => Company(
        id: json['id'],
        name: json['name'],
        pdfTemplateKey: List<String>.from(json['pdfTemplateKeys']),
        coverageType: Company.coverageTypeFromString(json['coverageType']),
        policySubtype: Company.policySubtypesFromString(json['policySubtype']),
        icon: json['icon'],
      );
  static Company fromFirestore(Map<String, dynamic> data) {
    return Company(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      pdfTemplateKey: List<String>.from(data['pdfTemplateKeys'] ?? []),
      coverageType: Company.coverageTypeFromString(data['coverageType']),

      policySubtype: Company.policySubtypesFromString(data['policySubtype']),
      icon: data['icon'],
    );
  }
}

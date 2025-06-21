import 'package:flutter/foundation.dart';
import 'package:my_app/Models/cover.dart';
import 'package:my_app/insurance_app.dart';

class PolicyType {
  final String id;
  final String name;
  final String description;

  String icon; // Added nullable field

  PolicyType({
    required this.id,
    required this.name,
    required this.description,
    this.icon = '', // Default to empty string
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
      };

  factory PolicyType.fromJson(Map<String, dynamic> json) => PolicyType(
        id: json['id'],
        name: json['name'],
        description: json['description'],
      );

  // Added fromFirestore factory method
  factory PolicyType.fromFirestore(Map<String, dynamic> data) => PolicyType(
        id: data['id'] ?? '',
        name: data['name'] ?? '',
        description: data['description'] ?? '',
      );
}

class PolicySubtype {
  final String id;
  final String name;
  final String policyTypeId;
  final String description;
  final String? pdfTemplateKey;

  String icon; // Made nullable

  PolicySubtype({
    required this.id,
    required this.name,
    required this.policyTypeId,
    required this.description,
    this.pdfTemplateKey, // Made optional
    this.icon = '', // Default to empty string
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'policyTypeId': policyTypeId,
        'description': description,
        'pdfTemplateKey': pdfTemplateKey, // Include in JSON
      };

  factory PolicySubtype.fromJson(Map<String, dynamic> json) => PolicySubtype(
        id: json['id'],
        name: json['name'],
        policyTypeId: json['policyTypeId'],
        description: json['description'],
        pdfTemplateKey: json['pdfTemplateKey'], // Nullable in fromJson
      );

  // Added fromFirestore factory method
  factory PolicySubtype.fromFirestore(Map<String, dynamic> data) => PolicySubtype(
        id: data['id'] ?? '',
        name: data['name'] ?? '',
        policyTypeId: data['policyTypeId'] ?? '',
        description: data['description'] ?? '',
        pdfTemplateKey: data['pdfTemplateKey'],
      );

  @override
  String toString() => name;
}

class CoverageType {
  final String id;
  final String name;
  final String description;
  final String? pdfTemplateKey;

  String icon; // Made nullable

  CoverageType({
    required this.id,
    required this.name,
    required this.description,
    this.pdfTemplateKey, // Made optional
    this.icon = '', // Default to empty string
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'pdfTemplateKey': pdfTemplateKey, // Include in JSON
      };

  factory CoverageType.fromJson(Map<String, dynamic> json) => CoverageType(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        pdfTemplateKey: json['pdfTemplateKey'], // Nullable in fromJson
      );

  // Added fromFirestore factory method
  factory CoverageType.fromFirestore(Map<String, dynamic> data) => CoverageType(
        id: data['id'] ?? '',
        name: data['name'] ?? '',
        description: data['description'] ?? '',
        pdfTemplateKey: data['pdfTemplateKey'],
      );




 @override
  String toString() => name;

}

class Policy {
  final String id;
  final String name; // Added name field
  final String insuredItemId;
  final String companyId;
  final PolicyType type;
  final PolicySubtype? subtype;
  final CoverageType? coverageType;
  final CoverStatus status;
  final DateTime? endDate;

  Policy({
    required this.id,
    required this.name, // Add name to constructor
    required this.insuredItemId,
    required this.companyId,
    required this.type,
    required this.subtype,
    required this.coverageType,
    required this.status,
    required this.endDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name, // Add name to JSON
        'insuredItemId': insuredItemId,
        'companyId': companyId,
        'type': type.toJson(),
        'subtype': subtype!.toJson(),
        'coverageType': coverageType!.toJson(),
        'status': status.name,
        'expirationDate': endDate?.toIso8601String(),
      };

  factory Policy.fromJson(Map<String, dynamic> json) => Policy(
        id: json['id'],
        name: json['name'], // Add name from JSON
        insuredItemId: json['insuredItemId'],
        companyId: json['companyId'],
        type: PolicyType.fromJson(json['type']),
        subtype: PolicySubtype.fromJson(json['subtype']),
        coverageType: CoverageType.fromJson(json['coverageType']),
        status: CoverStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => CoverStatus.active,
        ),
        endDate: json['expirationDate'] != null
            ? DateTime.parse(json['expirationDate'])
            : null,
      );

  // Added fromFirestore factory method
  factory Policy.fromFirestore(Map<String, dynamic> data) => Policy(
        id: data['id'] ?? '',
        name: data['name'] ?? '',
        insuredItemId: data['insuredItemId'] ?? '',
        companyId: data['companyId'] ?? '',
        type: PolicyType.fromFirestore(data['type'] ?? {}),
        subtype: PolicySubtype.fromFirestore(data['subtype'] ?? {}),
        coverageType: CoverageType.fromFirestore(data['coverageType'] ?? {}),
        status: CoverStatus.values.firstWhere(
          (e) => e.name == data['status'],
          orElse: () => CoverStatus.active,
        ),
        endDate: data['expirationDate'] != null
            ? DateTime.parse(data['expirationDate'])
            : null,
      );

  @override
  String toString() {
    return 'Policy(id: $id, name: $name, insuredItemId: $insuredItemId, companyId: $companyId, type: ${type.name}, subtype: ${subtype!.name}, coverageType: ${coverageType!.name}, status: ${status.name}, endDate: $endDate, )';
  }

  static Future<Policy> fromCover(Cover updatedCover) async {
    try {
      // Fetch PolicyType
      final policyTypes = await InsuranceHomeScreen.getPolicyTypes();
      final policyType = policyTypes.firstWhere(
        (t) => t.name.toLowerCase() == updatedCover.type.toLowerCase(),
        orElse: () => PolicyType(
          id: updatedCover.type,
          name: updatedCover.type,
          description: '',
        ),
      );

      // Fetch PolicySubtype
      final subtypes = await InsuranceHomeScreen.getPolicySubtypes(policyType.id);
      final policySubtype = subtypes.firstWhere(
        (s) => s.name.toLowerCase() == updatedCover.subtype.toLowerCase(),
        orElse: () => PolicySubtype(
          id: updatedCover.subtype,
          name: updatedCover.subtype,
          policyTypeId: policyType.id,
          description: '',
        ),
      );

      // Fetch CoverageType
      final coverageTypes = await InsuranceHomeScreen.getCoverageTypes(policyType.id);
      final coverageType = coverageTypes.firstWhere(
        (c) => c.name.toLowerCase() == updatedCover.coverageType.toLowerCase(),
        orElse: () => CoverageType(
          id: updatedCover.coverageType,
          name: updatedCover.coverageType,
          description: '',
        ),
      );

      // Create Policy
      return Policy(
        id: updatedCover.id,
        name: updatedCover.name, // Add name from Cover
        insuredItemId: updatedCover.insuredItemId,
        companyId: updatedCover.companyId,
        type: policyType,
        subtype: policySubtype,
        coverageType: coverageType,
        status: updatedCover.status,
        endDate: updatedCover.expirationDate,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error converting Cover to Policy: $e');
      }
      throw Exception('Failed to convert Cover to Policy: $e');
    }
  }
}
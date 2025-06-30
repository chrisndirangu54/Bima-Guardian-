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
  // Added toMap method
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
      };
  // Added fromMap factory method
  factory PolicyType.fromMap(Map<String, dynamic> map) => PolicyType(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        description: map['description'] ?? '',
      );
}

class PolicySubtype {
  final String id;
  final String name;
  final String policyTypeId;
  final String description;

  String icon; // Made nullable

  PolicySubtype({
    required this.id,
    required this.name,
    required this.policyTypeId,
    required this.description,
    this.icon = '', // Default to empty string
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'policyTypeId': policyTypeId,
        'description': description,
      };

  factory PolicySubtype.fromJson(Map<String, dynamic> json) => PolicySubtype(
        id: json['id'],
        name: json['name'],
        policyTypeId: json['policyTypeId'],
        description: json['description'],
      );

  // Added fromFirestore factory method
  factory PolicySubtype.fromFirestore(Map<String, dynamic> data) =>
      PolicySubtype(
        id: data['id'] ?? '',
        name: data['name'] ?? '',
        policyTypeId: data['policyTypeId'] ?? '',
        description: data['description'] ?? '',
      );

  // Added toMap method
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'policyTypeId': policyTypeId,
        'description': description,
      };
  // Added fromMap factory method
  factory PolicySubtype.fromMap(Map<String, dynamic> map) => PolicySubtype(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        policyTypeId: map['policyTypeId'] ?? '',
        description: map['description'] ?? '',
      );

  @override
  String toString() => name;
}

class CoverageType {
  final String id;
  final String name;
  final String description;

  String icon; // Made nullable

  CoverageType({
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

  factory CoverageType.fromJson(Map<String, dynamic> json) => CoverageType(
        id: json['id'],
        name: json['name'],
        description: json['description'],
      );

  // Added fromFirestore factory method
  factory CoverageType.fromFirestore(Map<String, dynamic> data) => CoverageType(
        id: data['id'] ?? '',
        name: data['name'] ?? '',
        description: data['description'] ?? '',
      );
  // Added toMap method
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
      };

  // Added fromMap factory method
  factory CoverageType.fromMap(Map<String, dynamic> map) => CoverageType(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        description: map['description'] ?? '',
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
  final bool? isClaim = false; // Added isClaim field
  final bool? isExtention = false; // Added isExtension field

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
        (t) => t.id == updatedCover.type.id,
        orElse: () => PolicyType(
          id: updatedCover.type.id,
          name: updatedCover.type.name,
          description: updatedCover.type.description,
        ),
      );

      // Fetch PolicySubtype
      final subtypes =
          await InsuranceHomeScreen.getPolicySubtypes(policyType.id);
      final policySubtype = subtypes.firstWhere(
        (s) => s.id == updatedCover.subtype.id,
        orElse: () => PolicySubtype(
          id: updatedCover.subtype.id,
          name: updatedCover.subtype.name,
          policyTypeId: policyType.id,
          description: updatedCover.subtype.description,
        ),
      );

      // Fetch CoverageType
      final coverageTypes =
          await InsuranceHomeScreen.getCoverageTypes(policyType.id);
      final coverageType = coverageTypes.firstWhere(
        (c) => c.id == updatedCover.coverageType.id,
        orElse: () => CoverageType(
          id: updatedCover.coverageType.id,
          name: updatedCover.coverageType.name,
          description: updatedCover.coverageType.description,
        ),
      );

      return Policy(
        id: updatedCover.id,
        name: updatedCover.name,
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

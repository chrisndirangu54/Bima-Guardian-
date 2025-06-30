import 'package:my_app/Models/cover.dart';
import 'package:my_app/Models/policy.dart';
import 'package:my_app/insurance_app.dart';
import 'package:flutter/foundation.dart';


class InsuredItem {
  final String id;
  final Map<String, String> details;
  final String name;
  final String email;
  final String contact;
  final String kraPin;
  final String? logbookPath;
  final String? previousPolicyPath;
  final PolicyType type;
  final PolicySubtype subtype;
  final CoverageType coverageType;
  final List<String> previousCompanies;
  final Cover? cover;

  InsuredItem({
    required this.id,
    required this.details,
    required this.kraPin,
    required this.name,
    required this.email,
    required this.contact,
    this.logbookPath,
    this.previousPolicyPath,
    required this.type,
    required this.subtype,
    required this.coverageType,
    this.cover,
    this.previousCompanies = const [],
  })  : assert(id.isNotEmpty, 'id cannot be empty'),
        assert(RegExp(r'^[PA][0-9]{9}[A-Z]$').hasMatch(kraPin) || kraPin.isEmpty, 'Invalid KRA PIN format'),
        assert(name.isNotEmpty, 'name cannot be empty'),
        assert(RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email) || email.isEmpty, 'Invalid email format'),
        assert(contact.isNotEmpty, 'contact cannot be empty');

  factory InsuredItem.fromMap(Map<String, dynamic> map) {
    try {
      return InsuredItem(
        id: map['id'] as String? ?? '',
        details: Map<String, String>.from(map['details'] as Map? ?? {}),
        kraPin: map['kraPin'] as String? ?? '',
        name: map['name'] as String? ?? '',
        email: map['email'] as String? ?? '',
        contact: map['contact'] as String? ?? '',
        logbookPath: map['logbookPath'] as String?,
        previousPolicyPath: map['previousPolicyPath'] as String?,
        type: PolicyType.fromMap(map['type'] as Map<String, dynamic>? ?? {}),
        subtype: PolicySubtype.fromMap(map['subtype'] as Map<String, dynamic>? ?? {}),
        coverageType: CoverageType.fromMap(map['coverageType'] as Map<String, dynamic>? ?? {}),
        cover: map['cover'] != null ? Cover.fromMap(map['cover'] as Map<String, dynamic>) : null,
        previousCompanies: map['previousCompanies'] is List
            ? List<String>.from(map['previousCompanies'] as List)
            : [],
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing InsuredItem: $e');
      }
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'details': details,
      'kraPin': kraPin,
      'name': name,
      'email': email,
      'contact': contact,
      'logbookPath': logbookPath,
      'previousPolicyPath': previousPolicyPath,
      'type': type.toMap(),
      'subtype': subtype.toMap(),
      'coverageType': coverageType.toMap(),
      'cover': cover?.toMap(),
      'previousCompanies': previousCompanies,
    };
  }

  factory InsuredItem.fromJson(Map<String, dynamic> json) => InsuredItem.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  InsuredItem copyWith({
    String? id,
    Map<String, String>? details,
    String? kraPin,
    String? name,
    String? email,
    String? contact,
    String? logbookPath,
    String? previousPolicyPath,
    PolicyType? type,
    PolicySubtype? subtype,
    CoverageType? coverageType,
    Cover? cover,
    List<String>? previousCompanies,
  }) {
    return InsuredItem(
      id: id ?? this.id,
      details: details ?? this.details,
      kraPin: kraPin ?? this.kraPin,
      name: name ?? this.name,
      email: email ?? this.email,
      contact: contact ?? this.contact,
      logbookPath: logbookPath ?? this.logbookPath,
      previousPolicyPath: previousPolicyPath ?? this.previousPolicyPath,
      type: type ?? this.type,
      subtype: subtype ?? this.subtype,
      coverageType: coverageType ?? this.coverageType,
      cover: cover ?? this.cover,
      previousCompanies: previousCompanies ?? this.previousCompanies,
    );
  }

  @override
  String toString() {
    return 'InsuredItem(id: $id, details: $details, kraPin: $kraPin, name: $name, email: $email, contact: $contact, logbookPath: $logbookPath, previousPolicyPath: $previousPolicyPath, type: $type, subtype: $subtype, coverageType: $coverageType, cover: $cover, previousCompanies: $previousCompanies)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InsuredItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          details == other.details &&
          kraPin == other.kraPin &&
          name == other.name &&
          email == other.email &&
          contact == other.contact &&
          logbookPath == other.logbookPath &&
          previousPolicyPath == other.previousPolicyPath &&
          type == other.type &&
          subtype == other.subtype &&
          coverageType == other.coverageType &&
          cover == other.cover &&
          previousCompanies == other.previousCompanies;

  @override
  int get hashCode => Object.hash(
        id,
        details,
        kraPin,
        name,
        email,
        contact,
        logbookPath,
        previousPolicyPath,
        type,
        subtype,
        coverageType,
        cover,
        previousCompanies,
      );
}
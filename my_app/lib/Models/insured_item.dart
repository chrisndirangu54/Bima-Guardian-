import 'package:my_app/Models/cover.dart';
import 'package:my_app/Models/policy.dart';
import 'package:my_app/insurance_app.dart';




class InsuredItem {
  final String id;
  final Map<String, String> details;
  final String name;
  final String email;
  final String contact;
  final String kraPin; // New: KRA PIN for tax purposes
  final String? logbookPath;
  final String? previousPolicyPath;
  final PolicyType type; // New: Policy type (e.g., 'motor')
  final PolicySubtype subtype; // New: Policy subtype (e.g., 'comprehensive')
  final CoverageType coverageType; // New: Coverage type (e.g., 'third_party')
  final List<String> previousCompanies; // New: List of previous insurers

  /// The cover this item is insured against, if any.
  final Cover? cover;

  /// Creates an [InsuredItem].
  InsuredItem({
    required String id,
    required Map<String, String> details,
    required String kraPin,
    required String name,
    required String email,
    required String contact,
    this.logbookPath,
    this.previousPolicyPath,
    required this.type,
    required this.subtype,
    required this.coverageType,
    this.cover, // Nullable
    List<String> previousCompanies = const [],
  })  : assert(id.isNotEmpty, 'id cannot be empty'),
        assert(kraPin.isNotEmpty, 'kraPin cannot be empty'),
        assert(RegExp(r'^[PA][0-9]{9}[A-Z]$').hasMatch(kraPin), 'Invalid KRA PIN format'),
        assert(name.isNotEmpty, 'name cannot be empty'),
        assert(RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email), 'Invalid email format'),
        assert(contact.isNotEmpty, 'contact cannot be empty'),
        assert(type != null, 'type cannot be null'),
        assert(subtype != null, 'subtype cannot be null'),
        assert(coverageType != null, 'coverageType cannot be null'),
        id = id,
        details = Map.unmodifiable(details),
        kraPin = kraPin,
        name = name,
        email = email,
        contact = contact,
        previousCompanies = List.unmodifiable(previousCompanies);

  /// Whether the associated cover is active.
  /// Returns `true` if the cover exists, its status is active or extended,
  /// its expirationDate is null or in the future, and it has at most 2 extensions.
  /// Returns `false` otherwise.
  bool get isCoverActive =>
      cover != null &&
      (cover!.status == CoverStatus.active || cover!.status == CoverStatus.extended) &&
      (cover!.expirationDate?.isAfter(DateTime.now()) ?? true) &&
      (cover?.extensionCount ?? 0) <= 2;

  /// Creates an [InsuredItem] from a [Map].
  factory InsuredItem.fromMap(Map<String, dynamic> map) {
    // Validate required fields and their types
    if (map['id'] is! String) throw ArgumentError('id must be a String');
    if (map['details'] is! Map) throw ArgumentError('details must be a Map');
    if (map['kraPin'] is! String) throw ArgumentError('kraPin must be a String');
    if (map['name'] is! String) throw ArgumentError('name must be a String');
    if (map['email'] is! String) throw ArgumentError('email must be a String');
    if (map['contact'] is! String) throw ArgumentError('contact must be a String');
    if (map['type'] is! Map) throw ArgumentError('type must be a Map');
    if (map['subtype'] is! Map) throw ArgumentError('subtype must be a Map');
    if (map['coverageType'] is! Map) throw ArgumentError('coverageType must be a Map');

    return InsuredItem(
      id: map['id'] as String,
      details: Map<String, String>.from(map['details'] as Map),
      kraPin: map['kraPin'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      contact: map['contact'] as String,
      logbookPath: map['logbookPath'] as String?,
      previousPolicyPath: map['previousPolicyPath'] as String?,
      type: PolicyType.fromMap(map['type'] as Map<String, dynamic>),
      subtype: PolicySubtype.fromMap(map['subtype'] as Map<String, dynamic>),
      coverageType: CoverageType.fromMap(map['coverageType'] as Map<String, dynamic>),
      cover: map['cover'] != null
          ? Cover.fromMap(map['cover'] as Map<String, dynamic>)
          : null,
      previousCompanies: map['previousCompanies'] is List
          ? List<String>.from(map['previousCompanies'])
          : [],
    );
  }

  /// Converts the [InsuredItem] to a [Map].
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

  /// Creates an [InsuredItem] from a JSON object.
  factory InsuredItem.fromJson(Map<String, dynamic> json) => InsuredItem.fromMap(json);

  /// Converts the [InsuredItem] to a JSON object.
  Map<String, dynamic> toJson() => toMap();

  /// Creates a copy of this [InsuredItem] with the specified fields replaced.
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

  /// Returns a string representation of the [InsuredItem].
  @override
  String toString() {
    return 'InsuredItem(id: $id, details: $details, kraPin: $kraPin, name: $name, email: $email, contact: $contact, logbookPath: $logbookPath, previousPolicyPath: $previousPolicyPath, type: $type, subtype: $subtype, coverageType: $coverageType, cover: $cover, previousCompanies: $previousCompanies)';
  }

  /// Compares two [InsuredItem] instances for equality.
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

  /// Computes the hash code for this [InsuredItem].
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
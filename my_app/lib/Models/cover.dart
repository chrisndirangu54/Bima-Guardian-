import 'package:my_app/insurance_app.dart';
import 'package:my_app/Models/policy.dart';

// Temporary ClaimStatus enum definition. Replace or adjust as needed.
enum ClaimStatus { none, pending, approved, rejected }

class Cover {
  final String id;
  final String name;
  final String insuredItemId;
  final String companyId;
  final PolicyType type;
  final PolicySubtype subtype;
  final CoverageType coverageType;
  CoverStatus status;
  DateTime? expirationDate;
  final String pdfTemplateKey;
  String paymentStatus;
  final double? premium;
  final String? billingFrequency;
  final Map<String, dynamic>? formData;
  final DateTime startDate;
  final DateTime? endDate;
  final int extensionCount; // New field to track extensions
  final ClaimStatus claimStatus;
  int claimCount = 0; // Default to 0, can be updated later  

  Cover({
    required this.id,
    required this.name,
    required this.insuredItemId,
    required this.companyId,
    required this.type,
    required this.subtype,
    required this.coverageType,
    required this.status,
    this.expirationDate, // Made nullable
    required this.pdfTemplateKey,
    required this.paymentStatus,
    this.premium,
    this.billingFrequency,
    this.formData,
    required this.startDate,
    this.endDate,
    this.extensionCount = 0, // Default to 0
    this.claimStatus = ClaimStatus.none, // Default to none
  }) : assert(extensionCount >= 0 && extensionCount <= 2,
            'Extension count must be 0, 1, or 2');

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'insuredItemId': insuredItemId,
        'companyId': companyId,
        'type': type.toJson(),
        'subtype': subtype.toJson(),
        'coverageType': coverageType.toJson(),
        'status': status.name,
        'expirationDate': expirationDate?.toIso8601String(),
        'pdfTemplateKey': pdfTemplateKey,
        'paymentStatus': paymentStatus,
        'premium': premium,
        'billingFrequency': billingFrequency,
        'formData': formData,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'extensionCount': extensionCount,
      };

  factory Cover.fromJson(Map<String, dynamic> json) => Cover(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        insuredItemId: json['insuredItemId'] as String? ?? '',
        companyId: json['companyId'] as String? ?? '',
        type: PolicyType.fromJson(json['type'] as Map<String, dynamic>? ?? {}),
        subtype: PolicySubtype.fromJson(
            json['subtype'] as Map<String, dynamic>? ?? {}),
        coverageType: CoverageType.fromJson(
            json['coverageType'] as Map<String, dynamic>? ?? {}),
        status: CoverStatus.values.firstWhere(
          (e) => e.name == (json['status'] as String? ?? ''),
          orElse: () => CoverStatus.active,
        ),
        expirationDate: json['expirationDate'] != null
            ? DateTime.parse(json['expirationDate'] as String)
            : null,
        pdfTemplateKey: json['pdfTemplateKey'] as String? ?? '',
        paymentStatus: json['paymentStatus'] as String? ?? '',
        premium: json['premium'] as double?,
        billingFrequency: json['billingFrequency'] as String?,
        formData: json['formData'] as Map<String, dynamic>?,
        startDate: DateTime.parse(
            json['startDate'] as String? ?? DateTime.now().toIso8601String()),
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
        extensionCount: json['extensionCount'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'insuredItemId': insuredItemId,
        'companyId': companyId,
        'type': type.toMap(),
        'subtype': subtype.toMap(),
        'coverageType': coverageType.toMap(),
        'status': status.name,
        'expirationDate': expirationDate?.toIso8601String(),
        'pdfTemplateKey': pdfTemplateKey,
        'paymentStatus': paymentStatus,
        'premium': premium,
        'billingFrequency': billingFrequency,
        'formData': formData,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'extensionCount': extensionCount,
      };

  factory Cover.fromMap(Map<String, dynamic> map) => Cover(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        insuredItemId: map['insuredItemId'] as String? ?? '',
        companyId: map['companyId'] as String? ?? '',
        type: PolicyType.fromMap(map['type'] as Map<String, dynamic>? ?? {}),
        subtype: PolicySubtype.fromMap(
            map['subtype'] as Map<String, dynamic>? ?? {}),
        coverageType: CoverageType.fromMap(
            map['coverageType'] as Map<String, dynamic>? ?? {}),
        status: CoverStatus.values.firstWhere(
          (e) => e.name == (map['status'] as String? ?? ''),
          orElse: () => CoverStatus.active,
        ),
        expirationDate: map['expirationDate'] != null
            ? DateTime.parse(map['expirationDate'] as String)
            : null,
        pdfTemplateKey: map['pdfTemplateKey'] as String? ?? '',
        paymentStatus: map['paymentStatus'] as String? ?? '',
        premium: map['premium'] as double?,
        billingFrequency: map['billingFrequency'] as String?,
        formData: map['formData'] as Map<String, dynamic>?,
        startDate: DateTime.parse(
            map['startDate'] as String? ?? DateTime.now().toIso8601String()),
        endDate: map['endDate'] != null
            ? DateTime.parse(map['endDate'] as String)
            : null,
        extensionCount: map['extensionCount'] as int? ?? 0,
      );

  Cover copyWith({
    String? id,
    String? name,
    String? insuredItemId,
    String? companyId,
    PolicyType? type,
    PolicySubtype? subtype,
    CoverageType? coverageType,
    CoverStatus? status,
    DateTime? expirationDate,
    String? pdfTemplateKey,
    String? paymentStatus,
    double? premium,
    String? billingFrequency,
    Map<String, dynamic>? formData,
    DateTime? startDate,
    DateTime? endDate,
    int? extensionCount,
  }) {
    return Cover(
      id: id ?? this.id,
      name: name ?? this.name,
      insuredItemId: insuredItemId ?? this.insuredItemId,
      companyId: companyId ?? this.companyId,
      type: type ?? this.type,
      subtype: subtype ?? this.subtype,
      coverageType: coverageType ?? this.coverageType,
      status: status ?? this.status,
      expirationDate: expirationDate ?? this.expirationDate,
      pdfTemplateKey: pdfTemplateKey ?? this.pdfTemplateKey,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      premium: premium ?? this.premium,
      billingFrequency: billingFrequency ?? this.billingFrequency,
      formData: formData ?? this.formData,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      extensionCount: extensionCount ?? this.extensionCount,
    );
  }

  /// Creates a copy of this [Cover] with a one-month extension.
  Cover extend() {
    if (extensionCount >= 2) {
      throw StateError('Cannot extend cover: maximum of 2 extensions reached');
    }
    if (expirationDate == null) {
      throw StateError('Cannot extend cover: expirationDate is null');
    }
    return copyWith(
      status: CoverStatus.extended,
      expirationDate:
          expirationDate!.add(Duration(days: 30)), // One-month extension
      extensionCount: extensionCount + 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cover &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          insuredItemId == other.insuredItemId &&
          companyId == other.companyId &&
          type == other.type &&
          subtype == other.subtype &&
          coverageType == other.coverageType &&
          status == other.status &&
          expirationDate == other.expirationDate &&
          pdfTemplateKey == other.pdfTemplateKey &&
          paymentStatus == other.paymentStatus &&
          premium == other.premium &&
          billingFrequency == other.billingFrequency &&
          formData == other.formData &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          extensionCount == other.extensionCount;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        insuredItemId,
        companyId,
        type,
        subtype,
        coverageType,
        status,
        expirationDate,
        pdfTemplateKey,
        paymentStatus,
        premium,
        billingFrequency,
        formData,
        startDate,
        endDate,
        extensionCount,
      );

  @override
  String toString() =>
      'Cover(id: $id, name: $name, insuredItemId: $insuredItemId, companyId: $companyId, type: ${type.name}, subtype: ${subtype.name}, coverageType: ${coverageType.name}, status: $status, expirationDate: $expirationDate, extensionCount: $extensionCount)';
}

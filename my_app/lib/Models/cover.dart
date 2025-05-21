class Cover {
  final String id;
  final String insuredItemId;
  final String companyId;
  final String type;
  final String subtype;
  final String coverageType;
  final String status; // e.g., 'pending', 'active', 'expired'
  final DateTime? expirationDate;
  final String pdfTemplateKey;
  final String paymentStatus; // e.g., 'pending', 'completed', 'failed'

  final double? premium; // Made nullable and final
  final String? billingFrequency; // Made nullable and final
  final Map<String, dynamic>?
  formData; // Made nullable and final, and type is dynamic
  final DateTime startDate; // Made final
  final DateTime? endDate; // Made nullable and final

  Cover({
    required this.id,
    required this.insuredItemId,
    required this.companyId,
    required this.type,
    required this.subtype,
    required this.coverageType,
    required this.status,
    required this.expirationDate,
    required this.pdfTemplateKey,
    required this.paymentStatus,
    required this.startDate, // Now directly assigned to field
    this.formData, // Optional in constructor
    this.premium, // Optional in constructor
    this.billingFrequency, // Optional in constructor
    this.endDate, // Optional in constructor
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'insuredItemId': insuredItemId,
    'companyId': companyId,
    'type': type,
    'subtype': subtype,
    'coverageType': coverageType,
    'status': status,
    'expirationDate': expirationDate!.toIso8601String(),
    'pdfTemplateKey': pdfTemplateKey,
    'paymentStatus': paymentStatus,
    'premium': premium,
    'billingFrequency': billingFrequency,
    'formData': formData,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(), // Handle nullable endDate
  };

  factory Cover.fromJson(Map<String, dynamic> json) => Cover(
    id: json['id'] as String,
    insuredItemId: json['insuredItemId'] as String,
    companyId: json['companyId'] as String,
    type: json['type'] as String,
    subtype: json['subtype'] as String,
    coverageType: json['coverageType'] as String,
    status: json['status'] as String,
    expirationDate: DateTime.parse(json['expirationDate'] as String),
    pdfTemplateKey: json['pdfTemplateKey'] as String,
    paymentStatus: json['paymentStatus'] as String,
    startDate: DateTime.parse(json['startDate'] as String),
    formData: json['formData'] as Map<String, dynamic>?, // Cast and allow null
    premium: json['premium'] as double?, // Cast and allow null
    billingFrequency:
        json['billingFrequency'] as String?, // Cast and allow null
    endDate:
        json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null, // Handle nullable endDate
  );

  /// Creates a new [Cover] instance with the given fields replaced by new values.
  Cover copyWith({
    String? id,
    String? insuredItemId,
    String? companyId,
    String? type,
    String? subtype,
    String? coverageType,
    String? status,
    DateTime? expirationDate,
    String? pdfTemplateKey,
    String? paymentStatus,
    double? premium,
    String? billingFrequency,
    Map<String, dynamic>? formData,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return Cover(
      id: id ?? this.id,
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
    );
  }
}

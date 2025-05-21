import 'package:my_app/insurance_app.dart';

class Policy {
  final String id;
  final String insuredItemId;
  final String companyId;
  final String type;
  final String subtype;
  final String coverageType; // e.g., 'third_party', 'comprehensive'
  final String status;
  final DateTime? endDate;
  final String pdfTemplateKey;

  Policy({
    required this.id,
    required this.insuredItemId,
    required this.companyId,
    required this.type,
    required this.subtype,
    required this.coverageType,
    required this.status,
    required this.endDate,
    required this.pdfTemplateKey,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'insuredItemId': insuredItemId,
    'companyId': companyId,
    'type': type,
    'subtype': subtype,
    'coverageType': coverageType,
    'status': status,
    'expirationDate': endDate?.toIso8601String(),
    'pdfTemplateKey': pdfTemplateKey,
  };

  factory Policy.fromJson(Map<String, dynamic> json) => Policy(
    id: json['id'],
    insuredItemId: json['insuredItemId'],
    companyId: json['companyId'],
    type: json['type'],
    subtype: json['subtype'],
    coverageType: json['coverageType'],
    status: json['status'],
    endDate: DateTime.parse(json['expirationDate']),
    pdfTemplateKey: json['pdfTemplateKey'],
  );
}

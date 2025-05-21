class InsuredItem {
  final String id;
  final String type;
  final String vehicleType;
  final Map<String, String> details;
  final String? vehicleValue;
  final String? regno;
  final String? propertyValue;
  final String? chassisNumber;
  final String? kraPin;
  final String? logbookPath;
  final String? previousPolicyPath;

  InsuredItem({
    required this.id,
    required this.type,
    required this.vehicleType,
    required this.details,
    this.vehicleValue,
    this.regno,
    this.propertyValue,
    this.chassisNumber,
    this.kraPin,
    this.logbookPath,
    this.previousPolicyPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'vehicleType': vehicleType,
    'details': details,
    'vehicleValue': vehicleValue,
    'regno': regno,
    'propertyValue': propertyValue,
    'chassisNumber': chassisNumber,
    'kraPin': kraPin,
    'logbookPath': logbookPath,
    'previousPolicyPath': previousPolicyPath,
  };

  factory InsuredItem.fromJson(Map<String, dynamic> json) => InsuredItem(
    id: json['id'],
    type: json['type'],
    vehicleType: json['vehicleType'] ?? '',
    details: Map<String, String>.from(json['details']),
    vehicleValue: json['vehicleValue'],
    regno: json['regno'],
    propertyValue: json['propertyValue'],
    chassisNumber: json['chassisNumber'],
    kraPin: json['kraPin'],
    logbookPath: json['logbookPath'],
    previousPolicyPath: json['previousPolicyPath'],
  );
}

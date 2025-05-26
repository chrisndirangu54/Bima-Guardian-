enum ExpectedType { text, number, email, phone, date, custom, name }

class FieldDefinition {
  final ExpectedType expectedType;
  final String? Function(String)? validator;
  final bool isSuggested;
  final double confidence;
  final Map<String, double>? boundingBox; // Added to store positional data

  FieldDefinition({
    required this.expectedType,
    required this.validator,
    this.isSuggested = false,
    this.confidence = 0.0,
    this.boundingBox,
  });

  Map<String, dynamic> toJson() => {
        'ExpectedType': expectedType.toString().split('.').last,
        'isSuggested': isSuggested,
        'confidence': confidence,
        'boundingBox': boundingBox, // Serialize boundingBox
      };

  factory FieldDefinition.fromJson(Map<String, dynamic> json) {
    final expectedType = ExpectedType.values.firstWhere(
      (e) => e.toString().split('.').last == json['ExpectedType'],
      orElse: () => ExpectedType.text,
    );
    String? Function(String) validator;
    switch (expectedType) {
      case ExpectedType.text:
        validator = (value) =>
            value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
                ? null
                : 'Invalid text';
        break;
      case ExpectedType.number:
        validator = (value) {
          if (value.isEmpty) return null;
          return double.tryParse(value) != null ? null : 'Invalid number';
        };
        break;
      case ExpectedType.email:
        validator = (value) => value.isEmpty ||
                RegExp(
                  r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                ).hasMatch(value)
            ? null
            : 'Invalid email';
        break;
      case ExpectedType.phone:
        validator = (value) =>
            value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)
                ? null
                : 'Invalid phone number';
        break;
      case ExpectedType.date:
        validator = (value) {
          if (value.isEmpty) return null;
          try {
            DateTime.parse(value);
            return null;
          } catch (e) {
            return 'Invalid date (use YYYY-MM-DD)';
          }
        };
        break;
      case ExpectedType.custom:
        validator = (value) => null;
        break;
      case ExpectedType.name:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
    return FieldDefinition(
      expectedType: expectedType,
      validator: validator,
      isSuggested: json['isSuggested'] ?? false,
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      boundingBox: json['boundingBox'] != null
          ? Map<String, double>.from(json['boundingBox'])
          : null, // Deserialize boundingBox
    );
  }
}

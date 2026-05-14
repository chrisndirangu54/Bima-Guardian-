enum ExpectedType {
  text,
  number,
  email,
  phone,
  date,
  custom,
  name,
  list,
  upload,
  grid,
  checkbox,
}

class FieldDefinition {
  final ExpectedType expectedType;
  final ExpectedType? listItemType;
  final String? Function(String?)? validator;
  final bool isSuggested;
  final double confidence;
  final Map<String, double>? boundingBox;

  FieldDefinition({
    required this.expectedType,
    required this.validator,
    this.listItemType,
    this.isSuggested = false,
    this.confidence = 0.0,
    this.boundingBox,
  });

  Map<String, dynamic> toJson() => {
        'expectedType': expectedType.toString().split('.').last,
        if (listItemType != null)
          'listItemType': listItemType.toString().split('.').last,
        'isSuggested': isSuggested,
        'confidence': confidence,
        'boundingBox': boundingBox,
      };

  factory FieldDefinition.fromJson(Map<String, dynamic> json) {
    final expectedType = ExpectedType.values.firstWhere(
      (e) => e.toString().split('.').last == json['expectedType'],
      orElse: () => ExpectedType.text,
    );

    ExpectedType? listItemType;
    if (json['listItemType'] != null) {
      listItemType = ExpectedType.values.firstWhere(
        (e) => e.toString().split('.').last == json['listItemType'],
        orElse: () => ExpectedType.text,
      );
    }

    String? Function(String?)? validator;

    switch (expectedType) {
      case ExpectedType.text:
        validator = (value) =>
            value == null || value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
                ? null
                : 'Invalid text';
        break;

      case ExpectedType.number:
        validator = (value) {
          if (value == null || value.isEmpty) return null;
          return double.tryParse(value) != null ? null : 'Invalid number';
        };
        break;

      case ExpectedType.email:
        validator = (value) =>
            value == null ||
                    value.isEmpty ||
                    RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                        .hasMatch(value)
                ? null
                : 'Invalid email';
        break;

      case ExpectedType.phone:
        validator = (value) =>
            value == null || value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)
                ? null
                : 'Invalid phone number';
        break;

      case ExpectedType.date:
        validator = (value) {
          if (value == null || value.isEmpty) return null;
          try {
            DateTime.parse(value);
            return null;
          } catch (_) {
            return 'Invalid date (use YYYY-MM-DD)';
          }
        };
        break;

      case ExpectedType.custom:
        validator = (value) => null;
        break;

      case ExpectedType.name:
        validator = (value) =>
            value == null || value.isEmpty || RegExp(r'^[A-Za-z\s\-]+$').hasMatch(value)
                ? null
                : 'Invalid name';
        break;

      case ExpectedType.list:
        validator = (value) {
          if (value == null || value.isEmpty) return null;
          final items = value.split(',').map((e) => e.trim()).toList();
          if (items.isEmpty) return 'List cannot be empty';

          if (listItemType != null) {
            for (final item in items) {
              // FIX: Use getValidatorForType directly instead of allocating
              // a throwaway FieldDefinition just to access its validator
              final result =
                  FieldDefinition.getValidatorForType(listItemType)?.call(item);
              if (result != null) return 'Invalid list item: $item';
            }
          }

          return null;
        };
        break;

      case ExpectedType.upload:
        validator = (value) {
          if (value == null || value.isEmpty) return null;
          const allowed = {'jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'};
          final ext = value.split('.').last.toLowerCase();
          return allowed.contains(ext) ? null : 'Unsupported file type: .$ext';
        };
        break;

      case ExpectedType.grid:
        validator = (value) {
          if (value == null || value.isEmpty) return null;
          if (!value.trim().startsWith('[')) return 'Grid must be a JSON array';
          return null;
        };
        break;

      case ExpectedType.checkbox:
        validator = (value) {
          if (value == null || value.isEmpty) return null;
          const valid = {'true', 'false', '1', '0', 'yes', 'no'};
          return valid.contains(value.toLowerCase())
              ? null
              : 'Invalid checkbox value';
        };
        break;
    }

    return FieldDefinition(
      expectedType: expectedType,
      listItemType: listItemType,
      validator: validator,
      isSuggested: json['isSuggested'] ?? false,
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      boundingBox: json['boundingBox'] != null
          ? Map<String, double>.from(json['boundingBox'])
          : null,
    );
  }

  static String? Function(String?)? getValidatorForType(ExpectedType? type) {
    switch (type) {
      case ExpectedType.text:
        return (value) =>
            value == null || value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
                ? null
                : 'Invalid text';

      case ExpectedType.number:
        return (value) =>
            value == null || value.isEmpty || double.tryParse(value) != null
                ? null
                : 'Invalid number';

      case ExpectedType.email:
        return (value) =>
            value == null ||
                    value.isEmpty ||
                    RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                        .hasMatch(value)
                ? null
                : 'Invalid email';

      case ExpectedType.phone:
        return (value) =>
            value == null || value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)
                ? null
                : 'Invalid phone number';

      case ExpectedType.date:
        return (value) {
          if (value == null || value.isEmpty) return null;
          try {
            DateTime.parse(value);
            return null;
          } catch (_) {
            return 'Invalid date (use YYYY-MM-DD)';
          }
        };

      case ExpectedType.name:
        return (value) =>
            value == null || value.isEmpty || RegExp(r'^[A-Za-z\s\-]+$').hasMatch(value)
                ? null
                : 'Invalid name';

      case ExpectedType.upload:
        return (value) {
          if (value == null || value.isEmpty) return null;
          const allowed = {'jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'};
          final ext = value.split('.').last.toLowerCase();
          return allowed.contains(ext) ? null : 'Unsupported file type: .$ext';
        };

      case ExpectedType.grid:
        return (value) {
          if (value == null || value.isEmpty) return null;
          if (!value.trim().startsWith('[')) return 'Grid must be a JSON array';
          return null;
        };

      case ExpectedType.checkbox:
        return (value) {
          if (value == null || value.isEmpty) return null;
          const valid = {'true', 'false', '1', '0', 'yes', 'no'};
          return valid.contains(value.toLowerCase())
              ? null
              : 'Invalid checkbox value';
        };

      default:
        return (value) => null;
    }
  }
}
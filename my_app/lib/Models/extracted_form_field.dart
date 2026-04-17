class ExtractedFormField {
  final String id;
  final String label;
  final String type;
  final bool required;
  final List<String> options;
  final String? placeholder;
  final String mappedKey;
  final String cssSelector;

  ExtractedFormField({
    required this.id,
    required this.label,
    required this.type,
    required this.required,
    this.options = const [],
    this.placeholder,
    required this.mappedKey,
    required this.cssSelector,
  });

  factory ExtractedFormField.fromJson(Map<String, dynamic> json) {
    return ExtractedFormField(
      id: json['id']?.toString() ??
          'field_${DateTime.now().millisecondsSinceEpoch}',
      label: json['label']?.toString() ?? 'Field',
      type: json['type']?.toString() ?? 'text',
      required: json['required'] == true,
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      placeholder: json['placeholder']?.toString(),
      mappedKey: json['mappedKey']?.toString() ?? 'general.unknown',
      cssSelector:
          json['cssSelector']?.toString() ?? '[name="${json['id'] ?? 'field'}"]',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type,
        'required': required,
        'options': options,
        'placeholder': placeholder,
        'mappedKey': mappedKey,
        'cssSelector': cssSelector,
      };
}

class WebFormSchema {
  final String url;
  final String title;
  final List<ExtractedFormField> fields;

  WebFormSchema({
    required this.url,
    required this.title,
    required this.fields,
  });

  factory WebFormSchema.fromJson(String url, Map<String, dynamic> json) {
    return WebFormSchema(
      url: url,
      title: json['title']?.toString() ?? 'Untitled Form',
      fields: (json['fields'] as List<dynamic>?)
              ?.map((f) => ExtractedFormField.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

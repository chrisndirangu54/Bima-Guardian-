class Company {
  final String id;
  final String name;
  final List<String> pdfTemplateKeys; // e.g., ['default', 'health_template']

  Company({
    required this.id,
    required this.name,
    required this.pdfTemplateKeys,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pdfTemplateKeys': pdfTemplateKeys,
  };

  factory Company.fromJson(Map<String, dynamic> json) => Company(
    id: json['id'],
    name: json['name'],
    pdfTemplateKeys: List<String>.from(json['pdfTemplateKeys']),
  );
}

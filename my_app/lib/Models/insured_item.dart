import 'package:my_app/Models/policy.dart';

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

  InsuredItem( {
    required this.id,
    required this.details,
    required this.kraPin,
required this.name, required this.email, required this.contact,
    this.logbookPath,
    this.previousPolicyPath,
    required this.type,
    required this.subtype,
    required this.coverageType,
    this.previousCompanies = const [],
  });
}
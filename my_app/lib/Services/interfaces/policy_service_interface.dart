import 'package:my_app/Models/policy.dart';
import 'package:my_app/Models/pdf_template.dart';
import 'package:my_app/Models/company.dart';

abstract class IPolicyService {
  Future<List<PolicyType>> getPolicyTypes();
  Future<List<PolicySubtype>> getPolicySubtypes(String policyTypeId);
  Future<List<CoverageType>> getCoverageTypes(String subtypeId);
  Future<PDFTemplate?> getPDFTemplate(String pdfTemplateKey);
  Future<List<Company>> getCompanies();
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:my_app/Services/interfaces/auth_service_interface.dart';
import 'package:my_app/Services/interfaces/policy_service_interface.dart';
import 'package:my_app/Models/policy.dart';
import 'package:my_app/Models/company.dart';
import 'package:my_app/Models/pdf_template.dart';
import 'package:my_app/Models/cover.dart';

class MockAuthService implements IAuthService {
  bool initializeCalled = false;
  bool signInCalled = false;

  @override
  Future<void> initializeUserData(User user) async {
    initializeCalled = true;
    return;
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    signInCalled = true;
    final auth = MockFirebaseAuth(
      mockUser: MockUser(
        isAnonymous: false,
        uid: 'test-uid',
        email: 'test@example.com',
        displayName: 'Test User',
      ),
    );
    return auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: 'fake-id-token', accessToken: 'fake-access-token'),
    );
  }
}

class MockPolicyService implements IPolicyService {
  final List<PolicyType> _types;
  final Map<String, List<PolicySubtype>> _subtypes;
  final Map<String, List<CoverageType>> _coverage;
  final Map<String, PDFTemplate> _templates;
  final List<Company> _companies;

  MockPolicyService({
    List<PolicyType>? types,
    Map<String, List<PolicySubtype>>? subtypes,
    Map<String, List<CoverageType>>? coverage,
    Map<String, PDFTemplate>? templates,
    List<Company>? companies,
  })  : _types = types ?? [PolicyType(id: '1', name: 'Motor', description: 'Motor insurance')],
        _subtypes = subtypes ?? {
          '1': [PolicySubtype(id: '1', name: 'Private', policyTypeId: '1', description: '')]
        },
        _coverage = coverage ?? {
          '1': [CoverageType(id: '1', name: 'Comprehensive', description: '')]
        },
        _templates = templates ?? {},
        _companies = companies ?? [Company(id: '1', name: 'TestCo', pdfTemplateKey: const [])];

  @override
  Future<List<PolicyType>> getPolicyTypes() async => _types;

  @override
  Future<List<PolicySubtype>> getPolicySubtypes(String policyTypeId) async =>
      _subtypes[policyTypeId] ?? [];

  @override
  Future<List<CoverageType>> getCoverageTypes(String subtypeId) async =>
      _coverage[subtypeId] ?? [];

  @override
  Future<PDFTemplate?> getPDFTemplate(String pdfTemplateKey) async =>
      _templates[pdfTemplateKey];

  @override
  Future<List<Company>> getCompanies() async => _companies;
}
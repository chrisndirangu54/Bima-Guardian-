import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_app/Models/company.dart';
import 'package:my_app/Models/pdf_template.dart';
import 'package:my_app/Models/policy.dart';
import 'interfaces/auth_service_interface.dart';
import 'interfaces/policy_service_interface.dart';

import '../Services/auth_service.dart' as auth_impl;
import '../insurance_app.dart' as ia;

final GetIt getIt = GetIt.instance;

class AuthServiceAdapter implements IAuthService {
  @override
  Future<void> initializeUserData(User user) =>
      auth_impl.AuthService.initializeUserData(user);

  @override
  Future<UserCredential> signInWithGoogle() =>
      auth_impl.AuthService.signInWithGoogle();
}

class PolicyServiceAdapter implements IPolicyService {
  @override
  Future<List<PolicyType>> getPolicyTypes() => ia.InsuranceHomeScreen.getPolicyTypes();

  @override
  Future<List<PolicySubtype>> getPolicySubtypes(String policyTypeId) =>
      ia.InsuranceHomeScreen.getPolicySubtypes(policyTypeId);

  @override
  Future<List<CoverageType>> getCoverageTypes(String subtypeId) =>
      ia.InsuranceHomeScreen.getCoverageTypes(subtypeId);

  @override
  Future<PDFTemplate?> getPDFTemplate(String pdfTemplateKey) =>
      ia.InsuranceHomeScreen.getPDFTemplate(pdfTemplateKey);

  @override
  // NOTE: this previously called InsuranceHomeScreen.loadCompanies(), which
  // is dead mock-data code — it always returns 3 hardcoded fake companies
  // (AIG, Cigna, UnitedHealth) with empty pdfTemplateKey lists and never
  // touches Firestore. getCompanies() is the real, Firestore-backed, cached
  // implementation used everywhere else in this app.
  Future<List<Company>> getCompanies() => ia.InsuranceHomeScreen.getCompanies();
}

Future<void> setupDI() async {
  // Register singletons / factories
  if (!getIt.isRegistered<IAuthService>()) {
    getIt.registerLazySingleton<IAuthService>(() => AuthServiceAdapter());
  }
  if (!getIt.isRegistered<IPolicyService>()) {
    getIt.registerLazySingleton<IPolicyService>(() => PolicyServiceAdapter());
  }
}
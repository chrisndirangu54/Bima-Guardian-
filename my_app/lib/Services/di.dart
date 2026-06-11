import 'package:get_it/get_it.dart';
import 'interfaces/auth_service_interface.dart';
import 'interfaces/policy_service_interface.dart';

import '../Services/auth_service.dart' as auth_impl;
import '../insurance_app.dart' as ia;

final GetIt getIt = GetIt.instance;

class AuthServiceAdapter implements IAuthService {
  @override
  Future<void> initializeUserData(user) => auth_impl.AuthService.initializeUserData(user);

  @override
  Future<dynamic> signInWithGoogle() => auth_impl.AuthService.signInWithGoogle();
}

class PolicyServiceAdapter implements IPolicyService {
  @override
  Future<List<PolicyType>> getPolicyTypes() => ia.InsuranceHomeScreen.getPolicyTypes();

  @override
  Future<List<PolicySubtype>> getPolicySubtypes(String policyTypeId) => ia.InsuranceHomeScreen.getPolicySubtypes(policyTypeId);

  @override
  Future<List<CoverageType>> getCoverageTypes(String subtypeId) => ia.InsuranceHomeScreen.getCoverageTypes(subtypeId);

  @override
  Future<PDFTemplate?> getPDFTemplate(String pdfTemplateKey) => ia.InsuranceHomeScreen.getPDFTemplate(pdfTemplateKey);

  @override
  Future<List<Company>> getCompanies() => ia.InsuranceHomeScreen.loadCompanies();
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

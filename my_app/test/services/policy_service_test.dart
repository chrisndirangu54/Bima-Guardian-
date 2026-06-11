import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/Services/di.dart' as di;
import 'services/mocks/mock_services.dart';
import 'package:my_app/Models/policy.dart';
import 'package:my_app/Services/policy_module_service.dart';

void main() {
  group('PolicyService DI and PolicyModule tests', () {
    setUp(() async {
      await di.getIt.reset();
      di.getIt.registerLazySingleton(() => MockPolicyService());
    });

    test('ConfigDrivenPolicyModule resolves policy from message', () async {
      final svc = di.getIt<MockPolicyService>();

      final policyType = PolicyType(id: '1', name: 'Motor', description: 'Motor insurance');

      final module = ConfigDrivenPolicyModule(
        policyType: policyType,
        getSubtypes: (id) => di.getIt<MockPolicyService>().getPolicySubtypes(id),
        getCoverageTypes: (id) => di.getIt<MockPolicyService>().getCoverageTypes(id),
        getCompanies: () => di.getIt<MockPolicyService>().getCompanies(),
      );

      final res = await module.resolveFromMessage('I want motor private comprehensive with TestCo');

      expect(res, isNotNull);
      expect(res!.type.name.toLowerCase(), contains('motor'));
      expect(res.subtype.name.toLowerCase(), contains('private'));
      expect(res.coverageType.name.toLowerCase(), contains('comprehensive'));
      expect(res.companyName?.toLowerCase(), contains('testco'));
    });
  });
}

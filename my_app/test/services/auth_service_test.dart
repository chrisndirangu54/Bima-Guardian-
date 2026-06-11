import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/Services/di.dart' as di;
import 'mocks/mock_services.dart';
import 'package:my_app/Services/interfaces/auth_service_interface.dart';

void main() {
  group('AuthService DI tests', () {
    setUp(() async {
      // Reset GetIt and register mock
      await di.getIt.reset();
      di.getIt.registerLazySingleton<IAuthService>(() => MockAuthService());
    });

    test('MockAuthService is used via DI', () async {
      final svc = di.getIt<IAuthService>();
      final mock = svc as MockAuthService;

      expect(mock.initializeCalled, isFalse);
      await svc.initializeUserData(null);
      expect(mock.initializeCalled, isTrue);

      expect(mock.signInCalled, isFalse);
      await svc.signInWithGoogle();
      expect(mock.signInCalled, isTrue);
    });
  });
}

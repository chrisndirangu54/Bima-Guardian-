import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
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
      // initializeUserData(User user) requires a real User — null was
      // never valid here once the interface was correctly typed.
      // MockUser fully implements User, so it's a valid stand-in.
      await svc.initializeUserData(MockUser(uid: 'test-uid', email: 'test@example.com'));
      expect(mock.initializeCalled, isTrue);

      expect(mock.signInCalled, isFalse);
      await svc.signInWithGoogle();
      expect(mock.signInCalled, isTrue);
    });
  });
}
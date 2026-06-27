import 'package:firebase_auth/firebase_auth.dart';

abstract class IAuthService {
  Future<void> initializeUserData(User user);
  Future<UserCredential> signInWithGoogle();
}

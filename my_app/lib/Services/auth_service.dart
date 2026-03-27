import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static Future<void> initializeUserData(User user) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    await userDoc.set({
      'createdAt': FieldValue.serverTimestamp(),
      'role': 'user',
      'isAdmin': false,
      'details': {
        'name': user.displayName ?? 'Anonymous',
        'email': user.email ?? '',
        'phone': user.phoneNumber ?? '',
      'details': {
        'name': user.displayName ?? 'Anonymous',
        'email': user.email ?? '',
      },
    }, SetOptions(merge: true));

    await userDoc.collection('policies').doc('default').set({
      'id': 'default',
      'type': 'Motor',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await userDoc.collection('quotes').doc('default').set({
      'id': 'default',
      'type': 'Motor',
      'amount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await userDoc.collection('insured_items').doc('default').set({
      'id': 'default',
      'type': 'Motor',
      'name': 'Default Item',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      return FirebaseAuth.instance.signInWithPopup(googleProvider);
    }

    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'google-signin-cancelled',
        message: 'Google Sign-In was cancelled by the user.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return FirebaseAuth.instance.signInWithCredential(credential);
  }
}

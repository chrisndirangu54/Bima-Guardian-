import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  /// Initializes Firestore data for [user].
  ///
  /// Called on both signup AND every login path (see login.dart/signup.dart),
  /// so this must be safe to call repeatedly without clobbering data that was
  /// set after the user's account was first created — most importantly their
  /// `isAdmin`/`role` fields, which an admin may have changed via the Admin
  /// Panel. We only seed those fields (and the default sub-documents) the
  /// FIRST time we see this user; on every subsequent call we just keep their
  /// contact details fresh.
  static Future<void> initializeUserData(User user) async {
    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    final existing = await userDoc.get();
    final isFirstTime = !existing.exists;

    await userDoc.set({
      if (isFirstTime) 'createdAt': FieldValue.serverTimestamp(),
      // Only seed role/isAdmin on first creation. Never overwrite them on
      // subsequent logins — doing so silently undoes any admin promotion.
      if (isFirstTime) 'role': 'user',
      if (isFirstTime) 'isAdmin': false,
      'details': {
        'name': user.displayName ?? 'Anonymous',
        'email': user.email ?? '',
        'phone': user.phoneNumber ?? '',
      },
    }, SetOptions(merge: true));

    if (!isFirstTime) return;

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
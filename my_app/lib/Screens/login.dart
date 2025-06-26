import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (kDebugMode) print('Login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      await initializeUserData(userCredential.user!.uid);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (kDebugMode) print('Anonymous login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Anonymous login failed: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Login',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          value!.isEmpty ? 'Enter an email' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      validator: (value) =>
                          value!.isEmpty ? 'Enter a password' : null,
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : Column(
                            children: [
                              ElevatedButton(
                                onPressed: _login,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Login'),
                              ),

                            ],
                          ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _signInAnonymously,
                      child: const Text('Continue as Guest'),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/signup'),
                      child: const Text('Don\'t have an account? Sign Up'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// Reuse the initializeUserData function from your original code
Future<void> initializeUserData(String userId) async {
  try {
    var userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
    await userDoc.set({
      'createdAt': FieldValue.serverTimestamp(),
      'details': {'name': 'Anonymous', 'email': ''},
    }, SetOptions(merge: true));
    await userDoc.collection('policies').doc('default').set({
      'id': 'default',
      'type': 'Motor',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await userDoc.collection('quotes').doc('default').set({
      'id': 'default',
      'type': 'Motor',
      'amount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await userDoc.collection('insured_items').doc('default').set({
      'id': 'default',
      'type': 'Motor',
      'name': 'Default Item',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (kDebugMode) print('Initialized default user details for $userId');
  } catch (e, stackTrace) {
    if (kDebugMode) print('Error initializing user details: $e\n$stackTrace');
  }
}
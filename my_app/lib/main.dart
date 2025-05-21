import 'package:flutter/material.dart';
import 'package:my_app/Screens/Policy_report_screen.dart';
import 'package:my_app/Screens/admin_panel.dart';
import 'package:my_app/insurance_app.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:my_app/firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseMessaging.instance.requestPermission();

  // --- THIS IS THE CRUCIAL CHANGE FOR STRIPE ON WEB ---
  if (!kIsWeb) {
    // Only initialize Stripe's native components on non-web platforms
    Stripe.publishableKey = 'your-stripe-publishable-key';
    await Stripe.instance.applySettings();
  } else {
    // For web, Stripe works directly with its JS SDK.
    // The flutter_stripe package usually handles this internally,
    // so explicit web-only initialization here is often not strictly needed
    // unless you have specific web-only Stripe configuration needs.
    debugPrint(
      'Stripe initialization (native parts) skipped on web (kIsWeb is true).',
    );
  }
  // ---------------------------------------------------

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Insurance Form Extractor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const InsuranceHomeScreen(),
      routes: {
        '/admin': (context) => const AdminPanel(),
        '/policy_report': (context) => const CoverReportScreen(),
      },
    );
  }
}

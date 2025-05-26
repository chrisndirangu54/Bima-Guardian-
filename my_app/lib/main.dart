import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:my_app/Providers/theme_provider.dart';
import 'package:my_app/Screens/Policy_report_screen.dart';
import 'package:my_app/Screens/admin_panel.dart';
import 'package:my_app/insurance_app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      print('Firebase initialized successfully');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error initializing Firebase: $e');
    }
  }

  // Sign in anonymously
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
      if (kDebugMode) {
        print(
            'Signed in anonymously: ${FirebaseAuth.instance.currentUser?.uid}');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error signing in anonymously: $e');
    }
  }

  // Request Firebase Messaging permissions
  try {
    await FirebaseMessaging.instance.requestPermission();
    if (kDebugMode) {
      print('Firebase Messaging permission requested');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error requesting Firebase Messaging permission: $e');
    }
  }

  // Initialize Stripe
  if (!kIsWeb) {
    try {
      Stripe.publishableKey = 'your-stripe-publishable-key';
      await Stripe.instance.applySettings();
      if (kDebugMode) {
        print('Stripe initialized for native platforms');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Stripe: $e');
      }
    }
  } else {
    if (kDebugMode) {
      print(
          'Stripe initialization (native parts) skipped on web (kIsWeb is true).');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => ColorProvider()),
        ChangeNotifierProvider(create: (context) => DialogState()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Bima Guardian',
      theme: ThemeData(
        primaryColor: Color(0xFF1B263B),
        scaffoldBackgroundColor: Color(0xFFFFFFFF),
        colorScheme: ColorScheme.light(
          primary: Color(0xFF1B263B),
          secondary: Color(0xFF8B0000),
          tertiary: Color(0xFFD4A017),
          surface: Color(0xFFFFFFFF),
          onPrimary: Color(0xFFFFFFFF),
          onSecondary: Color(0xFFFFFFFF),
          onTertiary: Color(0xFF1B263B),
          onSurface: Color(0xFF1B263B),
          error: Color(0xFFB00020),
        ),
        textTheme: GoogleFonts.robotoTextTheme().apply(
          bodyColor: Color(0xFF1B263B),
          displayColor: Color(0xFF1B263B),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF8B0000),
            foregroundColor: Color(0xFFFFFFFF),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: GoogleFonts.roboto(fontWeight: FontWeight.w500),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Color(0xFF1B263B),
            textStyle: GoogleFonts.roboto(fontWeight: FontWeight.w500),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFFD3D3D3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFFD3D3D3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFFD4A017)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFFB00020)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFFB00020)),
          ),
          labelStyle: GoogleFonts.roboto(color: Color(0xFFD3D3D3)),
          hintStyle: GoogleFonts.roboto(color: Color(0xFFD3D3D3)),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF1B263B),
          elevation: 0,
          titleTextStyle: GoogleFonts.lora(
            color: Color(0xFF1B263B),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        dividerTheme: DividerThemeData(
          color: Color(0xFFD3D3D3),
          thickness: 1,
        ),
        iconTheme: IconThemeData(color: Color(0xFF1B263B)),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF8B0000),
          foregroundColor: Color(0xFFFFFFFF),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        primaryColor: Color(0xFF1B263B),
        scaffoldBackgroundColor: Color(0xFF121212),
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF1B263B),
          secondary: Color(0xFF8B0000),
          tertiary: Color(0xFFD4A017),
          surface: Color(0xFF121212),
          onPrimary: Color(0xFFFFFFFF),
          onSecondary: Color(0xFFFFFFFF),
          onTertiary: Color(0xFF1B263B),
          onSurface: Color(0xFFFFFFFF),
          error: Color(0xFFCF6679),
        ),
        textTheme: GoogleFonts.robotoTextTheme().apply(
          bodyColor: Color(0xFFFFFFFF),
          displayColor: Color(0xFFFFFFFF),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF8B0000),
            foregroundColor: Color(0xFFFFFFFF),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: GoogleFonts.roboto(fontWeight: FontWeight.w500),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Color(0xFFD4A017),
            textStyle: GoogleFonts.roboto(fontWeight: FontWeight.w500),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFF757575)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFF757575)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFFD4A017)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFFCF6679)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFFCF6679)),
          ),
          labelStyle: GoogleFonts.roboto(color: Color(0xFF757575)),
          hintStyle: GoogleFonts.roboto(color: Color(0xFF757575)),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF121212),
          foregroundColor: Color(0xFFFFFFFF),
          elevation: 0,
          titleTextStyle: GoogleFonts.lora(
            color: Color(0xFFFFFFFF),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        dividerTheme: DividerThemeData(
          color: Color(0xFF757575),
          thickness: 1,
        ),
        iconTheme: IconThemeData(color: Color(0xFFFFFFFF)),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF8B0000),
          foregroundColor: Color(0xFFFFFFFF),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      themeMode: themeProvider.themeMode,
      home: const InsuranceHomeScreen(),
      routes: {
        '/admin': (context) => const AdminPanel(),
        '/policy_report': (context) => const CoverReportScreen(),
      },
    );
  }
}

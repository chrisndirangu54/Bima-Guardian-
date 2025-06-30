import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/Screens/login.dart';
import 'package:provider/provider.dart';
import 'package:my_app/Providers/theme_provider.dart';
import 'package:my_app/Screens/Policy_report_screen.dart';
import 'package:my_app/Screens/admin_panel.dart';
import 'package:my_app/insurance_app.dart';
import 'package:my_app/Screens/signup.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'firebase_options.dart';
import 'package:webview_flutter_web/webview_flutter_web.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  if (kIsWeb) {
    WebViewPlatform.instance = WebWebViewPlatform();
  }
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      print('Firebase initialized successfully');
    }

    // Configure Firestore persistence (before any Firestore operations)
    if (!kIsWeb) {
      // Enable persistence for native platforms
      await DefaultFirebaseOptions.enableFirestorePersistence();
    } else {
      // Disable persistence for web to avoid IndexedDB issues
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
      if (kDebugMode) {
        print('Firestore persistence disabled for web');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error initializing Firebase or Firestore settings: $e');
    }
  }

// Sign in anonymously
try {
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  if (FirebaseAuth.instance.currentUser == null) {
    final userCredential = await FirebaseAuth.instance.signInAnonymously();
    if (kDebugMode) print('Signed in anonymously: ${userCredential.user?.uid}');
    await initializeUserData(userCredential.user!.uid);
  } else {
    if (kDebugMode) print('User already authenticated: ${FirebaseAuth.instance.currentUser?.uid}');
  }
} catch (e, stackTrace) {
  if (kDebugMode) print('Error signing in anonymously: $e\n$stackTrace');
}

  // Request Firebase Messaging permissions
  try {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    if (kDebugMode) {
      print('Firebase Messaging permission status: ${settings.authorizationStatus}');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error requesting Firebase Messaging permission: $e');
    }
  }

  // Initialize Stripe
  if (!kIsWeb) {
    try {
      Stripe.publishableKey = 'your-stripe-publishable-key'; // Replace with actual key
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
      print('Stripe initialization (native parts) skipped on web (kIsWeb is true).');
    }
    // Optional: Initialize Stripe for web if using flutter_stripe_web
    // Stripe.publishableKey = 'your-stripe-publishable-key';
    // Add web-specific Stripe setup here if needed
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Define the modern accent color (Electric Cyan)
    const modernAccent = Color(0xFF00D1D1);
    const oliveGreen = Color.fromARGB(255, 171, 253, 6); // Olive green for containers
    const secondaryOlive = Color.fromARGB(255, 145, 175, 88); // Olive green
    const lightCream = Color(0xFFEFFBDB); // Light cream for contrast
    const darkTeal = Color(0xFF10212B); // Dark teal for primary elements

    return MaterialApp(
      title: 'Bima Guardian',
      theme: ThemeData(
        primaryColor: darkTeal, // Dark teal
        scaffoldBackgroundColor: Colors.white, // White background
        colorScheme: ColorScheme.light(
          primary: darkTeal, // Dark teal
          secondary: darkTeal, // Olive green
          tertiary: modernAccent, // Electric cyan
          surface: lightCream, // White surface
          onPrimary: Colors.white, // White on dark teal
          onSecondary: Colors.white, // White on olive green
          onTertiary: Colors.black, // Black on cyan
          onSurface: const Color(0xFF10212B), // Dark teal on white
          error: const Color(0xFFE57373), // Error red
        ),
        textTheme: GoogleFonts.robotoTextTheme()
            .apply(
              bodyColor: const Color(0xFF10212B),
              displayColor: const Color(0xFF10212B),
            )
            .copyWith(
              titleLarge: GoogleFonts.lora(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF10212B),
              ),
              bodyLarge: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF10212B),
              ),
              bodyMedium: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
              bodySmall: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: const Color.fromARGB(255, 0, 0, 0),
              ),
            ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10212B), // Dark teal
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 24,
            ),
            elevation: 4,
            shadowColor: const Color(0xFF10212B).withOpacity(0.3),
            textStyle: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF10212B), // Dark teal
            textStyle: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color.fromARGB(255, 178, 180, 174)), // Olive
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: modernAccent), // Olive
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Color(0xFF10212B), width: 2), // Dark teal
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE57373)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE57373), width: 2),
          ),
          labelStyle: GoogleFonts.roboto(
            color: oliveGreen, // Olive
            fontSize: 16,
          ),
          hintStyle: GoogleFonts.roboto(
            color: const Color.fromARGB(255, 78, 79, 78).withOpacity(0.7), // Olive
            fontSize: 16,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 16,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF10212B), // Dark teal
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: const Color(0xFF000000).withOpacity(0.2),
          titleTextStyle: GoogleFonts.lora(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
          centerTitle: true,
        ),
        dividerTheme: const DividerThemeData(
          color: Color.fromARGB(255, 119, 145, 68), // Olive
          thickness: 1,
        ),
        iconTheme: const IconThemeData(color: lightCream), // Dark teal
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: modernAccent, // Electric cyan
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 10,
          highlightElevation: 12,
          extendedPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
        ),
        cardTheme: CardThemeData(
          color: secondaryOlive, // Olive green for containers/cards
          elevation: 6,
          shadowColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(12),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        primaryColor: const Color.fromARGB(255, 2, 30, 46), // Dark teal
        scaffoldBackgroundColor: Colors.black, // White background
        colorScheme: ColorScheme.dark(
          primary: const Color.fromARGB(255, 6, 109, 169), // Olive green
          secondary: Colors.blue, // Electric cyan
          tertiary: const Color.fromARGB(255, 9, 9, 9), // Light cream
          surface: const Color.fromARGB(255, 31, 31, 31), // White surface
          onPrimary: const Color.fromARGB(255, 33, 32, 32), // White on olive
          onSecondary: Colors.black, // Black on cyan
          onTertiary: const Color.fromARGB(255, 195, 201, 204), // Dark teal on cream
          onSurface: const Color.fromARGB(255, 108, 156, 3), // Dark teal on white
          error: const Color(0xFFE57373), // Error red
        ),
        textTheme: GoogleFonts.robotoTextTheme()
            .apply(
              bodyColor: const Color.fromARGB(255, 5, 149, 233),
              displayColor: const Color.fromARGB(255, 9, 150, 231),
            )
            .copyWith(
              titleLarge: GoogleFonts.lora(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: const Color.fromARGB(255, 117, 158, 93),
              ),
              bodyLarge: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: const Color.fromARGB(255, 94, 134, 70),
              ),
              bodyMedium: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
              bodySmall: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: const Color.fromARGB(255, 0, 0, 0),
              ),

            ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: oliveGreen, // Olive
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 24,
            ),
            elevation: 8,
            shadowColor: const Color(0xFF000000).withOpacity(0.4),
            textStyle: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: modernAccent, // Electric cyan
            textStyle: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color.fromARGB(255, 31, 132, 226)), // Olive
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color.fromARGB(255, 5, 56, 198)), // Olive
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: modernAccent, width: 2), // Cyan
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE57373)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE57373), width: 2),
          ),
          labelStyle: GoogleFonts.roboto(
            color: const Color.fromARGB(255, 20, 148, 246), // Olive
            fontSize: 16,
          ),
          hintStyle: GoogleFonts.roboto(
            color: const Color.fromARGB(255, 208, 224, 229).withOpacity(0.7), // Olive
            fontSize: 16,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 16,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF10212B), // Dark teal
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: const Color(0xFF000000).withOpacity(0.3),
          titleTextStyle: GoogleFonts.lora(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
          centerTitle: true,
        ),
        dividerTheme: const DividerThemeData(
          color: oliveGreen, // Olive
          thickness: 1,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF10212B)), // Dark teal
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: modernAccent, // Electric cyan
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 10,
          highlightElevation: 12,
          extendedPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color.fromARGB(255, 13, 13, 23), // Olive green for containers/cards
          elevation: 6,
          shadowColor: const Color(0xFF000000).withOpacity(0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(12),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      themeMode: themeProvider.themeMode,
      home: const InsuranceHomeScreen(),
      routes: {
        '/admin': (context) => const AdminPanel(),
        '/policy_report': (context) => const CoverReportScreen(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
      },
    );
  }
}

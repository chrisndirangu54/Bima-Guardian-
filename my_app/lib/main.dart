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
        primaryColor:
            const Color.fromARGB(255, 35, 31, 242), // American flag blue
        scaffoldBackgroundColor: const Color(0xFFFFFFFF), // White
        colorScheme: const ColorScheme.light(
          primary: Color.fromARGB(255, 31, 27, 239), // Blue
          secondary: Color(0xFFB22234), // Red
          tertiary: Color(0xFFFFD700), // Gold
          surface: Color(0xFFFFFFFF), // White
          onPrimary: Color(0xFFFFFFFF), // White on blue
          onSecondary: Color(0xFFFFFFFF), // White on red
          onTertiary: Color(0xFF000000), // Black on gold
          onSurface: Color(0xFF000000), // Black on white
          error: Color(0xFFE57373), // Error red
        ),
        textTheme: GoogleFonts.robotoTextTheme()
            .apply(
              bodyColor: const Color(0xFF000000),
              displayColor: const Color(0xFF000000),
            )
            .copyWith(
              titleLarge: GoogleFonts.lora(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF000000),
              ),
              bodyLarge: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF000000),
              ),
            ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB22234), // Red
            foregroundColor: const Color(0xFFFFFFFF), // White
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // Softer corners
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 24,
            ), // Increased padding
            elevation: 8, // Higher elevation
            shadowColor:
                const Color(0xFF000000).withOpacity(0.3), // Pronounced shadow
            textStyle: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color.fromARGB(255, 49, 46, 239), // Blue
            textStyle: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ), // Increased padding
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), // Softer corners
            borderSide: const BorderSide(color: Color(0xFFBBBBBB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFBBBBBB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Color.fromARGB(255, 48, 45, 251), width: 2), // Blue
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
            color: const Color(0xFF757575),
            fontSize: 16,
          ),
          hintStyle: GoogleFonts.roboto(
            color: const Color(0xFF757575),
            fontSize: 16,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 16,
          ), // Increased padding
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFFFFFFF), // White
          foregroundColor: const Color(0xFF000000), // Black
          elevation: 4, // Increased elevation
          shadowColor:
              const Color(0xFF000000).withOpacity(0.2), // Pronounced shadow
          titleTextStyle: GoogleFonts.lora(
            color: const Color(0xFF000000),
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
          centerTitle: true, // iOS-style centered title
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFBBBBBB),
          thickness: 1,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF000000)),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: const Color(0xFFFFD700), // Gold
          foregroundColor: const Color(0xFF000000), // Black
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // Softer corners
          ),
          elevation: 10, // Higher elevation
          highlightElevation: 12,
          extendedPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ), // Increased padding
        ),
        cardTheme: CardTheme(
          color: const Color(0xFFFFFFFF), // White
          elevation: 6, // Increased elevation
          shadowColor:
              const Color(0xFF000000).withOpacity(0.25), // Pronounced shadow
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Softer corners
          ),
          margin: const EdgeInsets.all(12), // Increased spacing
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        primaryColor: const Color.fromARGB(255, 34, 31, 228), // Blue
        scaffoldBackgroundColor: const Color(0xFF2A2A2A), // Dark gray
        colorScheme: const ColorScheme.dark(
          primary: Color.fromARGB(255, 34, 31, 255), // Blue
          secondary: Color(0xFFB22234), // Red
          tertiary: Color(0xFFFFD700), // Gold
          surface: Color(0xFF2A2A2A), // Dark gray
          onPrimary: Color(0xFFFFFFFF), // White on blue
          onSecondary: Color(0xFFFFFFFF), // White on red
          onTertiary: Color(0xFF000000), // Black on gold
          onSurface: Color(0xFFFFFFFF), // White on dark
          error: Color(0xFFE57373), // Error red
        ),
        textTheme: GoogleFonts.robotoTextTheme()
            .apply(
              bodyColor: const Color(0xFFFFFFFF),
              displayColor: const Color(0xFFFFFFFF),
            )
            .copyWith(
              titleLarge: GoogleFonts.lora(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFFFFFF),
              ),
              bodyLarge: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: const Color(0xFFFFFFFF),
              ),
            ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB22234), // Red
            foregroundColor: const Color(0xFFFFFFFF), // White
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 24,
            ), // Increased padding
            elevation: 8, // Higher elevation
            shadowColor:
                const Color(0xFF000000).withOpacity(0.4), // Pronounced shadow
            textStyle: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFFFD700), // Gold
            textStyle: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ), // Increased padding
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF757575)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF757575)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF3C3B6E), width: 2), // Blue
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
            color: const Color(0xFF757575),
            fontSize: 16,
          ),
          hintStyle: GoogleFonts.roboto(
            color: const Color(0xFF757575),
            fontSize: 16,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 16,
          ), // Increased padding
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF2A2A2A), // Dark gray
          foregroundColor: const Color(0xFFFFFFFF), // White
          elevation: 4, // Increased elevation
          shadowColor:
              const Color(0xFF000000).withOpacity(0.3), // Pronounced shadow
          titleTextStyle: GoogleFonts.lora(
            color: const Color(0xFFFFFFFF),
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
          centerTitle: true, // iOS-style centered title
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF757575),
          thickness: 1,
        ),
        iconTheme: const IconThemeData(color: Color(0xFFFFFFFF)),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: const Color(0xFFFFD700), // Gold
          foregroundColor: const Color(0xFF000000), // Black
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 10, // Higher elevation
          highlightElevation: 12,
          extendedPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ), // Increased padding
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF2A2A2A), // Dark gray
          elevation: 6, // Increased elevation
          shadowColor:
              const Color(0xFF000000).withOpacity(0.35), // Pronounced shadow
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(12), // Increased spacing
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

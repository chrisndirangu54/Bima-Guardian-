import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
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
import 'Services/di.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.setupDI();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) print('Firebase initialized successfully');

    if (!kIsWeb) {
      await DefaultFirebaseOptions.enableFirestorePersistence();
    } else {
      FirebaseFirestore.instance.settings =
          const Settings(persistenceEnabled: false);
      if (kDebugMode) print('Firestore persistence disabled for web');
    }
  } catch (e) {
    if (kDebugMode) print('Error initializing Firebase: $e');
  }

  try {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      print('FCM permission: ${settings.authorizationStatus}');
    }
  } catch (e) {
    if (kDebugMode) print('FCM permission error: $e');
  }

  if (kIsWeb) {
    WebViewPlatform.instance = WebWebViewPlatform();
  }

  if (!kIsWeb) {
    try {
      Stripe.publishableKey = 'your-stripe-publishable-key';
      await Stripe.instance.applySettings();
    } catch (e) {
      if (kDebugMode) print('Stripe init error: $e');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ColorProvider()),
        ChangeNotifierProvider(create: (_) => DialogState()),
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

    // ── Core palette tokens ──────────────────────────────────────────────────
    const darkTeal       = Color(0xFF10212B); // primary backgrounds, appbars
    const deepTealShade  = Color(0xFF0C1A21); // deeper variant for depth
    const acidOlive      = Color(0xFFABFD06); // primary accent (CTA, FAB, highlights)
    const softOlive      = Color(0xFF91AF58); // secondary, muted accent
    const electricCyan   = Color(0xFF00D1D1); // tertiary highlight, links
    const creamSurface   = Color(0xFFEFFBDB); // light surface / cards
    const creamDark      = Color(0xFFD8EBB8); // slightly deeper cream for borders
    const onDark         = Color(0xFFEFFBDB); // text on dark backgrounds
    const errorRed       = Color(0xFFFF6B6B); // error state

    // ── Light Theme ───────────────────────────────────────────────────────────
    final lightTheme = ThemeData(
      useMaterial3: true,
      primaryColor: darkTeal,
      scaffoldBackgroundColor: const Color(0xFFF5FAF0),
      colorScheme: const ColorScheme.light(
        primary:          darkTeal,
        primaryContainer: Color(0xFF1E3340),
        secondary:        softOlive,
        secondaryContainer: Color(0xFFD4ECA8),
        tertiary:         electricCyan,
        surface:          creamSurface,
        surfaceContainerHighest: creamDark,
        onPrimary:        Colors.white,
        onSecondary:      Colors.white,
        onTertiary:       darkTeal,
        onSurface:        darkTeal,
        onSurfaceVariant: Color(0xFF4A6741),
        error:            errorRed,
        onError:          Colors.white,
        outline:          Color(0xFFB8D4A0),
        shadow:           Color(0xFF000000),
      ),
      textTheme: GoogleFonts.dmSansTextTheme().copyWith(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 32, fontWeight: FontWeight.w700, color: darkTeal,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 26, fontWeight: FontWeight.w600, color: darkTeal,
        ),
        titleLarge: GoogleFonts.playfairDisplay(
          fontSize: 20, fontWeight: FontWeight.w600, color: darkTeal,
        ),
        titleMedium: GoogleFonts.dmSans(
          fontSize: 16, fontWeight: FontWeight.w600, color: darkTeal,
          letterSpacing: 0.15,
        ),
        titleSmall: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w600, color: darkTeal,
          letterSpacing: 0.1,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 16, fontWeight: FontWeight.w400, color: darkTeal,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFF2A3D28),
        ),
        bodySmall: GoogleFonts.dmSans(
          fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF4A6741),
        ),
        labelLarge: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkTeal,
        foregroundColor: creamSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black26,
        centerTitle: false,
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: creamSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: creamSurface),
        actionsIconTheme: const IconThemeData(color: creamSurface),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
        ),
      ),
      cardTheme: CardThemeData(
        // White/cream cards — legible in light mode
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: creamDark, width: 1),
        ),
        margin: const EdgeInsets.all(0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkTeal,
          foregroundColor: creamSurface,
          disabledBackgroundColor: const Color(0xFFB0C4B0),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTeal,
          side: const BorderSide(color: darkTeal, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15, fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkTeal,
          textStyle: GoogleFonts.dmSans(
            fontSize: 14, fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: creamDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: creamDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkTeal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
        labelStyle: GoogleFonts.dmSans(
          color: const Color(0xFF4A6741), fontSize: 14,
        ),
        hintStyle: GoogleFonts.dmSans(
          color: const Color(0xFF8AAA80), fontSize: 14,
        ),
        errorStyle: GoogleFonts.dmSans(color: errorRed, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        prefixIconColor: const Color(0xFF4A6741),
        suffixIconColor: const Color(0xFF4A6741),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: darkTeal,
        unselectedItemColor: Color(0xFF8AAA80),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: acidOlive,
        foregroundColor: darkTeal,
        elevation: 4,
        highlightElevation: 8,
        shape: CircleBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: creamSurface,
        selectedColor: darkTeal,
        labelStyle: GoogleFonts.dmSans(fontSize: 13, color: darkTeal),
        secondaryLabelStyle: GoogleFonts.dmSans(
          fontSize: 13, color: creamSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: creamDark),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: creamDark, thickness: 1, space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 15, fontWeight: FontWeight.w500, color: darkTeal,
        ),
        subtitleTextStyle: GoogleFonts.dmSans(
          fontSize: 13, color: const Color(0xFF4A6741),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: deepTealShade,
        contentTextStyle: GoogleFonts.dmSans(color: creamSurface, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 18, fontWeight: FontWeight.w600, color: darkTeal,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? acidOlive : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? darkTeal
              : const Color(0xFFD0E4C8);
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: electricCyan,
        linearTrackColor: creamDark,
      ),
      iconTheme: const IconThemeData(color: darkTeal, size: 24),
      visualDensity: VisualDensity.standard,
    );

    // ── Dark Theme ─────────────────────────────────────────────────────────────
    final darkTheme = ThemeData(
      useMaterial3: true,
      primaryColor: acidOlive,
      scaffoldBackgroundColor: const Color(0xFF0A1520),
      colorScheme: const ColorScheme.dark(
        primary:          acidOlive,
        primaryContainer: Color(0xFF1E3340),
        secondary:        electricCyan,
        secondaryContainer: Color(0xFF0D3030),
        tertiary:         softOlive,
        surface:          Color(0xFF13232E),
        surfaceContainerHighest: Color(0xFF1A2E3A),
        onPrimary:        darkTeal,
        onSecondary:      darkTeal,
        onTertiary:       Colors.white,
        onSurface:        Color(0xFFD4ECA8),
        onSurfaceVariant: Color(0xFF91AF58),
        error:            errorRed,
        onError:          Colors.white,
        outline:          Color(0xFF2A4050),
        shadow:           Colors.black,
      ),
      textTheme: GoogleFonts.dmSansTextTheme().copyWith(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 32, fontWeight: FontWeight.w700, color: creamSurface,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 26, fontWeight: FontWeight.w600, color: creamSurface,
        ),
        titleLarge: GoogleFonts.playfairDisplay(
          fontSize: 20, fontWeight: FontWeight.w600, color: creamSurface,
        ),
        titleMedium: GoogleFonts.dmSans(
          fontSize: 16, fontWeight: FontWeight.w600, color: creamSurface,
        ),
        titleSmall: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFD4ECA8),
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 16, color: const Color(0xFFD4ECA8),
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14, color: const Color(0xFFB0CC90),
        ),
        bodySmall: GoogleFonts.dmSans(
          fontSize: 12, color: softOlive,
        ),
        labelLarge: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w600, color: darkTeal,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0C1A21),
        foregroundColor: creamSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black54,
        centerTitle: false,
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: creamSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Color(0xFFD4ECA8)),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF13232E),
        elevation: 0,
        shadowColor: Colors.black54,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2A4050), width: 1),
        ),
        margin: const EdgeInsets.all(0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: acidOlive,
          foregroundColor: darkTeal,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15, fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: acidOlive,
          textStyle: GoogleFonts.dmSans(
            fontSize: 14, fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A2E3A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A4050)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A4050)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: acidOlive, width: 2),
        ),
        labelStyle: GoogleFonts.dmSans(color: softOlive, fontSize: 14),
        hintStyle: GoogleFonts.dmSans(
          color: const Color(0xFF4A6050), fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0C1A21),
        selectedItemColor: acidOlive,
        unselectedItemColor: Color(0xFF4A6050),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: acidOlive,
        foregroundColor: darkTeal,
        elevation: 4,
        shape: CircleBorder(),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A4050), thickness: 1, space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? acidOlive : const Color(0xFF4A6050);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? const Color(0xFF2A4020)
              : const Color(0xFF1A2E3A);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A2E3A),
        contentTextStyle: GoogleFonts.dmSans(color: creamSurface, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF13232E),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 18, fontWeight: FontWeight.w600, color: creamSurface,
        ),
      ),
      iconTheme: const IconThemeData(color: Color(0xFFD4ECA8), size: 24),
      visualDensity: VisualDensity.standard,
    );

    return MaterialApp(
      title: 'Bima Guardian',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.themeMode,
      home: const AuthGate(),
      routes: {
        '/home': (context) => const InsuranceHomeScreen(),
        '/admin': (context) => const AdminPanel(),
        '/policy_report': (context) => const CoverReportScreen(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFF10212B),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFABFD06)),
                  const SizedBox(height: 20),
                  Text(
                    'BIMA GUARDIAN',
                    style: GoogleFonts.playfairDisplay(
                      color: const Color(0xFFEFFBDB),
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          return const InsuranceHomeScreen();
        }

        return const LoginPage();
      },
    );
  }
}
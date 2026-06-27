import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:my_app/Screens/admin_panel.dart';
import 'package:my_app/Screens/webview_page.dart';
import 'package:my_app/Services/email_analyzer.dart';
import 'package:my_app/Services/company_config_service.dart';
import 'package:my_app/Services/policy_module_service.dart';
import 'package:web/web.dart' as web;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:my_app/Models/insured_item.dart';
import 'package:my_app/Models/company.dart' as company_models;
import 'package:my_app/Models/cover.dart';
import 'package:my_app/Models/field_definition.dart';
import 'package:my_app/Models/pdf_template.dart';
import 'package:my_app/Models/policy.dart';
import 'package:my_app/Providers/theme_provider.dart';
import 'package:my_app/Screens/Policy_report_screen.dart';
import 'package:my_app/Screens/cover_screen.dart';
import 'package:my_app/Screens/notifications_screen.dart';
import 'package:my_app/Screens/pdf_preview.dart';
import 'package:my_app/Services/gemini_service.dart';
import 'package:my_app/Services/webview.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/pdf.dart' as pdfColors;
import 'package:pdfrx/pdfrx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_render/pdf_render.dart' as pdf;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Palette tokens (used throughout) ─────────────────────────────────────────
const _kDarkTeal  = Color(0xFF10212B);
const _kAcidOlive = Color(0xFFABFD06);
const _kSoftOlive = Color(0xFF91AF58);
const _kCyan      = Color(0xFF00D1D1);
const _kCream     = Color(0xFFEFFBDB);
const _kCreamDark = Color(0xFFD8EBB8);

enum UserRole { admin, regular }

enum CoverStatus {
  active,
  inactive,
  extended,
  nearingExpiration,
  expired,
  pending,
}

enum PolicyStatus { active, inactive, extended }

class Quote {
  final String id;
  final String type;
  final String subtype;
  final String company;
  final double premium;
  final Map<String, String> formData;
  final DateTime generatedAt;

  String? name;
  String? pdfTemplateKeys;

  Quote({
    required this.id,
    required this.type,
    required this.subtype,
    required this.company,
    required this.premium,
    required this.formData,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'subtype': subtype,
        'company': company,
        'premium': premium,
        'formData': formData,
        'generatedAt': generatedAt.toIso8601String(),
      };
}

class InsuranceHomeScreen extends StatefulWidget {
  const InsuranceHomeScreen({super.key});
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static List<company_models.Company> _cachedCompanies = [];
  static Map<String, PDFTemplate> _cachedPdfTemplates = {};

  static Future<Map<String, PDFTemplate>> getCachedPdfTemplates() async {
    if (_cachedPdfTemplates.isNotEmpty) return _cachedPdfTemplates;
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('pdf_templates').get();
      if (snapshot.docs.isNotEmpty) {
        _cachedPdfTemplates = Map.fromEntries(
          snapshot.docs.map((doc) =>
              MapEntry(doc.id, PDFTemplate.fromJson(doc.data()))),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error loading cached PDF templates: $e');
      _cachedPdfTemplates = {};
    }
    return _cachedPdfTemplates;
  }

  static Future<List<company_models.Company>> getCompanies() async {
    try {
      if (_cachedCompanies.isNotEmpty) return _cachedCompanies;
      final snapshot = await _firestore
          .collection('companies')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));
      final companies = snapshot.docs
          .map((doc) => company_models.Company.fromFirestore(doc.data()))
          .toList();
      if (companies.isNotEmpty) {
        _cachedCompanies = companies;
        return companies;
      }
    } catch (e, st) {
      if (kDebugMode) print('Error in getCompanies: $e\n$st');
    }
    await Future.delayed(const Duration(seconds: 1));
    final defaults = [
      company_models.Company(
          id: 'default', name: 'Default Company', pdfTemplateKey: ['default_template']),
    ];
    _cachedCompanies = defaults;
    return defaults;
  }

  static Future<List<PolicyType>> getPolicyTypes() async {
    try {
      final snapshot = await _firestore.collection('policyTypes').get()
          .timeout(const Duration(seconds: 8));
      final types = snapshot.docs
          .map((doc) => PolicyType.fromFirestore(doc.data()))
          .toList();
      if (types.isNotEmpty) return types;
    } catch (e) {
      if (kDebugMode) print('Error in getPolicyTypes: $e');
    }
    await Future.delayed(const Duration(seconds: 1));
    return [
      PolicyType(id: '1', name: 'Motor',    description: 'Motor insurance'),
      PolicyType(id: '2', name: 'Medical',  description: 'Medical insurance'),
      PolicyType(id: '3', name: 'Travel',   description: 'Travel insurance'),
      PolicyType(id: '4', name: 'Property', description: 'Property insurance'),
      PolicyType(id: '5', name: 'WIBA',     description: 'WIBA insurance'),
    ];
  }

  static Future<List<PolicySubtype>> getPolicySubtypes(String policyTypeId) async {
    try {
      final snapshot = await _firestore
          .collection('policySubtypes')
          .where('policyTypeId', isEqualTo: policyTypeId)
          .get()
          .timeout(const Duration(seconds: 8));
      final subtypes = snapshot.docs
          .map((doc) => PolicySubtype.fromFirestore(doc.data()))
          .toList();
      if (subtypes.isNotEmpty) return subtypes;
    } catch (e) {
      if (kDebugMode) print('Error in getPolicySubtypes: $e');
    }
    await Future.delayed(const Duration(seconds: 1));
    return [
      PolicySubtype(id: '1', name: 'Standard', policyTypeId: policyTypeId, description: ''),
      PolicySubtype(id: '2', name: 'Premium',  policyTypeId: policyTypeId, description: ''),
    ];
  }

  static Future<List<CoverageType>> getCoverageTypes(String subTypeId) async {
    try {
      final snapshot = await _firestore
          .collection('coverageTypes')
          .where('subTypeId', isEqualTo: subTypeId)
          .get()
          .timeout(const Duration(seconds: 8));
      final types = snapshot.docs
          .map((doc) => CoverageType.fromFirestore(doc.data()))
          .toList();
      if (types.isNotEmpty) return types;
    } catch (e) {
      if (kDebugMode) print('Error in getCoverageTypes: $e');
    }
    await Future.delayed(const Duration(seconds: 1));
    return [
      CoverageType(id: '1', name: 'Basic',         description: ''),
      CoverageType(id: '2', name: 'Comprehensive',  description: ''),
    ];
  }

  static Future<PDFTemplate?> getPDFTemplate(String pdfTemplateKey) async {
    try {
      final doc = await _firestore.collection('pdfTemplates').doc(pdfTemplateKey).get()
          .timeout(const Duration(seconds: 8));
      if (doc.exists) {
        // Previously this always returned a PDFTemplate with empty
        // fields/fieldMappings/coordinates regardless of what was actually
        // stored in Firestore — doc.data() was fetched but never used. Any
        // screen relying on a real template's fields (e.g. the insured-item
        // form, PDF autofill) silently got nothing to work with. Now parses
        // the real document via PDFTemplate.fromJson.
        final data = doc.data();
        if (data != null) {
          try {
            return PDFTemplate.fromJson({...data, 'templateKey': pdfTemplateKey});
          } catch (e) {
            if (kDebugMode) print('Error parsing PDFTemplate "$pdfTemplateKey": $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error in getPDFTemplate: $e');
    }
    await Future.delayed(const Duration(seconds: 1));
    return null;
  }

  @override
  State<InsuranceHomeScreen> createState() => InsuranceHomeScreenState();

  static Future<List<company_models.Company>> loadCompanies() async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      return [
        company_models.Company(id: '1', name: 'AIG',         pdfTemplateKey: const []),
        company_models.Company(id: '2', name: 'Cigna',       pdfTemplateKey: const []),
        company_models.Company(id: '3', name: 'UnitedHealth', pdfTemplateKey: const []),
      ];
    } catch (e) {
      if (kDebugMode) print('Error in loadCompanies: $e');
      return [company_models.Company(id: '1', name: 'AIG', pdfTemplateKey: const [])];
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class InsuranceHomeScreenState extends State<InsuranceHomeScreen> {
  final Map<String, TextEditingController> _genericControllers = {};
  List<InsuredItem> insuredItems = [];
  List<Cover> covers = [];
  List<Quote> quotes = [];
  List<company_models.Company> companies = [];
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = false;
  bool _hasLoadedInsuredItems = false;
  bool _hasLoadedData = false;
  Map<String, PDFTemplate> cachedPdfTemplates = {};
  Map<String, String> userDetails = {};
  TextEditingController chatController = TextEditingController();
  String currentState = 'start';
  final Map<String, String> formResponses = {};
  int currentFieldIndex = 0;
  UserRole userRole = UserRole.regular;
  final secureStorage = const FlutterSecureStorage();
  String? selectedInsuredItemId;
  String? selectedQuoteId;
  static const String openAiApiKey    = 'your-openai-api-key-here';
  static const String mpesaApiKey     = 'your-mpesa-api-key-here';
  List<Policy> policies = [];
  static const String paystackSecretKey = 'your-paystack-secret-key-here';
  InsuredItem? insuredItem;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController           = TextEditingController();
  final TextEditingController _emailController          = TextEditingController();
  final TextEditingController _phoneController          = TextEditingController();
  final TextEditingController _ageController            = TextEditingController();
  final TextEditingController _spouseAgeController      = TextEditingController();
  final TextEditingController _childrenCountController  = TextEditingController();
  final TextEditingController _chassisNumberController  = TextEditingController();
  final TextEditingController _kraPinController         = TextEditingController();
  String? _selectedVehicleType;
  String? _selectedInpatientLimit;
  final List<String> _selectedMedicalServices = [];
  final List<String> _selectedUnderwriters    = [];
  File? _logbookFile;
  File? _previousPolicyFile;
  List<dynamic> trendingTopics = [];
  List<String> blogPosts = [];
  late bool _isDialogOpening = false;
  bool _isOcrLoading   = false;
  Map<String, String>? _initialExtractedData;
  InsuredItem? _selectedInsuredItem;
  bool _isLoadingItems = false;

  String pdfTemplateKey = 'default_template';
  List<PolicyType> cachedPolicyTypes = [];
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  Map<String, dynamic> chatbotTemplate = {
    'states': {
      'start': {
        'message': 'Welcome to the chatbot!',
        'options': [{'text': 'Option 1'}, {'text': 'Option 2'}],
      },
    },
  };
  List<Map<String, String>> chatMessages = [];

  final Map<String, Map<String, Map<String, dynamic>>> policyCalculators = {
    'motor': {
      'commercial': {'companyA': {'basePremium': 5000, 'factor': 0.02, 'email': 'motor@companyA.com'}},
      'psv':        {'companyA': {'basePremium': 7000, 'factor': 0.03, 'email': 'motor@companyA.com'}},
    },
    'medical': {
      'individual': {'companyA': {'basePremium': 10000, 'email': 'health@companyA.com'}},
      'corporate':  {'companyA': {'basePremium': 15000, 'email': 'health@companyA.com'}},
    },
    'property': {
      'residential': {'companyA': {'basePremium': 8000, 'factor': 0.01, 'email': 'property@companyA.com'}},
    },
  };

  var _selectedIndex;
  String? selectedCompany;
  Map<String, String>? extractedData;
  late bool isDesktop;

  // ── helpers ─────────────────────────────────────────────────────────────────

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _surface    => _isDark ? const Color(0xFF13232E) : Colors.white;
  Color get _border     => _isDark ? const Color(0xFF2A4050) : _kCreamDark;
  Color get _textPrimary => _isDark ? const Color(0xFFD4ECA8) : _kDarkTeal;
  Color get _textMuted  => _isDark ? _kSoftOlive : const Color(0xFF4A6741);
  Color get _iconBg     => _isDark ? const Color(0xFF1A2E3A) : _kCream;
  Color get _accent     => _isDark ? _kAcidOlive : _kDarkTeal;

  // ── lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadCachedPdfTemplates();
    _loadUserDetails();
    _loadQuotes();
    _loadNotifications();
    fetchTrendingTopics();
    fetchBlogPosts();
    _startChatbot();
    _checkUserRole();
    _setupFirebaseMessaging();
    _checkCoverExpirations();
    _preloadConfigs();
    _autofillUserDetails();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedData) {
      _hasLoadedData = true;
      _loadPolicies();
      _loadInsuredItems();
      isDesktop = !kIsWeb && MediaQuery.of(context).size.width > 600;
      _loadNotifications();
      _startChatbot();
    }
  }

  void _preloadConfigs() async {
    for (final type in ['motor', 'medical', 'travel', 'property', 'wiba']) {
      await ConfigCache().getInsuranceConfigs(type);
      logger.i('Preloaded configs for $type');
    }
  }

  Future<void> _autofillUserDetails() async {
    if (userDetails.isNotEmpty) {
      _nameController.text  = userDetails['name']  ?? '';
      _emailController.text = userDetails['email'] ?? '';
      _phoneController.text = userDetails['phone'] ?? '';
    }
    if (selectedInsuredItemId != null) {
      final item = insuredItems.firstWhere((i) => i.id == selectedInsuredItemId);
      _kraPinController.text = item.kraPin ?? '';
    }
  }

  /// Returns a persistent AES key/IV pair for on-device encryption,
  /// creating and storing one in secure storage the first time it's needed.
  ///
  /// Previously, every call site that encrypted something (user details,
  /// Paystack auto-billing config) generated a brand-new random key and IV
  /// on the spot, encrypted with it, and then only saved the *ciphertext* —
  /// the key itself was never persisted anywhere. That made the encrypted
  /// data permanently undecryptable the instant the function returned.
  /// By persisting one key/IV pair and reusing it, anything we encrypt here
  /// can actually be decrypted again later.
  Future<encrypt.Encrypted> _encryptPayload(String plaintext) async {
    const keyStorageKey = 'app_encryption_key_v1';
    const ivStorageKey = 'app_encryption_iv_v1';

    var keyBase64 = await secureStorage.read(key: keyStorageKey);
    var ivBase64 = await secureStorage.read(key: ivStorageKey);

    encrypt.Key key;
    encrypt.IV iv;

    if (keyBase64 == null || ivBase64 == null) {
      key = encrypt.Key.fromSecureRandom(32);
      iv = encrypt.IV.fromSecureRandom(16);
      await secureStorage.write(key: keyStorageKey, value: key.base64);
      await secureStorage.write(key: ivStorageKey, value: iv.base64);
    } else {
      key = encrypt.Key.fromBase64(keyBase64);
      iv = encrypt.IV.fromBase64(ivBase64);
    }

    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.encrypt(plaintext, iv: iv);
  }

  /// Decrypts a payload produced by [_encryptPayload]. Returns null if no
  /// encryption key has ever been created on this device (nothing to
  /// decrypt) or if decryption otherwise fails.
  Future<String?> _decryptPayload(String base64Ciphertext) async {
    const keyStorageKey = 'app_encryption_key_v1';
    const ivStorageKey = 'app_encryption_iv_v1';

    final keyBase64 = await secureStorage.read(key: keyStorageKey);
    final ivBase64 = await secureStorage.read(key: ivStorageKey);
    if (keyBase64 == null || ivBase64 == null) return null;

    try {
      final key = encrypt.Key.fromBase64(keyBase64);
      final iv = encrypt.IV.fromBase64(ivBase64);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      return encrypter.decrypt(
        encrypt.Encrypted.fromBase64(base64Ciphertext),
        iv: iv,
      );
    } catch (e) {
      if (kDebugMode) print('Decryption error: $e');
      return null;
    }
  }

  Future<void> _saveUserDetails(Map<String, String> newDetails) async {
    try {
      userDetails.addAll(newDetails);
      final encrypted = await _encryptPayload(jsonEncode(userDetails));
      await secureStorage.write(key: 'user_details', value: encrypted.base64);
      setState(() {
        _nameController.text  = userDetails['name']  ?? '';
        _emailController.text = userDetails['email'] ?? '';
        _phoneController.text = userDetails['phone'] ?? '';
      });
    } catch (e) {
      if (kDebugMode) print('Error saving user details: $e');
    }
  }

  Future<void> autofillFromPreviousPolicy(
      File pdfFile, Map<String, String>? extractedData, String? selectedCompany) async {
    try {
      if (extractedData != null) {
        await _saveUserDetails(extractedData);
        await FirebaseFirestore.instance.collection('autofilled_forms').add({
          'user_id': insuredItems.isNotEmpty ? insuredItems.first.id : 'unknown',
          'source': 'previous_policy',
          'fields': extractedData,
          'insurer': selectedCompany ?? 'unknown',
          'file_path': pdfFile.path,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      if (selectedCompany != null) {
        await FirebaseFirestore.instance.collection('user_preferences').add({
          'user_id': insuredItems.isNotEmpty ? insuredItems.first.id : 'unknown',
          'insurer': selectedCompany,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error in autofillFromPreviousPolicy: $e');
    }
  }

  Future<void> autofillFromLogbook(
      File logbookFile, Map<String, String>? extractedData) async {
    try {
      if (extractedData != null) {
        await _saveUserDetails(extractedData);
        await FirebaseFirestore.instance.collection('autofilled_forms').add({
          'user_id': insuredItems.isNotEmpty ? insuredItems.first.id : 'unknown',
          'source': 'logbook',
          'fields': extractedData,
          'file_path': logbookFile.path,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error in autofillFromLogbook: $e');
    }
  }

  Future<void> _checkUserRole() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (mounted) setState(() => userRole = UserRole.regular);
        return;
      }
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final data = userDoc.data() ?? <String, dynamic>{};
      final bool isAdmin = data['isAdmin'] == true || data['role'] == 'admin';
      await secureStorage.write(key: 'user_role', value: isAdmin ? 'admin' : 'user');
      if (mounted) setState(() => userRole = isAdmin ? UserRole.admin : UserRole.regular);
    } catch (_) {
      final role = await secureStorage.read(key: 'user_role');
      if (mounted) setState(() => userRole = role == 'admin' ? UserRole.admin : UserRole.regular);
    }
  }

  void _setupFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      setState(() {
        notifications.add({
          'title': message.notification?.title ?? 'Notification',
          'body':  message.notification?.body  ?? 'New notification',
          'timestamp': DateTime.now().toIso8601String(),
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.notification?.body ?? 'New notification')),
      );
    });
  }

  Future<void> _loadPolicies() async {
    bool shown = false;
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (mounted) setState(() => policies = []);
        return;
      }
      final snapshot = await FirebaseFirestore.instance
          .collection('policies')
          .doc(userId)
          .collection('user_policies')
          .get();
      final loaded = <Policy>[];
      for (var doc in snapshot.docs) {
        try {
          if (doc.data().isNotEmpty) loaded.add(Policy.fromJson({...doc.data(), 'id': doc.id}));
        } catch (e) {
          if (kDebugMode) print('Error parsing policy ${doc.id}: $e');
        }
      }
      if (mounted) setState(() => policies = loaded);
    } catch (e) {
      if (kDebugMode) print('Error loading policies: $e');
      if (mounted && !shown) {
        shown = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to load policies: $e')));
          }
        });
      }
    }
  }

  Future<void> _loadInsuredItems() async {
    if (_hasLoadedInsuredItems) return;
    _hasLoadedInsuredItems = true;
    try {
      final snapshot = await FirebaseFirestore.instance.collection('insured_items').get();
      final items = <InsuredItem>[];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          if (data.containsKey('data') && data['data'] is List) {
            items.addAll((data['data'] as List)
                .map((i) => InsuredItem.fromJson(i as Map<String, dynamic>)));
          }
        } catch (e) {
          if (kDebugMode) print('Error processing ${doc.id}: $e');
        }
      }
      if (mounted) setState(() => insuredItems = items);
    } catch (e) {
      if (kDebugMode) print('Error loading insured items: $e');
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (mounted) setState(() => notifications = []);
        return;
      }
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(userId)
          .collection('user_notifications')
          .get();
      if (mounted) setState(() => notifications = snapshot.docs.map((d) => d.data()).toList());
    } catch (e) {
      if (kDebugMode) print('Error loading notifications: $e');
      if (mounted) setState(() => notifications = []);
    }
  }

  Future<void> _loadQuotes() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (mounted) setState(() => quotes = []);
        return;
      }
      final snapshot = await FirebaseFirestore.instance
          .collection('quotes')
          .doc(userId)
          .collection('user_quotes')
          .get();
      if (!mounted) return;
      setState(() {
        quotes = snapshot.docs.map((doc) => Quote(
          id:          doc['id']      as String,
          type:        doc['type']    as String,
          subtype:     doc['subtype'] as String,
          company:     doc['company'] as String,
          premium:     (doc['premium'] as num).toDouble(),
          formData:    Map<String, String>.from(doc['formData'] as Map),
          generatedAt: (doc['generatedAt'] as Timestamp).toDate(),
        )).toList();
      });
    } catch (e) {
      if (kDebugMode) print('Error loading quotes: $e');
      if (mounted) setState(() => quotes = []);
    }
  }

  Future<void> _checkCoverExpirations() async {
    final now = DateTime.now();
    for (var cover in covers) {
      if (cover.expirationDate != null) {
        final days = cover.expirationDate!.difference(now).inDays;
        if (days <= 0 && cover.status != CoverStatus.expired) {
          setState(() {
            covers = covers.map((c) =>
                c.id == cover.id ? c.copyWith(status: CoverStatus.expired) : c).toList();
          });
          await FirebaseMessaging.instance.sendMessage(
            to: '/topics/policy_updates',
            data: {'Cover_id': cover.id, 'message': 'Policy ${cover.id} has expired'},
          );
        } else if (days <= 30 && cover.status != CoverStatus.nearingExpiration) {
          setState(() {
            covers = covers.map((c) =>
                c.id == cover.id ? c.copyWith(status: CoverStatus.nearingExpiration) : c).toList();
          });
          await FirebaseMessaging.instance.sendMessage(
            to: '/topics/policy_updates',
            data: {'policy_id': cover.id, 'message': 'Policy ${cover.id} is nearing expiration'},
          );
        }
      }
    }
    await _saveCovers();
  }

  void _startChatbot() {
    if (!chatbotTemplate.containsKey('states')) {
      setState(() => chatMessages.add({'sender': 'bot', 'text': 'Error: Chatbot config missing.'}));
      return;
    }
    final states = chatbotTemplate['states'] as Map<String, dynamic>?;
    final startState = states?['start'] as Map<String, dynamic>?;
    if (startState == null) {
      setState(() => chatMessages.add({'sender': 'bot', 'text': 'Error: Start state missing.'}));
      return;
    }
    final message = startState['message'] as String? ?? 'Welcome!';
    final options = startState['options'] as List<dynamic>? ?? [];
    final formatted = '$message\n${options.asMap().entries.map((e) => '${e.key + 1}. ${e.value['text'] ?? 'Option'}').join('\n')}';
    setState(() => chatMessages.add({'sender': 'bot', 'text': formatted}));
  }

  /// Extracts all text from [pdfFile] using pdfrx.
  ///
  /// IMPORTANT: PdfPage.loadText() returns a PdfPageRawText? object, not a
  /// String — its `fullText` field holds the actual extracted text. Simply
  /// writing the object itself would call the default Object.toString(),
  /// producing the literal string "Instance of 'PdfPageRawText'" instead of
  /// real content, silently making any downstream validation meaningless.
  Future<String> extractPdfText(File pdfFile) async {
    final document = await PdfDocument.openFile(pdfFile.path);
    try {
      final buffer = StringBuffer();
      for (int i = 1; i <= document.pages.length; i++) {
        final page = document.pages[i - 1];
        final pageText = await page.loadText();
        if (pageText != null) buffer.writeln(pageText.fullText);
      }
      return buffer.toString();
    } finally {
      await document.dispose();
    }
  }

  /// Validates a filled PDF's extracted text using the Gemini service
  /// (already configured elsewhere in this app — see GeminiService).
  ///
  /// This used to call OpenAI directly with a placeholder API key that was
  /// never set, which meant every non-admin user's submission silently
  /// failed validation and the form/PDF/email never actually went out.
  ///
  /// We now fail OPEN rather than closed: if the AI check itself can't run
  /// (network issue, bad response, etc.) we let the submission proceed
  /// rather than blocking it, since unlike admins, regular users never get
  /// to see/approve the PDF themselves — blocking them on an AI hiccup
  /// would silently strand their submission with no way to retry it.
  Future<bool> _validatePdfWithChatGPT(File pdfFile) async {
    try {
      final text = await extractPdfText(pdfFile);

      if (text.trim().isEmpty) {
        // Nothing to validate — likely a generation failure upstream.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not read the generated PDF; please try again.')));
        }
        return false;
      }

      final rawText = await GeminiService.generateText(
        prompt: '''You are validating a filled insurance form PDF before it is submitted.
Read the extracted text below and check whether it looks like a properly filled form
(has recognizable field values, is not blank/garbled).
Return ONLY a JSON object: {"valid": true|false, "message": "<short reason>"}.

Extracted text:
$text''',
        maxOutputTokens: 150,
        jsonResponse: true,
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(GeminiService.cleanJsonText(rawText)) as Map<String, dynamic>;
      final valid = result['valid'] == true;

      if (!valid && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Validation warning: ${result['message'] ?? 'Form may be incomplete.'}')));
      }
      return valid;
    } catch (e) {
      if (kDebugMode) print('PDF validation error: $e');
      // Fail OPEN — see method doc above.
      return true;
    }
  }

  /// Either previews the PDF for an admin to approve/reject, or validates
  /// it automatically via [_validatePdfWithChatGPT] for regular users.
  ///
  /// NOTE: a version of this method seen locally replaced the
  /// admin/non-admin branching with an unconditional, un-awaited
  /// `Navigator.push` that didn't return a usable bool at all — every
  /// caller that does `if (... && await _previewPdf(pdfFile))` would have
  /// gotten `null`/a dangling Future rather than a real approve/deny
  /// result, silently breaking the submission gate for everyone (admins
  /// included). Restored to the working admin/non-admin branch.
  Future<bool> _previewPdf(File pdfFile) async {
    if (userRole == UserRole.admin) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Preview Filled PDF'),
          content: SizedBox(width: double.maxFinite, height: 400, child: PdfPreview(file: pdfFile)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Approve')),
          ],
        ),
      );
      return approved ?? false;
    }
    return _validatePdfWithChatGPT(pdfFile);
  }

  Future<File?> _fillPdfTemplate(
      String templateKey, Map<String, String> formData, String insuranceType, BuildContext context) async {
    try {
      final template = await InsuranceHomeScreen.getPDFTemplate(templateKey);
      if (template == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF template not found')));
        }
        return null;
      }
      final directory    = await getApplicationDocumentsDirectory();
      final templateFile = File('${directory.path}/pdf_templates/$templateKey.pdf');
      if (!await templateFile.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF template file not found')));
        }
        return null;
      }
      final pdfBytes  = await templateFile.readAsBytes();
      final pdfDoc    = await pdf.PdfDocument.openData(pdfBytes);
      final outputPdf = pw.Document();
      for (int i = 0; i < pdfDoc.pageCount; i++) {
        final page         = await pdfDoc.getPage(i + 1);
        final renderedPage = await page.render(width: page.width.toInt(), height: page.height.toInt());
        final bgBytes      = renderedPage.pixels;
        outputPdf.addPage(pw.Page(build: (pw.Context ctx) {
          return pw.Stack(children: [
            if (bgBytes != null)
              pw.Image(pw.MemoryImage(bgBytes), width: page.width.toDouble(), height: page.height.toDouble())
            else
              pw.Container(width: page.width.toDouble(), height: page.height.toDouble(), color: PdfColors.white),
            ...formData.entries.map((entry) {
              final coord    = template.coordinates[entry.key];
              if (coord == null || coord['page'] != (i + 1).toDouble()) return pw.SizedBox();
              final fieldDef = template.fields[entry.key] ??
                  FieldDefinition(expectedType: ExpectedType.text,
                      validator: FieldDefinition.getValidatorForType(ExpectedType.text));
              if (fieldDef.validator?.call(entry.value) != null) return pw.SizedBox();
              return pw.Positioned(left: coord['x']!, top: coord['y']!,
                  child: pw.Text(entry.value,
                      style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 12, color: pdfColors.PdfColors.black)));
            }),
          ]);
        }));
      }
      await pdfDoc.dispose();
      final reportsDir = Directory('${directory.path}/reports');
      if (!await reportsDir.exists()) await reportsDir.create(recursive: true);
      final outputFile = File('${reportsDir.path}/filled_$templateKey.pdf');
      await outputFile.writeAsBytes(await outputPdf.save());
      return outputFile;
    } catch (e, st) {
      if (kDebugMode) print('Error filling PDF: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')));
      }
      return null;
    }
  }

  Future<File?> _fillQuotePdfWithOriginalLayout({required String templateKey, required Map<String, String> data}) async {
    try {
      final template     = await InsuranceHomeScreen.getPDFTemplate(templateKey);
      if (template == null) return null;
      final templateFile = await _ensureTemplateFileAvailable(templateKey);
      if (templateFile == null || !await templateFile.exists()) return null;
      final pdfBytes  = await templateFile.readAsBytes();
      final pdfDoc    = await pdf.PdfDocument.openData(pdfBytes);
      final outputPdf = pw.Document();
      for (int i = 0; i < pdfDoc.pageCount; i++) {
        final page         = await pdfDoc.getPage(i + 1);
        final renderedPage = await page.render(width: page.width.toInt(), height: page.height.toInt());
        final bgBytes      = renderedPage.pixels;
        outputPdf.addPage(pw.Page(build: (pw.Context ctx) => pw.Stack(children: [
          if (bgBytes != null) pw.Image(pw.MemoryImage(bgBytes),
              width: page.width.toDouble(), height: page.height.toDouble(), fit: pw.BoxFit.contain),
          ...data.entries.map((entry) {
            final coord = template.coordinates[entry.key];
            if (coord == null || coord['page'] != (i + 1).toDouble()) return pw.SizedBox();
            return pw.Positioned(left: coord['x']!, top: coord['y']!,
                child: pw.Text(entry.value,
                    style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 12, color: pdfColors.PdfColors.black)));
          }),
        ])));
      }
      await pdfDoc.dispose();
      final directory  = await getApplicationDocumentsDirectory();
      final reportsDir = Directory('${directory.path}/reports');
      if (!await reportsDir.exists()) await reportsDir.create(recursive: true);
      final file = File('${reportsDir.path}/filled_quote_$templateKey.pdf');
      await file.writeAsBytes(await outputPdf.save());
      return file;
    } catch (e, st) {
      if (kDebugMode) print('Error generating quote PDF: $e\n$st');
      return null;
    }
  }

  Future<File?> _ensureTemplateFileAvailable(String templateKey) async {
    final directory   = await getApplicationDocumentsDirectory();
    final templateDir = Directory('${directory.path}/pdf_templates');
    if (!await templateDir.exists()) await templateDir.create(recursive: true);
    final file = File('${templateDir.path}/$templateKey.pdf');
    if (await file.exists()) return file;
    try {
      final ref = FirebaseStorage.instance.ref('pdf_templates/$templateKey.pdf');
      await ref.writeToFile(file);
      return file;
    } catch (e) {
      if (kDebugMode) print('Unable to download template $templateKey: $e');
      return null;
    }
  }

  /// Handles submitting a new application, claim, cancellation, or
  /// extension for an insurance cover.
  ///
  /// [insuredItemId], when provided (e.g. from `cover.insuredItemId` on an
  /// existing cover), is used to look up the InsuredItem that was already
  /// created when the cover was first purchased. Previously this method
  /// always fell into the "create a brand-new InsuredItem" branch — even
  /// for claims/cancellations/extensions on an existing cover — because
  /// `details['insured_item_id']` is never actually set anywhere in this
  /// codebase. That meant every claim/cancellation required `details['name']`
  /// to be non-empty, which crashed (via InsuredItem's constructor assert)
  /// whenever the cancellation/claim form didn't re-collect the person's
  /// name — which it shouldn't have to, since the InsuredItem already exists.
  Future<void> handleCoverSubmission(
      BuildContext context, PolicyType type, PolicySubtype subtype,
      CoverageType coverageType, String companyId, String pdfTemplateKey,
      Map<String, String> details, [dynamic coverId = '', String? insuredItemId]) async {
    try {
      final isClaim        = details['isClaim']        == 'true';
      final isExtension    = details['isExtension']    == 'true';
      final isCancellation = details['isCancellation'] == 'true';

      final effectiveInsuredItemId =
          insuredItemId ?? details['insured_item_id'];

      InsuredItem insuredItem;
      if (effectiveInsuredItemId != null && effectiveInsuredItemId.isNotEmpty) {
        final existing = insuredItems
            .where((i) => i.id == effectiveInsuredItemId)
            .firstOrNull;
        if (existing != null) {
          insuredItem = existing;
        } else {
          final snap = await FirebaseFirestore.instance
              .collection('insured_items').doc(effectiveInsuredItemId).get();
          if (!snap.exists) throw Exception('Insured item not found');
          insuredItem = InsuredItem.fromJson(snap.data()!);
        }
      } else {
        insuredItem = InsuredItem(
          id: const Uuid().v4(), name: details['name'] ?? '', email: details['email'] ?? '',
          contact: details['phone'] ?? '', type: type, subtype: subtype,
          coverageType: coverageType, details: details,
          kraPin: type.name == 'motor' ? (details['kra_pin'] ?? '') : '',
          logbookPath: type.name == 'motor' ? details['logbook_path'] : null,
          previousPolicyPath: type.name == 'motor' ? details['previous_policy_path'] : null,
        );
        await FirebaseFirestore.instance
            .collection('insured_items').doc(insuredItem.id).set(insuredItem.toJson());
        insuredItems.add(insuredItem);
      }

      if (isClaim || isCancellation) {
        File? pdfFile;
        if (cachedPdfTemplates.isNotEmpty && cachedPdfTemplates.containsKey(pdfTemplateKey)) {
          pdfFile = await _fillPdfTemplate(pdfTemplateKey, details, type.name, context);
          if (pdfFile != null && await _previewPdf(pdfFile)) {
            await _sendEmail(companyId, type.name, subtype.name, details, pdfFile,
                details['regno'] ?? '', details['vehicle_type'] ?? '', coverId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isClaim ? 'Claim sent.' : 'Cancellation sent.')));
            }
          }
        } else {
          pdfFile = await _generateFallbackPdf(type.name, subtype.name, details);
          if (pdfFile != null) {
            await _sendEmail(companyId, type.name, subtype.name, details,
              pdfFile, details['regno'] ?? '', details['vehicle_type'] ?? '', coverId);
          }
        }
        currentState = 'claim_process';
        chatMessages.add({'sender': 'bot', 'text': '${type.name.toUpperCase()} claim submitted.'});
        return;
      }

      final premium = await _calculatePremium(
          companyId: companyId, type: type.name, subtype: subtype.name, formData: details);

      final proceedWithPayment = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Choose an Option'),
          content: const Text('Generate a quote or proceed with payment?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Generate Quote')),
            TextButton(onPressed: () => Navigator.pop(ctx, true),  child: const Text('Proceed with Payment')),
          ],
        ),
      );

      if (proceedWithPayment == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Action canceled.')));
        }
        return;
      }

      if (!proceedWithPayment) {
        final quote = Quote(id: const Uuid().v4(), type: type.name, subtype: subtype.name,
            company: companyId, premium: premium, generatedAt: DateTime.now(), formData: details);
        await FirebaseFirestore.instance.collection('quotes').doc(quote.id).set(quote.toJson());
        final pdfFile = await _generateQuotePdf(quote, companyId: companyId, type: type.name, subtype: subtype.name);
        if (pdfFile != null && context.mounted && await _previewPdf(pdfFile)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote generated.')));
        }
        currentState = 'quote_process';
        chatMessages.add({'sender': 'bot', 'text': '${type.name.toUpperCase()} quote generated.'});
        return;
      }

      final cover = Cover(
        id: const Uuid().v4(), insuredItemId: insuredItem.id, companyId: companyId,
        type: type, subtype: subtype,
        coverageType: CoverageType(id: coverageType.name, name: coverageType.name, description: ''),
        status: CoverStatus.pending,
        expirationDate: isExtension
            ? DateTime.now().add(const Duration(days: 30))
            : DateTime.now().add(const Duration(days: 365)),
        pdfTemplateKey: pdfTemplateKey, paymentStatus: 'pending',
        startDate: DateTime.now(), formData: details, premium: premium,
        billingFrequency: 'annual', name: '',
      );
      await FirebaseFirestore.instance.collection('covers').doc(cover.id).set(cover.toJson());
      covers.add(cover);

      File? pdfFile;
      if (cachedPdfTemplates.isNotEmpty && cachedPdfTemplates.containsKey(pdfTemplateKey)) {
        pdfFile = await _fillPdfTemplate(pdfTemplateKey, details, type.name, context);
        if (pdfFile != null && await _previewPdf(pdfFile)) {
          await _sendEmail(companyId, type.name, subtype.name, details, pdfFile,
              details['regno'] ?? '', details['vehicle_type'] ?? '', cover.id);
        }
      } else {
        pdfFile = await _generateFallbackPdf(type.name, subtype.name, details);
        if (pdfFile != null) {
          await _sendEmail(companyId, type.name, subtype.name, details,
            pdfFile, details['regno'] ?? '', details['vehicle_type'] ?? '', cover.id);
        }
      }

      final paymentStatus = await _initializePayment(cover, premium.toString(), '', context: context);
      await FirebaseFirestore.instance.collection('covers').doc(cover.id).update({
        'status': paymentStatus == 'completed' ? CoverStatus.active.toString() : CoverStatus.pending.toString(),
        'paymentStatus': paymentStatus,
      });
      final updatedCover = cover.copyWith(
        status: paymentStatus == 'completed' ? CoverStatus.active : CoverStatus.pending,
        paymentStatus: paymentStatus,
      );
      final idx = covers.indexWhere((c) => c.id == cover.id);
      if (idx != -1) covers[idx] = updatedCover;

      currentState = type.name == 'medical' ? 'health_process' : 'pdf_process';
      chatMessages.add({'sender': 'bot', 'text': '${type.name.toUpperCase()} cover created. Payment: $paymentStatus.'});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cover created, payment $paymentStatus')));
        _showCompletionDialog(context, type.name, await Policy.fromCover(updatedCover),
            pdfTemplateKey, (ctx, t, s, c, [String? ex]) {
          if (kDebugMode) print('Final submission: $t, $s, $c');
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error in handleCoverSubmission: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process action: $e')));
      }
    }
  }

  Future<File?> _generateQuotePdf(Quote quote,
      {required String companyId, required String type, required String subtype}) async {
    final pdfDoc = pw.Document();
    final template = await CompanyConfigService.fetchQuoteTemplate(companyId, type, subtype);
    final sections      = template?.sections ?? const <QuoteTemplateSection>[];
    final resolvedValues = <String, String>{
      'quote_id': quote.id, 'policy_type': quote.type, 'policy_subtype': quote.subtype,
      'company': quote.company, 'premium': quote.premium.toStringAsFixed(2),
      'generated_at': quote.generatedAt.toIso8601String(), ...quote.formData,
    };
    if ((template?.useOriginalLayout ?? false) && (template?.pdfTemplateKey ?? '').isNotEmpty) {
      final file = await _fillQuotePdfWithOriginalLayout(
          templateKey: template!.pdfTemplateKey!, data: resolvedValues);
      if (file != null) return file;
    }
    pdfDoc.addPage(pw.Page(build: (pw.Context ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(template?.title ?? 'Insurance Quote',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 20),
        pw.Text('Quote ID: ${quote.id}'), pw.Text('Type: ${quote.type}'),
        pw.Text('Subtype: ${quote.subtype}'), pw.Text('Company: ${quote.company}'),
        pw.Text('Premium: KES ${quote.premium.toStringAsFixed(2)}'),
        pw.Text('Generated: ${quote.generatedAt}'),
        if (sections.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Text('Company Quote Template',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          ...sections.map((s) => pw.Text(
              '${s.label}: ${s.prefix}${resolvedValues[s.fieldKey] ?? ''}${s.suffix}')),
        ],
        pw.SizedBox(height: 20),
        pw.Text('Details:', style: pw.TextStyle(fontSize: 16)),
        ...quote.formData.entries.map((e) => pw.Text('${e.key}: ${e.value}')),
        if ((template?.footer ?? '').isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Text(template!.footer, style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        ],
      ],
    )));
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/quote_${quote.id}.pdf');
    await file.writeAsBytes(await pdfDoc.save());
    return file;
  }

  Future<double> _calculatePremium({required String companyId, required String type,
      required String subtype, required Map<String, String> formData}) async {
    final nType    = type.trim().toLowerCase();
    final nSubtype = subtype.trim().toLowerCase();
    final rateCard = await CompanyConfigService.fetchRateCard(companyId, nType, nSubtype);
    if (rateCard != null) return CompanyConfigService.calculatePremium(rateCard, formData);
    final calc = policyCalculators[nType]?[nSubtype]?['companyA'];
    if (calc == null) return 0.0;
    final base   = (calc['basePremium'] as num).toDouble();
    final factor = (calc['factor'] as num?)?.toDouble() ?? 0.01;
    switch (nType) {
      case 'motor':
        return base + (double.tryParse(formData['vehicle_value'] ?? '0') ?? 0) * factor;
      case 'medical':
        final bens     = int.tryParse(formData['beneficiaries'] ?? (nSubtype == 'corporate' ? '3' : '1')) ?? 1;
        final inpat    = double.tryParse(formData['inpatient_limit']?.replaceAll('KES ', '').replaceAll(',', '') ?? '0') ?? 0;
        final outpat   = double.tryParse(formData['outpatient_limit'] ?? '0') ?? 0;
        final dental   = double.tryParse(formData['dental_limit']    ?? '0') ?? 0;
        final optical  = double.tryParse(formData['optical_limit']   ?? '0') ?? 0;
        final maternity = double.tryParse(formData['maternity_limit'] ?? '0') ?? 0;
        final deps     = (formData['has_spouse'] == 'Yes' ? 1 : 0) + (int.tryParse(formData['children_count'] ?? '0') ?? 0);
        return base + bens * 1000 + inpat * 0.0001 + outpat * 0.00005 + dental * 0.00003 +
            optical * 0.00002 + maternity * 0.00004 + deps * 500;
      case 'travel':
        return base + (int.tryParse(formData['number_of_travelers'] ?? '1') ?? 1) * 500 +
            (double.tryParse(formData['coverage_limit'] ?? '0') ?? 0) * 0.0001;
      case 'property':
        return base + (double.tryParse(formData['property_value'] ?? '0') ?? 0) * factor;
      case 'wiba':
        return base + (int.tryParse(formData['number_of_employees'] ?? '1') ?? 1) * 300 +
            (double.tryParse(formData['coverage_limit'] ?? '0') ?? 0) * 0.0001;
      default:
        return base;
    }
  }

  /// Initiates an M-Pesa STK push for [amount] to [phoneNumber].
  ///
  /// NOTE on the 'Password' field: Safaricom's Daraja API requires this to
  /// be base64(Shortcode + Passkey + Timestamp) — it is NOT a literal
  /// account password. The previous version sent the literal string
  /// 'your-mpesa-password', which Safaricom would reject outright even once
  /// a real API key was configured. We now compute it correctly, but you
  /// still need to supply the real [mpesaShortcode]/[mpesaPasskey] (from
  /// your Daraja app credentials) below.
  ///
  /// Also note: the 'Authorization: Bearer' header here needs a short-lived
  /// OAuth access token (from POST .../oauth/v1/generate using your Consumer
  /// Key/Secret), not a long-lived static API key — `mpesaApiKey` as
  /// declared further up is not actually sufficient on its own. Fetching
  /// and caching that token is a separate piece of work; this fix only
  /// addresses the STK push request body itself.
  Future<bool> _initiateMpesaPayment(String phoneNumber, double amount) async {
    try {
      const mpesaShortcode = '174379'; // Replace with your real shortcode.
      const mpesaPasskey = 'your-mpesa-passkey-here'; // From Daraja app credentials.

      final now = DateTime.now();
      String pad2(int n) => n.toString().padLeft(2, '0');
      final timestamp = '${now.year}${pad2(now.month)}${pad2(now.day)}'
          '${pad2(now.hour)}${pad2(now.minute)}${pad2(now.second)}';
      final password = base64Encode(
        utf8.encode('$mpesaShortcode$mpesaPasskey$timestamp'),
      );

      final response = await http.post(
        Uri.parse('https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest'),
        headers: {'Authorization': 'Bearer $mpesaApiKey', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'BusinessShortCode': mpesaShortcode, 'Password': password,
          'Timestamp': timestamp,
          'TransactionType': 'CustomerPayBillOnline', 'Amount': amount,
          'PartyA': phoneNumber, 'PartyB': mpesaShortcode, 'PhoneNumber': phoneNumber,
          'CallBackURL': 'https://your-callback-url.com',
          'AccountReference': 'InsurancePayment', 'TransactionDesc': 'Policy Payment',
        }),
      );
      if (response.statusCode == 200) return true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('MPESA Payment Failed: ${response.body}')));
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('MPESA payment error: $e');
      return false;
    }
  }

  Future<bool> _initiatePaystackPayment(double amount, bool autoBilling) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.paystack.co/transaction/initialize'),
        headers: {'Authorization': 'Bearer $paystackSecretKey', 'Content-Type': 'application/json'},
        body: jsonEncode({'amount': (amount * 100).toInt(), 'currency': 'KES',
            'email': userDetails['email'] ?? '', 'callback_url': 'https://your-callback-url.com'}),
      );
      if (response.statusCode == 200) {
        final tx = jsonDecode(response.body);
        await launchUrl(Uri.parse(tx['data']['authorization_url']));
        return true;
      }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paystack Payment Failed: ${response.body}')));
      return false;
    } catch (e) {
      if (kDebugMode) print('Paystack payment error: $e');
      return false;
    }
  }

  Future<void> _schedulePaystackAutoBilling(Cover cover) async {
    try {
      final cr = await http.post(Uri.parse('https://api.paystack.co/customer'),
          headers: {'Authorization': 'Bearer $paystackSecretKey', 'Content-Type': 'application/json'},
          body: jsonEncode({'email': cover.formData!['email'], 'first_name': cover.formData!['name']}));
      if (cr.statusCode != 200) return;
      final customerId = jsonDecode(cr.body)['data']['id'];
      final pr = await http.post(Uri.parse('https://api.paystack.co/plan'),
          headers: {'Authorization': 'Bearer $paystackSecretKey', 'Content-Type': 'application/json'},
          body: jsonEncode({'name': '${cover.id}_plan', 'amount': (cover.premium! * 100).toInt(),
              'interval': cover.billingFrequency == 'monthly' ? 'monthly' : 'yearly'}));
      if (pr.statusCode != 200) return;
      final planId = jsonDecode(pr.body)['data']['id'];
      final sr = await http.post(Uri.parse('https://api.paystack.co/subscription'),
          headers: {'Authorization': 'Bearer $paystackSecretKey', 'Content-Type': 'application/json'},
          body: jsonEncode({'customer': customerId, 'plan': planId}));
      if (sr.statusCode != 200) return;
      final subId = jsonDecode(sr.body)['data']['id'];
      final encrypted = await _encryptPayload(jsonEncode({
        'coverId': cover.id,
        'customerId': customerId,
        'subscriptionId': subId,
        'amount': cover.premium,
        'frequency': cover.billingFrequency,
      }));
      await secureStorage.write(key: 'billing_${cover.id}', value: encrypted.base64);
    } catch (e) {
      if (kDebugMode) print('Paystack auto-billing error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set up auto-billing: $e')));
    }
  }

  Future<void> _autofillDMVICWebsiteForMotorInsurance(
      String registrationNumber, String vehicleType, BuildContext context) async {
    Navigator.push(context, MaterialPageRoute(
        builder: (context) => DMVICWebViewPage(
          registrationNumber: registrationNumber, vehicleType: vehicleType,
          email: 'loginemail@gmail.com', password: 'your-password')));
  }

  Future<void> _sendEmail(String company, String insuranceType, String insuranceSubtype,
      Map<String, String> formData, File filledPdf, String registrationNumber,
      String vehicleType, String coverId) async {
    if (insuranceType == 'motor') {
      await _autofillDMVICWebsiteForMotorInsurance(registrationNumber, vehicleType, context);
    }
    final smtpServer = gmail('your-email@gmail.com', 'your-app-specific-password');
    final message = mailer.Message()
      ..from = const mailer.Address('your-email@gmail.com', 'Insurance App')
      ..recipients.add(
          policyCalculators[insuranceType]![insuranceSubtype]!['companyA']!['email'])
      ..subject = 'Insurance Form Submission: $insuranceSubtype ($insuranceType)'
      ..html = '<h3>Form Submission Details</h3><ul>${formData.entries.map((e) => '<li>${e.key}: ${e.value}</li>').join('')}</ul>'
      ..attachments.add(mailer.FileAttachment(filledPdf, fileName: 'filled_form.pdf'));
    try {
      await mailer.send(message, smtpServer);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Form details and PDF sent to company email')));
      }
      _logAction('Email sent to $company for $insuranceSubtype ($insuranceType)');
      Future.delayed(const Duration(minutes: 5), () async {
        final analyzer = EmailAnalyzer();
        await analyzer.analyzeAndUpdateClaimStatus(coverId: coverId,
            query: 'from:${policyCalculators[insuranceType]![insuranceSubtype]!['companyA']!['email']}');
      });
    } catch (e) {
      if (kDebugMode) print('Error sending email: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send email')));
      }
    }
  }

  void _logAction(String action) async {
    final directory = await getApplicationDocumentsDirectory();
    final logFile = File('${directory.path}/app.log');
    await logFile.writeAsString('${DateTime.now()}: $action\n', mode: FileMode.append);
  }

  Future<void> _saveCovers() async {
    await const FlutterSecureStorage().write(
        key: 'covers', value: jsonEncode(covers.map((c) => c.toJson()).toList()));
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0: return _buildHomeScreen(context, pdfTemplateKey, GlobalKey<ScaffoldMessengerState>(), []);
      case 1: return _buildQuotesScreen();
      case 2: return _buildUpcomingScreen();
      case 3: return _buildMyAccountScreen(context);
      case 4: return _buildInsurableItemScreen(context);
      default: return _buildHomeScreen(context, pdfTemplateKey, GlobalKey<ScaffoldMessengerState>(), []);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UI COMPONENTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Policy type card used in the home screen grid.
  Widget _buildPolicyCard(BuildContext context, PolicyType policyType,
      GlobalKey<ScaffoldMessengerState> smKey) {
    final icon = getCustomEmojiWidget(policyType.name);
    return GestureDetector(
      onTap: () async {
        if (_isDialogOpening) return;
        _isDialogOpening = true;
        try {
          // Use this State's own (stable) context rather than the
          // GridView.builder itemBuilder's context passed in above. The
          // wizard this kicks off is a long-running, multi-step async chain
          // (Firestore lookups, retries, several nested dialogs) — a grid
          // item's context can be torn down and rebuilt by Flutter well
          // before that chain finishes, even with nothing visibly changing
          // on screen. When that happened, `context.mounted` silently went
          // false partway through the wizard, the next step's dialog never
          // opened, and the flow appeared to freeze with no error at all.
          await showInsuranceDialog(this.context, policyType.name,
              scaffoldMessengerKey: smKey, onFinalSubmit: null);
        } catch (e) {
          smKey.currentState?.showSnackBar(SnackBar(content: Text('Failed to show dialog: $e')));
        } finally {
          _isDialogOpening = false;
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: _isDark ? Colors.black38 : _kDarkTeal.withOpacity(0.06),
              blurRadius: 12, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Accent gradient stripe at top
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_kAcidOlive, _kCyan]),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: _iconBg, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: icon ?? const Text('🔧', style: TextStyle(fontSize: 22))),
                  ),
                  const Spacer(),
                  Text(
                    policyType.name.toUpperCase(),
                    style: GoogleFonts.dmSans(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: _textPrimary, letterSpacing: 0.8),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text('Get quote', style: GoogleFonts.dmSans(fontSize: 11, color: _textMuted)),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward, size: 10, color: _textMuted),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Desktop/web sidebar navigation item.
  Widget _buildNavItem(BuildContext context,
      {required IconData icon, required String title,
       required VoidCallback onTap, bool isSelected = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? (_isDark ? _kAcidOlive.withOpacity(0.15) : _kDarkTeal.withOpacity(0.08))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: _isDark ? _kAcidOlive.withOpacity(0.4) : _kDarkTeal.withOpacity(0.2))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (_isDark ? _kAcidOlive : _kDarkTeal)
                        : _iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18,
                      color: isSelected
                          ? (_isDark ? _kDarkTeal : Colors.white)
                          : _textMuted),
                ),
                const SizedBox(width: 12),
                Text(title,
                    style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? _accent : _textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Notification bell with acid-olive badge.
  Widget _buildNotificationButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => NotificationsScreen(notifications: notifications))),
          ),
          if (notifications.isNotEmpty)
            Positioned(
              right: 8, top: 8,
              child: Container(
                width: 16, height: 16,
                decoration: const BoxDecoration(color: _kAcidOlive, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    '${notifications.length > 9 ? '9+' : notifications.length}',
                    style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: _kDarkTeal),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Quote list card with emoji type icon and premium in Playfair Display.
  Widget _buildQuoteCard(BuildContext context, Quote quote) {
    final typeEmoji = {
      'motor': '🚘', 'medical': '🏥', 'travel': '✈️', 'property': '🏠', 'wiba': '💼',
    }[quote.type.toLowerCase()] ?? '📋';

    return GestureDetector(
      onTap: () => handleCoverSubmission(
        context,
        PolicyType(id: '', name: quote.type,    description: ''),
        PolicySubtype(id: '', name: quote.subtype, description: '', policyTypeId: ''),
        CoverageType(id: '', name: '', description: ''),
        quote.company, '', quote.formData,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: _surface, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: _iconBg, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(typeEmoji, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${quote.type} — ${quote.subtype}',
                      style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary)),
                  const SizedBox(height: 4),
                  Text('KES ${quote.premium.toStringAsFixed(0)}',
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 18, fontWeight: FontWeight.w700, color: _accent)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  '${quote.generatedAt.day}/${quote.generatedAt.month}/${quote.generatedAt.year}',
                  style: GoogleFonts.dmSans(fontSize: 11, color: _textMuted),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _iconBg, borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _border),
                  ),
                  child: Text('Apply',
                      style: GoogleFonts.dmSans(
                          fontSize: 11, fontWeight: FontWeight.w600, color: _accent)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  /// Upcoming expiration card with urgency colour coding.
  Widget _buildUpcomingCard(BuildContext context, Cover cover) {
    final daysLeft  = cover.endDate!.difference(DateTime.now()).inDays;
    final isUrgent  = daysLeft <= 7;
    final urgentColor = isUrgent ? const Color(0xFFFF6B6B) : const Color(0xFFFFB84D);
    final urgentBg    = urgentColor.withOpacity(0.1);

    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('${cover.type} — ${cover.subtype}'),
          content: Text('Expires in $daysLeft days'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            TextButton(
              onPressed: () {
                final item = insuredItems.firstWhere(
                  (i) => i.id == cover.insuredItemId,
                  orElse: () => InsuredItem(
                    id: cover.insuredItemId, name: '', email: '', contact: '',
                    type: cover.type, subtype: cover.subtype,
                    coverageType: cover.coverageType, details: {}, kraPin: '',
                  ),
                );
                _showCoverActionsDialog(context, item);
              },
              child: const Text('Renew'),
            ),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isUrgent ? urgentColor.withOpacity(0.4) : _border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: urgentBg, borderRadius: BorderRadius.circular(12)),
              child: Center(
                child: Icon(
                  isUrgent ? Icons.warning_amber_rounded : Icons.access_time_rounded,
                  color: urgentColor, size: 24,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${cover.type} — ${cover.subtype}',
                    style: GoogleFonts.dmSans(
                        fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary)),
                const SizedBox(height: 4),
                Text(
                  isUrgent ? 'Expires in $daysLeft days — Act now!' : 'Expires in $daysLeft days',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: urgentColor,
                      fontWeight: isUrgent ? FontWeight.w600 : FontWeight.w400),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _iconBg, borderRadius: BorderRadius.circular(20)),
              child: Text('Renew',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, fontWeight: FontWeight.w600, color: _accent)),
            ),
          ]),
        ),
      ),
    );
  }

  /// Account screen label–value row.
  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  letterSpacing: 0.5, color: _textMuted)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(value, style: GoogleFonts.dmSans(fontSize: 14, color: _textPrimary))),
      ]),
    );
  }

  /// Desktop right-sidebar trending + learn content.
  Widget _buildSidebarContent(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSidebarSectionHeader('📰', 'Market Pulse'),
          const SizedBox(height: 12),
          if (trendingTopics.isNotEmpty)
            ...trendingTopics.take(5).map((article) {
              final a = article as Map<String, dynamic>?;
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => WebViewPage(url: a?['url']?.toString() ?? 'https://newsapi.org'))),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: _surface, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 4, height: 40,
                      decoration: BoxDecoration(
                          color: _kAcidOlive, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(a?['title']?.toString() ?? 'Untitled',
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                              fontSize: 12, fontWeight: FontWeight.w500, color: _textPrimary)),
                    ),
                  ]),
                ),
              );
            }).toList()
          else
            const Center(
                child: Padding(padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: _kCyan, strokeWidth: 2))),
          const SizedBox(height: 20),
          _buildSidebarSectionHeader('📚', 'Learn'),
          const SizedBox(height: 12),
          if (blogPosts.isNotEmpty)
            ...blogPosts.take(5).map((post) => GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const WebViewPage(url: 'https://newsapi.org'))),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: _surface, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border)),
                child: Row(children: [
                  Expanded(child: Text(post,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(fontSize: 12, color: _textMuted))),
                  const SizedBox(width: 8),
                  Icon(Icons.open_in_new, size: 14, color: _textMuted),
                ]),
              ),
            )).toList()
          else
            const Center(
                child: Padding(padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: _kCyan, strokeWidth: 2))),
        ]),
      ),
    );
  }

  Widget _buildSidebarSectionHeader(String emoji, String title) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _iconBg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.playfairDisplay(
                fontSize: 16, fontWeight: FontWeight.w600, color: _textPrimary)),
      ]),
    );
  }

  /// Section header used across screens.
  Widget _buildSectionHeader(BuildContext context, String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.playfairDisplay(
                fontSize: 22, fontWeight: FontWeight.w700, color: _textPrimary)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.dmSans(fontSize: 13, color: _textMuted)),
        ],
      ]),
    );
  }

  // ── Screens ──────────────────────────────────────────────────────────────────

  Widget _buildInsurableItemScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Insurable Items',
            style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w600)),
        backgroundColor: _kDarkTeal,
        foregroundColor: _kCream,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('insured_items').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _kCyan));
          final items = snapshot.data!.docs
              .map((doc) {
                try { return InsuredItem.fromJson(doc.data() as Map<String, dynamic>); }
                catch (_) { return null; }
              })
              .whereType<InsuredItem>()
              .toList();
          if (items.isEmpty) {
            return Center(
              child: Text('No insurable items found.',
                  style: GoogleFonts.dmSans(fontSize: 14, color: _textMuted)));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final cover = item.cover;
              final daysLeft = cover?.expirationDate != null
                  ? cover!.expirationDate!.difference(DateTime.now()).inDays
                  : null;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                    color: _surface, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: _iconBg, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: getCustomEmojiWidget(item.type.name)),
                  ),
                  title: Text('${item.type.name} — ${item.subtype.name}',
                      style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary)),
                  subtitle: cover != null
                      ? Text(
                          'Status: ${cover.status.name}'
                          '${daysLeft != null ? ', $daysLeft days left' : ''}',
                          style: GoogleFonts.dmSans(fontSize: 12,
                              color: daysLeft != null && daysLeft <= 7
                                  ? const Color(0xFFFF6B6B) : _textMuted))
                      : Text('No active cover',
                          style: GoogleFonts.dmSans(fontSize: 12, color: _textMuted)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (daysLeft != null && daysLeft <= 30)
                      Icon(Icons.warning_amber_rounded,
                          color: daysLeft <= 7 ? const Color(0xFFFF6B6B) : const Color(0xFFFFB84D),
                          size: 20),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, color: _textMuted, size: 16),
                  ]),
                  onTap: () => _showCoverActionsDialog(context, item),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCoverActionsDialog(BuildContext context, InsuredItem item) async {
    final cover       = item.cover;
    final canExtend   = cover != null && (cover.status == CoverStatus.active || cover.status == CoverStatus.nearingExpiration);
    final canFileClaim = cover != null && (cover.status == CoverStatus.active || cover.status == CoverStatus.extended);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${item.type.name} — ${item.subtype.name}',
            style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.w600)),
        content: cover != null
            ? Text('Status: ${cover.status.name}\n'
                '${cover.expirationDate != null ? 'Expires: ${cover.expirationDate!.toLocal().toString().split(' ')[0]}' : ''}\n'
                'Extensions: ${cover.extensionCount}/2',
                style: GoogleFonts.dmSans(fontSize: 14))
            : Text('No active cover.', style: GoogleFonts.dmSans(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          if (cover != null)
            TextButton(onPressed: () async { Navigator.pop(context); await _cancelCover(context, cover); },
                child: const Text('Cancel')),
          if (canExtend)
            TextButton(onPressed: () async { Navigator.pop(context); await _showExtendDialog(context, item); },
                child: const Text('Extend')),
          if (canFileClaim)
            TextButton(onPressed: () async { Navigator.pop(context); await _showFileClaimDialog(context, item, cover); },
                child: const Text('File Claim')),
          TextButton(onPressed: () async { Navigator.pop(context); await _showRenewDialog(context, item); },
              child: const Text('Renew')),
        ],
      ),
    );
  }

  Future<void> _cancelCover(BuildContext context, Cover cover) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('company').where('isCancellation', isEqualTo: true).get();
      final companies = snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
      if (companies.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No companies available.')));
        return;
      }
      final updatedCover = cover.copyWith(status: CoverStatus.inactive);
      await FirebaseFirestore.instance.collection('covers').doc(cover.id).update(updatedCover.toJson());
      final idx = covers.indexWhere((c) => c.id == cover.id);
      if (idx != -1) covers[idx] = updatedCover;
      cover.status        = CoverStatus.inactive;
      cover.expirationDate = DateTime.now();
      cover.paymentStatus  = 'canceled';
      final tmplKey = (companies.isNotEmpty && companies[0]['pdfTemplateKey'] != null)
          ? companies[0]['pdfTemplateKey'] as String : 'default_template';
      Map<String, FieldDefinition> fields = {};
      final pdfTmpl = await InsuranceHomeScreen.getPDFTemplate(tmplKey);
      if (pdfTmpl != null) fields = pdfTmpl.fields;
      fields.forEach((key, _) {
        if (!_genericControllers.containsKey(key)) _genericControllers[key] = TextEditingController();
      });
      if (fields.isNotEmpty) {
        final formKey = GlobalKey<FormState>();
        if (!context.mounted) return;
        final result = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('${cover.type.name.toUpperCase()} Cancellation Details',
                style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.w600)),
            content: SingleChildScrollView(child: Form(key: formKey, child: Column(
              mainAxisSize: MainAxisSize.min,
              children: fields.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _genericControllers[entry.key],
                  decoration: InputDecoration(labelText: entry.key),
                  validator: entry.value.validator,
                ),
              )).toList(),
            ))),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () { if (formKey.currentState!.validate()) Navigator.of(dialogContext).pop(true); },
                child: const Text('Submit'),
              ),
            ],
          ),
        );
        if (result != true) return;
      }
      final details = _genericControllers.map((k, v) => MapEntry(k, v.text.trim()));
      setState(() {});
      await _saveCovers();
      if (context.mounted) {
        await handleCoverSubmission(context, cover.type, cover.subtype, cover.coverageType,
            cover.companyId, cover.pdfTemplateKey, details, cover.id, cover.insuredItemId);
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cover canceled.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel cover: $e')));
    }
  }

  Future<void> _showExtendDialog(BuildContext context, InsuredItem item) async {
    final snap = await FirebaseFirestore.instance
        .collection('company').where('isExtension', isEqualTo: true).get();
    final companies = snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
    if (companies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No companies available.')));
      return;
    }
    final subtypes      = await InsuranceHomeScreen.getPolicySubtypes(item.type.id);
    final coverageTypes = await InsuranceHomeScreen.getCoverageTypes(item.type.id);
    String? selectedCompanyId     = item.cover?.companyId ?? companies[0]['id'];
    PolicySubtype? selectedSubtype      = item.subtype;
    CoverageType?  selectedCoverageType = item.coverageType;
    final cover = item.cover!;
    Map<String, FieldDefinition> fields = {};
    final pdfTmpl = await InsuranceHomeScreen.getPDFTemplate(pdfTemplateKey);
    if (pdfTmpl != null) fields = pdfTmpl.fields;
    fields.forEach((key, _) {
      if (!_genericControllers.containsKey(key)) _genericControllers[key] = TextEditingController();
    });
    if (fields.isNotEmpty) {
      if (!context.mounted) return;
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${item.type.name.toUpperCase()} Extension Details',
              style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(child: Form(
            key: GlobalKey<FormState>(),
            child: Column(mainAxisSize: MainAxisSize.min,
              children: fields.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _genericControllers[entry.key],
                  decoration: InputDecoration(labelText: entry.key),
                  validator: entry.value.validator,
                ),
              )).toList()),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Submit')),
          ],
        ),
      );
      if (result != true) return;
    }
    final details = _genericControllers.map((k, v) => MapEntry(k, v.text.trim()));
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Extend Cover',
            style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: selectedCompanyId,
            decoration: const InputDecoration(labelText: 'Insurance Company'),
            items: companies.map((c) =>
                DropdownMenuItem<String>(value: c['id'], child: Text(c['name']))).toList(),
            onChanged: (v) => setState(() => selectedCompanyId = v),
          ),
          DropdownButtonFormField<PolicySubtype>(
            value: selectedSubtype,
            decoration: const InputDecoration(labelText: 'Policy Subtype'),
            items: subtypes.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
            onChanged: (v) => setState(() => selectedSubtype = v),
          ),
          DropdownButtonFormField<CoverageType>(
            value: selectedCoverageType,
            decoration: const InputDecoration(labelText: 'Coverage Type'),
            items: coverageTypes.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
            onChanged: (v) => setState(() => selectedCoverageType = v),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (selectedCompanyId == null || selectedSubtype == null || selectedCoverageType == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select all options.')));
                return;
              }
              Navigator.pop(context);
              final selCo = companies.firstWhere((c) => c['id'] == selectedCompanyId,
                  orElse: () => {'id': 'default', 'pdfTemplateKey': 'default_template'});
              await handleCoverSubmission(context, item.type, selectedSubtype!, selectedCoverageType!,
                  selectedCompanyId!, selCo['pdfTemplateKey'] ?? 'default_template', details, cover.id, item.id);
            },
            child: const Text('Submit'),
          ),
        ],
      )),
    );
  }

  Future<void> _showRenewDialog(BuildContext context, InsuredItem item) async {
    final companies     = await InsuranceHomeScreen.getCompanies();
    final subtypes      = await InsuranceHomeScreen.getPolicySubtypes(item.type.id);
    final coverageTypes = await InsuranceHomeScreen.getCoverageTypes(item.type.id);
    String? selectedCompanyId         = item.cover?.companyId ?? companies[0].id;
    PolicySubtype? selectedSubtype    = item.subtype;
    CoverageType?  selectedCoverage   = item.coverageType;
    final details = Map<String, String>.from(item.details);
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Renew Cover',
            style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: selectedCompanyId,
            decoration: const InputDecoration(labelText: 'Insurance Company'),
            items: companies.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (v) => setState(() => selectedCompanyId = v),
          ),
          DropdownButtonFormField<PolicySubtype>(
            value: selectedSubtype,
            decoration: const InputDecoration(labelText: 'Policy Subtype'),
            items: subtypes.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
            onChanged: (v) => setState(() => selectedSubtype = v),
          ),
          DropdownButtonFormField<CoverageType>(
            value: selectedCoverage,
            decoration: const InputDecoration(labelText: 'Coverage Type'),
            items: coverageTypes.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
            onChanged: (v) => setState(() => selectedCoverage = v),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (selectedCompanyId == null || selectedSubtype == null || selectedCoverage == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select all options.')));
                return;
              }
              Navigator.pop(context);
              final selCo = companies.firstWhere((c) => c.id == selectedCompanyId,
                  orElse: () => company_models.Company(id: 'default', name: 'Default', pdfTemplateKey: ['default_template']));
              await handleCoverSubmission(context, item.type, selectedSubtype!, selectedCoverage!,
                  selectedCompanyId!,
                  selCo.pdfTemplateKey.isNotEmpty ? selCo.pdfTemplateKey.first : 'default_template',
                  details, '', item.id);
            },
            child: const Text('Submit'),
          ),
        ],
      )),
    );
  }

  Future<void> _showFileClaimDialog(BuildContext context, InsuredItem item, Cover cover) async {
    if (!context.mounted) return;
    try {
      final companySnap = await FirebaseFirestore.instance
          .collection('company').doc(cover.companyId).get();
      if (!companySnap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company not found.')));
        return;
      }
      final companyData = companySnap.data() as Map<String, dynamic>;
      if (companyData['isClaim'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company does not support claims.')));
        return;
      }
      final tmplKey = companyData['pdfTemplateKey'] as String? ?? 'default_template';
      Map<String, FieldDefinition> fields = {};
      final pdfTmpl = await InsuranceHomeScreen.getPDFTemplate(tmplKey);
      if (pdfTmpl != null) fields = pdfTmpl.fields;
      fields.forEach((key, _) {
        if (!_genericControllers.containsKey(key)) _genericControllers[key] = TextEditingController();
      });
      if (fields.isNotEmpty) {
        final formKey = GlobalKey<FormState>();
        if (!context.mounted) return;
        final result = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('${item.type.name.toUpperCase()} Claim Details',
                style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.w600)),
            content: SingleChildScrollView(child: Form(key: formKey, child: Column(
              mainAxisSize: MainAxisSize.min,
              children: fields.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _genericControllers[entry.key],
                  decoration: InputDecoration(labelText: entry.key),
                  validator: entry.value.validator,
                ),
              )).toList(),
            ))),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () { if (formKey.currentState!.validate()) Navigator.of(dialogContext).pop(true); },
                child: const Text('Submit'),
              ),
            ],
          ),
        );
        if (result != true) return;
      }
      final details = _genericControllers.map((k, v) => MapEntry(k, v.text.trim()));
      await handleCoverSubmission(context, item.type, item.subtype, item.coverageType,
          cover.companyId, tmplKey, details, cover.id, item.id);
      _genericControllers.forEach((_, c) => c.clear());

      // `claimCount` is immutable on Cover, so bump it via copyWith rather
      // than mutating in place, then keep the in-memory list and Firestore
      // in sync with the new value.
      final updatedClaimCover = cover.copyWith(claimCount: cover.claimCount + 1);
      if (mounted) {
        setState(() {
          covers = covers
              .map((c) => c.id == cover.id ? updatedClaimCover : c)
              .toList();
        });
      }
      await FirebaseFirestore.instance
          .collection('covers')
          .doc(cover.id)
          .update({'claimCount': updatedClaimCover.claimCount});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process claim: $e')));
      }
    }
  }

  Widget _buildHomeScreen(BuildContext context, String pdfTemplateKey,
      GlobalKey<ScaffoldMessengerState> smKey, List<PolicyType> cachedPolicyTypes) {
    final Map<String, Map<String, List<DialogStepConfig>>> configCache = {};
    return Consumer<DialogState>(builder: (context, dialogState, _) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text('Home',
              style: GoogleFonts.playfairDisplay(
                  fontSize: 20, fontWeight: FontWeight.w600, color: _kCream)),
          backgroundColor: _kDarkTeal,
          foregroundColor: _kCream,
          elevation: 0,
        ),
        key: smKey,
        body: FutureBuilder<List<PolicyType>>(
          future: Future.value(cachedPolicyTypes),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _kCyan));
            }
            if (snapshot.hasError) {
              return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Error: ${snapshot.error}',
                    style: GoogleFonts.dmSans(fontSize: 14, color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 16),
                ElevatedButton(
                    onPressed: () => (context as Element).markNeedsBuild(),
                    child: const Text('Retry')),
              ]));
            }
            final policyTypes = snapshot.data?.isNotEmpty == true ? snapshot.data! : [
              PolicyType(id: '1', name: 'Motor',    description: 'Motor insurance'),
              PolicyType(id: '2', name: 'Medical',  description: 'Medical insurance'),
              PolicyType(id: '3', name: 'Travel',   description: 'Travel insurance'),
              PolicyType(id: '4', name: 'Property', description: 'Property insurance'),
              PolicyType(id: '5', name: 'WIBA',     description: 'WIBA insurance'),
            ];
            final currentType  = dialogState.currentType;
            final dialogIndex  = dialogState.currentStep;

            return CustomScrollView(slivers: [
              if (!kIsWeb)
                SliverAppBar(
                  pinned: true,
                  backgroundColor: _kDarkTeal,
                  foregroundColor: _kCream,
                  elevation: 0,
                  title: Text('BIMA GUARDIAN',
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 20, fontWeight: FontWeight.w700,
                          color: _kCream, letterSpacing: 1.5)),
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
                  actions: [
                    if (userRole == UserRole.admin)
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.admin_panel_settings, color: _kCream, size: 20),
                        ),
                        onPressed: () => Navigator.pushNamed(context, '/admin'),
                        tooltip: 'Admin Panel',
                      ),
                    _buildNotificationButton(context),
                  ],
                ),
              const SliverPadding(padding: EdgeInsets.only(top: 16)),
              SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  height: 200,
                  child: BannerCarousel(
                    banners: [
                      BannerModel(imagePath: 'banners/promo1.jpg', title: 'Promo 1', createdAt: DateTime.now()),
                      BannerModel(imagePath: 'banners/promo2.jpg', title: 'Promo 2', createdAt: DateTime.now()),
                      BannerModel(imagePath: 'banners/promo3.jpg', title: 'Promo 3', createdAt: DateTime.now()),
                    ],
                    onUpload: (File file) { if (kDebugMode) print('Banner uploaded: ${file.path}'); },
                  ),
                ),
                const SizedBox(height: 16),
                // Quick-action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(child: _buildActionButton(
                      context,
                      label: _isOcrLoading ? 'Processing…'
                          : (_initialExtractedData == null || _selectedInsuredItem != null
                              ? 'Upload Previous Policy' : 'Policy Uploaded ✓'),
                      onPressed: _isOcrLoading || _isLoadingItems ? null : _uploadPreviousPolicy,
                      isSecondary: _initialExtractedData != null && _selectedInsuredItem == null,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _buildActionButton(
                      context,
                      label: _isLoadingItems ? 'Loading…'
                          : (_selectedInsuredItem == null ? 'Autofill from Item' : 'Item Loaded ✓'),
                      onPressed: _isOcrLoading || _isLoadingItems ? null : _autofillFromInsuredItem,
                      isSecondary: _selectedInsuredItem != null,
                    )),
                  ]),
                ),
                if (_selectedInsuredItem != null) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildActionButton(
                      context,
                      label: 'Select Policy',
                      onPressed: () => navigateToCoverDetailScreen(
                          'motor', 'comprehensive', 'third_party', 'subtype_id', 'coverage_type_id'),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (currentType.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FutureBuilder<Map<String, List<DialogStepConfig>>>(
                      future: configCache.containsKey(currentType)
                          ? Future.value(configCache[currentType])
                          : ConfigCache().getInsuranceConfigs(currentType).timeout(
                              const Duration(seconds: 100), onTimeout: () {
                            return {currentType: [DialogStepConfig(
                              title: 'Default $currentType Config',
                              fields: [FieldConfig(key: 'subtype', label: 'Subtype', type: 'dropdown',
                                  options: ['Standard', 'Premium'],
                                  validator: (v) => v != null ? null : 'Select a subtype')],
                              customCallback: (ctx, ds) async {},
                            )]};
                          }).then((configs) { configCache[currentType] = configs; return configs; }),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return LinearProgressIndicator(
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            valueColor: const AlwaysStoppedAnimation<Color>(_kCyan),
                          );
                        }
                        if (snapshot.hasError) return const SizedBox.shrink();
                        final count = snapshot.data?[currentType]?.length ?? 1;
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (dialogIndex + 1) / count.clamp(1, double.infinity),
                            backgroundColor: _kDarkTeal.withOpacity(0.15),
                            valueColor: const AlwaysStoppedAnimation<Color>(_kAcidOlive),
                            minHeight: 5,
                          ),
                        );
                      },
                    ),
                  ),
                _buildSectionHeader(context, 'Select Your Cover',
                    subtitle: 'Tap a category to get started'),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 1.35,
                    crossAxisSpacing: 12, mainAxisSpacing: 12,
                  ),
                  itemCount: policyTypes.length,
                  itemBuilder: (context, index) =>
                      _buildPolicyCard(context, policyTypes[index], smKey),
                ),
              ])),
            ]);
          },
        ),
      );
    });
  }

  Widget _buildActionButton(BuildContext context,
      {required String label, VoidCallback? onPressed, bool isSecondary = false}) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSecondary ? _kAcidOlive : _kDarkTeal,
          foregroundColor: isSecondary ? _kDarkTeal : _kCream,
          disabledBackgroundColor: _isDark ? const Color(0xFF2A4050) : const Color(0xFFD8EBB8),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget? getCustomEmojiWidget(String? iconName) {
    const style = TextStyle(fontSize: 22);
    switch (iconName?.toLowerCase()) {
      case 'motor':    return const Text('🚘', style: style);
      case 'medical':  return const Text('🏥', style: style);
      case 'travel':   return const Text('✈️', style: style);
      case 'property': return const Text('🏠', style: style);
      case 'wiba':     return const Text('💼', style: style);
      default:         return const Text('🔧', style: style);
    }
  }

  Widget _buildMyAccountScreen(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('My Account',
            style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w600)),
        backgroundColor: _kDarkTeal,
        foregroundColor: _kCream,
        elevation: 0,
      ),
      body: SafeArea(child: StreamBuilder<DocumentSnapshot>(
        stream: user != null
            ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots()
            : null,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _kCyan));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('User data not found',
                style: GoogleFonts.dmSans(fontSize: 14, color: _textMuted)));
          }
          final ud   = snapshot.data!.data() as Map<String, dynamic>;
          final name = ud['name']  ?? 'N/A';
          final email = user?.email ?? 'N/A';
          final phone = ud['phone'] ?? 'N/A';
          final autobilling = ud['autobilling_enabled'] ?? false;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Profile card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                decoration: BoxDecoration(
                    color: _surface, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: _iconBg, borderRadius: BorderRadius.circular(14)),
                        child: Center(child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: GoogleFonts.playfairDisplay(
                              fontSize: 22, fontWeight: FontWeight.w700, color: _textPrimary),
                        )),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: GoogleFonts.dmSans(
                            fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
                        Text(email, style: GoogleFonts.dmSans(fontSize: 12, color: _textMuted)),
                      ])),
                      TextButton(
                        onPressed: () => _showEditUserDetailsDialog(context, name, phone),
                        child: Text('Edit', style: GoogleFonts.dmSans(
                            fontSize: 13, fontWeight: FontWeight.w600, color: _accent)),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Divider(color: _border, height: 1),
                    const SizedBox(height: 16),
                    _buildDetailRow(context, 'NAME',  name),
                    _buildDetailRow(context, 'EMAIL', email),
                    _buildDetailRow(context, 'PHONE', phone),
                  ]),
                ),
              ),
              // Settings card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                decoration: BoxDecoration(
                    color: _surface, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border)),
                child: Column(children: [
                  _buildSettingsRow(context,
                    icon: Icons.description_outlined,
                    label: 'Policy Reports',
                    trailing: Icon(Icons.arrow_forward_ios, size: 16, color: _textMuted),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CoverReportScreen())),
                  ),
                  Divider(color: _border, height: 1, indent: 16, endIndent: 16),
                  _buildSettingsRow(context,
                    icon: Icons.payment_outlined,
                    label: 'Autobilling',
                    trailing: Switch(
                      value: autobilling,
                      activeColor: _kAcidOlive,
                      activeTrackColor: _kDarkTeal,
                      onChanged: (v) async {
                        try {
                          await FirebaseFirestore.instance
                              .collection('users').doc(user!.uid)
                              .update({'autobilling_enabled': v});
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update autobilling: $e')));
                        }
                      },
                    ),
                  ),
                  Divider(color: _border, height: 1, indent: 16, endIndent: 16),
                  _buildSettingsRow(context,
                    icon: Icons.dark_mode_outlined,
                    label: 'Dark Mode',
                    trailing: Switch(
                      value: themeProvider.themeMode == ThemeMode.dark,
                      activeColor: _kAcidOlive,
                      activeTrackColor: _kDarkTeal,
                      onChanged: themeProvider.toggleTheme,
                    ),
                  ),
                ]),
              ),
              // Logout
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      try {
                        await FirebaseAuth.instance.signOut();
                        await FirebaseAuth.instance.signInAnonymously();
                      } catch (e) {
                        showDialog(context: context, builder: (_) => AlertDialog(
                          title: const Text('Error'),
                          content: Text('Failed to sign out: $e'),
                          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
                        ));
                      }
                    },
                    child: Text('Log Out',
                        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ]),
          );
        },
      )),
    );
  }

  Widget _buildSettingsRow(BuildContext context,
      {required IconData icon, required String label,
       required Widget trailing, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: _iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: _textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: _textPrimary))),
          trailing,
        ]),
      ),
    );
  }

  void _showEditUserDetailsDialog(BuildContext context, String currentName, String currentPhone) {
    final nameCtrl  = TextEditingController(text: currentName);
    final phoneCtrl = TextEditingController(text: currentPhone);
    final formKey   = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Details', style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.w600)),
        content: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null),
          const SizedBox(height: 8),
          TextFormField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Phone is required';
                if (!RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(v)) return 'Invalid phone number';
                return null;
              }),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final u = FirebaseAuth.instance.currentUser;
                  if (u != null) {
                    await FirebaseFirestore.instance.collection('users').doc(u.uid)
                        .update({'name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim()});
                    if (context.mounted) Navigator.of(context).pop();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update details: $e')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotesScreen() {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Quotes',
            style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w600)),
        backgroundColor: _kDarkTeal,
        foregroundColor: _kCream,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            // Previously this replaced the real quotes list with 3 hardcoded
            // sample quotes that had empty formData — tapping any of them
            // crashed handleCoverSubmission with "name cannot be empty"
            // (InsuredItem requires a non-empty name). This now actually
            // refreshes from Firestore via the real loader.
            onPressed: _loadQuotes,
          ),
        ],
      ),
      body: quotes.isEmpty
          ? Center(child: Text('No quotes yet.', style: GoogleFonts.dmSans(fontSize: 14, color: _textMuted)))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: quotes.length,
              itemBuilder: (context, index) => _buildQuoteCard(context, quotes[index]),
            ),
    );
  }

  Widget _buildUpcomingScreen() {
    final upcoming = covers.where((cover) {
      if (cover.endDate == null) return false;
      final days = cover.endDate!.difference(DateTime.now()).inDays;
      return days <= 30 && days > 0;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Upcoming Expirations',
            style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w600)),
        backgroundColor: _kDarkTeal,
        foregroundColor: _kCream,
        elevation: 0,
      ),
      body: upcoming.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('All policies are up to date!',
                  style: GoogleFonts.dmSans(fontSize: 14, color: _textMuted)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: upcoming.length,
              itemBuilder: (context, index) => _buildUpcomingCard(context, upcoming[index]),
            ),
    );
  }

  static const String apiKey = 'your-newsapi-key-here';

  Future<void> fetchTrendingTopics() async {
    try {
      final response = await http.get(Uri.parse(
          'https://newsapi.org/v2/everything?q=insurance+Kenya+trending&apiKey=$apiKey'));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() => trendingTopics = (jsonDecode(response.body)['articles'] as List<dynamic>));
        }
      } else {
        throw Exception('Status ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => trendingTopics = [
          {'title': 'Insurance trends in Kenya: What you need to know', 'url': 'https://newsapi.org'},
          {'title': 'Top insurance companies in Kenya',                 'url': 'https://newsapi.org'},
          {'title': 'How technology is transforming insurance in Kenya', 'url': 'https://newsapi.org'},
        ]);
      }
    }
  }

  Future<void> fetchBlogPosts() async {
    try {
      final response = await http.get(Uri.parse(
          'https://newsapi.org/v2/everything?q=insurance+Kenya+blog&apiKey=$apiKey'));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() => blogPosts = (jsonDecode(response.body)['articles'] as List<dynamic>)
              .map((a) => a['title']?.toString() ?? 'Untitled').toList());
        }
      } else {
        throw Exception('Status ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => blogPosts = [
          'Understanding Insurance Policies in Kenya',
          'How to Choose the Right Insurance Provider',
          'The Future of Insurance in Kenya',
        ]);
      }
    }
  }

  // ── Chat bottom sheet ───────────────────────────────────────────────────────

  void _showChatBottomSheet(BuildContext context) {
    final ctrl = TextEditingController();
    final msgs = <String>[];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final surface = isDark ? const Color(0xFF13232E) : Colors.white;
          final border  = isDark ? const Color(0xFF2A4050) : _kCreamDark;
          final tp = isDark ? const Color(0xFFD4ECA8) : _kDarkTeal;
          final tm = isDark ? _kSoftOlive : const Color(0xFF4A6741);
          final fill = isDark ? const Color(0xFF1A2E3A) : const Color(0xFFF9FDF4);

          return Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: border),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 20, right: 20, top: 8,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2))),
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: _kAcidOlive, borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Text('🤖', style: TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('BIMA Bot',
                      style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: tp)),
                  Text('Ask about insurance',
                      style: GoogleFonts.dmSans(fontSize: 11, color: tm)),
                ]),
              ]),
              if (msgs.isNotEmpty) ...[
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: msgs.length,
                    itemBuilder: (context, i) {
                      final isBot = msgs[i].startsWith('Bot:');
                      return Align(
                        alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                          decoration: BoxDecoration(
                            color: isBot ? fill : _kDarkTeal,
                            borderRadius: BorderRadius.only(
                              topLeft:     const Radius.circular(14),
                              topRight:    const Radius.circular(14),
                              bottomLeft:  Radius.circular(isBot ? 4 : 14),
                              bottomRight: Radius.circular(isBot ? 14 : 4),
                            ),
                          ),
                          child: Text(
                            msgs[i].replaceFirst('Bot: ', '').replaceFirst('You: ', ''),
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: isBot ? tp : _kCream,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    style: GoogleFonts.dmSans(color: tp, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '"I need motor insurance"',
                      hintStyle: GoogleFonts.dmSans(color: tm.withOpacity(0.6), fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: isDark ? _kAcidOlive : _kDarkTeal, width: 2)),
                      filled: true, fillColor: fill,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () async {
                    final rawInput = ctrl.text.trim();
                    if (rawInput.isEmpty) return;
                    setSheet(() { msgs.add('You: $rawInput'); ctrl.clear(); });
                    final input   = rawInput.toLowerCase();
                    final resolved = await _resolveNaturalLanguageApplication(input);
                    final matched  = resolved?['type'] as PolicyType?;
                    final hasIntent = _isApplicationIntent(input);
                    if (matched != null && matched.id.isNotEmpty) {
                      final sub  = resolved?['subtype']      as PolicySubtype?;
                      final cov  = resolved?['coverageType'] as CoverageType?;
                      final co   = resolved?['company']      as String?;
                      final hint = resolved?['moduleHint']   as String?;
                      setSheet(() {
                        if (sub != null && cov != null) {
                          msgs.add('Bot: Done. Selected ${matched.name} / ${sub.name} / ${cov.name}${co != null ? " / $co" : ""}.');
                          if (hint != null && hint.trim().isNotEmpty) msgs.add('Bot: $hint');
                        } else {
                          msgs.add('Bot: Great! Starting ${matched.name} insurance flow…');
                        }
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        if (sub != null && cov != null) {
                          await _showInsuredItemDialog(context, matched, sub, cov, preSelectedCompany: co);
                        } else {
                          showInsuranceDialog(context, matched.name.toLowerCase(),
                              scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
                              onFinalSubmit: (ctx, t, s, c, co) {},
                              initialResponses: await _extractDialogPrefillFromMessage(input, matched));
                        }
                      }
                    } else if (hasIntent) {
                      setSheet(() => msgs.add('Bot: I can help! Mention: motor, medical, travel, property, or WIBA.'));
                    } else {
                      setSheet(() => msgs.add('Bot: Tell me what you want to insure, e.g. "I need medical cover".'));
                    }
                  },
                  child: Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                        color: _kDarkTeal, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.send_rounded, color: _kAcidOlive, size: 20),
                  ),
                ),
              ]),
            ]),
          );
        },
      ),
    );
  }

  // ── Natural language helpers ─────────────────────────────────────────────────

  PolicyType? _extractInsuranceTypeFromMessage(String message, List<PolicyType> policyTypes) {
    final nm = message.toLowerCase();
    for (final t in policyTypes) {
      if (nm.contains(t.name.toLowerCase())) return t;
    }
    const aliases = <String, String>{
      'car': 'motor', 'auto': 'motor', 'vehicle': 'motor',
      'health': 'medical', 'hospital': 'medical',
      'trip': 'travel', 'flight': 'travel',
      'home': 'property', 'house': 'property', 'building': 'property',
      'worker': 'wiba', 'workers': 'wiba', 'injury': 'wiba',
    };
    for (final entry in aliases.entries) {
      if (nm.contains(entry.key)) {
        return policyTypes.firstWhere(
            (t) => t.name.toLowerCase() == entry.value,
            orElse: () => PolicyType(id: '', name: '', description: ''));
      }
    }
    return null;
  }

  bool _isApplicationIntent(String message) {
    const keywords = ['apply', 'buy', 'purchase', 'start', 'need', 'want', 'insure', 'cover', 'quote', 'policy'];
    return keywords.any(message.toLowerCase().contains);
  }

  Future<Map<String, String>> _extractDialogPrefillFromMessage(String message, PolicyType policyType) async {
    final nm     = message.toLowerCase();
    final prefill = <String, String>{};
    try {
      final subtypes = await InsuranceHomeScreen.getPolicySubtypes(policyType.id);
      PolicySubtype? matched;
      for (final s in subtypes) {
        if (nm.contains(s.name.toLowerCase())) { matched = s; prefill['subtype'] = s.name; break; }
      }
      if (matched != null) {
        final coverage = await InsuranceHomeScreen.getCoverageTypes(matched.id);
        for (final c in coverage) {
          if (nm.contains(c.name.toLowerCase())) { prefill['coverage_type'] = c.name; break; }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Prefill error: $e');
    }
    return prefill;
  }

  Future<Map<String, dynamic>?> _resolveNaturalLanguageApplication(String message) async {
    // Primary: try module-based resolution if service is available
    try {
      final policyTypes = await InsuranceHomeScreen.getPolicyTypes();
      final modules = policyTypes.map((pt) => PolicyModuleFactory.fromPolicyType(
        policyType: pt,
        getSubtypes: InsuranceHomeScreen.getPolicySubtypes,
        getCoverageTypes: InsuranceHomeScreen.getCoverageTypes,
        getCompanies: InsuranceHomeScreen.getCompanies,
      )).toList();
      final moduleMatch = await PolicyModuleResolver.resolve(message: message, modules: modules);
      if (moduleMatch != null) {
        final res = moduleMatch.resolution;
        return {
          'type':             res.type,
          'subtype':          res.subtype,
          'coverageType':     res.coverageType,
          'coverageDetail':   res.coverageDetail,
          'additionalLevels': res.additionalLevels,
          'company':          res.companyName,
          'moduleHint':       moduleMatch.module.guiHint,
          'moduleBundle':     res.bundle,
        };
      }
    } catch (_) {
      // fall through to legacy resolution below
    }

    // Fallback: keyword-based resolution
    final nm    = message.toLowerCase();
    final types = await InsuranceHomeScreen.getPolicyTypes();
    final matched = _extractInsuranceTypeFromMessage(nm, types);
    if (matched == null || matched.id.isEmpty) return null;
    final subtypes = await InsuranceHomeScreen.getPolicySubtypes(matched.id);
    if (subtypes.isEmpty) return null;
    var sub = subtypes.first;
    for (final s in subtypes) { if (nm.contains(s.name.toLowerCase())) { sub = s; break; } }
    final coverage = await InsuranceHomeScreen.getCoverageTypes(sub.id);
    if (coverage.isEmpty) return null;
    var cov = coverage.first;
    for (final c in coverage) { if (nm.contains(c.name.toLowerCase())) { cov = c; break; } }
    String? co;
    try {
      final all = await InsuranceHomeScreen.getCompanies();
      if (all.isNotEmpty) {
        co = all.firstWhere((c) => nm.contains(c.name.toLowerCase()), orElse: () => all.first).name;
      }
    } catch (_) {}
    return {'type': matched, 'subtype': sub, 'coverageType': cov, 'company': co};
  }

  // ── Full build() ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return kIsWeb
        ? LayoutBuilder(builder: (context, constraints) {
            final isDesktopWeb = constraints.maxWidth > 800;
            return Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              appBar: AppBar(
                title: Text('BIMA GUARDIAN',
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: _kCream, letterSpacing: 1.5)),
                backgroundColor: _kDarkTeal,
                foregroundColor: _kCream,
                elevation: 0,
                actions: isDesktopWeb ? [_buildNotificationButton(context)] : null,
                leading: isDesktopWeb ? null : Builder(builder: (ctx) =>
                    IconButton(icon: const Icon(Icons.menu, color: _kCream),
                        onPressed: () => Scaffold.of(ctx).openDrawer())),
              ),
              drawer: isDesktopWeb ? null : _buildDrawer(context),
              body: Row(children: [
                if (isDesktopWeb)
                  Container(
                    width: 260,
                    color: _isDark ? const Color(0xFF0C1A21) : Colors.white,
                    child: Column(children: [
                      const SizedBox(height: 12),
                      _buildNavItem(context, icon: Icons.home,             title: 'Home',            onTap: () => _onItemTapped(0), isSelected: _selectedIndex == 0),
                      _buildNavItem(context, icon: Icons.description,      title: 'Quotes',          onTap: () => _onItemTapped(1), isSelected: _selectedIndex == 1),
                      _buildNavItem(context, icon: Icons.hourglass_empty,  title: 'Upcoming',        onTap: () => _onItemTapped(2), isSelected: _selectedIndex == 2),
                      _buildNavItem(context, icon: Icons.account_circle,   title: 'My Account',      onTap: () => _onItemTapped(3), isSelected: _selectedIndex == 3),
                      _buildNavItem(context, icon: Icons.add_business,     title: 'Insurable Items', onTap: () => _onItemTapped(4), isSelected: _selectedIndex == 4),
                      if (userRole == UserRole.admin)
                        _buildNavItem(context, icon: Icons.admin_panel_settings, title: 'Admin Panel',
                            onTap: () => Navigator.pushNamed(context, '/admin')),
                    ]),
                  ),
                Expanded(child: _getSelectedScreen()),
                if (isDesktopWeb)
                  Container(
                    width: 260,
                    decoration: BoxDecoration(
                      color: _isDark ? const Color(0xFF0C1A21) : Colors.white,
                      border: Border(left: BorderSide(color: _border)),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: _buildSidebarContent(context),
                  ),
              ]),
              floatingActionButton: FloatingActionButton(
                onPressed: () => _showChatBottomSheet(context),
                backgroundColor: _kAcidOlive,
                foregroundColor: _kDarkTeal,
                elevation: 4,
                child: const Icon(Icons.chat_bubble_outline_rounded, size: 24),
              ),
            );
          })
        : Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: _getSelectedScreen(),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF0C1A21) : Colors.white,
                border: Border(top: BorderSide(color: _border)),
              ),
              child: BottomNavigationBar(
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home),            label: 'Home'),
                  BottomNavigationBarItem(icon: Icon(Icons.description),     label: 'Quotes'),
                  BottomNavigationBarItem(icon: Icon(Icons.hourglass_empty), label: 'Upcoming'),
                  BottomNavigationBarItem(icon: Icon(Icons.account_circle),  label: 'My Account'),
                  BottomNavigationBarItem(icon: Icon(Icons.add_business),    label: 'Items'),
                ],
                currentIndex: _selectedIndex ?? 0,
                onTap: _onItemTapped,
                selectedItemColor:   _isDark ? _kAcidOlive : _kDarkTeal,
                unselectedItemColor: _isDark ? const Color(0xFF4A6050) : const Color(0xFF8AAA80),
                backgroundColor:     Colors.transparent,
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                selectedLabelStyle:   GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 11),
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showChatBottomSheet(context),
              backgroundColor: _kAcidOlive,
              foregroundColor: _kDarkTeal,
              elevation: 4,
              child: const Icon(Icons.chat_bubble_outline_rounded, size: 24),
            ),
          );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: _isDark ? const Color(0xFF0C1A21) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(
          topRight: Radius.circular(20), bottomRight: Radius.circular(20))),
      child: SafeArea(child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: _kDarkTeal),
          child: Row(children: [
            const Text('🛡️', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Text('BIMA GUARDIAN',
                style: GoogleFonts.playfairDisplay(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _kCream)),
          ]),
        ),
        const SizedBox(height: 8),
        _buildNavItem(context, icon: Icons.home,             title: 'Home',            onTap: () { _onItemTapped(0); Navigator.pop(context); }),
        _buildNavItem(context, icon: Icons.description,      title: 'Quotes',          onTap: () { _onItemTapped(1); Navigator.pop(context); }),
        _buildNavItem(context, icon: Icons.hourglass_empty,  title: 'Upcoming',        onTap: () { _onItemTapped(2); Navigator.pop(context); }),
        _buildNavItem(context, icon: Icons.account_circle,   title: 'My Account',      onTap: () { _onItemTapped(3); Navigator.pop(context); }),
        _buildNavItem(context, icon: Icons.add_business,     title: 'Insurable Items', onTap: () { _onItemTapped(4); Navigator.pop(context); }),
        if (userRole == UserRole.admin)
          _buildNavItem(context, icon: Icons.admin_panel_settings, title: 'Admin Panel',
              onTap: () { Navigator.pushNamed(context, '/admin'); Navigator.pop(context); }),
        _buildNavItem(context, icon: Icons.notifications, title: 'Notifications',
            onTap: () { Navigator.push(context, MaterialPageRoute(
                builder: (_) => NotificationsScreen(notifications: notifications))); Navigator.pop(context); }),
      ])),
    );
  }

  // ── Payment dialogs ───────────────────────────────────────────────────────────

  /// Shows a payment dialog for [cover].
  ///
  /// Previously this used a hardcoded placeholder cover ID ('cover123')
  /// instead of the actual cover being paid for. Since this method wasn't
  /// being called from anywhere yet, we fix it forward by requiring a real
  /// [Cover] so any future caller is forced to supply the correct one.
  Future<void> showPaymentDialog(BuildContext context, Cover cover) async {
    String paymentMethod = 'mpesa';
    String phoneNumber   = '';
    String amount        = '';
    bool   autoBilling   = false;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Make a Payment',
              style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(child: Form(key: formKey, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Amount (KES)'),
                keyboardType: TextInputType.number,
                validator: (v) => double.tryParse(v ?? '') == null ? 'Enter a valid amount' : null,
                onSaved: (v) => amount = v!,
              ),
              const SizedBox(height: 16),
              Text('Payment Method', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _buildPaymentMethodCard(context, 'mpesa', 'M-Pesa', Icons.phone, Colors.green, paymentMethod, (v) => setState(() => paymentMethod = v!))),
                const SizedBox(width: 8),
                Expanded(child: _buildPaymentMethodCard(context, 'paystack', 'Paystack', Icons.credit_card, Colors.blue, paymentMethod, (v) => setState(() => paymentMethod = v!))),
              ]),
              if (paymentMethod == 'paystack') CheckboxListTile(
                title: Text('Enable Auto-Billing', style: GoogleFonts.dmSans(fontSize: 13)),
                value: autoBilling,
                onChanged: (v) => setState(() => autoBilling = v!),
                activeColor: _kAcidOlive,
                contentPadding: EdgeInsets.zero,
              ),
              if (paymentMethod == 'mpesa') TextFormField(
                decoration: const InputDecoration(labelText: 'Phone Number (254…)'),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.startsWith('254') && v.length == 12 ? null : 'Use format 254XXXXXXXXX',
                onSaved: (v) => phoneNumber = v!,
              ),
            ],
          ))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  final result = await _initializePayment(cover, amount, paymentMethod,
                      phoneNumber: phoneNumber, autoBilling: autoBilling, context: dialogContext);
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(result == 'completed' ? 'Payment successful' : 'Payment failed')));
                }
              },
              child: const Text('Pay'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard(BuildContext context, String value, String label,
      IconData icon, Color iconColor, String selectedValue, ValueChanged<String?> onTap) {
    final selected = selectedValue == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _kDarkTeal : _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _kAcidOlive : _border, width: selected ? 2 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: selected ? _kAcidOlive : iconColor, size: 28),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.dmSans(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: selected ? _kCream : _textPrimary)),
        ]),
      ),
    );
  }

  /// Initiates payment for [cover].
  ///
  /// Takes the full [Cover] (not just its id) so that, when auto-billing is
  /// requested, we can schedule it against the real cover's actual data
  /// instead of fabricating a near-empty placeholder Cover with blank
  /// name/company/policy fields and a hardcoded fake customer name.
  Future<String> _initializePayment(Cover cover, String amount, String paymentMethod,
      {String? phoneNumber, bool autoBilling = false, required BuildContext context}) async {
    try {
      final parsed = double.tryParse(amount);
      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount')));
        return 'failed';
      }
      if (paymentMethod == 'mpesa') {
        if (phoneNumber == null || !phoneNumber.startsWith('254') || phoneNumber.length != 12) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid phone number')));
          return 'failed';
        }
        return await _initiateMpesaPayment(phoneNumber, parsed) ? 'completed' : 'failed';
      } else if (paymentMethod == 'paystack') {
        final ok = await _initiatePaystackPayment(parsed, autoBilling);
        if (ok && autoBilling) {
          await _schedulePaystackAutoBilling(cover.copyWith(
            premium: parsed,
            billingFrequency: 'monthly',
            formData: {
              ...?cover.formData?.map((k, v) => MapEntry(k, v.toString())),
              'email': userDetails['email'] ?? cover.formData?['email'] ?? '',
              'name': userDetails['name'] ?? cover.formData?['name'] ?? cover.name,
            },
          ));
        }
        return ok ? 'completed' : 'failed';
      } else {
        final r = await http.post(Uri.parse('https://api.payment-gateway.com/v1/payments'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer your-payment-api-key'},
            body: jsonEncode({'coverId': cover.id, 'amount': parsed, 'currency': 'KES', 'description': 'Insurance cover payment'}));
        return r.statusCode == 200 ? 'completed' : 'failed';
      }
    } catch (e) {
      if (kDebugMode) print('Payment initialization error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment error: $e')));
      return 'failed';
    }
  }

  // ── Data loaders ──────────────────────────────────────────────────────────────

  Future<void> _loadCachedPdfTemplates() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('pdf_templates').get();
      if (snapshot.docs.isNotEmpty) {
        setState(() {
          cachedPdfTemplates = Map.fromEntries(
              snapshot.docs.map((d) => MapEntry(d.id, PDFTemplate.fromJson(d.data()))));
        });
      } else {
        final defaultTmpl = PDFTemplate(
          templateKey: 'default', policyType: 'motor', policySubtype: 'comprehensive',
          coordinates: {
            'name':  {'page': 1.0, 'x': 50.0, 'y': 50.0},
            'email': {'page': 1.0, 'x': 50.0, 'y': 70.0},
            'phone': {'page': 1.0, 'x': 50.0, 'y': 90.0},
          },
          fields: {
            'name':  FieldDefinition(expectedType: ExpectedType.name,  validator: (_) => null),
            'email': FieldDefinition(expectedType: ExpectedType.email, validator: (_) => null),
            'phone': FieldDefinition(expectedType: ExpectedType.phone, validator: (_) => null),
          },
          fieldMappings: {},
        );
        await FirebaseFirestore.instance.collection('pdf_templates').doc('default').set(defaultTmpl.toJson());
        setState(() => cachedPdfTemplates['default'] = defaultTmpl);
      }
    } catch (e) {
      if (kDebugMode) print('Error loading PDF templates: $e');
      setState(() => cachedPdfTemplates = {});
    }
  }

  Future<void> _loadUserDetails() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) { setState(() => userDetails = {}); return; }
      final cached = await _getCachedUserDetails(userId);
      if (cached.isNotEmpty) {
        setState(() => userDetails = cached);
        if (await _hasNetwork()) _fetchUserDetails(userId);
        return;
      }
      await _fetchUserDetails(userId);
    } catch (e) {
      if (kDebugMode) print('Error loading user details: $e');
      setState(() => userDetails = {});
    }
  }

  Future<void> _fetchUserDetails(String userId) async {
    if (!await _hasNetwork()) return;
    final docRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final doc = await retryOperation(() => docRef.get(const GetOptions(source: Source.server)), 3,
        delay: const Duration(seconds: 1))
        .timeout(const Duration(seconds: 15), onTimeout: () => throw Exception('Firestore timeout'));
    if (doc.exists && doc['details'] != null) {
      try {
        final detailsData = doc['details'];
        if (detailsData is String) { await _initializeUserDetails(userId); setState(() => userDetails = {}); return; }
        final details = Map<String, String>.from(detailsData as Map);
        await _cacheUserDetails(userId, details);
        setState(() => userDetails = details);
      } catch (e) {
        if (kDebugMode) print('Error parsing details: $e');
        await _initializeUserDetails(userId);
        setState(() => userDetails = {});
      }
    } else {
      await _initializeUserDetails(userId);
      setState(() => userDetails = {});
    }
  }

  Future<void> _initializeUserDetails(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId)
          .set({'details': {'name': 'Anonymous', 'email': ''}}, SetOptions(merge: true));
      // Previously called FirebaseFirestore.instance.clearPersistence() here.
      // clearPersistence() can only be called before any Firestore instance
      // has been used, or after it's been terminated — never mid-session,
      // which is the only time this function actually runs. It threw
      // [cloud_firestore/failed-precondition] every single time and served
      // no purpose for "initializing user details," so it's removed.
    } catch (e) {
      if (kDebugMode) print('Error initializing user details: $e');
    }
  }

  Future<bool> _hasNetwork() async {
    if (kIsWeb) return web.window.navigator.onLine ?? true;
    try {
      final r = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 2));
      return r.isNotEmpty && r[0].rawAddress.isNotEmpty;
    } catch (_) { return false; }
  }

  Future<void> _cacheUserDetails(String userId, Map<String, String> details) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_details_$userId', jsonEncode(details));
    } catch (e) { if (kDebugMode) print('Error caching user details: $e'); }
  }

  Future<Map<String, String>> _getCachedUserDetails(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('user_details_$userId');
      if (s != null) return Map<String, String>.from(jsonDecode(s));
    } catch (e) { if (kDebugMode) print('Error retrieving cached details: $e'); }
    return {};
  }

  // ── InsuredItem dialog & company dialog (unchanged logic) ─────────────────────

  Future<void> _showInsuredItemDialog(BuildContext context, PolicyType type,
      PolicySubtype subtype, CoverageType coverageType, {String? preSelectedCompany}) async {
    String? insuredItemId;
    bool createNew = insuredItems.isEmpty;
    String? tmplKey = preSelectedCompany != null
        ? companies.firstWhere((c) => c.name == preSelectedCompany,
            orElse: () => company_models.Company(id: '', name: '', pdfTemplateKey: []))
            .pdfTemplateKey.firstOrNull
        : null;

    final motorFields = _motorFields();
    final medicalFields = _medicalFields();
    final propertyFields = _propertyFields();
    final travelFields = _travelFields();
    final wibaFields = _wibaFields();

    Map<String, FieldDefinition> fields = {};
    if (tmplKey != null) {
      final pdfTmpl = await InsuranceHomeScreen.getPDFTemplate(tmplKey);
      if (pdfTmpl != null) fields = pdfTmpl.fields;
    }
    if (fields.isEmpty) {
      fields = {
        'motor': motorFields, 'medical': medicalFields, 'property': propertyFields,
        'travel': travelFields, 'wiba': wibaFields,
      }[type.name.toLowerCase()] ?? {};
    }
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Select or Create Insured Item',
              style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.w600)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!createNew)
              DropdownButtonFormField<String>(
                value: insuredItemId,
                decoration: const InputDecoration(labelText: 'Existing Insured Item'),
                items: insuredItems.map((item) => DropdownMenuItem(
                  value: item.id,
                  child: Text('${item.details['name'] ?? 'Item'} (${item.type.name.toUpperCase()})'),
                )).toList(),
                onChanged: (v) => setDialogState(() => insuredItemId = v),
              ),
            if (!createNew)
              CheckboxListTile(
                title: const Text('Create New Insured Item'),
                value: createNew,
                onChanged: (v) => setDialogState(() => createNew = v ?? false),
                activeColor: _kDarkTeal,
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                try {
                  final selectedInsuredItem = insuredItemId != null
                      ? insuredItems.where((i) => i.id == insuredItemId).firstOrNull
                      : null;
                  if (context.mounted) {
                    Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CoverDetailScreen(
                      type: type.name.toLowerCase(), subtype: subtype.name.toLowerCase(),
                      coverageType: coverageType.name.toLowerCase(),
                      insuredItem: selectedInsuredItem,
                      fields: fields,
                      onSubmit: (_) {},
                      onAutofillPreviousPolicy: autofillFromPreviousPolicy,
                      onAutofillLogbook: autofillFromLogbook,
                      showCompanyDialog: (ctx, t, s, c, details, {required String subtypeId,
                          required String coverageTypeId, String? preSelectedCompany}) =>
                          _showCompanyDialog(ctx, t, s, c, details,
                              subtypeId: subtypeId, coverageTypeId: coverageTypeId,
                              preSelectedCompany: preSelectedCompany),
                      preSelectedCompany: preSelectedCompany,
                    ),
                  ));
                  }
                } catch (e, st) {
                  if (kDebugMode) print('Error opening cover detail screen: $e\n$st');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Something went wrong opening this form. Please try again.')));
                  }
                }
              },
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCompanyDialog(BuildContext context, PolicyType type, PolicySubtype subtype,
      CoverageType coverageType, Map<String, String> details,
      {String? preSelectedCompany, required String subtypeId, required String coverageTypeId}) async {
    try {
      final companies = await InsuranceHomeScreen.getCompanies();
      final cached    = await InsuranceHomeScreen.getCachedPdfTemplates();
      final eligible  = companies.where((c) {
        return c.policySubtype?.id == subtypeId || c.coverageType?.id == coverageTypeId;
      }).toList();
      if (eligible.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No companies available.')));
        return;
      }
      String companyId = preSelectedCompany != null && eligible.any((c) => c.name == preSelectedCompany)
          ? eligible.firstWhere((c) => c.name == preSelectedCompany).id
          : eligible.first.id;
      String tmplKey = eligible.firstWhere((c) => c.id == companyId)
          .pdfTemplateKey.firstWhere((k) => cached.containsKey(k), orElse: () => 'default');

      showDialog(context: context, builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Select Insurance Company',
              style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.w600)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: companyId,
              decoration: const InputDecoration(labelText: 'Company'),
              items: eligible.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
              onChanged: (v) => setDS(() {
                companyId = v ?? companyId;
                final co = eligible.firstWhere((c) => c.id == companyId);
                tmplKey = co.pdfTemplateKey.firstWhere((k) => cached.containsKey(k), orElse: () => 'default');
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: tmplKey,
              decoration: const InputDecoration(labelText: 'PDF Template'),
              items: eligible.firstWhere((c) => c.id == companyId)
                  .pdfTemplateKey.where((k) => cached.containsKey(k))
                  .map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
              onChanged: (v) => setDS(() => tmplKey = v ?? tmplKey),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await FirebaseFirestore.instance.collection('form_submissions').add({
                  'user_id': details['insured_item_id'] ?? 'unknown',
                  'type': type.name, 'subtype': subtype.name, 'coverage_type': coverageType.name,
                  'company_id': companyId, 'pdf_template_key': tmplKey,
                  'details': details, 'timestamp': FieldValue.serverTimestamp(),
                });
                handleCoverSubmission(context, type, subtype, coverageType, companyId, tmplKey, details);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ));
    } catch (e, st) {
      if (kDebugMode) print('Error in _showCompanyDialog: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load company options.')));
    }
  }

  Future<void> showCompanyDialog(BuildContext context, String type, String subtype,
      String coverageType, Map<String, String> details,
      {String? preSelectedCompany, required String subtypeId, required String coverageTypeId,
       Map<String, String>? initialExtractedData, InsuredItem? insuredItem}) async {
    company_models.Company? selCo;
    Map<String, String>? extractedData;
    PDFTemplate? tmpl;
    if (preSelectedCompany != null) {
      final doc = await FirebaseFirestore.instance.collection('pdf_templates').doc(preSelectedCompany).get();
      tmpl = doc.exists ? PDFTemplate.fromJson(doc.data()!) : null;
    }
    await showDialog(context: context, builder: (context) => CompanySelectionDialog(
      previousCompany: preSelectedCompany ?? initialExtractedData?['insurer'],
      subtypeId: subtypeId, coverageTypeId: coverageTypeId,
      initialExtractedData: initialExtractedData,
      previousCompanies: insuredItem?.previousCompanies ?? [],
      onConfirm: (company, data) { selCo = company as company_models.Company?; extractedData = data; },
    ));
    if (selCo != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CoverDetailScreen(
        type: insuredItem?.type is String ? insuredItem?.type as String : insuredItem?.type.toString() ?? type,
        subtype: insuredItem?.subtype is PolicySubtype ? (insuredItem?.subtype as PolicySubtype).name : subtype,
        coverageType: (insuredItem?.coverageType ?? coverageType).toString(),
        insuredItem: insuredItem, onSubmit: (_) {},
        onAutofillPreviousPolicy: (f, d, c) {}, onAutofillLogbook: (f, d) {},
        fields: tmpl?.fields ?? {},
        showCompanyDialog: (ctx, t, s, c, d, {required String subtypeId, required String coverageTypeId, String? preSelectedCompany}) =>
            showCompanyDialog(ctx, t.name, s.name, c.name, d,
                subtypeId: subtypeId, coverageTypeId: coverageTypeId, preSelectedCompany: preSelectedCompany),
        preSelectedCompany: selCo?.id, extractedData: extractedData,
      )));
    }
  }

  void navigateToCoverDetailScreen(String type, String subtype, String coverageType,
      String subtypeId, String coverageTypeId) {
    showCompanyDialog(context, type, subtype, coverageType, {},
        subtypeId: subtypeId, coverageTypeId: coverageTypeId,
        initialExtractedData: _initialExtractedData, insuredItem: _selectedInsuredItem);
  }

  // ── OCR & autofill ────────────────────────────────────────────────────────────

  /// Extracts structured data from a photographed/scanned document using
  /// Gemini (the AI provider actually configured in this app — see
  /// GeminiService). This used to call OpenAI GPT-4o Vision directly with a
  /// hardcoded placeholder key that was never set, so this always silently
  /// returned null. It now matches the working implementation already used
  /// in cover_screen.dart's CompanySelectionDialog.
  Future<Map<String, String>?> _performOCR(File file) async {
    try {
      setState(() => _isOcrLoading = true);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      final rawText = await GeminiService.generateFromImage(
        prompt:
            'Extract the following fields from the provided document: name, email, phone, id_number, kra_pin, vehicle_value, regno, chassis_number, health_condition, travel_destination, employee_count, insurer. Return ONLY a JSON object.',
        base64Image: base64Image,
        maxOutputTokens: 300,
        jsonResponse: true,
      );

      final extracted = jsonDecode(GeminiService.cleanJsonText(rawText))
          as Map<String, dynamic>;
      return extracted.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      if (kDebugMode) print('OCR Error: $e');
      return null;
    } finally {
      if (mounted) setState(() => _isOcrLoading = false);
    }
  }

  Future<void> _uploadPreviousPolicy() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final data = await _performOCR(file);
      if (data != null && data.isNotEmpty) {
        setState(() { _initialExtractedData = data; _selectedInsuredItem = null; });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Previous policy data extracted.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data extracted from document.')));
      }
    }
  }

  Future<void> _autofillFromInsuredItem() async {
    setState(() => _isLoadingItems = true);
    try {
      await _loadInsuredItems();
      if (!mounted) return;
      if (insuredItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No insured items available.')));
        return;
      }
      final selected = await showDialog<InsuredItem>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Select Insured Item',
              style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
            children: insuredItems.map((item) => ListTile(
              leading: getCustomEmojiWidget(item.type.name),
              title: Text(item.details['name'] ?? 'Unknown', style: GoogleFonts.dmSans(fontSize: 14)),
              subtitle: Text(item.type.name, style: GoogleFonts.dmSans(fontSize: 12, color: _textMuted)),
              onTap: () => Navigator.pop(context, item),
            )).toList())),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
        ),
      );
      if (selected != null && mounted) {
        setState(() {
          _selectedInsuredItem   = selected;
          _initialExtractedData  = {...selected.details, if (selected.kraPin != null) 'kra_pin': selected.kraPin!};
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insured item data loaded.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load insured items.')));
      }
    } finally {
      setState(() => _isLoadingItems = false);
    }
  }

  // ── Field definition helpers ──────────────────────────────────────────────────

  Map<String, FieldDefinition> _motorFields() => {
    'name':           FieldDefinition(expectedType: ExpectedType.name,   validator: (v) => v!.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(v) ? null : 'Invalid name'),
    'email':          FieldDefinition(expectedType: ExpectedType.email,  validator: (v) => v!.isEmpty || RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(v) ? null : 'Invalid email'),
    'phone':          FieldDefinition(expectedType: ExpectedType.phone,  validator: (v) => v!.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(v) ? null : 'Invalid phone'),
    'chassis_number': FieldDefinition(expectedType: ExpectedType.text,   validator: (v) => v!.isEmpty || RegExp(r'^[A-Za-z0-9\-]{10,20}$').hasMatch(v) ? null : 'Invalid chassis number'),
    'kra_pin':        FieldDefinition(expectedType: ExpectedType.text,   validator: (v) => v!.isEmpty || RegExp(r'^[A-Za-z0-9]{11}$').hasMatch(v) ? null : 'Invalid KRA PIN'),
    'regno':          FieldDefinition(expectedType: ExpectedType.text,   validator: (v) => v!.isEmpty || RegExp(r'^[A-Za-z0-9\s\-]{5,10}$').hasMatch(v) ? null : 'Invalid reg number'),
    'vehicle_value':  FieldDefinition(expectedType: ExpectedType.number, validator: (v) { if (v!.isEmpty) return null; final n = double.tryParse(v); return n != null && n > 0 ? null : 'Invalid value'; }),
    'vehicle_type':   FieldDefinition(expectedType: ExpectedType.text,   validator: (v) => v!.isEmpty || ['private','commercial','motorcycle','psv'].contains(v) ? null : 'Invalid type'),
  };

  Map<String, FieldDefinition> _medicalFields() => {
    'name':  FieldDefinition(expectedType: ExpectedType.name,  validator: (v) => v!.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(v) ? null : 'Invalid name'),
    'email': FieldDefinition(expectedType: ExpectedType.email, validator: (v) => v!.isEmpty || RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(v) ? null : 'Invalid email'),
    'phone': FieldDefinition(expectedType: ExpectedType.phone, validator: (v) => v!.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(v) ? null : 'Invalid phone'),
    'age':   FieldDefinition(expectedType: ExpectedType.number, validator: (v) { if (v!.isEmpty) return null; final n = int.tryParse(v); return n != null && n >= 0 && n <= 120 ? null : 'Invalid age'; }),
    'beneficiaries': FieldDefinition(expectedType: ExpectedType.number, validator: (v) { if (v!.isEmpty) return null; final n = int.tryParse(v); return n != null && n >= 1 ? null : 'Min 1 beneficiary'; }),
    'inpatient_limit': FieldDefinition(expectedType: ExpectedType.text, validator: (v) => v!.isEmpty || ['100000','500000','1000000','2000000'].contains(v) ? null : 'Invalid limit'),
    'pre_existing_conditions': FieldDefinition(expectedType: ExpectedType.text, validator: (_) => null),
  };

  Map<String, FieldDefinition> _propertyFields() => {
    'name':              FieldDefinition(expectedType: ExpectedType.name,   validator: (v) => v!.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(v) ? null : 'Invalid name'),
    'email':             FieldDefinition(expectedType: ExpectedType.email,  validator: (v) => v!.isEmpty || RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(v) ? null : 'Invalid email'),
    'phone':             FieldDefinition(expectedType: ExpectedType.phone,  validator: (v) => v!.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(v) ? null : 'Invalid phone'),
    'property_value':    FieldDefinition(expectedType: ExpectedType.number, validator: (v) { if (v!.isEmpty) return null; final n = double.tryParse(v); return n != null && n > 0 ? null : 'Invalid value'; }),
    'property_type':     FieldDefinition(expectedType: ExpectedType.text,   validator: (v) => v!.isEmpty || ['residential','commercial','industrial','landlord'].contains(v) ? null : 'Invalid type'),
    'property_location': FieldDefinition(expectedType: ExpectedType.text,   validator: (v) => v!.isEmpty || RegExp(r'^[A-Za-z0-9\s\,\.\-]+$').hasMatch(v) ? null : 'Invalid location'),
    'deed_number':       FieldDefinition(expectedType: ExpectedType.text,   validator: (v) => v!.isEmpty || RegExp(r'^[A-Za-z0-9\-\/]{5,20}$').hasMatch(v) ? null : 'Invalid deed number'),
  };

  Map<String, FieldDefinition> _travelFields() => {
    'name':                FieldDefinition(expectedType: ExpectedType.name,   validator: (v) => v!.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(v) ? null : 'Invalid name'),
    'email':               FieldDefinition(expectedType: ExpectedType.email,  validator: (v) => v!.isEmpty || RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(v) ? null : 'Invalid email'),
    'phone':               FieldDefinition(expectedType: ExpectedType.phone,  validator: (v) => v!.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(v) ? null : 'Invalid phone'),
    'destination':         FieldDefinition(expectedType: ExpectedType.text,   validator: (v) => v!.isEmpty || RegExp(r'^[A-Za-z\s\,\-]+$').hasMatch(v) ? null : 'Invalid destination'),
    'number_of_travelers': FieldDefinition(expectedType: ExpectedType.number, validator: (v) { if (v!.isEmpty) return null; final n = int.tryParse(v); return n != null && n >= 1 ? null : 'Min 1 traveler'; }),
    'coverage_limit':      FieldDefinition(expectedType: ExpectedType.number, validator: (v) { if (v!.isEmpty) return null; final n = double.tryParse(v); return n != null && n >= 0 ? null : 'Invalid limit'; }),
  };

  Map<String, FieldDefinition> _wibaFields() => {
    'name':               FieldDefinition(expectedType: ExpectedType.name,   validator: (v) => v!.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(v) ? null : 'Invalid name'),
    'email':              FieldDefinition(expectedType: ExpectedType.email,  validator: (v) => v!.isEmpty || RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(v) ? null : 'Invalid email'),
    'phone':              FieldDefinition(expectedType: ExpectedType.phone,  validator: (v) => v!.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(v) ? null : 'Invalid phone'),
    'business_name':      FieldDefinition(expectedType: ExpectedType.text,   validator: (v) => v!.isEmpty || RegExp(r'^[A-Za-z0-9\s\-\.]+$').hasMatch(v) ? null : 'Invalid name'),
    'number_of_employees': FieldDefinition(expectedType: ExpectedType.number, validator: (v) { if (v!.isEmpty) return null; final n = int.tryParse(v); return n != null && n >= 1 ? null : 'Min 1 employee'; }),
    'coverage_limit':     FieldDefinition(expectedType: ExpectedType.number, validator: (v) { if (v!.isEmpty) return null; final n = double.tryParse(v); return n != null && n >= 0 ? null : 'Invalid limit'; }),
    'industry_type':      FieldDefinition(expectedType: ExpectedType.text,   validator: (v) => v!.isEmpty || ['construction','manufacturing','services','retail'].contains(v) ? null : 'Invalid industry'),
  };

  Future<File?> _generateFallbackPdf(String type, String subtype, Map<String, String> details) async {
    try {
      final pdfDoc = pw.Document();
      pdfDoc.addPage(pw.Page(build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Insurance Cover Details', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Text('Type: ${type.toUpperCase()}'),
          pw.Text('Subtype: ${subtype.replaceAll('_', ' ').toUpperCase()}'),
          pw.SizedBox(height: 20),
          pw.Text('Form Data:', style: pw.TextStyle(fontSize: 16)),
          ...details.entries.map((e) => pw.Text('${e.key}: ${e.value}')),
        ],
      )));
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/fallback_cover_${const Uuid().v4()}.pdf');
      await file.writeAsBytes(await pdfDoc.save());
      return file;
    } catch (e) {
      if (kDebugMode) print('Error generating fallback PDF: $e');
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting classes (ColorProvider, DialogState, ConfigCache, etc.)
// ─────────────────────────────────────────────────────────────────────────────

class CompaniesCarousel {
  final List<company_models.Company> companies;
  final Function(company_models.Company) onCompanySelected;
  final double itemWidth;
  CompaniesCarousel({required this.companies, required this.onCompanySelected, this.itemWidth = 150.0});
  Widget build(BuildContext context) {
    return SizedBox(height: 200, child: ListView.builder(
      scrollDirection: Axis.horizontal, itemCount: companies.length,
      itemBuilder: (context, index) {
        final company = companies[index];
        return GestureDetector(
          onTap: () => onCompanySelected(company),
          child: Container(
            width: itemWidth,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircleAvatar(radius: 40, backgroundImage: NetworkImage(company.logoUrl ?? 'https://via.placeholder.com/80')),
              const SizedBox(height: 8),
              Text(company.name, style: GoogleFonts.playfairDisplay(
                  fontSize: 14, fontWeight: FontWeight.w600, color: _kDarkTeal), textAlign: TextAlign.center),
            ]),
          ),
        );
      },
    ));
  }
}

class ColorProvider with ChangeNotifier {
  static const Color blueGreen = Color(0xFF26A69A);
  static const Color orange    = Color(0xFFFFA726);
  Color _color = _kDarkTeal;
  Color get color => _color;
  void setColor(Color color) { _color = color; notifyListeners(); }
}

class DialogState extends ChangeNotifier {
  final Map<String, String> _responses = {};
  String _currentType = '';
  int    _currentStep = 0;
  String? _insuredItemId;
  String? _companyId;

  Map<String, String> get responses    => _responses;
  String              get currentType  => _currentType;
  int                 get currentStep  => _currentStep;
  String?             get insuredItemId => _insuredItemId;
  String?             get companyId    => _companyId;

  void updateResponse(String key, String value) { _responses[key] = value; notifyListeners(); }
  void setCurrentType(String type)  { _currentType = type.toLowerCase(); notifyListeners(); }
  void setCurrentStep(int step)     { _currentStep = step; notifyListeners(); }
  void setInsuredItemId(String? id) { _insuredItemId = id; notifyListeners(); }
  void setCompanyId(String? id)     { _companyId = id; notifyListeners(); }

  void resetForNewCycle({bool clearResponses = true}) {
    if (clearResponses) _responses.clear();
    _currentStep = 0; _insuredItemId = null; _companyId = null;
    notifyListeners();
  }

  void saveProgress(String type, int step) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dialog_progress_$type', jsonEncode({
        'step': step, 'responses': _responses,
        'insuredItemId': _insuredItemId, 'companyId': _companyId,
      }));
    } catch (e) { if (kDebugMode) print('Error saving progress: $e'); }
  }

  Future<void> loadProgress(String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('dialog_progress_$type');
      if (s != null) {
        final data = jsonDecode(s);
        _currentStep = data['step'] ?? 0;
        _responses.clear();
        _responses.addAll(Map<String, String>.from(data['responses'] ?? {}));
        _insuredItemId = data['insuredItemId'];
        _companyId     = data['companyId'];
        notifyListeners();
      }
    } catch (e) { if (kDebugMode) print('Error loading progress: $e'); }
  }

  Future<void> clearProgress(String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('dialog_progress_$type');
    } catch (e) { if (kDebugMode) print('Error clearing progress: $e'); }
  }
}

Future<T> retryOperation<T>(Future<T> Function() operation, int maxAttempts,
    {Duration delay = const Duration(seconds: 1)}) async {
  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try { return await operation(); }
    catch (e) {
      if (attempt == maxAttempts) rethrow;
      if (kDebugMode) print('Attempt $attempt failed: $e');
      await Future.delayed(delay);
    }
  }
  throw Exception('Operation failed after $maxAttempts attempts');
}

extension StringExtension on String {
  String capitalize() => isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : this;
}

// ── ConfigCache, FieldConfig, DialogStepConfig, GenericInsuranceDialog,
//    DynamicForm, GridFieldWidget, FormFieldWidget — all unchanged from
//    the original; paste them verbatim after this point. ─────────────────────

final logger = Logger();

Future<void> authenticateUser() async {
  try {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
      if (kDebugMode) print('Signed in anonymously: ${auth.currentUser?.uid}');
    }
  } catch (e, st) {
    if (kDebugMode) print('Authentication failed: $e\n$st');
    throw Exception('Authentication failed');
  }
}

Map<String, List<DialogStepConfig>> _defaultConfigs(String normalizedType) {
  return {
    normalizedType: [
      DialogStepConfig(
        title: 'Select ${normalizedType.replaceAll('_', ' ').toUpperCase()} Options',
        fields: [
          FieldConfig(key: 'company', label: 'Insurance Company', type: 'dropdown',
              options: ['AIG', 'Cigna', 'UnitedHealth'],
              validator: (v) => v?.isNotEmpty == true ? null : 'Please select a company'),
          FieldConfig(key: 'subtype', label: 'Policy Subtype', type: 'dropdown',
              options: ['Standard', 'Premium'],
              validator: (v) => v?.isNotEmpty == true ? null : 'Please select a subtype'),
        ],
        nextStep: 'coverage',
        customCallback: (context, dialogState) async {},
      ),
      DialogStepConfig(
        title: 'Select Coverage Type',
        fields: [FieldConfig(key: 'coverage', label: 'Coverage Type', type: 'dropdown',
            options: ['Basic', 'Comprehensive'],
            validator: (v) => v?.isNotEmpty == true ? null : 'Please select a coverage type')],
        nextStep: 'details',
      ),
      DialogStepConfig(
        title: 'Personal Details',
        fields: [
          FieldConfig(key: 'name',  label: 'Full Name',      validator: (v) => v?.isNotEmpty == true ? null : 'Name is required'),
          FieldConfig(key: 'email', label: 'Email Address',  keyboardType: TextInputType.emailAddress,
              validator: (v) => v?.isNotEmpty == true && RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(v!) ? null : 'Valid email required'),
        ],
        nextStep: 'summary',
      ),
      DialogStepConfig(
        title: 'Summary',
        fields: [],
        customCallback: (context, dialogState) async {
          final missing = ['company', 'subtype', 'coverage', 'name', 'email']
              .where((k) => (dialogState.responses[k] ?? '').isEmpty).toList();
          if (missing.isNotEmpty && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please complete all required fields'), backgroundColor: Colors.red));
          }
        },
      ),
    ],
  };
}

Future<Map<String, List<DialogStepConfig>>> fetchConfigs(String normalizedType) async {
  final op = CancelableOperation.fromFuture(
    ConfigCache().getInsuranceConfigs(normalizedType).timeout(const Duration(seconds: 8),
        onTimeout: () => _defaultConfigs(normalizedType)),
  );
  return await op.valueOrCancellation(_defaultConfigs(normalizedType)) ?? _defaultConfigs(normalizedType);
}

Future<void> showInsuranceDialog(BuildContext context, String insuranceType,
    {int step = 0, void Function(BuildContext, String, String, String, String?)? onFinalSubmit,
     required GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
     Map<String, String>? initialResponses}) async {
  if (kDebugMode) print('[wizard] showInsuranceDialog called: type=$insuranceType step=$step');
  if (!context.mounted) {
    if (kDebugMode) print('[wizard] showInsuranceDialog: context not mounted, returning early');
    return;
  }
  final normalizedType = insuranceType.toLowerCase();
  final dialogState    = Provider.of<DialogState>(context, listen: false);
  try {
    await authenticateUser();
    if (kDebugMode) print('[wizard] showInsuranceDialog: authenticateUser done');
    dialogState.setCurrentType(normalizedType);
    if (step == 0) {
      await dialogState.clearProgress(normalizedType);
      dialogState.resetForNewCycle();
      initialResponses?.forEach(dialogState.updateResponse);
    } else {
      await dialogState.loadProgress(normalizedType);
      if (kDebugMode) print('[wizard] showInsuranceDialog: loadProgress done, dialogState.currentStep=${dialogState.currentStep}');
    }
    int currentStep = step == 0 ? 0 : dialogState.currentStep;
    dialogState.setCurrentStep(currentStep);
    if (kDebugMode) print('[wizard] showInsuranceDialog: resolved currentStep=$currentStep (param step was $step)');
    final configs = await fetchConfigs(normalizedType);
    if (kDebugMode) print('[wizard] showInsuranceDialog: fetchConfigs done, found ${configs[normalizedType]?.length ?? 0} steps');
    if (!context.mounted) {
      if (kDebugMode) print('[wizard] showInsuranceDialog: context unmounted after fetchConfigs, returning early');
      scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(
          content: Text('Something interrupted the form. Please try again.')));
      return;
    }
    if (!configs.containsKey(normalizedType) || configs[normalizedType]!.isEmpty) {
      scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Invalid insurance type: $normalizedType')));
      return;
    }
    final configList = configs[normalizedType]!;
    if (currentStep >= configList.length) {
      dialogState.setCurrentStep(0); currentStep = 0;
      await dialogState.clearProgress(normalizedType);
    }
    final config = configList[currentStep];
    if (kDebugMode) print('[wizard] showInsuranceDialog: about to showDialog for step $currentStep ("${config.title}")');
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async { dialogState.saveProgress(normalizedType, currentStep); return true; },
        child: GenericInsuranceDialog(
          insuranceType: normalizedType, step: currentStep,
          config: config, dialogState: dialogState, scaffoldMessengerKey: scaffoldMessengerKey,
          onCancel: () => showDialog(context: dialogContext, builder: (ctx) => AlertDialog(
            title: const Text('Discard Progress?'),
            content: const Text('Are you sure you want to discard your progress?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Stay')),
              TextButton(onPressed: () {
                dialogState.clearProgress(normalizedType);
                dialogState.resetForNewCycle();
                Navigator.pop(ctx); Navigator.pop(dialogContext);
              }, child: const Text('Discard')),
            ],
          )),
          onBack: currentStep > 0 ? () async {
            if (kDebugMode) print('[wizard] onBack: step $currentStep -> ${currentStep - 1}');
            dialogState.saveProgress(normalizedType, currentStep);
            Navigator.of(dialogContext).pop();
            if (context.mounted) {
              showInsuranceDialog(context, normalizedType, step: currentStep - 1,
                onFinalSubmit: onFinalSubmit, scaffoldMessengerKey: scaffoldMessengerKey);
            }
          } : null,
          onSubmit: () async {
            if (kDebugMode) print('[wizard] onSubmit: step $currentStep, configList.length=${configList.length}');
            // Previously `saveProgress` was fired without awaiting it, then
            // the recursive showInsuranceDialog call below immediately tried
            // to read the step back via loadProgress(). That's a race: if
            // the read won, currentStep got reset to the stale saved value,
            // which could make the wizard appear to loop back / "freeze" on
            // the same step instead of advancing. Now awaited properly.
            if (config.nextStep != null || currentStep + 1 < configList.length) {
              dialogState.saveProgress(normalizedType, currentStep + 1);
            }
            if (kDebugMode) print('[wizard] onSubmit: progress saved, popping dialog');
            Navigator.of(dialogContext).pop();
            if (currentStep + 1 < configList.length) {
              if (kDebugMode) print('[wizard] onSubmit: advancing to step ${currentStep + 1}');
              if (context.mounted) {
                await showInsuranceDialog(context, normalizedType, step: currentStep + 1,
                    onFinalSubmit: onFinalSubmit, scaffoldMessengerKey: scaffoldMessengerKey);
              } else {
                // Don't fail silently: scaffoldMessengerKey is independent
                // of `context`, so it can still notify the user even if the
                // context we were holding has been unmounted.
                if (kDebugMode) print('[wizard] onSubmit: context unmounted, cannot advance to step ${currentStep + 1}');
                scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(
                    content: Text('Something interrupted the form. Please start again.')));
              }
              if (kDebugMode) print('[wizard] onSubmit: showInsuranceDialog for next step returned');
            } else {
              if (kDebugMode) print('[wizard] onSubmit: final step reached, looking up policy/coverage');
              final subtype  = dialogState.responses['subtype']?.toString();
              final coverage = dialogState.responses['coverage_type']?.toString();
              if (kDebugMode) print('[wizard] onSubmit: subtype=$subtype coverage=$coverage');
              if (subtype != null && coverage != null && subtype.isNotEmpty && coverage.isNotEmpty) {
                try {
                  if (kDebugMode) print('[wizard] onSubmit: fetching policy types...');
                  final types    = await InsuranceHomeScreen.getPolicyTypes();
                  if (kDebugMode) print('[wizard] onSubmit: got ${types.length} policy types');
                  final pType    = types.firstWhere((t) => t.name.toLowerCase() == normalizedType,
                      orElse: () => PolicyType(id: '1', name: normalizedType, description: ''));
                  final subtypes = await InsuranceHomeScreen.getPolicySubtypes(pType.id);
                  final subtypeObj = subtypes.firstWhere((s) => s.name == subtype,
                      orElse: () => PolicySubtype(id: '1', name: subtype, policyTypeId: pType.id, description: ''));
                  final coverageTypes = await InsuranceHomeScreen.getCoverageTypes(subtypeObj.id);
                  final covType = coverageTypes.firstWhere((c) => c.name == coverage,
                      orElse: () => CoverageType(id: '1', name: coverage, description: ''));
                  if (!context.mounted) return;
                  String? selectedCompany;
                  await showDialog(context: context, builder: (ctx) => CompanySelectionDialog(
                    previousCompany: null, subtypeId: subtypeObj.id, coverageTypeId: covType.id,
                    onConfirm: (company, _) { selectedCompany = company; Navigator.pop(ctx); },
                  ));
                  if (!context.mounted) return;
                  if (selectedCompany != null) {
                    final state = context.findAncestorStateOfType<InsuranceHomeScreenState>();
                    if (state != null) {
                      await state._showInsuredItemDialog(
                        context, pType, subtypeObj, covType, preSelectedCompany: selectedCompany);
                    }
                    dialogState.clearProgress(normalizedType);
                    dialogState.resetForNewCycle();
                    onFinalSubmit?.call(dialogContext, normalizedType, subtype, coverage, selectedCompany);
                  } else {
                    scaffoldMessengerKey.currentState?.showSnackBar(
                        const SnackBar(content: Text('Please select an insurance company')));
                  }
                } catch (e, st) {
                  if (kDebugMode) print('Error processing final step: $e\n$st');
                  scaffoldMessengerKey.currentState?.showSnackBar(
                      const SnackBar(content: Text('Failed to process insurance options')));
                }
              } else {
                scaffoldMessengerKey.currentState?.showSnackBar(
                    const SnackBar(content: Text('Please complete all required fields')));
              }
            }
          },
          onFinalSubmit: onFinalSubmit,
          showInsuredItemDialog: (ctx, pType, sub, cov, {String? preSelectedCompany}) async {
            final state = ctx.findAncestorStateOfType<InsuranceHomeScreenState>();
            if (state != null && ctx.mounted) {
              await state._showInsuredItemDialog(ctx, pType, sub, cov, preSelectedCompany: preSelectedCompany);
            }
          },
        ),
      ),
    );
  } catch (e, st) {
    if (kDebugMode) print('Error in showInsuranceDialog: $e\n$st');
    scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Failed to display insurance options')));
  }
}

void _showCompletionDialog(BuildContext context, String type, Policy policy,
    String? pdfTemplateKey, void Function(BuildContext, String, String, String, String?)? onFinalSubmit) {
  final dialogState  = context.read<DialogState>();
  final colorProvider = context.watch<ColorProvider>();
  final company = dialogState.responses['company'] ?? '';
  showDialog(context: context, builder: (dialogContext) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: Text('Submission Complete',
        style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w600, color: _kDarkTeal)),
    content: Text('Policy created for ${policy.type.name}. Start a new submission?',
        style: GoogleFonts.dmSans(fontSize: 14, color: _kDarkTeal)),
    actions: [
      TextButton(onPressed: () {
        Navigator.pop(dialogContext);
        onFinalSubmit?.call(context, policy.type.name, policy.subtype!.name, policy.coverageType!.name, company);
      }, child: const Text('Close')),
      ElevatedButton(onPressed: () {
        dialogState.resetForNewCycle();
        Navigator.pop(dialogContext);
        showInsuranceDialog(context, type, step: 0, onFinalSubmit: onFinalSubmit,
            scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>());
      }, child: const Text('New Submission')),
    ],
  ));
}

// ── ConfigCache ───────────────────────────────────────────────────────────────
class ConfigCache {
  static final ConfigCache _instance = ConfigCache._();
  factory ConfigCache() => _instance;
  ConfigCache._();
  final Map<String, Map<String, List<DialogStepConfig>>> _cache = {};

  Future<bool> _isCacheStale(String typeName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt('cache_timestamp_$typeName') ?? 0;
      return DateTime.now().millisecondsSinceEpoch - ts > const Duration(hours: 1).inMilliseconds;
    } catch (e) { return true; }
  }

  Future<bool> _isCacheValid(String typeName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt('cache_timestamp_$typeName') ?? 0;
      return DateTime.now().millisecondsSinceEpoch - ts < const Duration(hours: 1).inMilliseconds;
    } catch (e) { return false; }
  }

  Future<bool> hasNetwork() async {
    if (kIsWeb) return true;
    try {
      final r = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 2));
      return r.isNotEmpty && r[0].rawAddress.isNotEmpty;
    } catch (_) { return false; }
  }

  Future<T> retryOperation<T>(Future<T> Function() op, int max, {Duration delay = const Duration(seconds: 1)}) async {
    for (int i = 1; i <= max; i++) {
      try { return await op(); }
      catch (e) { if (i == max) rethrow; await Future.delayed(delay); }
    }
    throw Exception('Failed after $max attempts');
  }

  Future<Map<String, List<DialogStepConfig>>> getInsuranceConfigs(String type) async {
    final nt = type.toLowerCase();
    if (await _isCacheValid(nt)) {
      final cached = await _getCachedConfigs(nt);
      if (cached.isNotEmpty && _isValidConfigs(cached)) {
        if (await hasNetwork()) {
          unawaited(_fetchAndCacheConfigs(nt).catchError((e) => logger.e('BG fetch failed: $e')));
        }
        return {nt: cached};
      }
    }
    if (!await hasNetwork()) return _defaultConfigs(nt);
    return await _fetchAndCacheConfigs(nt);
  }

  Future<Map<String, List<DialogStepConfig>>> _fetchAndCacheConfigs(String nt) async {
    final configs = <String, List<DialogStepConfig>>{};
    try {
      final cached = await _loadCachedConfigs(nt);
      if (cached != null && _isValidConfigs(cached) && !await _isCacheStale(nt)) {
        configs[nt] = cached; return configs;
      }
      await clearCachedConfigs(nt);
      final policyTypes = await retryOperation(InsuranceHomeScreen.getPolicyTypes, 3,
          delay: const Duration(seconds: 1))
          .timeout(const Duration(seconds: 8), onTimeout: () => [PolicyType(id: '1', name: nt, description: '')]);
      bool found = false;
      for (final pt in policyTypes) {
        if (pt.name.toLowerCase() != nt) continue;
        found = true;
        final subtypes = await retryOperation(() => InsuranceHomeScreen.getPolicySubtypes(pt.id), 3)
            .timeout(const Duration(seconds: 5), onTimeout: () => [
              PolicySubtype(id: '1', name: 'Standard', policyTypeId: pt.id, description: '', icon: '⭐'),
              PolicySubtype(id: '2', name: 'Premium',  policyTypeId: pt.id, description: '', icon: '💎'),
            ]);
        final coverageTypes = <CoverageType>[];
        for (final s in subtypes) {
          final types = await retryOperation(() => InsuranceHomeScreen.getCoverageTypes(s.id), 3)
              .timeout(const Duration(seconds: 5), onTimeout: () => [
                CoverageType(id: '1', name: 'Basic',        description: '', icon: '🛡️'),
                CoverageType(id: '2', name: 'Comprehensive', description: '', icon: '🔒'),
              ]);
          coverageTypes.addAll(types.where((t) => !coverageTypes.any((e) => e.name == t.name)));
        }
        configs[nt] = [
          DialogStepConfig(
            title: 'Select ${pt.name} Options',
            fields: [
              FieldConfig(key: 'subtype', label: '${pt.name} Subtype', type: 'grid',
                  options: subtypes.map((s) => s.name).toSet().toList(),
                  icons:   subtypes.map((s) => s.icon ?? '❓').toList(),
                  isRequired: true,
                  validator: (v) => v?.isNotEmpty == true ? null : 'Please select a subtype'),
              FieldConfig(key: 'coverage_type', label: 'Coverage Type', type: 'grid',
                  options: coverageTypes.map((c) => c.name).toSet().toList(),
                  icons:   coverageTypes.map((c) => c.icon ?? '❓').toList(),
                  isRequired: true,
                  validator: (v) => v?.isNotEmpty == true ? null : 'Please select a coverage type'),
            ],
            nextStep: 'summary',
          ),
          DialogStepConfig(
            title: 'Summary',
            fields: [
              FieldConfig(key: 'subtype_summary',  label: 'Selected Subtype',        type: 'text', isRequired: false, validator: null),
              FieldConfig(key: 'coverage_summary', label: 'Selected Coverage Type',  type: 'text', isRequired: false, validator: null),
            ],
            customCallback: (context, ds) async {
              if ((ds.responses['subtype'] ?? '').isEmpty || (ds.responses['coverage_type'] ?? '').isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please complete all required fields'), backgroundColor: Colors.red));
              }
            },
          ),
        ];
        if (_isValidConfigs(configs[nt]!)) await _cacheConfigs(nt, configs[nt]!);
      }
      if (!found) { configs[nt] = _defaultConfigs(nt)[nt]!; await _cacheConfigs(nt, configs[nt]!); }
    } catch (e, st) {
      if (kDebugMode) print('Error fetching configs for $nt: $e\n$st');
      configs[nt] = _defaultConfigs(nt)[nt]!;
      await _cacheConfigs(nt, configs[nt]!);
    }
    return configs;
  }

  Future<List<DialogStepConfig>?> _loadCachedConfigs(String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('insurance_configs_$type');
      if (s != null) return (jsonDecode(s) as List).map((j) => DialogStepConfig.fromJson(j)).toList();
    } catch (e) { if (kDebugMode) print('Error loading cached configs: $e'); }
    return null;
  }

  Future<List<DialogStepConfig>> _getCachedConfigs(String typeName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list  = prefs.getStringList('configs_$typeName') ?? [];
      return list.map((j) => DialogStepConfig.fromJson(jsonDecode(j))).toList();
    } catch (e) { return []; }
  }

  Future<void> _cacheConfigs(String typeName, List<DialogStepConfig> configs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('configs_$typeName', configs.map((c) => jsonEncode(c.toJson())).toList());
      await prefs.setInt('cache_timestamp_$typeName', DateTime.now().millisecondsSinceEpoch);
    } catch (e) { logger.e('Error caching configs: $e'); }
  }

  Future<void> clearCachedConfigs(String typeName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('configs_$typeName');
      _cache.remove(typeName);
    } catch (e) { if (kDebugMode) print('Error clearing cached configs: $e'); }
  }

  bool _isValidConfigs(List<DialogStepConfig> configs) =>
      configs.isNotEmpty && configs.every((c) => c.title.isNotEmpty);
}

// ── FieldConfig ───────────────────────────────────────────────────────────────
class FieldConfig {
  final String key;
  final String label;
  final TextInputType? keyboardType;
  final bool isRequired;
  final String? Function(String?)? validator;
  final String type;
  final List<String>? icons;
  final List<String>? options;
  final String? initialValue;
  final String? dependsOnKey;
  final String? dependsOnValue;
  final bool? isMultiSelect;

  FieldConfig({required this.key, required this.label, this.keyboardType, this.isRequired = true,
      this.validator, this.type = 'text', this.icons, this.options, this.initialValue,
      this.dependsOnKey, this.dependsOnValue, this.isMultiSelect});

  Map<String, dynamic> toJson() => {
    'key': key, 'label': label, 'isRequired': isRequired, 'type': type,
    'options': options, 'initialValue': initialValue, 'dependsOnKey': dependsOnKey,
    'dependsOnValue': dependsOnValue, 'isMultiSelect': isMultiSelect,
  };

  factory FieldConfig.fromJson(Map<String, dynamic> json) => FieldConfig(
    key: json['key'], label: json['label'], isRequired: json['isRequired'] ?? true,
    type: json['type'] ?? 'text', options: (json['options'] as List<dynamic>?)?.cast<String>(),
    initialValue: json['initialValue'], dependsOnKey: json['dependsOnKey'],
    dependsOnValue: json['dependsOnValue'], isMultiSelect: json['isMultiSelect'],
  );
}

// ── DialogStepConfig ──────────────────────────────────────────────────────────
class DialogStepConfig {
  final String title;
  final List<FieldConfig> fields;
  final String? nextStep;
  final bool Function(Map<String, String>)? customValidator;
  final String? pdfTemplateKeySource;
  final dynamic customCallback;

  DialogStepConfig({required this.title, required this.fields, this.nextStep,
      this.customValidator, this.pdfTemplateKeySource, this.customCallback});

  factory DialogStepConfig.fromJson(Map<String, dynamic> json) => DialogStepConfig(
    title: json['title'] as String,
    fields: (json['fields'] as List<dynamic>? ?? []).map((f) => FieldConfig(
      key: f['key'] ?? '', label: f['label'] ?? '', type: f['type'] ?? 'text',
      options: (f['options'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      isRequired: f['isRequired'] ?? true, initialValue: f['initialValue'],
      dependsOnKey: f['dependsOnKey'], dependsOnValue: f['dependsOnValue'],
    )).toList(),
    nextStep: json['nextStep'],
    pdfTemplateKeySource: json['pdfTemplateKeySource'],
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'fields': fields.map((f) => {'key': f.key, 'label': f.label, 'type': f.type,
        'options': f.options, 'isRequired': f.isRequired, 'initialValue': f.initialValue,
        'dependsOnKey': f.dependsOnKey, 'dependsOnValue': f.dependsOnValue}).toList(),
    'nextStep': nextStep, 'pdfTemplateKeySource': pdfTemplateKeySource,
  };
}

// ── GenericInsuranceDialog ────────────────────────────────────────────────────
class GenericInsuranceDialog extends StatefulWidget {
  final String insuranceType;
  final int step;
  final DialogStepConfig config;
  final DialogState dialogState;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  final VoidCallback onCancel;
  final VoidCallback? onBack;
  final VoidCallback onSubmit;
  final void Function(BuildContext, String, String, String, String?)? onFinalSubmit;
  final Future<void> Function(BuildContext, PolicyType, PolicySubtype, CoverageType, {String? preSelectedCompany}) showInsuredItemDialog;

  const GenericInsuranceDialog({
    super.key, required this.insuranceType, required this.step,
    required this.config, required this.dialogState, required this.scaffoldMessengerKey,
    required this.onCancel, this.onBack, required this.onSubmit, this.onFinalSubmit,
    required this.showInsuredItemDialog,
  });

  @override
  State<GenericInsuranceDialog> createState() => _GenericInsuranceDialogState();
}

class _GenericInsuranceDialogState extends State<GenericInsuranceDialog> {
  late final Future<List<FieldConfig>> _fieldsFuture;

  @override
  void initState() {
    super.initState();
    _fieldsFuture = _getFields();
    if (widget.config.customCallback != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.config.customCallback!(context, widget.dialogState);
      });
    }
  }

  Future<List<FieldConfig>> _getFields() async {
    final fields = <FieldConfig>[];
    for (var field in widget.config.fields) {
      if (field.type == 'dropdown' && (field.key == 'subtype' || field.key == 'coverage_type')) {
        List<Map<String, String>> optsWithIcons = [];
        if (field.key == 'subtype') {
          final types = await InsuranceHomeScreen.getPolicyTypes();
          final pt    = types.firstWhere((t) => t.name.toLowerCase() == widget.insuranceType.toLowerCase(),
              orElse: () => PolicyType(id: '1', name: widget.insuranceType, description: ''));
          final subs  = await InsuranceHomeScreen.getPolicySubtypes(pt.id);
          optsWithIcons = subs.map((s) => {'name': s.name, 'icon': s.icon ?? '❓'}).toList();
        } else if (field.key == 'coverage_type') {
          if (widget.dialogState.responses['subtype'] == null) continue;
          final types   = await InsuranceHomeScreen.getPolicyTypes();
          final pt      = types.firstWhere((t) => t.name.toLowerCase() == widget.insuranceType.toLowerCase(),
              orElse: () => PolicyType(id: '1', name: widget.insuranceType, description: ''));
          final subs    = await InsuranceHomeScreen.getPolicySubtypes(pt.id);
          final subtype = subs.firstWhere((s) => s.name == (widget.dialogState.responses['subtype'] ?? 'Standard'),
              orElse: () => PolicySubtype(id: '1', name: 'Standard', policyTypeId: pt.id, description: ''));
          final covTypes = await InsuranceHomeScreen.getCoverageTypes(subtype.id);
          optsWithIcons = covTypes.map((c) => {'name': c.name, 'icon': c.icon ?? '❓'}).toList();
        }
        if (optsWithIcons.isNotEmpty) {
          fields.add(FieldConfig(
            key: field.key, label: field.label, type: 'grid',
            options: optsWithIcons.map((o) => o['name']!).toList(),
            icons:   optsWithIcons.map((o) => o['icon']!).toList(),
            isRequired: field.isRequired, validator: field.validator,
          ));
        }
      } else if (field.key == 'subtype_summary' || field.key == 'coverage_summary') {
        final rk = field.key == 'subtype_summary' ? 'subtype' : 'coverage_type';
        fields.add(FieldConfig(key: field.key, label: field.label, type: field.type,
            isRequired: field.isRequired,
            initialValue: widget.dialogState.responses[rk] ?? 'Not selected',
            validator: field.validator));
      } else {
        fields.add(field);
      }
    }
    return fields;
  }

  @override
  Widget build(BuildContext context) {
    final formKey       = GlobalKey<FormState>();
    final colorProvider = context.watch<ColorProvider>();
    final screenWidth   = MediaQuery.of(context).size.width;
    final dialogWidth   = (screenWidth < 500 ? screenWidth * 0.80 : screenWidth < 750 ? screenWidth * 0.70 : 600.0).clamp(280.0, 600.0);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: FutureBuilder<List<FieldConfig>>(
        future: _fieldsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return AlertDialog(content: SizedBox(width: dialogWidth, height: 100, child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: _kCyan),
              const SizedBox(height: 16),
              Text('Loading ${widget.insuranceType} options…', style: GoogleFonts.dmSans()),
            ])));
          }
          if (snapshot.hasError) {
            return AlertDialog(title: const Text('Error'),
                content: Text('Failed to load options: ${snapshot.error}'),
                actions: [TextButton(onPressed: widget.onCancel, child: const Text('Close'))]);
          }
          final fields = snapshot.data ?? widget.config.fields;
          if (fields.isEmpty && widget.config.customCallback == null) {
            return AlertDialog(content: const Text('No options available.'),
                actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))]);
          }
          if (widget.config.customCallback != null && fields.isEmpty) {
            widget.config.customCallback!(context, widget.dialogState);
            return const SizedBox.shrink();
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(widget.config.title,
                  style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface))),
              IconButton(
                icon: Icon(Icons.save_outlined, color: Theme.of(context).colorScheme.primary),
                onPressed: () {
                  widget.dialogState.saveProgress(widget.insuranceType, widget.step);
                  widget.scaffoldMessengerKey.currentState?.showSnackBar(
                      const SnackBar(content: Text('Progress saved')));
                },
                tooltip: 'Save progress',
              ),
            ]),
            content: SizedBox(
              width: dialogWidth,
              height: (fields.length * 130.0).clamp(100.0, 500.0),
              child: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min,
                children: fields.asMap().entries.map((entry) {
                  final field = entry.value;
                  if (field.dependsOnKey != null &&
                      widget.dialogState.responses[field.dependsOnKey!] != field.dependsOnValue) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: field.type == 'grid'
                        ? GridFieldWidget(config: field,
                            value: widget.dialogState.responses[field.key] ?? field.initialValue,
                            onChanged: (v) { widget.dialogState.updateResponse(field.key, v ?? ''); setState(() {}); },
                            colorProvider: colorProvider)
                        : FormFieldWidget(config: field,
                            value: field.key == 'subtype_summary'  ? widget.dialogState.responses['subtype']       ?? 'Not selected'
                                 : field.key == 'coverage_summary' ? widget.dialogState.responses['coverage_type'] ?? 'Not selected'
                                 : widget.dialogState.responses[field.key] ?? field.initialValue,
                            onChanged: (v) { widget.dialogState.updateResponse(field.key, v); setState(() {}); },
                            colorProvider: colorProvider),
                  );
                }).toList(),
              ))),
            ),
            actions: [
              if (widget.onBack != null)
                TextButton(onPressed: widget.onBack,
                    child: Text('Back', style: GoogleFonts.dmSans(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)))),
              TextButton(onPressed: widget.onCancel,
                  child: Text('Cancel', style: GoogleFonts.dmSans(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)))),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final subFilled = widget.dialogState.responses['subtype']?.isNotEmpty == true;
                    final covFilled = widget.dialogState.responses['coverage_type']?.isNotEmpty == true;
                    if (subFilled && covFilled &&
                        (widget.config.customValidator == null || widget.config.customValidator!(widget.dialogState.responses))) {
                      formKey.currentState!.save();
                      if (widget.config.nextStep != null) {
                        widget.dialogState.saveProgress(widget.insuranceType, widget.step + 1);
                      }
                      widget.onSubmit();
                    } else {
                      widget.scaffoldMessengerKey.currentState?.showSnackBar(
                          const SnackBar(content: Text('Please complete all required fields')));
                    }
                  } else {
                    widget.scaffoldMessengerKey.currentState?.showSnackBar(
                        const SnackBar(content: Text('Please correct the errors in the form')));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kDarkTeal, foregroundColor: _kCream,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(widget.config.nextStep == null ? 'Submit' : 'Next',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── FormFieldWidget ───────────────────────────────────────────────────────────
class FormFieldWidget extends StatelessWidget {
  final FieldConfig config;
  final String? value;
  final Function(String) onChanged;
  final ColorProvider colorProvider;

  const FormFieldWidget({super.key, required this.config, this.value, required this.onChanged, required this.colorProvider});

  @override
  Widget build(BuildContext context) {
    if (!config.isRequired && config.validator == null) {
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(config.label, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF4A6741), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value ?? 'Not provided', style: GoogleFonts.dmSans(fontSize: 15, color: _kDarkTeal)),
      ]));
    }
    switch (config.type) {
      case 'dropdown':
        final opts = config.options?.toSet().toList() ?? ['Basic', 'Comprehensive'];
        String? sel = value;
        if (sel == null || !opts.contains(sel)) sel = opts.contains(config.initialValue) ? config.initialValue : opts.firstOrNull;
        return DropdownButtonFormField<String>(
          value: sel,
          decoration: InputDecoration(labelText: config.label),
          items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o.replaceAll('_', ' ').toUpperCase()))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
          validator: config.validator ?? (v) => config.isRequired && (v == null || v.isEmpty) ? '${config.label} is required' : null,
        );
      case 'checkbox':
        return CheckboxListTile(
          title: Text(config.label, style: GoogleFonts.dmSans()),
          value: value == 'Yes',
          onChanged: (v) => onChanged(v == true ? 'Yes' : 'No'),
          activeColor: colorProvider.color,
          contentPadding: EdgeInsets.zero,
        );
      case 'grid':
        final opts  = config.options ?? [];
        final icons = config.icons  ?? [];
        return Wrap(spacing: 8, runSpacing: 8, children: List.generate(opts.length, (i) {
          final isSelected = value == opts[i];
          final icon = icons.isNotEmpty && i < icons.length ? icons[i] : '❓';
          return GestureDetector(
            onTap: () => onChanged(opts[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? _kDarkTeal : Theme.of(context).colorScheme.surface,
                border: Border.all(color: isSelected ? _kAcidOlive : Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(opts[i].replaceAll('_', ' '),
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600,
                        color: isSelected ? _kCream : Theme.of(context).colorScheme.onSurface)),
              ]),
            ),
          );
        }));
      default:
        return TextFormField(
          decoration: InputDecoration(labelText: config.label),
          keyboardType: config.keyboardType,
          validator: config.validator,
          onChanged: onChanged,
          initialValue: value,
        );
    }
  }
}

// ── GridFieldWidget ───────────────────────────────────────────────────────────
class GridFieldWidget extends StatelessWidget {
  final FieldConfig config;
  final String? value;
  final Function(String?) onChanged;
  final ColorProvider colorProvider;

  const GridFieldWidget({super.key, required this.config, this.value, required this.onChanged, required this.colorProvider});

  @override
  Widget build(BuildContext context) {
    final opts  = config.options;
    final icons = config.icons ?? [];
    if (opts == null || opts.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(config.label, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text('No options available', style: GoogleFonts.dmSans(fontSize: 13, color: Theme.of(context).colorScheme.error)),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(config.label, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: List.generate(opts.length, (i) {
        final isSelected = value == opts[i];
        final icon = i < icons.length && icons[i].isNotEmpty ? icons[i] : '❓';
        return GestureDetector(
          onTap: () => onChanged(opts[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? _kDarkTeal : Theme.of(context).colorScheme.surface,
              border: Border.all(
                  color: isSelected ? _kAcidOlive : Theme.of(context).colorScheme.outline,
                  width: isSelected ? 2 : 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(opts[i], style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600,
                  color: isSelected ? _kCream : Theme.of(context).colorScheme.onSurface)),
            ]),
          ),
        );
      })),
      if (config.isRequired && value == null)
        Padding(padding: const EdgeInsets.only(top: 6),
            child: Text('Please select an option',
                style: GoogleFonts.dmSans(fontSize: 11, color: Theme.of(context).colorScheme.error))),
    ]);
  }
}

// ── DynamicForm ───────────────────────────────────────────────────────────────
class DynamicForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<Map<String, dynamic>> fields;
  final Function(String, String) onFieldChanged;
  final Map<String, String> responses;

  const DynamicForm({super.key, required this.formKey, required this.fields,
      required this.onFieldChanged, required this.responses});

  @override
  Widget build(BuildContext context) {
    return Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
      children: fields.asMap().entries.where((entry) {
        final field = entry.value;
        return field['condition'] == null || field['condition'](responses);
      }).map((entry) {
        final field = entry.value;
        final isLast = entry.key == fields.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 14.0),
          child: TextFormField(
            decoration: InputDecoration(labelText: field['label']),
            keyboardType: field['keyboardType'] ?? TextInputType.text,
            validator: (v) => field['validator']?.call(v ?? ''),
            onChanged: (v) => onFieldChanged(field['key'], v),
            initialValue: responses[field['key']] ?? '',
          ),
        );
      }).toList(),
    ));
  }
}
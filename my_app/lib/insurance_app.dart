import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web/web.dart' as web; // Use this instead of dart:html

// Remove this import; see below for correct usage.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:my_app/Models/Insured_item.dart';
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
import 'package:my_app/Services/webview.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf_text/pdf_text.dart';
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
import 'package:google_fonts/google_fonts.dart'; // For elegant typography
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Correct import for url_launcher
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'subtype': subtype,
      'company': company,
      'premium': premium,
      'formData': formData,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
}

class InsuranceHomeScreen extends StatefulWidget {
  const InsuranceHomeScreen({super.key});
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static List<company_models.Company> _cachedCompanies = [];

  // Add this static method to access cachedPdfTemplates from the state
  static Map<String, PDFTemplate> _cachedPdfTemplates = {};

  static Future<Map<String, PDFTemplate>> getCachedPdfTemplates() async {
    // If already loaded, return the cache
    if (_cachedPdfTemplates.isNotEmpty) {
      return _cachedPdfTemplates;
    }
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('pdf_templates').get();
      if (snapshot.docs.isNotEmpty) {
        _cachedPdfTemplates = Map.fromEntries(
          snapshot.docs.map(
            (doc) => MapEntry(
              doc.id,
              PDFTemplate.fromJson(doc.data()),
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading cached PDF templates: $e');
      }
      _cachedPdfTemplates = {};
    }
    return _cachedPdfTemplates;
  }

  static Future<List<company_models.Company>> getCompanies() async {
    try {
      // Check cache first
      if (_cachedCompanies.isNotEmpty) {
        if (kDebugMode) print('Using cached companies: ${_cachedCompanies.length}');
        return _cachedCompanies;
      }

      // Fetch from Firestore
      final snapshot = await _firestore
          .collection('companies')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));
      
      final companies = snapshot.docs
          .map((doc) => company_models.Company.fromFirestore(doc.data()))
          .toList();

      // Return Firestore data if not empty, otherwise return defaults
      if (companies.isNotEmpty) {
        _cachedCompanies = companies; // Update cache
        if (kDebugMode) print('Loaded ${companies.length} companies from Firestore');
        return companies;
      } else {
        await Future.delayed(const Duration(seconds: 1));
        final defaults = [
          company_models.Company(
            id: 'default',
            name: 'Default Company',
            pdfTemplateKey: ['default_template'], 
          ),
        ];
        _cachedCompanies = defaults; // Cache defaults
        return defaults;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) print('Error in getCompanies: $e\n$stackTrace');
      // Fallback to defaults on error
      await Future.delayed(const Duration(seconds: 1));
      final defaults = [
        company_models.Company(
          id: 'default',
          name: 'Default Company',
          pdfTemplateKey: ['default_template'],
  
        ),
      ];
      _cachedCompanies = defaults; // Cache defaults
      return defaults;
    }
  }

  static Future<List<PolicyType>> getPolicyTypes() async {
    try {
      // Fetch from Firestore
      final snapshot = await _firestore.collection('policyTypes').get();
      final policyTypes = snapshot.docs
          .map((doc) => PolicyType.fromFirestore(doc.data()))
          .toList();

      // Return Firestore data if not empty, otherwise return defaults
      if (policyTypes.isNotEmpty) {
        return policyTypes;
      } else {
        await Future.delayed(const Duration(seconds: 1)); // Simulate delay
        return [
          PolicyType(id: '1', name: 'Motor', description: 'Motor insurance'),
          PolicyType(
              id: '2', name: 'Medical', description: 'Medical insurance'),
          PolicyType(id: '3', name: 'Travel', description: 'Travel insurance'),
          PolicyType(
              id: '4', name: 'Property', description: 'Property insurance'),
          PolicyType(id: '5', name: 'WIBA', description: 'WIBA insurance'),
        ];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in getPolicyTypes: $e');
      }
      // Fallback to defaults on error
      await Future.delayed(const Duration(seconds: 1));
      return [
        PolicyType(id: '1', name: 'Motor', description: 'Motor insurance'),
        PolicyType(id: '2', name: 'Medical', description: 'Medical insurance'),
        PolicyType(id: '3', name: 'Travel', description: 'Travel insurance'),
        PolicyType(
            id: '4', name: 'Property', description: 'Property insurance'),
        PolicyType(id: '5', name: 'WIBA', description: 'WIBA insurance'),
      ];
    }
  }

  static Future<List<PolicySubtype>> getPolicySubtypes(
      String policyTypeId) async {
    try {
      // Fetch from Firestore
      final snapshot = await _firestore
          .collection('policySubtypes')
          .where('policyTypeId', isEqualTo: policyTypeId)
          .get();
      final subtypes = snapshot.docs
          .map((doc) => PolicySubtype.fromFirestore(doc.data()))
          .toList();

      // Return Firestore data if not empty, otherwise return defaults
      if (subtypes.isNotEmpty) {
        return subtypes;
      } else {
        await Future.delayed(const Duration(seconds: 1));
        return [
          PolicySubtype(
              id: '1',
              name: 'Standard',
              policyTypeId: policyTypeId,
              description: ''),
          PolicySubtype(
              id: '2',
              name: 'Premium',
              policyTypeId: policyTypeId,
              description: ''),
        ];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in getPolicySubtypes: $e');
      }
      // Fallback to defaults on error
      await Future.delayed(const Duration(seconds: 1));
      return [
        PolicySubtype(
            id: '1',
            name: 'Standard',
            policyTypeId: policyTypeId,
            description: ''),
      ];
    }
  }

  static Future<List<CoverageType>> getCoverageTypes(String subTypeId) async {
    try {
      // Fetch from Firestore
      final snapshot = await _firestore
          .collection('coverageTypes')
          .where('subTypeId', isEqualTo: subTypeId)
          .get();
      final coverageTypes = snapshot.docs
          .map((doc) => CoverageType.fromFirestore(doc.data()))
          .toList();

      // Return Firestore data if not empty, otherwise return defaults
      if (coverageTypes.isNotEmpty) {
        return coverageTypes;
      } else {
        await Future.delayed(const Duration(seconds: 1));
        return [
          CoverageType(id: '1', name: 'Basic', description: ''),
          CoverageType(id: '2', name: 'Comprehensive', description: ''),
        ];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in getCoverageTypes: $e');
      }
      // Fallback to defaults on error
      await Future.delayed(const Duration(seconds: 1));
      return [
        CoverageType(id: '1', name: 'Basic', description: ''),
      ];
    }
  }

  static Future<PDFTemplate?> getPDFTemplate(String pdfTemplateKey) async {
    try {
      // Fetch from Firestore
      final doc =
          await _firestore.collection('pdfTemplates').doc(pdfTemplateKey).get();
      if (doc.exists) {
        // Assuming PDFTemplate.fromFirestore exists; adjust based on your model
        // return PDFTemplate.fromFirestore(doc.data()!);
        return PDFTemplate(
            fields: {},
            fieldMappings: {},
            coordinates: {},
            policyType: '',
            policySubtype: '',
            templateKey: ''); // Replace with actual parsing logic
      } else {
        await Future.delayed(const Duration(seconds: 1));
        return null; // Simulate no template found
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in getPDFTemplate: $e');
      }
      await Future.delayed(const Duration(seconds: 1));
      return null;
    }
  }

  @override
  State<InsuranceHomeScreen> createState() => _InsuranceHomeScreenState();

  static Future<List<company_models.Company>> loadCompanies() async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      return [
        company_models.Company(id: '1', name: 'AIG', pdfTemplateKey: const [], ),
        company_models.Company(
          id: '2',
          name: 'Cigna',
          pdfTemplateKey: const [],
        ),
        company_models.Company(id: '3', name: 'UnitedHealth', pdfTemplateKey: const [], )
      ];
    } catch (e) {
      if (kDebugMode) {
        print('Error in loadCompanies: $e');
      }
      return [company_models.Company(id: '1', name: 'AIG', pdfTemplateKey: const [], )];
    }
  }
}

class _InsuranceHomeScreenState extends State<InsuranceHomeScreen> {
  List<InsuredItem> insuredItems = [];
  List<Cover> covers = [];
  List<Quote> quotes = [];
  List<company_models.Company> companies = [];
  List<Map<String, dynamic>> notifications = []; // Changed from List<dynamic>
  bool isLoading = false;
  bool _hasLoadedInsuredItems = false;
  bool _hasLoadedData = false; // <-- Added to fix undefined name error
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
  static const String openAiApiKey = 'your-openai-api-key-here';
  static const String mpesaApiKey = 'your-mpesa-api-key-here';
  List<Policy> policies = [];
  static const String paystackSecretKey = 'your-paystack-secret-key-here';

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _spouseAgeController = TextEditingController();
  final TextEditingController _childrenCountController =
      TextEditingController();
  final TextEditingController _chassisNumberController =
      TextEditingController();
  final TextEditingController _kraPinController = TextEditingController();
  String? _selectedVehicleType;
  String? _selectedInpatientLimit;
  List<String> _selectedMedicalServices = [];
  List<String> _selectedUnderwriters = [];
  File? _logbookFile;
  File? _previousPolicyFile;
  List<String> trendingTopics = [];
  List<String> blogPosts = [];

  String pdfTemplateKey = 'default_template';
  List<PolicyType> cachedPolicyTypes = [];
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  Map<String, dynamic> chatbotTemplate = {
    'states': {
      'start': {
        'message': 'Welcome to the chatbot!',
        'options': [
          {'text': 'Option 1'},
          {'text': 'Option 2'},
        ],
      },
    },
  };
  List<Map<String, String>> chatMessages = [];

  final Map<String, Map<String, Map<String, dynamic>>> policyCalculators = {
    'motor': {
      'commercial': {
        'companyA': {
          'basePremium': 5000,
          'factor': 0.02,
          'email': 'motor@companyA.com',
        },
      },
      'psv': {
        'companyA': {
          'basePremium': 7000,
          'factor': 0.03,
          'email': 'motor@companyA.com',
        },
      },
      // ... other motor subtypes
    },
    'medical': {
      'individual': {
        'companyA': {'basePremium': 10000, 'email': 'health@companyA.com'},
      },
      'corporate': {
        'companyA': {'basePremium': 15000, 'email': 'health@companyA.com'},
      },
    },
    'property': {
      'residential': {
        'companyA': {
          'basePremium': 8000,
          'factor': 0.01,
          'email': 'property@companyA.com',
        },
      },
      // ... other property subtypes
    },
  };

  var _selectedIndex;

  String? selectedCompany;

  Map<String, String>? extractedData;

  late bool isDesktop;

  @override
  void initState() {
    super.initState();
    _loadCachedPdfTemplates();
    _loadUserDetails();
    _loadQuotes();
    _loadNotifications(); // Add this
    fetchTrendingTopics();
    fetchBlogPosts();
    _startChatbot();
    _checkUserRole();
    _setupFirebaseMessaging();
    _checkCoverExpirations();
    _autofillUserDetails();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedData) {
      _hasLoadedData = true;
      _loadPolicies();
      _loadInsuredItems();
      isDesktop = !kIsWeb &&
          MediaQuery.of(context).size.width > 600; // Example threshold

      _loadNotifications();
      _startChatbot();
    }
  }

  Future<void> _autofillUserDetails() async {
    if (userDetails.isNotEmpty) {
      _nameController.text = userDetails['name'] ?? '';
      _emailController.text = userDetails['email'] ?? '';
      _phoneController.text = userDetails['phone'] ?? '';
    }
    if (selectedInsuredItemId != null) {
      final item = insuredItems.firstWhere(
        (i) => i.id == selectedInsuredItemId,
      );
      _selectedVehicleType = item.vehicleType;
      _chassisNumberController.text = item.chassisNumber ?? '';
      _kraPinController.text = item.kraPin ?? '';
    }
  }

  Future<void> _saveUserDetails(Map<String, String> newDetails) async {
    try {
      userDetails.addAll(newDetails);
      final key = encrypt.Key.fromLength(32);
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypter.encrypt(jsonEncode(userDetails), iv: iv);
      await secureStorage.write(key: 'user_details', value: encrypted.base64);
      setState(() {
        _nameController.text = userDetails['name'] ?? '';
        _emailController.text = userDetails['email'] ?? '';
        _phoneController.text = userDetails['phone'] ?? '';
      });
    } catch (e) {
      print('Error saving user details: $e');
    }
  }

  Future<void> autofillFromPreviousPolicy(File pdfFile,
      Map<String, String>? extractedData, String? selectedCompany) async {
    try {
      if (extractedData != null) {
        await _saveUserDetails(extractedData); // Save to secure storage
        await FirebaseFirestore.instance.collection('autofilled_forms').add({
          'user_id': insuredItems ?? 'unknown',
          'source': 'previous_policy',
          'fields': extractedData,
          'insurer': selectedCompany ?? 'unknown',
          'file_path': pdfFile.path,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      if (selectedCompany != null) {
        await FirebaseFirestore.instance.collection('user_preferences').add({
          'user_id': insuredItems ?? 'unknown',
          'insurer': selectedCompany,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in autofillFromPreviousPolicy: $e');
      }
    }
  }

  Future<void> autofillFromLogbook(
      File logbookFile, Map<String, String>? extractedData) async {
    try {
      if (extractedData != null) {
        await _saveUserDetails(extractedData); // Save to secure storage
        await FirebaseFirestore.instance.collection('autofilled_forms').add({
          'user_id': insuredItems ?? 'unknown',
          'source': 'logbook',
          'fields': extractedData,
          'file_path': logbookFile.path,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in autofillFromLogbook: $e');
      }
    }
  }

  Future<void> _checkUserRole() async {
    String? role = await secureStorage.read(key: 'user_role');
    setState(() {
      userRole = role == 'admin' ? UserRole.admin : UserRole.regular;
    });
  }

  void _setupFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      setState(() {
        notifications.add({
          'title': message.notification?.title ?? 'Notification',
          'body': message.notification?.body ?? 'New notification',
          'timestamp': DateTime.now().toIso8601String(),
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.notification?.body ?? 'New notification'),
        ),
      );
    });
  }

  Future<void> _loadPolicies() async {
    bool hasShownSnackBar = false;
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (kDebugMode) {
          print('No user authenticated for loading policies.');
        }
        if (mounted && !hasShownSnackBar) {
          setState(() {
            policies = [];
          });
          await Future.delayed(Duration.zero); // Ensure post-frame
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted && !hasShownSnackBar) {
              hasShownSnackBar = true;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Please sign in to view policies')),
              );
            }
          });
        }
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('policies')
          .doc(userId)
          .collection('user_policies')
          .get();

      final loadedPolicies = <Policy>[];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          if (data.isNotEmpty) {
            loadedPolicies.add(Policy.fromJson({
              ...data,
              'id': doc.id,
            }));
          } else {
            if (kDebugMode) {
              print('Empty data for policy document ${doc.id}');
            }
          }
        } catch (e, stackTrace) {
          if (kDebugMode) {
            print('Error parsing policy ${doc.id}: $e\n$stackTrace');
          }
        }
      }

      if (mounted) {
        setState(() {
          policies = loadedPolicies;
        });
        if (policies.isEmpty && !hasShownSnackBar) {
          if (kDebugMode) {
            print('No policies found for user $userId.');
          }
          await Future.delayed(Duration.zero);
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted && !hasShownSnackBar) {
              hasShownSnackBar = true;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No policies found')),
              );
            }
          });
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error loading policies: $e\n$stackTrace');
      }
      if (mounted && !hasShownSnackBar) {
        await Future.delayed(Duration.zero);
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted && !hasShownSnackBar) {
            hasShownSnackBar = true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to load policies: $e')),
            );
          }
        });
      }
    }
  }

  Future<void> _loadInsuredItems() async {
    if (_hasLoadedInsuredItems) return;
    _hasLoadedInsuredItems = true;
    bool hasShownSnackBar = false;
    try {
      final collection = FirebaseFirestore.instance.collection('insured_items');
      final snapshot = await collection.get();
      if (kDebugMode) {
        print('Insured items snapshot: ${snapshot.docs.length} documents');
        for (var doc in snapshot.docs) {
          print('Document ${doc.id}: ${doc.data()}');
        }
      }

      List<InsuredItem> items = [];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          if (data.containsKey('data') && data['data'] is List) {
            final jsonData = data['data'] as List;
            items.addAll(jsonData
                .map((item) =>
                    InsuredItem.fromJson(item as Map<String, dynamic>))
                .toList());
          } else {
            if (kDebugMode) {
              print(
                  'Invalid or missing "data" field in document ${doc.id}: $data');
            }
          }
        } catch (e, stackTrace) {
          if (kDebugMode) {
            print('Error processing document ${doc.id}: $e\n$stackTrace');
          }
        }
      }

      if (mounted) {
        setState(() {
          insuredItems = items;
        });
        if (items.isEmpty && !hasShownSnackBar) {
          if (kDebugMode) {
            print('No insured items found.');
          }
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted && !hasShownSnackBar) {
              hasShownSnackBar = true;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No insured items found')),
              );
            }
          });
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error loading insured items from Firestore: $e\n$stackTrace');
      }
      if (mounted && !hasShownSnackBar) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted && !hasShownSnackBar) {
            hasShownSnackBar = true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to load insured items: $e')),
            );
          }
        });
      }
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (kDebugMode) {
          print('No user authenticated for loading notifications.');
        }
        if (mounted) {
          setState(() {
            notifications = [];
          });
        }
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(userId)
          .collection('user_notifications')
          .get();

      if (mounted) {
        setState(() {
          notifications = snapshot.docs.map((doc) => doc.data()).toList();
        });
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error loading notifications: $e\n$stackTrace');
      }
      if (mounted) {
        setState(() {
          notifications = [];
        });
      }
    }
  }

  Future<void> _loadQuotes() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (kDebugMode) {
          print('No user authenticated for loading quotes.');
        }
        setState(() {
          quotes = [];
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('quotes')
          .doc(userId)
          .collection('user_quotes')
          .get();

      setState(() {
        quotes = snapshot.docs
            .map(
              (doc) => Quote(
                id: doc['id'] as String,
                type: doc['type'] as String,
                subtype: doc['subtype'] as String,
                company: doc['company'] as String,
                premium: (doc['premium'] as num).toDouble(),
                formData: Map<String, String>.from(doc['formData'] as Map),
                generatedAt: (doc['generatedAt'] as Timestamp).toDate(),
              ),
            )
            .toList();
      });

      if (quotes.isEmpty && kDebugMode) {
        if (kDebugMode) {
          print('No quotes found for user $userId.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading quotes: $e');
      }
      setState(() {
        quotes = [];
      });
    }
  }

  Future<void> _checkCoverExpirations() async {
    final now = DateTime.now();
    for (var cover in covers) {
      if (cover.expirationDate != null) {
        final daysUntilExpiration =
            cover.expirationDate!.difference(now).inDays;
        if (daysUntilExpiration <= 0 && cover.status != CoverStatus.expired) {
          setState(() {
            covers = covers
                .map(
                  (c) => c.id == cover.id
                      ? c.copyWith(status: CoverStatus.expired)
                      : c,
                )
                .toList();
          });
          await FirebaseMessaging.instance.sendMessage(
            to: '/topics/policy_updates',
            data: {
              'Cover_id': cover.id,
              'message': 'Policy ${cover.id} has expired',
            },
          );
        } else if (daysUntilExpiration <= 30 &&
            cover.status != CoverStatus.nearingExpiration) {
          setState(() {
            covers = covers
                .map(
                  (c) => c.id == cover.id
                      ? c.copyWith(
                          status: CoverStatus.nearingExpiration,
                        )
                      : c,
                )
                .toList();
          });
          await FirebaseMessaging.instance.sendMessage(
            to: '/topics/policy_updates',
            data: {
              'policy_id': cover.id,
              'message': 'Policy ${cover.id} is nearing expiration',
            },
          );
        }
      }
    }
    await _saveCovers();
  }

  void _startChatbot() {
    // Fallback if chatbotTemplate is null or missing keys
    if (!chatbotTemplate.containsKey('states')) {
      if (kDebugMode) {
        print('chatbotTemplate or states is null or missing');
      }
      setState(() {
        chatMessages.add({
          'sender': 'bot',
          'text': 'Error: Chatbot configuration not found.',
        });
      });
      return;
    }

    final states = chatbotTemplate['states'] as Map<String, dynamic>?;
    if (states == null || !states.containsKey('start')) {
      if (kDebugMode) {
        print('Start state is missing in chatbotTemplate');
      }
      setState(() {
        chatMessages.add({
          'sender': 'bot',
          'text': 'Error: Start state not found.',
        });
      });
      return;
    }

    final startState = states['start'] as Map<String, dynamic>?;
    if (startState == null ||
        !startState.containsKey('message') ||
        !startState.containsKey('options')) {
      if (kDebugMode) {
        print('Invalid startState structure');
      }
      setState(() {
        chatMessages.add({
          'sender': 'bot',
          'text': 'Error: Invalid chatbot start state.',
        });
      });
      return;
    }

    final message = startState['message'] as String? ?? 'Welcome!';
    final options = startState['options'] as List<dynamic>? ?? [];
    final formattedMessage =
        '$message\n${options.asMap().entries.map((e) => '${e.key + 1}. ${e.value['text'] ?? 'Option'}').join('\n')}';

    setState(() {
      chatMessages.add({'sender': 'bot', 'text': formattedMessage});
    });
  }

  Future<bool> _validatePdfWithChatGPT(File pdfFile) async {
    try {
      PDFDoc doc = await PDFDoc.fromPath(pdfFile.path);
      String text = await doc.text;

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $openAiApiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are an expert at validating form data. Given the text of a filled PDF, check if fields like name, email, phone, etc., are correctly filled. Return a JSON object with a boolean "valid" and a "message" explaining any issues.',
            },
            {'role': 'user', 'content': 'Validate this PDF text:\n\n$text'},
          ],
          'max_tokens': 200,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = jsonDecode(data['choices'][0]['message']['content']);
        if (!result['valid']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ChatGPT Validation Failed: ${result['message']}'),
            ),
          );
        }
        return result['valid'];
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('ChatGPT validation error: $e');
      }
      return false;
    }
  }

  Future<bool> _previewPdf(File pdfFile) async {
    if (userRole == UserRole.admin) {
      bool? approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Preview Filled PDF'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: PdfPreview(file: pdfFile),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve'),
            ),
          ],
        ),
      );
      return approved ?? false;
    } else {
      return await _validatePdfWithChatGPT(pdfFile);
    }
  }

  Future<File?> _fillPdfTemplate(
    String templateKey,
    Map<String, String> formData,
    String insuranceType,
    BuildContext context,
  ) async {
    try {
      // Fetch PDFTemplate from Firestore
      final template = await InsuranceHomeScreen.getPDFTemplate(templateKey);
      if (template == null) {
        if (kDebugMode) {
          print('Template not found for key: $templateKey');
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF template not found')),
          );
        }
        return null;
      }

      // Get template file from assets or Firestore
      final directory = await getApplicationDocumentsDirectory();
      final templateFile =
          File('${directory.path}/pdf_templates/$templateKey.pdf');
      if (!await templateFile.exists()) {
        if (kDebugMode) {
          print('Template file does not exist: ${templateFile.path}');
        }
        if (kIsWeb) {
          if (kDebugMode) {
            print(
                'PDF template files not supported on web without asset loading');
          }
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF template file not found')),
          );
        }
        return null;
      }

      // Load PDF document
      final pdfBytes = await templateFile.readAsBytes();
      final pdfDoc = await pdf.PdfDocument.openData(pdfBytes);
      final outputPdf = pw.Document();

      // Process each page
      for (int i = 0; i < pdfDoc.pageCount; i++) {
        final page = await pdfDoc.getPage(i + 1);
        outputPdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Stack(
                children: [
                  // Placeholder background (no image on web)
                  pw.Container(
                    width: page.width.toDouble(),
                    height: page.height.toDouble(),
                    color: PdfColors.white,
                  ),
                  // Render form data fields
                  ...formData.entries.map((entry) {
                    final fieldKey = entry.key;
                    final fieldValue = entry.value;
                    final coord = template.coordinates[fieldKey];

                    if (coord == null || coord['page'] != (i + 1).toDouble()) {
                      return pw.SizedBox();
                    }

                    // Get FieldDefinition for validation
                    final fieldDef = template.fields[fieldKey] ??
                        FieldDefinition(
                          expectedType: ExpectedType.text,
                          validator: FieldDefinition.getValidatorForType(
                              ExpectedType.text),
                        );

                    // Validate field value
                    String? error = fieldDef.validator?.call(fieldValue);
                    if (error != null) {
                      if (kDebugMode) {
                        print('Validation error for $fieldKey: $error');
                      }
                      return pw.SizedBox(); // Skip invalid fields
                    }

                    // Handle list (dropdown) fields
                    if (fieldDef.expectedType == ExpectedType.list &&
                        fieldDef.listItemType != null) {
                      final itemValidator = FieldDefinition.getValidatorForType(
                          fieldDef.listItemType);
                      final itemError = itemValidator?.call(fieldValue);
                      if (itemError != null) {
                        if (kDebugMode) {
                          print(
                              'List item validation error for $fieldKey: $itemError');
                        }
                        return pw.SizedBox();
                      }
                    }

                    return pw.Positioned(
                      left: coord['x']!,
                      top: coord['y']!,
                      child: pw.Text(
                        fieldValue,
                        style: pw.TextStyle(
                          font: pw.Font.helvetica(),
                          fontSize: 12,
                          color: PdfColors.black,
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        );
      }
      await pdfDoc.dispose();

      // Save output PDF
      final reportsDirectory = Directory('${directory.path}/reports');
      if (!await reportsDirectory.exists()) {
        await reportsDirectory.create(recursive: true);
      }
      final filePath = '${reportsDirectory.path}/filled_$templateKey.pdf';
      final outputFile = File(filePath);
      await outputFile.writeAsBytes(await outputPdf.save());

      if (kDebugMode) {
        print('PDF generated successfully: $filePath');
      }
      return outputFile;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error filling PDF template: $e\n$stackTrace');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
      return null;
    }
  }

  Future<void> handleCoverSubmission(
    BuildContext context,
    String type,
    String subtype,
    String coverageType,
    String companyId,
    String pdfTemplateKey,
    Map<String, String> details,
  ) async {
    try {
      // Create or select InsuredItem
      InsuredItem insuredItem;
      if (details['insured_item_id']?.isNotEmpty ?? false) {
        final snapshot = await FirebaseFirestore.instance
            .collection('insured_items')
            .doc(details['insured_item_id'])
            .get();
        if (!snapshot.exists) {
          throw Exception('Insured item not found');
        }
        insuredItem = InsuredItem.fromJson(snapshot.data()!);
      } else {
        insuredItem = InsuredItem(
          id: Uuid().v4(),
          type: type,
          vehicleType: type == 'motor' ? subtype : '',
          details: details,
          vehicleValue: type == 'motor' ? details['vehicle_value'] : null,
          regno: type == 'motor' ? details['regno'] : null,
          propertyValue: type == 'property' ? details['property_value'] : null,
          chassisNumber: type == 'motor' ? details['chassis_number'] : null,
          kraPin: type == 'motor' ? details['kra_pin'] : null,
          logbookPath: type == 'motor' ? details['logbook_path'] : null,
          previousPolicyPath:
              type == 'motor' ? details['previous_policy_path'] : null,
        );
        // Save to Firestore
        await FirebaseFirestore.instance
            .collection('insured_items')
            .doc(insuredItem.id)
            .set(insuredItem.toJson());
        insuredItems.add(insuredItem); // Update global list
      }

      // Calculate premium
      double premium = await _calculatePremium(type, subtype, details);

      // Ask user whether to generate a quote or proceed with payment
      bool? proceedWithPayment;
      if (context.mounted) {
        proceedWithPayment = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Choose an Option'),
              content: const Text(
                'Would you like to generate a quote or proceed with payment?',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, false), // Generate quote
                  child: const Text('Generate Quote'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, true), // Proceed with payment
                  child: const Text('Proceed with Payment'),
                ),
              ],
            );
          },
        );
      }

      if (proceedWithPayment == null) {
        // User dismissed the dialog
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Action canceled.')),
          );
        }
        return;
      }

      if (!proceedWithPayment) {
        // Generate and save quote
        final quote = Quote(
          id: Uuid().v4(),
          type: type,
          subtype: subtype,
          company: companyId,
          premium: premium,
          generatedAt: DateTime.now(),
          formData: details,
        );

        // Save quote to Firestore
        await FirebaseFirestore.instance
            .collection('quotes')
            .doc(quote.id)
            .set(quote.toJson());

        // Generate quote PDF
        final pdfFile = await _generateQuotePdf(quote);
        if (pdfFile != null && context.mounted) {
          // Optionally preview the quote PDF
          if (await _previewPdf(pdfFile)) {
            await _sendEmail(
              companyId,
              type,
              subtype,
              details,
              pdfFile,
              details['regno'] ?? '',
              details['vehicle_type'] ?? '',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Quote generated and sent.')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Quote PDF preview failed or was not approved.')),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to generate quote PDF.')),
            );
          }
        }

        // Update chatbot state for quote
        currentState = 'quote_process';
        chatMessages.add({
          'sender': 'bot',
          'text':
              'Your ${type.toUpperCase()} quote ($subtype) has been generated.',
        });
        return;
      }

      // Proceed with payment
      final cover = Cover(
        id: Uuid().v4(),
        insuredItemId: insuredItem.id,
        companyId: companyId,
        type: type,
        subtype: subtype,
        coverageType: type == 'motor' ? coverageType : 'custom',
        status: CoverStatus.pending,
        expirationDate: DateTime.now().add(const Duration(days: 365)),
        pdfTemplateKey: pdfTemplateKey,
        paymentStatus: 'pending',
        startDate: DateTime.now(),
        formData: details,
        premium: premium,
        billingFrequency: 'annual',
        name: '',
      );

      // Save cover to Firestore
      await FirebaseFirestore.instance
          .collection('covers')
          .doc(cover.id)
          .set(cover.toJson());
      covers.add(cover);

      // Handle PDF generation
      File? pdfFile;
      if (cachedPdfTemplates.isNotEmpty &&
          cachedPdfTemplates.containsKey(pdfTemplateKey)) {
        pdfFile = await _fillPdfTemplate(
          pdfTemplateKey ?? '',
          details,
          type,
          context,
        );
        if (pdfFile != null && await _previewPdf(pdfFile)) {
          await _sendEmail(
            companyId,
            type,
            subtype,
            details,
            pdfFile,
            details['regno'] ?? '',
            details['vehicle_type'] ?? '',
          );
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PDF preview failed or was not approved.'),
              ),
            );
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('No PDF templates available. Proceeding without PDF.'),
            ),
          );
        }
        pdfFile = await _generateFallbackPdf(type, subtype, details);
        if (pdfFile != null) {
          await _sendEmail(
            companyId,
            type,
            subtype,
            details,
            pdfFile,
            details['regno'] ?? '',
            details['vehicle_type'] ?? '',
          );
        }
      }

      // Initialize payment
      final paymentStatus = await _initializePayment(
        cover.id,
        premium.toString(),
      );

      // Update cover status in Firestore
      await FirebaseFirestore.instance
          .collection('covers')
          .doc(cover.id)
          .update({
        'status': paymentStatus == 'completed'
            ? CoverStatus.active.toString()
            : CoverStatus.pending.toString(),
        'paymentStatus': paymentStatus,
      });

      final updatedCover = cover.copyWith(
        status: paymentStatus == 'completed'
            ? CoverStatus.active
            : CoverStatus.pending,
        paymentStatus: paymentStatus,
      );
      final index = covers.indexWhere((c) => c.id == cover.id);
      if (index != -1) {
        covers[index] = updatedCover;
      }

      // Update chatbot state and UI
      currentState = type == 'medical' ? 'health_process' : 'pdf_process';
      chatMessages.add({
        'sender': 'bot',
        'text':
            'Your ${type.toUpperCase()} cover ($subtype) has been created. Payment status: $paymentStatus.',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Cover created, payment $paymentStatus${pdfFile == null ? ', no PDF generated' : ''}'),
          ),
        );
        // Show completion dialog
        _showCompletionDialog(
          context,
          type,
          await Policy.fromCover(updatedCover),
          pdfTemplateKey,
          (context, type, subtype, coverageType) {
            if (kDebugMode) {
              print('Final submission: $type, $subtype, $coverageType');
            }
          },
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in handleCoverSubmission: $e');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create cover: $e'),
          ),
        );
      }
    }
  }

// Assuming _generateQuotePdf remains the same as provided
  Future<File?> _generateQuotePdf(Quote quote) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Insurance Quote',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Quote ID: ${quote.id}'),
            pw.Text('Type: ${quote.type}'),
            pw.Text('Subtype: ${quote.subtype}'),
            pw.Text('Company: ${quote.company}'),
            pw.Text('Premium: KES ${quote.premium.toStringAsFixed(2)}'),
            pw.Text('Generated: ${quote.generatedAt}'),
            pw.SizedBox(height: 20),
            pw.Text('Details:', style: pw.TextStyle(fontSize: 16)),
            ...quote.formData.entries.map(
              (e) => pw.Text('${e.key}: ${e.value}'),
            ),
          ],
        ),
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/quote_${quote.id}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<double> _calculatePremium(
    String type,
    String subtype,
    Map<String, String> formData,
  ) async {
    final calculator = policyCalculators[type]?[subtype]?['companyA'];
    if (calculator == null) return 0.0;
    double basePremium = calculator['basePremium'].toDouble();
    double factor = calculator['factor']?.toDouble() ?? 0.01;

    switch (type) {
      case 'motor':
        double vehicleValue =
            double.tryParse(formData['vehicle_value'] ?? '0') ?? 0;
        return basePremium + (vehicleValue * factor);
      case 'medical':
        int beneficiaries = int.tryParse(
              formData['beneficiaries'] ?? (subtype == 'corporate' ? '3' : '1'),
            ) ??
            1;
        double inpatientFactor = double.tryParse(
              formData['inpatient_limit']
                      ?.replaceAll('KES ', '')
                      .replaceAll(',', '') ??
                  '0',
            ) ??
            0;
        double outpatientFactor =
            double.tryParse(formData['outpatient_limit'] ?? '0') ?? 0;
        double dentalFactor =
            double.tryParse(formData['dental_limit'] ?? '0') ?? 0;
        double opticalFactor =
            double.tryParse(formData['optical_limit'] ?? '0') ?? 0;
        double maternityFactor =
            double.tryParse(formData['maternity_limit'] ?? '0') ?? 0;
        int dependentCount = (formData['has_spouse'] == 'Yes' ? 1 : 0) +
            (int.tryParse(formData['children_count'] ?? '0') ?? 0);
        return basePremium +
            (beneficiaries * 1000) +
            (inpatientFactor * 0.0001) +
            (outpatientFactor * 0.00005) +
            (dentalFactor * 0.00003) +
            (opticalFactor * 0.00002) +
            (maternityFactor * 0.00004) +
            (dependentCount * 500);
      case 'travel':
        int travelers =
            int.tryParse(formData['number_of_travelers'] ?? '1') ?? 1;
        double coverageLimit =
            double.tryParse(formData['coverage_limit'] ?? '0') ?? 0;
        return basePremium + (travelers * 500) + (coverageLimit * 0.0001);
      case 'property':
        double propertyValue =
            double.tryParse(formData['property_value'] ?? '0') ?? 0;
        return basePremium + (propertyValue * factor);
      case 'wiba':
        int employees =
            int.tryParse(formData['number_of_employees'] ?? '1') ?? 1;
        double coverageLimit =
            double.tryParse(formData['coverage_limit'] ?? '0') ?? 0;
        return basePremium + (employees * 300) + (coverageLimit * 0.0001);
      default:
        return basePremium;
    }
  }

  Future<bool> _initiateMpesaPayment(String phoneNumber, double amount) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest',
        ),
        headers: {
          'Authorization': 'Bearer $mpesaApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'BusinessShortCode': '174379',
          'Password': 'your-mpesa-password',
          'Timestamp': DateTime.now().toIso8601String(),
          'TransactionType': 'CustomerPayBillOnline',
          'Amount': amount,
          'PartyA': phoneNumber,
          'PartyB': '174379',
          'PhoneNumber': phoneNumber,
          'CallBackURL': 'https://your-callback-url.com',
          'AccountReference': 'InsurancePayment',
          'TransactionDesc': 'Policy Payment',
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('MPESA Payment Failed: ${response.body}')),
        );
        return false;
      }
    } catch (e) {
      print('MPESA payment error: $e');
      return false;
    }
  }

  Future<bool> _initiatePaystackPayment(double amount, bool autoBilling) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.paystack.co/transaction/initialize'),
        headers: {
          'Authorization': 'Bearer $paystackSecretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount':
              (amount * 100).toInt(), // Amount in kobo (100 kobo = 1 Naira)
          'currency': 'KES',
          'email': userDetails['email'] ?? '', // The email of the user
          'callback_url':
              'https://your-callback-url.com', // Callback after payment
        }),
      );

      if (response.statusCode == 200) {
        final transaction = jsonDecode(response.body);
        final accessCode = transaction['data']['access_code'];
        final paymentUrl = transaction['data']['authorization_url'];

        // Open the Paystack payment page in a browser (or webview in the app)
        await launchUrl(Uri.parse(paymentUrl));

        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paystack Payment Failed: ${response.body}')),
        );
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Paystack payment error: $e');
      }
      return false;
    }
  }

  Future<void> _schedulePaystackAutoBilling(Cover cover) async {
    try {
      final customerResponse = await http.post(
        Uri.parse('https://api.paystack.co/customer'),
        headers: {
          'Authorization': 'Bearer $paystackSecretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': cover.formData!['email'],
          'first_name': cover.formData!['name'],
        }),
      );

      if (customerResponse.statusCode == 200) {
        final customer = jsonDecode(customerResponse.body);
        final customerId = customer['data']['id'];

        final planResponse = await http.post(
          Uri.parse('https://api.paystack.co/plan'),
          headers: {
            'Authorization': 'Bearer $paystackSecretKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'name': '${cover.id}_plan',
            'amount': (cover.premium! * 100).toInt(), // Amount in kobo
            'interval':
                cover.billingFrequency == 'monthly' ? 'monthly' : 'yearly',
          }),
        );

        if (planResponse.statusCode == 200) {
          final plan = jsonDecode(planResponse.body);
          final planId = plan['data']['id'];

          final subscriptionResponse = await http.post(
            Uri.parse('https://api.paystack.co/subscription'),
            headers: {
              'Authorization': 'Bearer $paystackSecretKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'customer': customerId,
              'plan': planId,
            }),
          );

          if (subscriptionResponse.statusCode == 200) {
            final subscription = jsonDecode(subscriptionResponse.body);
            final subscriptionId = subscription['data']['id'];

            final key = encrypt.Key.fromLength(32);
            final iv = encrypt.IV.fromLength(16);
            final encrypter = encrypt.Encrypter(encrypt.AES(key));
            final encrypted = encrypter.encrypt(
              jsonEncode({
                'coverId': cover.id,
                'customerId': customerId,
                'subscriptionId': subscriptionId,
                'amount': cover.premium,
                'frequency': cover.billingFrequency,
              }),
              iv: iv,
            );

            await secureStorage.write(
              key: 'billing_${cover.id}',
              value: encrypted.base64,
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Paystack auto-billing error: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set up auto-billing: $e')),
      );
    }
  }

  Future<void> _autofillDMVICWebsiteForMotorInsurance(String registrationNumber,
      String vehicleType, BuildContext context) async {
    // Step 1: Fetch login details from secure storage
    final loginEmail = 'loginemail@gmail.com';
    final password = 'your-password';

    // Open the DMVIC website in a WebView
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DMVICWebViewPage(
          registrationNumber: registrationNumber,
          vehicleType: vehicleType,
          email: loginEmail,
          password: password,
        ),
      ),
    );
  }

  Future<void> _sendEmail(
    String company,
    String insuranceType,
    String insuranceSubtype,
    Map<String, String> formData,
    File filledPdf,
    String registrationNumber,
    String vehicleType,
  ) async {
    if (insuranceType == 'motor') {
      // Trigger the autofill method when insurance type is motor
      await _autofillDMVICWebsiteForMotorInsurance(
          registrationNumber, vehicleType, context);
    }

    // Step 8: Send email logic (this part remains unchanged)
    final smtpServer = gmail(
      'your-email@gmail.com',
      'your-app-specific-password',
    );

    final message = mailer.Message()
      ..from = const mailer.Address('your-email@gmail.com', 'Insurance App')
      ..recipients.add(
        policyCalculators[insuranceType]![insuranceSubtype]!['companyA']![
            'email'],
      )
      ..subject =
          'Insurance Form Submission: $insuranceSubtype ($insuranceType)'
      ..html =
          '<h3>Form Submission Details</h3><ul>${formData.entries.map((e) => '<li>${e.key}: ${e.value}</li>').join('')}</ul>'
      ..attachments.add(
        mailer.FileAttachment(filledPdf, fileName: 'filled_form.pdf'),
      );

    try {
      final sendReport = await mailer.send(message, smtpServer);
      if (kDebugMode) {
        print('Email sent: ${sendReport.toString()}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Form details and PDF sent to company email'),
        ),
      );
      _logAction(
        'Email sent to $company for $insuranceSubtype ($insuranceType)',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error sending email: $e');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to send email')));
      _logAction('Email failed: $e');
    }
  }

  void _logAction(String action) async {
    final directory = await getApplicationDocumentsDirectory();
    final logFile = File('${directory.path}/app.log');
    await logFile.writeAsString(
      '${DateTime.now()}: $action\n',
      mode: FileMode.append,
    );
  }

  Future<void> _saveCovers() async {
    final storage = FlutterSecureStorage();
    await storage.write(
      key: 'covers',
      value: jsonEncode(covers.map((c) => c.toJson()).toList()),
    );
  }

  // Navigation handler
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Widget for each navigation screen
  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeScreen(
          context,
          pdfTemplateKey,
          GlobalKey<ScaffoldMessengerState>(),
          [], // Provide a list of PolicyType or your cachedPolicyTypes variable if available
        );
      case 1:
        return _buildQuotesScreen();
      case 2:
        return _buildUpcomingScreen();
      case 3:
        return _buildMyAccountScreen(context);
      default:
        return _buildHomeScreen(
          context,
          pdfTemplateKey,
          GlobalKey<ScaffoldMessengerState>(),
          [], // Provide a list of PolicyType or your cachedPolicyTypes variable if available
        );
    }
  }

  Widget _buildHomeScreen(
    BuildContext context,
    String pdfTemplateKey,
    GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
    List<PolicyType> cachedPolicyTypes,
  ) {
    // Cache for getInsuranceConfigs results
    final Map<String, Map<String, List<DialogStepConfig>>> configCache = {};

    return Consumer<DialogState>(builder: (context, dialogState, _) {
      return Scaffold(
        key: scaffoldMessengerKey,
        body: FutureBuilder<List<PolicyType>>(
          future: Future.value(cachedPolicyTypes),
          builder: (context, snapshot) {
            if (kDebugMode) {
              print('Policy FutureBuilder: state=${snapshot.connectionState}, '
                  'data=${snapshot.data?.map((p) => p.name).toList()}, error=${snapshot.error}');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              if (kDebugMode) {
                print('Error fetching policies: ${snapshot.error}');
              }
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: ${snapshot.error}',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => (context as Element).markNeedsBuild(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 6,
                        shadowColor: Theme.of(context)
                            .colorScheme
                            .shadow
                            .withOpacity(0.3),
                      ),
                      child: Text(
                        'Retry',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final policyTypes = snapshot.data?.isNotEmpty == true
                ? snapshot.data!
                : [
                    PolicyType(
                        id: '1', name: 'Motor', description: 'Motor insurance'),
                    PolicyType(
                        id: '2',
                        name: 'Medical',
                        description: 'Medical insurance'),
                    PolicyType(
                        id: '3',
                        name: 'Travel',
                        description: 'Travel insurance'),
                    PolicyType(
                        id: '4',
                        name: 'Property',
                        description: 'Property insurance'),
                    PolicyType(
                        id: '5', name: 'WIBA', description: 'WIBA insurance'),
                  ];

            if (kDebugMode) {
              print('Policy types: ${policyTypes.map((p) => p.name).toList()}');
            }

            final currentType = dialogState.currentType;
            final dialogIndex = dialogState.currentStep;

            return CustomScrollView(
              slivers: [
                if (!kIsWeb)
                  SliverAppBar(
                    pinned: true,
                    title: Text(
                      'BIMA GUARDIAN',
                      style: GoogleFonts.lora(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    elevation: 8,
                    shadowColor:
                        Theme.of(context).colorScheme.shadow.withOpacity(0.3),
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                    actions: [
                      if (userRole == UserRole.admin)
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.admin_panel_settings,
                              color: Theme.of(context).colorScheme.onPrimary,
                              semanticLabel: 'Admin Panel',
                            ),
                          ),
                          onPressed: () =>
                              Navigator.pushNamed(context, '/admin'),
                          tooltip: 'Admin Panel',
                        ),
                      Stack(
                        children: [
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.notifications,
                                color: Theme.of(context).colorScheme.onPrimary,
                                semanticLabel: 'Notifications',
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NotificationsScreen(
                                      notifications: notifications ?? []),
                                ),
                              );
                            },
                            tooltip: 'Notifications',
                          ),
                          if ((notifications?.length ?? 0) > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .shadow
                                          .withOpacity(0.2),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                constraints: const BoxConstraints(
                                    minWidth: 20, minHeight: 20),
                                child: Text(
                                  '${notifications?.length ?? 0}',
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onError,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withOpacity(
                                    currentType.isNotEmpty ? 0.2 : 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.save,
                            color: currentType.isNotEmpty
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context)
                                    .colorScheme
                                    .onPrimary
                                    .withOpacity(0.5),
                            semanticLabel: 'Save Progress',
                          ),
                        ),
                        onPressed: currentType.isNotEmpty
                            ? () {
                                dialogState.saveProgress(
                                    currentType, dialogIndex);
                                scaffoldMessengerKey.currentState?.showSnackBar(
                                  const SnackBar(
                                      content: Text('Progress saved')),
                                );
                              }
                            : null,
                        tooltip: 'Save progress',
                      ),
                    ],
                  ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CarouselSlider(
                        options: CarouselOptions(
                          height: 180.0, // Reduced height to prevent overflow
                          autoPlay: true,
                          autoPlayInterval: const Duration(seconds: 3),
                          enlargeCenterPage: true,
                          viewportFraction: 0.9,
                          aspectRatio: 2.0,
                        ),
                        items: [
                          'banners/promo1.jpg',
                          'banners/promo2.jpg',
                          'banners/promo3.jpg',
                        ].asMap().entries.map((entry) {
                          final index = entry.key;
                          final imagePath = entry.value;
                          return Builder(
                            builder: (BuildContext context) {
                              return Container(
                                width: MediaQuery.of(context).size.width,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .shadow
                                          .withOpacity(0.2),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.asset(
                                    imagePath,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      //if (kDebugMode) {
                                        //print('Image load error: $error');
                                      //}
                                      return Container(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.2),
                                        child: Center(
                                          child: Text(
                                            'Promo ${index + 1}',
                                            style: GoogleFonts.lora(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      if (currentType.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: FutureBuilder<
                              Map<String, List<DialogStepConfig>>>(
                            future: configCache.containsKey(currentType)
                                ? Future.value(configCache[currentType])
                                : getInsuranceConfigs(
                                        currentType)
                                    .timeout(const Duration(seconds: 100),
                                        onTimeout: () {
                                    if (kDebugMode) {
                                      print('Config FutureBuilder timed out');
                                    }
                                    return {
                                      currentType: [
                                        DialogStepConfig(
                                          title: 'Default $currentType Config',
                                          fields: [
                                            FieldConfig(
                                              key: 'subtype',
                                              label: 'Subtype',
                                              type: 'dropdown',
                                              options: ['Standard', 'Premium'],
                                              validator: (value) => value !=
                                                      null
                                                  ? null
                                                  : 'Please select a subtype',
                                            ),
                                          ],
                                          customCallback:
                                              (context, dialogState) async {},
                                        ),
                                      ],
                                    };
                                  }).then((configs) {
                                    configCache[currentType] = configs;
                                    return configs;
                                  }),
                            builder: (context, snapshot) {
                              if (kDebugMode) {
                                print(
                                    'Config FutureBuilder: state=${snapshot.connectionState}, '
                                    'data=${snapshot.data?.keys.toList()}, error=${snapshot.error}');
                              }
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return LinearProgressIndicator(
                                  value: null,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainer,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                );
                              }
                              if (snapshot.hasError) {
                                if (kDebugMode) {
                                  print(
                                      'Error in config FutureBuilder: ${snapshot.error}');
                                }
                                return const SizedBox.shrink();
                              }
                              final dialogCount =
                                  snapshot.data?[currentType]?.length ?? 1;
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Theme.of(context).colorScheme.surface,
                                ),
                                child: LinearProgressIndicator(
                                  value: (dialogIndex + 1) /
                                      dialogCount.clamp(1, double.infinity),
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.3),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(8),
                                  semanticsLabel:
                                      'Progress: ${((dialogIndex + 1) / dialogCount * 100).toStringAsFixed(0)}%',
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Select Your Insurance Cover',
                          style: GoogleFonts.lora(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.4, // Adjusted to prevent overflow
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: (policyTypes).length,
                        itemBuilder: (context, index) {
                          if (kDebugMode) {
                            print(
                                'Building grid item $index: ${policyTypes[index].name}');
                          }
                          final policyType = policyTypes[index];
                          final icon = getCustomEmojiWidget(policyType.icon) ??
                              fallbackEmojiWidget(
                                  policyType.name.toLowerCase());
                          return InkWell(
                            onTap: () async {
                              if (kDebugMode) {
                                print('Tapped policy: ${policyType.name}');
                              }
                              try {
                                await showInsuranceDialog(
                                  context,
                                  policyType.name,
                                  scaffoldMessengerKey: scaffoldMessengerKey,
                                  onFinalSubmit: null,
                                );
                              } catch (e) {
                                if (kDebugMode) {
                                  print('Error in showInsuranceDialog: $e');
                                }
                                scaffoldMessengerKey.currentState?.showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Failed to show dialog: $e')),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Card(
                              elevation: 8,
                              shadowColor: Theme.of(context)
                                  .colorScheme
                                  .shadow
                                  .withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .shadow
                                          .withOpacity(0.2),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(
                                    12.0), // Reduced padding
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(
                                          10.0), // Reduced icon padding
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: icon,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      policyType.name.toUpperCase(),
                                      style: GoogleFonts.roboto(
                                        fontSize: 14, // Reduced font size
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    });
  }

// Returns a Text widget with the appropriate emoji
  Widget? getCustomEmojiWidget(String? iconName) {
    if (iconName == null) {
      return const Text('🔧', style: TextStyle(fontSize: 24));
    }
    switch (iconName.toLowerCase()) {
      case 'MOTOR':
        return const Text('🚘', style: TextStyle(fontSize: 24));
      case 'MEDICAL':
        return const Text('🏥', style: TextStyle(fontSize: 24));
      case 'TRAVEL':
        return const Text('✈️', style: TextStyle(fontSize: 24));
      case 'PROPERTY':
        return const Text('🏠', style: TextStyle(fontSize: 24));
      case 'WIBA':
        return const Text('💼', style: TextStyle(fontSize: 24));
      default:
        return const Text('🔧', style: TextStyle(fontSize: 24));
    }
  }

// Fallback version also returns emoji as Text widget
  Widget fallbackEmojiWidget(String type) {
    switch (type.toLowerCase()) {
      case 'MOTOR':
        return const Text('🚘', style: TextStyle(fontSize: 24));
      case 'MEDICAL':
        return const Text('🏥', style: TextStyle(fontSize: 24));
      case 'TRAVEL':
        return const Text('✈️', style: TextStyle(fontSize: 24));
      case 'PROPERTY':
        return const Text('🏠', style: TextStyle(fontSize: 24));
      case 'WIBA':
        return const Text('💼', style: TextStyle(fontSize: 24));
      default:
        return const Text('🔧', style: TextStyle(fontSize: 24));
    }
  }

  Widget _buildMyAccountScreen(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Account'),
        elevation: 4,
        shadowColor: Colors.grey.withOpacity(0.5),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Settings-style grouped list
              Card(
                elevation: 4,
                shadowColor: Colors.grey.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                margin:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    // Policy Reports Row
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12.0),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const CoverReportScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey[300]!,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.description_outlined,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Policy Reports',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        fontSize: 16,
                                      ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.arrow_forward_ios,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Theme Toggle Row
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.dark_mode_outlined,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Dark Mode',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    fontSize: 16,
                                  ),
                            ),
                          ),
                          Switch(
                            value: themeProvider.themeMode == ThemeMode.dark,
                            onChanged: (value) {
                              themeProvider.toggleTheme(value);
                            },
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Logout Button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    elevation: 4,
                    shadowColor: Colors.grey.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: () async {
                    try {
                      await FirebaseAuth.instance.signOut();
                      if (kDebugMode) {
                        print('User signed out');
                      }
                      await FirebaseAuth.instance.signInAnonymously();
                    } catch (e) {
                      if (kDebugMode) {
                        print('Error signing out: $e');
                      }
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          title: const Text('Error'),
                          content: Text('Failed to sign out: $e'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  child: Text(
                    'Log Out',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuotesScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotes'),
        elevation: 4,
        shadowColor: Colors.grey.withOpacity(0.5),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        itemCount: quotes.length,
        itemBuilder: (context, index) {
          final quote = quotes[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Card(
              elevation: 4,
              shadowColor: Colors.grey.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16.0),
                title: Text(
                  '${quote.type} - ${quote.subtype}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  'Premium: KES ${quote.premium.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${quote.generatedAt.day}/${quote.generatedAt.month}/${quote.generatedAt.year}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      title: Text('${quote.type} - ${quote.subtype}'),
                      content: Text(
                        'Premium: KES ${quote.premium.toStringAsFixed(2)}\nGenerated: ${quote.generatedAt.day}/${quote.generatedAt.month}/${quote.generatedAt.year}',
                      ),
                      actions: [
                        TextButton(
                          child: const Text('Close'),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUpcomingScreen() {
    final upcomingPolicies = policies.where((policy) {
      if (policy.endDate == null) return false;
      final daysUntilExpiration =
          policy.endDate!.difference(DateTime.now()).inDays;
      return daysUntilExpiration <= 30 && daysUntilExpiration > 0;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Expirations'),
        elevation: 4,
        shadowColor: ThemeData().colorScheme.shadow.withOpacity(0.5),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        itemCount: upcomingPolicies.length,
        itemBuilder: (context, index) {
          final policy = upcomingPolicies[index];
          final daysUntilExpiration =
              policy.endDate!.difference(DateTime.now()).inDays;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Card(
              elevation: 4,
              shadowColor: Colors.grey.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16.0),
                title: Text(
                  '${policy.type} - ${policy.subtype}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  'Expires in $daysUntilExpiration days',
                  style: TextStyle(
                    fontSize: 14,
                    color: daysUntilExpiration <= 7
                        ? Colors.red
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: daysUntilExpiration <= 7
                            ? Colors.red
                            : Colors.amber,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      title: Text('${policy.type} - ${policy.subtype}'),
                      content: Text('Expires in $daysUntilExpiration days'),
                      actions: [
                        TextButton(
                          child: const Text('Close'),
                          onPressed: () => Navigator.pop(context),
                        ),
                        TextButton(
                          child: const Text('Renew'),
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Renewal initiated')),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> fetchTrendingTopics() async {
    setState(() {
      trendingTopics = [
        'Insurance in Kenya: The Future',
        'Top Insurance Companies in Kenya',
        'Health Insurance in Kenya: Trends and Updates',
      ];
    });
  }

  Future<void> fetchBlogPosts() async {
    setState(() {
      blogPosts = [
        '5 Tips for Choosing the Right Health Insurance in Kenya',
        'How to Save on Car Insurance Premiums in Kenya',
        'The Importance of Life Insurance in Kenya: A Growing Need',
      ];
    });
  }

// Add this method inside _InsuranceHomeScreenState
  Widget _buildNotificationButton(BuildContext context) {
    return IconButton(
      icon: Stack(
        children: [
          Icon(Icons.notifications,
              size: 30, color: const Color.fromARGB(221, 148, 183, 82)),
          if (notifications.isNotEmpty)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  '${notifications.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      tooltip: 'Notifications',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                NotificationsScreen(notifications: notifications),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return kIsWeb
        ? LayoutBuilder(
            builder: (context, constraints) {
              bool isDesktop = constraints.maxWidth > 800;

              return Scaffold(
                backgroundColor: Colors.white,
                appBar: AppBar(
                  title: const Text('BIMA GUARDIAN'),
                  backgroundColor: Theme.of(context).primaryColor,
                  elevation: 4,
                  shadowColor: ThemeData().colorScheme.shadow.withOpacity(0.5),
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  actions:
                      isDesktop ? [_buildNotificationButton(context)] : null,
                  leading: isDesktop
                      ? null
                      : Builder(
                          builder: (BuildContext drawerContext) {
                            return IconButton(
                              icon: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(Icons.menu, size: 30),
                              ),
                              onPressed: () {
                                Scaffold.of(drawerContext).openDrawer();
                              },
                            );
                          },
                        ),
                ),
                drawer: isDesktop
                    ? null
                    : Drawer(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SafeArea(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'BIMA GUARDIAN',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).secondaryHeaderColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ListTile(
                                leading: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(Icons.home, size: 24),
                                ),
                                title: const Text('Home'),
                                onTap: () {
                                  _onItemTapped(0);
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                leading: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(Icons.description, size: 24),
                                ),
                                title: const Text('Quotes'),
                                onTap: () {
                                  _onItemTapped(1);
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                leading: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(Icons.hourglass_empty, size: 24),
                                ),
                                title: const Text('Upcoming'),
                                onTap: () {
                                  _onItemTapped(2);
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                leading: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(Icons.account_circle, size: 24),
                                ),
                                title: const Text('My Account'),
                                onTap: () {
                                  _onItemTapped(3);
                                  Navigator.pop(context);
                                },
                              ),
                              if (userRole == UserRole.admin)
                                ListTile(
                                  leading: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(Icons.admin_panel_settings,
                                        size: 24),
                                  ),
                                  title: const Text('Admin Panel'),
                                  onTap: () {
                                    Navigator.pushNamed(context, '/admin');
                                    Navigator.pop(context);
                                  },
                                ),
                              ListTile(
                                leading: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(Icons.notifications, size: 24),
                                ),
                                title: const Text('Notifications'),
                                onTap: () {
                                  // Implement notification logic
                                  Navigator.pop(context,
                                      (_buildNotificationButton(context)));
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                body: Row(
                  children: [
                    if (isDesktop)
                      Container(
                        width: 280,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(16),
                            bottomRight: Radius.circular(28),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              blurRadius: 12,
                              offset: Offset(2, 0),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            _buildNavItem(
                              context,
                              icon: Icons.home,
                              title: 'Home',
                              onTap: () => _onItemTapped(0),
                            ),
                            _buildNavItem(
                              context,
                              icon: Icons.description,
                              title: 'Quotes',
                              onTap: () => _onItemTapped(1),
                            ),
                            _buildNavItem(
                              context,
                              icon: Icons.hourglass_empty,
                              title: 'Upcoming',
                              onTap: () => _onItemTapped(2),
                            ),
                            _buildNavItem(
                              context,
                              icon: Icons.account_circle,
                              title: 'My Account',
                              onTap: () => _onItemTapped(3),
                            ),
                            if (userRole == UserRole.admin)
                              _buildNavItem(
                                context,
                                icon: Icons.admin_panel_settings,
                                title: 'Admin Panel',
                                onTap: () =>
                                    Navigator.pushNamed(context, '/admin'),
                              ),
                          ],
                        ),
                      ),
                    Expanded(child: _getSelectedScreen()),
                    if (isDesktop)
                      Container(
                        width: 280,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black,
                              blurRadius: 12,
                              offset: Offset(-2, 0),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trending in Insurance',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                trendingTopics.isNotEmpty
                                    ? ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: trendingTopics.length,
                                        itemBuilder: (context, index) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                            child: Card(
                                              elevation: 4,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: ListTile(
                                                title: Text(
                                                  trendingTopics[index]
                                                      .toString()
                                                      .split('.')
                                                      .last, // Convert PolicyType to String
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : const Center(
                                        child: CircularProgressIndicator()),
                                const SizedBox(height: 24),
                                Text(
                                  'Learn more about Insurance',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                blogPosts.isNotEmpty
                                    ? ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: blogPosts.length,
                                        itemBuilder: (context, index) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                            child: Card(
                                              elevation: 4,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: ListTile(
                                                title: Text(
                                                  blogPosts[index]
                                                      .toString()
                                                      .split('.')
                                                      .last, // Convert PolicyType to String
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : const Center(
                                        child: CircularProgressIndicator()),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () {
                    if (kDebugMode) {
                      print('Chat button pressed');
                    }
                    _showChatBottomSheet(context);
                  },
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.chat, size: 30),
                  ),
                ),
              );
            },
          )
        : Scaffold(
            backgroundColor: Colors.white,
            body: _getSelectedScreen(),
            bottomNavigationBar: BottomNavigationBar(
              items: const [
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.home, size: 30),
                  ),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.description, size: 30),
                  ),
                  label: 'Quotes',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.hourglass_empty, size: 30),
                  ),
                  label: 'Upcoming',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.account_circle, size: 30),
                  ),
                  label: 'My Account',
                ),
              ],
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: Theme.of(context).primaryColor,
              unselectedItemColor: Colors.grey,
              elevation: 8,
              backgroundColor: Colors.white,
              type: BottomNavigationBarType.fixed,
              showSelectedLabels: true,
              showUnselectedLabels: true,
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                if (kDebugMode) {
                  print('Chat button pressed');
                }
                _showChatBottomSheet(context);
              },
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.chat, size: 30),
              ),
            ),
          );
  }

// Updated _buildNavItem to match Material Design with elevation and rounded corners
  Widget _buildNavItem(BuildContext context,
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(icon, size: 24),
          ),
          title: Text(title),
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

// _showChatBottomSheet (unchanged)
  void _showChatBottomSheet(BuildContext context) {
    final TextEditingController chatController = TextEditingController();
    final List<String> chatMessages = [];
    String? pdfTemplateKey;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Chat with BIMA Bot',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    selectionColor: Colors.blue,
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: chatMessages.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(chatMessages[index]),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: chatController,
                          decoration: InputDecoration(
                            hintText:
                                'Type an insurance type (e.g., motor, medical)...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () async {
                          final input =
                              chatController.text.trim().toLowerCase();
                          if (input.isEmpty) return;

                          setState(() {
                            chatMessages.add('You: $input');
                            chatController.clear();
                          });

                          // Fetch policy types to validate input
                          final policyTypes =
                              await InsuranceHomeScreen.getPolicyTypes();
                          final validType = policyTypes.firstWhere(
                            (type) => type.name.toLowerCase() == input,
                            orElse: () =>
                                PolicyType(id: '', name: '', description: ''),
                          );

                          if (validType.id.isNotEmpty) {
                            setState(() {
                              chatMessages.add(
                                  'Bot: Starting $input insurance flow...');
                            });

                            // Trigger showInsuranceDialog
                            if (context.mounted) {
                              Navigator.pop(context); // Close bottom sheet
                              showInsuranceDialog(
                                context,
                                input,
                                onFinalSubmit:
                                    (context, type, subtype, coverage) {
                                  // Save policy to Firestore or update UI
                                  if (kDebugMode) {
                                    print(
                                        'Policy created: $type, $subtype, $coverage');
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Policy created for $type'),
                                    ),
                                  );
                                },
                                scaffoldMessengerKey:
                                    GlobalKey<ScaffoldMessengerState>(),
                              );
                            }
                          } else {
                            setState(() {
                              chatMessages.add(
                                  'Bot: Invalid insurance type. Try motor, medical, etc.');
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

Future<void> _showInsuredItemDialog(
  BuildContext context,
  PolicyType type,
  PolicySubtype subtype,
  CoverageType coverageType,
) async {
  String? insuredItemId;
  bool createNew = insuredItems.isEmpty;

  // Fetch pdfTemplateKey
  String? pdfTemplateKey;
  if (coverageType.pdfTemplateKey != null) {
    pdfTemplateKey = coverageType.pdfTemplateKey;
  } else if (subtype.pdfTemplateKey != null) {
    pdfTemplateKey = subtype.pdfTemplateKey;
  } else {
    pdfTemplateKey = type.pdfTemplateKey;
  }

  const List<String> inpatientLimits = ['100000', '500000', '1000000', '2000000'];
  const List<String> medicalServices = ['general', 'surgery', 'dental', 'optical', 'maternity'];
  const List<String> underwriters = ['Aetna', 'Cigna', 'UnitedHealth', 'Humana', 'Kaiser'];
  const List<String> vehicleTypes = ['private', 'commercial', 'motorcycle', 'psv'];

  // Field definitions (unchanged from provided code)
  final Map<String, FieldDefinition> travelFields = {
    'name': FieldDefinition(
      expectedType: ExpectedType.name,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value) ? null : 'Invalid name',
    ),
    'email': FieldDefinition(
      expectedType: ExpectedType.email,
      validator: (value) => value.isEmpty ||
              RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(value)
          ? null
          : 'Invalid email',
    ),
    'phone': FieldDefinition(
      expectedType: ExpectedType.phone,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value) ? null : 'Invalid phone number',
    ),
    'destination': FieldDefinition(
      expectedType: ExpectedType.text,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[A-Za-z\s\,\-]+$').hasMatch(value)
              ? null
              : 'Invalid destination (use letters, commas, or hyphens)',
    ),
    'travel_start_date': FieldDefinition(
      expectedType: ExpectedType.text,
      validator: (value) {
        if (value.isEmpty) return null;
        try {
          DateTime.parse(value);
          return null;
        } catch (e) {
          return 'Invalid date format (use YYYY-MM-DD)';
        }
      },
    ),
    'travel_end_date': FieldDefinition(
      expectedType: ExpectedType.text,
      validator: (value) {
        if (value.isEmpty) return null;
        try {
          DateTime.parse(value);
          return null;
        } catch (e) {
          return 'Invalid date format (use YYYY-MM-DD)';
        }
      },
    ),
    'number_of_travelers': FieldDefinition(
      expectedType: ExpectedType.number,
      validator: (value) {
        if (value.isEmpty) return null;
        int? val = int.tryParse(value);
        return val != null && val >= 1 ? null : 'Must have at least 1 traveler';
      },
    ),
    'coverage_limit': FieldDefinition(
      expectedType: ExpectedType.number,
      validator: (value) {
        if (value.isEmpty) return null;
        double? val = double.tryParse(value);
        return val != null && val >= 0 ? null : 'Invalid coverage limit';
      },
    ),
  };

  final Map<String, FieldDefinition> wibaFields = {
    'name': FieldDefinition(
      expectedType: ExpectedType.name,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value) ? null : 'Invalid name',
    ),
    'email': FieldDefinition(
      expectedType: ExpectedType.email,
      validator: (value) => value.isEmpty ||
              RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(value)
          ? null
          : 'Invalid email',
    ),
    'phone': FieldDefinition(
      expectedType: ExpectedType.phone,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value) ? null : 'Invalid phone number',
    ),
    'business_name': FieldDefinition(
      expectedType: ExpectedType.text,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[A-Za-z0-9\s\-\.]+$').hasMatch(value)
              ? null
              : 'Invalid business name',
    ),
    'number_of_employees': FieldDefinition(
      expectedType: ExpectedType.number,
      validator: (value) {
        if (value.isEmpty) return null;
        int? val = int.tryParse(value);
        return val != null && val >= 1 ? null : 'Must have at least 1 employee';
      },
    ),
    'coverage_limit': FieldDefinition(
      expectedType: ExpectedType.number,
      validator: (value) {
        if (value.isEmpty) return null;
        double? val = double.tryParse(value);
        return val != null && val >= 0 ? null : 'Invalid coverage limit';
      },
    ),
    'industry_type': FieldDefinition(
      expectedType: ExpectedType.text,
      validator: (value) => ['construction', 'manufacturing', 'services', 'retail'].contains(value)
          ? null
          : 'Invalid industry type',
    ),
  };

  final Map<String, FieldDefinition> propertyFields = {
    'name': FieldDefinition(
      expectedType: ExpectedType.name,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value) ? null : 'Invalid name',
    ),
    'email': FieldDefinition(
      expectedType: ExpectedType.email,
      validator: (value) => value.isEmpty ||
              RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(value)
          ? null
          : 'Invalid email',
    ),
    'phone': FieldDefinition(
      expectedType: ExpectedType.phone,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value) ? null : 'Invalid phone number',
    ),
    'property_value': FieldDefinition(
      expectedType: ExpectedType.number,
      validator: (value) {
        if (value.isEmpty) return null;
        double? val = double.tryParse(value);
        return val != null && val > 0 ? null : 'Invalid property value';
      },
    ),
    'property_type': FieldDefinition(
      expectedType: ExpectedType.text,
      validator: (value) => ['residential', 'commercial', 'industrial', 'landlord'].contains(value)
          ? null
          : 'Invalid property type',
    ),
    'property_location': FieldDefinition(
      expectedType: ExpectedType.text,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[A-Za-z0-9\s\,\.\-]+$').hasMatch(value)
              ? null
              : 'Invalid location (use letters, numbers, commas, or periods)',
    ),
    'deed_number': FieldDefinition(
      expectedType: ExpectedType.text,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[A-Za-z0-9\-\/]{5,20}$').hasMatch(value)
              ? null
              : 'Invalid deed number (5-20 alphanumeric characters)',
    ),
    'construction_year': FieldDefinition(
      expectedType: ExpectedType.number,
      validator: (value) {
        if (value.isEmpty) return null;
        int? val = int.tryParse(value);
        return val != null && val >= 1900 && val <= DateTime.now().year
            ? null
            : 'Invalid construction year';
      },
    ),
  };

  final Map<String, FieldDefinition> medicalFields = {
    'name': FieldDefinition(
      expectedType: ExpectedType.name,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value) ? null : 'Invalid name',
    ),
    'email': FieldDefinition(
      expectedType: ExpectedType.email,
      validator: (value) => value.isEmpty ||
              RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(value)
          ? null
          : 'Invalid email',
    ),
    'phone': FieldDefinition(
      expectedType: ExpectedType.phone,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value) ? null : 'Invalid phone number',
    ),
    'age': FieldDefinition(
      expectedType: ExpectedType.number,
      validator: (value) {
        if (value.isEmpty) return null;
        int? val = int.tryParse(value);
        return val != null && val >= 0 && val <= 120 ? null : 'Invalid age';
      },
    ),
    'spouse_age': FieldDefinition(
      expectedType: ExpectedType.number,
      validator: (value) {
        if (value.isEmpty) return null;
        int? val = int.tryParse(value);
        return val != null && val >= 0 && val <= 120 ? null : 'Invalid spouse age';
      },
    ),
    'children_count': FieldDefinition(
      expectedType: ExpectedType.number,
      validator: (value) {
        if (value.isEmpty) return null;
        int? val = int.tryParse(value);
        return val != null && val >= 0 ? null : 'Invalid number of children';
      },
    ),
    'pre_existing_conditions': FieldDefinition(
      expectedType: ExpectedType.text,
      validator: (value) => null,
    ),
    'beneficiaries': FieldDefinition(
      expectedType: ExpectedType.number,
      validator: (value) {
        if (value.isEmpty) return null;
        int? val = int.tryParse(value);
        return val != null && val >= 1 ? null : 'At least 1 beneficiary is required';
      },
    ),
    'inpatient_limit': FieldDefinition(
      expectedType: ExpectedType.text,
      validator: (value) => value.isEmpty || inpatientLimits.contains(value) ? null : 'Invalid inpatient limit',
    ),
    'outpatient_limit': FieldDefinition(
      expectedType: ExpectedType.number,
      validator: (value) {
        if (value.isEmpty) return null;
        double? val = double.tryParse(value);
        return val != null && val >= 0 ? null : 'Invalid outpatient limit';
      },
    ),
    'dental_limit': FieldDefinition(
      expectedType: ExpectedType.number,
      validator: (value) {
        if (value.isEmpty) return null;
        double? val = double.tryParse(value);
        return val != null && val >= 0 ? null : 'Invalid dental limit';
      },
    ),
    'optical_limit': FieldDefinition(
      expectedType: ExpectedType.number,
      validator: (value) {
        if (value.isEmpty) return null;
        double? val = double.tryParse(value);
        return val != null && val >= 0 ? null : 'Invalid optical limit';
      },
    ),
    'maternity_limit': FieldDefinition(
      expectedType: ExpectedType.number,
      validator: (value) {
        if (value.isEmpty) return null;
        double? val = double.tryParse(value);
        return val != null && val >= 0 ? null : 'Invalid maternity limit';
      },
    ),
    'medical_services': FieldDefinition(
      expectedType: ExpectedType.list,
      listItemType: ExpectedType.text,
      validator: (value) {
        if (value.isEmpty) return null;
        var services = value.split(', ').map((s) => s.trim()).toList();
        return services.every((s) => medicalServices.contains(s)) ? null : 'Invalid medical services';
      },
    ),
    'underwriters': FieldDefinition(
      expectedType: ExpectedType.list,
      listItemType: ExpectedType.text,
      validator: (value) {
        if (value.isEmpty) return null;
        var selected = value.split(', ').map((s) => s.trim()).toList();
        return selected.length <= 3 && selected.every((s) => underwriters.contains(s))
            ? null
            : 'Select up to 3 valid underwriters';
      },
    ),
  };

  final Map<String, FieldDefinition> motorFields = {
    'name': FieldDefinition(
      expectedType: ExpectedType.name,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value) ? null : 'Invalid name',
    ),
    'email': FieldDefinition(
      expectedType: ExpectedType.email,
      validator: (value) => value.isEmpty ||
              RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(value)
          ? null
          : 'Invalid email',
    ),
    'phone': FieldDefinition(
      expectedType: ExpectedType.phone,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value) ? null : 'Invalid phone number',
    ),
    'chassis_number': FieldDefinition(
      expectedType: ExpectedType.text,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[A-Za-z0-9\-]{10,20}$').hasMatch(value)
              ? null
              : 'Invalid chassis number (10-20 alphanumeric characters)',
    ),
    'kra_pin': FieldDefinition(
      expectedType: ExpectedType.text,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[A-Za-z0-9]{11}$').hasMatch(value)
              ? null
              : 'Invalid KRA PIN (11 alphanumeric characters)',
    ),
    'regno': FieldDefinition(
      expectedType: ExpectedType.text,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[A-Za-z0-9\s\-]{5,10}$').hasMatch(value)
              ? null
              : 'Invalid registration number (5-10 alphanumeric characters)',
    ),
    'vehicle_value': FieldDefinition(
      expectedType: ExpectedType.number,
      validator: (value) {
        if (value.isEmpty) return null;
        double? val = double.tryParse(value);
        return val != null && val > 0 ? null : 'Invalid vehicle value';
      },
    ),
    'vehicle_type': FieldDefinition(
      expectedType: ExpectedType.text,
      validator: (value) => value.isEmpty || vehicleTypes.contains(value) ? null : 'Invalid vehicle type',
    ),
  };

  // Fetch fields from PDFTemplate or use fieldMap
  Map<String, FieldDefinition> fields = {};
  if (pdfTemplateKey != null) {
    final pdfTemplate = await InsuranceHomeScreen.getPDFTemplate(pdfTemplateKey);
    if (pdfTemplate != null) {
      fields = pdfTemplate.fields;
    }
  }

  // Fallback to fieldMap
  if (fields.isEmpty) {
    fields = {
      'motor': motorFields,
      'medical': medicalFields,
      'property': propertyFields,
      'travel': travelFields,
      'wiba': wibaFields,
    }[type.name.toLowerCase()] ?? {};
  }

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text(
              'Select or Create Insured Item',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!createNew)
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Existing Insured Item',
                      labelStyle: const TextStyle(color: Color(0xFFD3D3D3)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF8B0000)),
                      ),
                    ),
                    value: insuredItemId,
                    items: insuredItems
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              '${item.details['name'] ?? 'Item'} (${item.type.toUpperCase()})',
                              style: const TextStyle(color: Color(0xFF1B263B)),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(() => insuredItemId = value),
                  ),
                if (!createNew)
                  CheckboxListTile(
                    title: const Text(
                      'Create New Insured Item',
                      style: TextStyle(color: Color(0xFF1B263B)),
                    ),
                    value: createNew,
                    onChanged: (value) => setDialogState(() => createNew = value ?? false),
                    activeColor: const Color(0xFF8B0000),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFFD3D3D3)),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CoverDetailScreen(
                        type: type.name,
                        subtype: subtype.name,
                        coverageType: coverageType.name,
                        insuredItem: insuredItemId != null
                            ? insuredItems.firstWhere(
                                (item) => item.id == insuredItemId,
                              )
                            : null,
                        fields: fields,
                        onSubmit: (details) {
                          // CoverDetailScreen handles _showCompanyDialog
                        },
                        onAutofillPreviousPolicy: autofillFromPreviousPolicy,
                        onAutofillLogbook: autofillFromLogbook,
                        showCompanyDialog: _showCompanyDialog, // <-- Added required argument
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B0000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showCompanyDialog(
  BuildContext context,
  String type,
  String subtype,
  String coverageType,
  Map<String, String> details, {
  String? preSelectedCompany,
  required String subtypeId,
  required String coverageTypeId,
}) async {
  try {
    final companies = await InsuranceHomeScreen.getCompanies();
    final cachedPdfTemplates = await InsuranceHomeScreen.getCachedPdfTemplates();
    final eligibleCompanies = companies.where((c) {
      final matchesSubtype = c.policySubtype?.id == subtypeId;
      final matchesCoverage = c.coverageType?.id == coverageTypeId;
      return matchesSubtype || matchesCoverage;
    }).toList();

    if (eligibleCompanies.isEmpty) {
      if (kDebugMode) print('No eligible companies for subtypeId: $subtypeId, coverageTypeId: $coverageTypeId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No companies available for this policy'),
          backgroundColor: Color(0xFF8B0000),
        ),
      );
      return;
    }

    // Pre-select company if provided and valid
    String companyId = preSelectedCompany != null &&
            eligibleCompanies.any((c) => c.name == preSelectedCompany)
        ? eligibleCompanies.firstWhere((c) => c.name == preSelectedCompany).id
        : eligibleCompanies.first.id;
    String pdfTemplateKey = eligibleCompanies
        .firstWhere((c) => c.id == companyId)
        .pdfTemplateKey
        .firstWhere((key) => cachedPdfTemplates.containsKey(key), orElse: () => 'default');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(
                'Select Insurance Company',
                style: GoogleFonts.lora(
                  color: const Color(0xFF1B263B),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Company',
                      labelStyle: GoogleFonts.roboto(color: const Color(0xFFD3D3D3)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF8B0000)),
                      ),
                    ),
                    value: companyId,
                    items: eligibleCompanies
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                c.name,
                                style: GoogleFonts.roboto(color: const Color(0xFF1B263B)),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) => setDialogState(() {
                      companyId = value ?? companyId;
                      final company = eligibleCompanies.firstWhere((c) => c.id == companyId);
                      pdfTemplateKey = company.pdfTemplateKey.firstWhere(
                        (key) => cachedPdfTemplates.containsKey(key),
                        orElse: () => 'default',
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'PDF Template',
                      labelStyle: GoogleFonts.roboto(color: const Color(0xFFD3D3D3)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF8B0000)),
                      ),
                    ),
                    value: pdfTemplateKey,
                    items: eligibleCompanies
                        .firstWhere((c) => c.id == companyId)
                        .pdfTemplateKey
                        .where((key) => cachedPdfTemplates.containsKey(key))
                        .map((key) => DropdownMenuItem(
                              value: key,
                              child: Text(
                                key,
                                style: GoogleFonts.roboto(color: const Color(0xFF1B263B)),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) => setDialogState(() {
                      pdfTemplateKey = value ?? pdfTemplateKey;
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.roboto(color: const Color(0xFFD3D3D3)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await FirebaseFirestore.instance.collection('form_submissions').add({
                      'user_id': details['insured_item_id'] ?? 'unknown',
                      'type': type,
                      'subtype': subtype,
                      'coverage_type': coverageType,
                      'company_id': companyId,
                      'pdf_template_key': pdfTemplateKey,
                      'details': details,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    handleCoverSubmission(
                      context,
                      type,
                      subtype,
                      coverageType,
                      companyId,
                      pdfTemplateKey,
                      details,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B0000),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Submit',
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  } catch (e, stackTrace) {
    if (kDebugMode) print('Error in _showCompanyDialog: $e\n$stackTrace');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to load company options'),
        backgroundColor: Color(0xFF8B0000),
      ),
    );
  }
}

// New helper method for fallback PDF generation
  Future<File?> _generateFallbackPdf(
      String type, String subtype, Map<String, String> details) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Insurance Cover Details',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Type: ${type.toUpperCase()}'),
              pw.Text('Subtype: ${subtype.replaceAll('_', ' ').toUpperCase()}'),
              pw.SizedBox(height: 20),
              pw.Text('Form Data:', style: pw.TextStyle(fontSize: 16)),
              ...details.entries.map(
                (e) => pw.Text('${e.key}: ${e.value}'),
              ),
            ],
          ),
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/fallback_cover_${Uuid().v4()}.pdf');
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      if (kDebugMode) {
        print('Error generating fallback PDF: $e');
      }
      return null;
    }
  }

  // Mock payment initialization
  Future<String> _initializePayment(String coverId, String amount) async {
    try {
      // Mock API call to payment gateway (e.g., Stripe, PayPal)
      final response = await http.post(
        Uri.parse('https://api.payment-gateway.com/v1/payments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer your-payment-api-key',
        },
        body: jsonEncode({
          'coverId': coverId,
          'amount': double.parse(amount),
          'currency': 'KES',
          'description': 'Insurance cover payment',
        }),
      );

      if (response.statusCode == 200) {
        return 'completed';
      } else {
        return 'failed';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Payment initialization error: $e');
      }
      return 'failed';
    }
  }

  Future<void> _loadCachedPdfTemplates() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('pdf_templates').get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          cachedPdfTemplates = Map.fromEntries(
            snapshot.docs.map(
              (doc) => MapEntry(
                doc.id,
                PDFTemplate.fromJson(doc.data()),
              ),
            ),
          );
        });
        if (kDebugMode) {
          print('PDF templates loaded from Firestore.');
        }
      } else {
        // Initialize default template
        final defaultTemplate = PDFTemplate(
          templateKey: 'default',
          policyType: 'motor',
          policySubtype: 'comprehensive',
          coordinates: {
            'name': {'page': 1.0, 'x': 50.0, 'y': 50.0},
            'email': {'page': 1.0, 'x': 50.0, 'y': 70.0},
            'phone': {'page': 1.0, 'x': 50.0, 'y': 90.0},
          },
          fields: {
            'name': FieldDefinition(
                expectedType: ExpectedType.name,
                validator: (String) {
                  return null;
                }),
            'email': FieldDefinition(
                expectedType: ExpectedType.email,
                validator: (String) {
                  return null;
                }),
            'phone': FieldDefinition(
                expectedType: ExpectedType.phone,
                validator: (String) {
                  return null;
                }),
          },
          fieldMappings: {},
        );
        await FirebaseFirestore.instance
            .collection('pdf_templates')
            .doc('default')
            .set(defaultTemplate.toJson());
        setState(() {
          cachedPdfTemplates['default'] = defaultTemplate;
        });
        if (kDebugMode) {
          print('Initialized default PDF template in Firestore.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading cached PDF templates: $e');
      }
      setState(() {
        cachedPdfTemplates = {};
      });
    }
  }





Future<void> _loadUserDetails() async {
  try {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (kDebugMode) print('No user authenticated.');
      setState(() {
        userDetails = {};
      });
      return;
    }

    // Try cached data
    final cachedDetails = await _getCachedUserDetails(userId);
    if (cachedDetails.isNotEmpty) {
      if (kDebugMode) print('Loaded cached user details for $userId');
      setState(() {
        userDetails = cachedDetails;
      });
      if (await _hasNetwork()) _fetchUserDetails(userId);
      return;
    }

    await _fetchUserDetails(userId);
  } catch (e) {
    if (kDebugMode) print('Error loading user details: $e');
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final cachedDetails = userId != null ? await _getCachedUserDetails(userId) : {};
    setState(() {
      userDetails = cachedDetails.isNotEmpty ? Map<String, String>.from(cachedDetails) : {};
    });
    if (userDetails.isEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load user details.')),
      );
    }
  }
}

Future<void> _fetchUserDetails(String userId) async {
  if (!await _hasNetwork()) {
    if (kDebugMode) print('No network, skipping Firestore fetch.');
    return;
  }

  final docRef = FirebaseFirestore.instance.collection('users').doc(userId);
  final doc = await retryOperation(
    () => docRef.get(const GetOptions(source: Source.server)), // Force server fetch
    3,
    delay: const Duration(seconds: 1),
  ).timeout(const Duration(seconds: 15), onTimeout: () {
    if (kDebugMode) print('Firestore timeout for $userId');
    throw Exception('Firestore timeout');
  });

  if (doc.exists && doc['details'] != null) {
    try {
      final detailsData = doc['details'];
      // Check for legacy string data
      if (detailsData is String) {
        if (kDebugMode) print('Legacy string data detected for user $userId: $detailsData. Reinitializing.');
        await _initializeUserDetails(userId);
        setState(() {
          userDetails = {};
        });
        return;
      }
      // Expect a Map
      final details = Map<String, String>.from(detailsData as Map<dynamic, dynamic>);
      await _cacheUserDetails(userId, details);
      setState(() {
        userDetails = details;
      });
    } catch (e) {
      if (kDebugMode) print('Error parsing details: $e');
      await _initializeUserDetails(userId);
      setState(() {
        userDetails = {};
      });
    }
  } else {
    if (kDebugMode) print('No user details for $userId.');
    await _initializeUserDetails(userId);
    setState(() {
      userDetails = {};
    });
  }
}

Future<void> _initializeUserDetails(String userId) async {
  final docRef = FirebaseFirestore.instance.collection('users').doc(userId);
  try {
    final defaultDetails = {'name': 'Anonymous', 'email': ''};
    await docRef.set({'details': defaultDetails}, SetOptions(merge: true));
    if (kDebugMode) print('Initialized default user details for $userId');
    // Clear local cache to prevent stale data
    await FirebaseFirestore.instance.clearPersistence();
  } catch (e) {
    if (kDebugMode) print('Error initializing user details: $e');
    throw Exception('Failed to initialize user details');
  }
}

Future<bool> _hasNetwork() async {
  if (kIsWeb) {
    return web.window.navigator.onLine ?? true;
  }
  try {
    final result = await InternetAddress.lookup('google.com').timeout(Duration(seconds: 2));
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } catch (e) {
    return false;
  }
}

Future<void> _cacheUserDetails(String userId, Map<String, String> details) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_details_$userId', jsonEncode(details));
  } catch (e) {
    if (kDebugMode) print('Error caching user details: $e');
  }
}

Future<Map<String, String>> _getCachedUserDetails(String userId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('user_details_$userId');
    if (jsonString != null) {
      return Map<String, String>.from(jsonDecode(jsonString));
    }
  } catch (e) {
    if (kDebugMode) print('Error retrieving cached details: $e');
  }
  return {};
}}

// Color provider
class ColorProvider with ChangeNotifier {
  // Colors
  static const Color blueGreen = Color(0xFF26A69A);
  static const Color orange = Color(0xFFFFA726);
  Color _color = blueGreen;
  Color get color => _color;
  void setColor(Color color) {
    _color = color;
    notifyListeners();
  }
}

// Dialog state provider with save/resume
class DialogState extends ChangeNotifier {
  final Map<String, String> _responses = {};
  String _currentType = '';
  int _currentStep = 0;
  String? _insuredItemId;
  String? _companyId;

  Map<String, String> get responses => _responses;
  String get currentType => _currentType;
  int get currentStep => _currentStep;
  String? get insuredItemId => _insuredItemId;
  String? get companyId => _companyId;

  void updateResponse(String key, String value) {
    _responses[key] = value;
    notifyListeners();
  }

  void setCurrentType(String type) {
    _currentType = type.toLowerCase();
    notifyListeners();
  }

  void setCurrentStep(int step) {
    _currentStep = step;
    notifyListeners();
  }

  void setInsuredItemId(String? id) {
    _insuredItemId = id;
    notifyListeners();
  }

  void setCompanyId(String? id) {
    _companyId = id;
    notifyListeners();
  }

  void resetForNewCycle() {
    _responses.clear();
    _currentStep = 0;
    _insuredItemId = null;
    _companyId = null;
    notifyListeners();
  }

  void saveProgress(String type, int step) async {
    if (kDebugMode) {
      print('Saving progress: type=$type, step=$step, responses=$_responses');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'dialog_progress_$type',
          jsonEncode({
            'step': step,
            'responses': _responses,
            'insuredItemId': _insuredItemId,
            'companyId': _companyId,
          }));
    } catch (e) {
      if (kDebugMode) print('Error saving progress: $e');
    }
  }

  Future<void> loadProgress(String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('dialog_progress_$type');
      if (jsonString != null) {
        final data = jsonDecode(jsonString);
        _currentStep = data['step'] ?? 0;
        _responses.clear();
        _responses.addAll(Map<String, String>.from(data['responses'] ?? {}));
        _insuredItemId = data['insuredItemId'];
        _companyId = data['companyId'];
        notifyListeners();
        if (kDebugMode) print('Loaded progress for $type: step=$_currentStep');
      }
    } catch (e) {
      if (kDebugMode) print('Error loading progress: $e');
    }
  }
}

Future<T> retryOperation<T>(
  Future<T> Function() operation,
  int maxAttempts, {
  Duration delay = const Duration(seconds: 1),
}) async {
  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (e) {
      if (attempt == maxAttempts) rethrow;
      if (kDebugMode) print('Attempt $attempt failed: $e');
      await Future.delayed(delay);
    }
  }
  throw Exception('Operation failed after $maxAttempts attempts');
}

Future<bool> hasNetwork() async {
  if (kIsWeb) {
    return web.window.navigator.onLine ?? true;
  }
  try {
    final result = await InternetAddress.lookup('google.com')
        .timeout(Duration(seconds: 2));
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } catch (e) {
    return false;
  }
}



Future<Map<String, List<DialogStepConfig>>> getInsuranceConfigs(String type) async {
  if (kDebugMode) print('Fetching configs for type: $type');
  final normalizedType = type.toLowerCase();
  final configs = <String, List<DialogStepConfig>>{};

  // Clear cache to ensure fresh data (temporary for debugging)
  await clearCachedConfigs(normalizedType);

  // Try cached configs
  final cachedConfigs = await _getCachedConfigs(normalizedType);
  if (cachedConfigs.isNotEmpty && _isValidConfigs(cachedConfigs)) {
    if (kDebugMode) print('Using cached configs for $normalizedType');
    configs[normalizedType] = cachedConfigs;
    // Fetch fresh configs in background if network available
    if (await hasNetwork()) {
      unawaited(_fetchAndCacheConfigs(normalizedType).then((freshConfigs) {
        if (freshConfigs.containsKey(normalizedType)) {
          configs[normalizedType] = freshConfigs[normalizedType]!;
          if (kDebugMode) print('Updated configs with fresh data for $normalizedType');
        }
      }).catchError((e) {
        if (kDebugMode) print('Background fetch failed: $e');
      }));
    }
    return configs;
  }

  if (!await hasNetwork()) {
    if (kDebugMode) print('No network, using default configs');
    return _defaultConfigs(normalizedType);
  }

  configs.addAll(await _fetchAndCacheConfigs(normalizedType));
  return configs;
}

Future<Map<String, List<DialogStepConfig>>> _fetchAndCacheConfigs(String normalizedType) async {
  final configs = <String, List<DialogStepConfig>>{};
  try {
    List<PolicyType> policyTypes = await retryOperation(
      InsuranceHomeScreen.getPolicyTypes,
      3,
      delay: const Duration(seconds: 1),
    ).timeout(const Duration(seconds: 8), onTimeout: () {
      if (kDebugMode) print('Policy types timeout for $normalizedType');
      return [PolicyType(id: '1', name: normalizedType, description: '')];
    });

    bool typeFound = false;
    for (final policyType in policyTypes) {
      final typeName = policyType.name.toLowerCase();
      if (typeName != normalizedType) continue;
      typeFound = true;

      List<PolicySubtype> subtypes = await retryOperation(
        () => InsuranceHomeScreen.getPolicySubtypes(policyType.id),
        3,
        delay: const Duration(seconds: 1),
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        if (kDebugMode) print('Subtypes timeout for $normalizedType');
        return [PolicySubtype(id: '1', name: 'Standard', policyTypeId: policyType.id, description: '')];
      });

      List<CoverageType> coverageTypes = [];
      for (final subtype in subtypes) {
        final types = await retryOperation(
          () => InsuranceHomeScreen.getCoverageTypes(subtype.id),
          3,
          delay: const Duration(seconds: 1),
        ).timeout(const Duration(seconds: 5), onTimeout: () {
          if (kDebugMode) print('Coverage types timeout for $normalizedType');
          return [CoverageType(id: '1', name: 'Basic', description: '')];
        });
        coverageTypes.addAll(types);
      }

      final subtypeOptions = subtypes.isNotEmpty ? subtypes.map((s) => s.name).toList() : ['Standard'];
      final coverageOptions = coverageTypes.isNotEmpty ? coverageTypes.map((c) => c.name).toList() : ['Basic'];
      if (kDebugMode) {
        print('Subtypes for $normalizedType: $subtypeOptions');
        print('Coverage types for $normalizedType: $coverageOptions');
      }

      configs[typeName] = [
        DialogStepConfig(
          title: 'Select ${policyType.name} Subtype',
          fields: [
            FieldConfig(
              key: 'subtype',
              label: '${policyType.name} Subtype',
              type: 'dropdown',
              options: subtypeOptions,
              validator: (value) => value?.isNotEmpty == true ? null : 'Please select a subtype',
            ),
          ],
          nextStep: 'coverage',
          customCallback: null,
        ),
        DialogStepConfig(
          title: 'Select Coverage Type',
          fields: [
            FieldConfig(
              key: 'coverage_type',
              label: 'Coverage Type',
              type: 'dropdown',
              options: coverageOptions,
              validator: (value) => value?.isNotEmpty == true ? null : 'Please select a coverage type',
            ),
          ],
          nextStep: 'summary',
          customCallback: null,
        ),
        DialogStepConfig(
          title: 'Summary',
          fields: [],
          customCallback: (context, dialogState) async {
            if (kDebugMode) print('Final submission for $normalizedType: ${dialogState.responses}');
            final name = dialogState.responses['name'] ?? '';
            final email = dialogState.responses['email'] ?? '';
            if (name.isEmpty || email.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Name and Email are required'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      ];

      if (_isValidConfigs(configs[typeName]!)) {
        await _cacheConfigs(normalizedType, configs[typeName]!);
      } else {
        if (kDebugMode) print('Invalid configs for $normalizedType, not caching');
      }
    }

    if (!typeFound) {
      if (kDebugMode) print('No policy type found for $normalizedType, using default');
      configs[normalizedType] = _defaultConfigs(normalizedType)[normalizedType]!;
      await _cacheConfigs(normalizedType, configs[normalizedType]!);
    }
  } catch (e, stackTrace) {
    if (kDebugMode) print('Error fetching configs for $normalizedType: $e\n$stackTrace');
    configs[normalizedType] = _defaultConfigs(normalizedType)[normalizedType]!;
    await _cacheConfigs(normalizedType, configs[normalizedType]!);
  }
  return configs;
}
Future<void> clearCachedConfigs(String typeName) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('configs_$typeName');
    if (kDebugMode) print('Cleared cached configs for $typeName');
  } catch (e) {
    if (kDebugMode) print('Error clearing cached configs: $e');
  }
}

Future<List<DialogStepConfig>> _getCachedConfigs(String typeName) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('configs_$typeName') ?? [];
    final configs = jsonList.map((json) => DialogStepConfig.fromJson(jsonDecode(json))).toList();
    if (kDebugMode) print('Retrieved ${configs.length} cached configs for $typeName');
    return configs;
  } catch (e) {
    if (kDebugMode) print('Error retrieving cached configs: $e');
    return [];
  }
}

Future<void> _cacheConfigs(String typeName, List<DialogStepConfig> configs) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final configsJson = configs.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList('configs_$typeName', configsJson);
    if (kDebugMode) print('Cached ${configs.length} configs for $typeName');
  } catch (e) {
    if (kDebugMode) print('Error caching configs: $e');
  }
}

bool _isValidConfigs(List<DialogStepConfig> configs) {
  return configs.isNotEmpty &&
      configs.every((c) => c.title.isNotEmpty && (c.fields.isEmpty || c.fields.every((f) => f.key.isNotEmpty)));
}

class FieldConfig {
  final String key;
  final String label;
  final TextInputType? keyboardType;
  final bool isRequired;
  final String? Function(String?)? validator;
  final String type;
  final List<String>? options;
  final String? initialValue;
  final String? dependsOnKey;
  final String? dependsOnValue;

  FieldConfig({
    required this.key,
    required this.label,
    this.keyboardType,
    this.isRequired = true,
    this.validator,
    this.type = 'text',
    this.options,
    this.initialValue,
    this.dependsOnKey,
    this.dependsOnValue,
    this.isMultiSelect,
  });

  // Static map for dropdown options based on listItemType or field key
  static const Map<String, List<String>> _dropdownOptions = {
    'email': ['user1@example.com', 'user2@example.com', 'user3@example.com'],
    'phone': ['+1234567890', '+0987654321', '+1122334455'],
    'name': ['John Doe', 'Jane Smith', 'Alex Johnson'],
    'number': ['100', '200', '300'],
    'text': ['Option 1', 'Option 2', 'Option 3'],
    'date': ['2025-01-01', '2025-06-01', '2025-12-01'],
    'custom': ['Custom 1', 'Custom 2', 'Custom 3'],
    // Add more mappings as needed
  };

  bool? isMultiSelect;

  factory FieldConfig.fromFieldDefinition(
      FieldDefinition fieldDef, String label,
      {String? fieldKey}) {
    String type;
    TextInputType? keyboardType;
    String? Function(String?)? validator;
    List<String>? options;

    // Use provided fieldKey or fallback to a unique identifier
    final key = fieldKey ?? fieldDef.toString();

    switch (fieldDef.expectedType) {
      case ExpectedType.text:
        type = 'text';
        keyboardType = TextInputType.text;
        validator = (value) => fieldDef.validator?.call(value ?? '');
        break;

      case ExpectedType.number:
        type = 'number';
        keyboardType = TextInputType.number;
        validator = (value) => fieldDef.validator?.call(value ?? '');
        break;

      case ExpectedType.email:
        type = 'text';
        keyboardType = TextInputType.emailAddress;
        validator = (value) => fieldDef.validator?.call(value ?? '');
        break;

      case ExpectedType.phone:
        type = 'text';
        keyboardType = TextInputType.phone;
        validator = (value) => fieldDef.validator?.call(value ?? '');
        break;

      case ExpectedType.date:
        type = 'text';
        keyboardType = TextInputType.datetime;
        validator = (value) => fieldDef.validator?.call(value ?? '');
        break;

      case ExpectedType.custom:
        type = 'text';
        keyboardType = TextInputType.text;
        validator = (value) => fieldDef.validator?.call(value ?? '');
        break;

      case ExpectedType.name:
        type = 'text';
        keyboardType = TextInputType.name;
        validator = (value) => fieldDef.validator?.call(value ?? '');
        break;

      case ExpectedType.list:
        type = 'dropdown';
        keyboardType = null; // Dropdown doesn't use keyboard
        options = _dropdownOptions[
                fieldDef.listItemType?.toString().split('.').last ?? 'text'] ??
            ['Option 1', 'Option 2'];
        validator = (value) {
          if (value == null || value.isEmpty) {
            return fieldDef.isSuggested ? null : 'Selection required';
          }
          if (fieldDef.listItemType != null) {
            final itemValidator =
                FieldDefinition.getValidatorForType(fieldDef.listItemType);
            final result = itemValidator?.call(value);
            if (result != null) return 'Invalid selection: $result';
          }
          return null;
        };
        break;
    }

    return FieldConfig(
      key: key,
      label: label,
      type: type,
      keyboardType: keyboardType,
      isRequired: fieldDef.isSuggested ? false : true,
      validator: validator,
      options: options,
      initialValue: null,
      dependsOnKey: null,
      dependsOnValue: null,
    );
  }
  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'keyboardType': keyboardType?.toString(),
        'isRequired': isRequired,
        'type': type,
        'options': options,
        'initialValue': initialValue,
        'dependsOnKey': dependsOnKey,
        'dependsOnValue': dependsOnValue,
        'isMultiSelect': isMultiSelect,
      };

  factory FieldConfig.fromJson(Map<String, dynamic> json) => FieldConfig(
        key: json['key'],
        label: json['label'],
        keyboardType: json['keyboardType'] != null
            ? TextInputType.values
                .firstWhere((e) => e.toString() == json['keyboardType'])
            : null,
        isRequired: json['isRequired'] ?? true,
        type: json['type'] ?? 'text',
        options: (json['options'] as List<dynamic>?)?.cast<String>(),
        initialValue: json['initialValue'],
        dependsOnKey: json['dependsOnKey'],
        dependsOnValue: json['dependsOnValue'],
        isMultiSelect: json['isMultiSelect'],
      );
}

class FormFieldWidget extends StatelessWidget {
  final FieldConfig config;
  final String? value;
  final Function(String) onChanged;
  final ColorProvider colorProvider;

  const FormFieldWidget({
    super.key,
    required this.config,
    this.value,
    required this.onChanged,
    required this.colorProvider,
  });

  @override
  Widget build(BuildContext context) {
    switch (config.type) {
      case 'dropdown':
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: config.label,
            labelStyle: GoogleFonts.roboto(color: const Color(0xFFD3D3D3)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colorProvider.color),
            ),
          ),
          value: value ?? config.options?.first,
          items: config.options
              ?.map((option) => DropdownMenuItem(
                    value: option,
                    child: Text(
                      option.replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.roboto(color: const Color(0xFF1B263B)),
                    ),
                  ))
              .toList(),
          onChanged: (newValue) => onChanged(newValue ?? ''),
          validator: config.validator,
        );
      case 'checkbox':
        return CheckboxListTile(
          title: Text(
            config.label,
            style: GoogleFonts.roboto(color: const Color(0xFF1B263B)),
          ),
          value: value == 'Yes',
          onChanged: (newValue) => onChanged(newValue == true ? 'Yes' : 'No'),
          activeColor: colorProvider.color,
        );
      case 'number':
        return TextFormField(
          decoration: InputDecoration(
            labelText: config.label,
            labelStyle: GoogleFonts.roboto(color: const Color(0xFFD3D3D3)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colorProvider.color),
            ),
          ),
          keyboardType: TextInputType.number,
          validator: config.validator,
          onChanged: onChanged,
          initialValue: value,
          style: GoogleFonts.roboto(color: const Color(0xFF1B263B)),
        );
      default:
        return TextFormField(
          decoration: InputDecoration(
            labelText: config.label,
            labelStyle: GoogleFonts.roboto(color: const Color(0xFFD3D3D3)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colorProvider.color),
            ),
          ),
          keyboardType: config.keyboardType,
          validator: config.validator,
          onChanged: onChanged,
          initialValue: value,
          style: GoogleFonts.roboto(color: const Color(0xFF1B263B)),
        );
    }
  }
}

class DialogStepConfig {
  final String title;
  final List<FieldConfig> fields;
  final String? nextStep;
  final bool Function(Map<String, String>)? customValidator;
  final String? pdfTemplateKeySource;

  dynamic customCallback; // 'policy', 'type', 'subtype', 'coverage'

  DialogStepConfig({
    required this.title,
    required this.fields,
    this.nextStep,
    this.customValidator,
    this.pdfTemplateKeySource,
    required customCallback,
  });

  // Add this fromJson factory constructor
  static DialogStepConfig fromJson(Map<String, dynamic> json) {
    return DialogStepConfig(
      title: json['title'] as String,
      fields: (json['fields'] as List<dynamic>? ?? [])
          .map((f) => FieldConfig(
                key: f['key'] ?? '',
                label: f['label'] ?? '',
                type: f['type'] ?? 'text',
                options: (f['options'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList(),
                validator: null, // Validators can't be deserialized directly
                keyboardType: null,
                isRequired: f['isRequired'] ?? true,
                initialValue: f['initialValue'],
                dependsOnKey: f['dependsOnKey'],
                dependsOnValue: f['dependsOnValue'],
              ))
          .toList(),
      nextStep: json['nextStep'],
      customValidator: null, // Can't deserialize functions
      pdfTemplateKeySource: json['pdfTemplateKeySource'],
      customCallback: null, // Can't deserialize functions
    );
  }

  // Optionally, add toJson if needed for caching
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'fields': fields
          .map((f) => {
                'key': f.key,
                'label': f.label,
                'type': f.type,
                'options': f.options,
                'isRequired': f.isRequired,
                'initialValue': f.initialValue,
                'dependsOnKey': f.dependsOnKey,
                'dependsOnValue': f.dependsOnValue,
              })
          .toList(),
      'nextStep': nextStep,
      'pdfTemplateKeySource': pdfTemplateKeySource,
      // customValidator and customCallback are not serializable
    };
  }
}

// Generic dialog widget with progress indicatorimport 'package:flutter/material.dart';



class GenericInsuranceDialog extends StatefulWidget {
  final String insuranceType;
  final int step;
  final DialogStepConfig config;
  final DialogState dialogState;
  final VoidCallback onCancel;
  final VoidCallback? onBack;
  final VoidCallback onSubmit;
  final void Function(BuildContext, String, String, String)? onFinalSubmit;
  final Future<void> Function(
    BuildContext context,
    PolicyType policyType,
    PolicySubtype subtype,
    CoverageType coverageType,
  ) showInsuredItemDialog;

  const GenericInsuranceDialog({
    super.key,
    required this.insuranceType,
    required this.step,
    required this.config,
    required this.dialogState,
    required this.onCancel,
    this.onBack,
    required this.onSubmit,
    this.onFinalSubmit,
    required this.showInsuredItemDialog,
  });

  @override
  _GenericInsuranceDialogState createState() => _GenericInsuranceDialogState();
}

class _GenericInsuranceDialogState extends State<GenericInsuranceDialog> {
  late final Future<List<FieldConfig>> _fieldsFuture;

  @override
  void initState() {
    super.initState();
    _fieldsFuture = _getFields();
    if (widget.config.customCallback != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.config.customCallback!(context, widget.dialogState);
        }
      });
    }
  }

  Future<List<FieldConfig>> _getFields() async {
    if (kDebugMode) print('Fetching fields for ${widget.config.title}');
    return widget.config.fields;
  }

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final colorProvider = context.watch<ColorProvider>();

    return FutureBuilder<List<FieldConfig>>(
      future: _fieldsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading fields'));
        }
        if (snapshot.hasError) {
          if (kDebugMode) print('FutureBuilder error: ${snapshot.error}');
          return AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to load options: ${snapshot.error}'),
            actions: [
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Close'),
              ),
            ],
          );
        }

        final fields = snapshot.data ?? widget.config.fields;
        if (fields.isEmpty && widget.config.customCallback == null) {
          if (kDebugMode) print('No fields available for ${widget.config.title}');
          return AlertDialog(
            content: const Text('No options available for this step.'),
            actions: [
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
            ],
          );
        }
        if (widget.config.customCallback != null && fields.isEmpty) {
          return const SizedBox.shrink();
        }

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            widget.config.title,
            style: GoogleFonts.lora(
              color: const Color(0xFF1B263B),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: fields.map((field) {
                  if (field.dependsOnKey != null &&
                      widget.dialogState.responses[field.dependsOnKey!] !=
                          field.dependsOnValue) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: FormFieldWidget(
                      config: field,
                      value: widget.dialogState.responses[field.key] ?? field.initialValue,
                      onChanged: (value) {
                        widget.dialogState.updateResponse(field.key, value);
                        if (field.key == 'subtype' && value != 'corporate') {
                          widget.dialogState.updateResponse('beneficiaries', '');
                        }
                        if (field.key == 'has_spouse' && value == 'No') {
                          widget.dialogState.updateResponse('spouse_age', '');
                        }
                        if (field.key == 'has_children' && value == 'No') {
                          widget.dialogState.updateResponse('children_count', '');
                        }
                      },
                      colorProvider: colorProvider,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            if (widget.onBack != null)
              TextButton(
                onPressed: widget.onBack,
                child: Text(
                  'Back',
                  style: GoogleFonts.roboto(color: const Color(0xFFD3D3D3)),
                ),
              ),
            TextButton(
              onPressed: widget.onCancel,
              child: Text(
                'Cancel',
                style: GoogleFonts.roboto(color: const Color(0xFFD3D3D3)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate() &&
                    (widget.config.customValidator == null ||
                        widget.config.customValidator!(widget.dialogState.responses))) {
                  widget.dialogState.saveProgress(widget.insuranceType, widget.step);
                  if (kDebugMode) print('Form validated, nextStep: ${widget.config.nextStep}');
                  if (widget.config.nextStep == 'summary') {
                    final typeName = widget.insuranceType;
                    final subtypeName = widget.dialogState.responses['subtype'] ?? '';
                    final coverageName = widget.dialogState.responses['coverage_type'] ?? '';
                    if (subtypeName.isEmpty || coverageName.isEmpty) {
                      if (kDebugMode) print('Missing subtype or coverage: $subtypeName, $coverageName');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a subtype and coverage type')),
                        );
                      }
                      return;
                    }
                    try {
                      if (kDebugMode) print('Processing summary for $typeName, $subtypeName, $coverageName');
                      final policyTypes = await InsuranceHomeScreen.getPolicyTypes();
                      final policyType = policyTypes.firstWhere(
                        (t) => t.name.toLowerCase() == typeName.toLowerCase(),
                        orElse: () => PolicyType(id: '1', name: typeName, description: ''),
                      );
                      final subtypes = await InsuranceHomeScreen.getPolicySubtypes(policyType.id);
                      final subtype = subtypes.firstWhere(
                        (s) => s.name == subtypeName,
                        orElse: () => PolicySubtype(
                          id: '1',
                          name: subtypeName,
                          policyTypeId: policyType.id,
                          description: '',
                        ),
                      );
                      final coverageTypes = await InsuranceHomeScreen.getCoverageTypes(subtype.id);
                      final coverageType = coverageTypes.firstWhere(
                        (c) => c.name == coverageName,
                        orElse: () => CoverageType(id: '1', name: coverageName, description: ''),
                      );

                      if (mounted) {
                        if (kDebugMode) print('Calling showInsuredItemDialog');
                        await widget.showInsuredItemDialog(
                          context,
                          policyType,
                          subtype,
                          coverageType,
                        );
                        widget.dialogState.resetForNewCycle();
                      }
                    } catch (e, stackTrace) {
                      if (kDebugMode) print('Error triggering insured item dialog: $e\n$stackTrace');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to proceed. Please try again.')),
                        );
                      }
                    }
                  } else {
                    widget.onSubmit();
                  }
                } else {
                  if (kDebugMode) print('Form validation failed');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Please correct the errors in the form',
                          style: GoogleFonts.roboto(color: Colors.white),
                        ),
                        backgroundColor: colorProvider.color,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorProvider.color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                widget.config.nextStep == 'summary' ? 'Submit' : 'Next',
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
// Reusable dynamic form widget
class DynamicForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<Map<String, dynamic>> fields;
  final Function(String, String) onFieldChanged;
  final Map<String, String> responses;

  const DynamicForm({
    super.key,
    required this.formKey,
    required this.fields,
    required this.onFieldChanged,
    required this.responses,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: fields.asMap().entries.where((entry) {
          final field = entry.value;
          return field['condition'] == null || field['condition'](responses);
        }).map((entry) {
          final field = entry.value;
          final isLast = entry.key == fields.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16.0),
            child: TextFormField(
              decoration: InputDecoration(
                labelText: field['label'],
                labelStyle: GoogleFonts.roboto(
                  color: const Color(0xFF1B263B),
                ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: context.watch<ColorProvider>().color),
                ),
              ),
              keyboardType: field['keyboardType'] ?? TextInputType.text,
              validator: (value) {
                final error = field['validator']?.call(value ?? '');
                if (error != null && kDebugMode) {
                  print('Validation error for ${field['key']}: $error');
                }
                return error;
              },
              onChanged: (value) => onFieldChanged(field['key'], value),
              initialValue: responses[field['key']] ?? '',
              style: GoogleFonts.roboto(
                color: const Color(0xFF1B263B),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}


Future<void> showInsuranceDialog(
  BuildContext context,
  String insuranceType, {
  int step = 0,
  void Function(BuildContext, String, String, String)? onFinalSubmit,
  required GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
}) async {
  if (kDebugMode) print('showInsuranceDialog: starting for type=$insuranceType, step=$step');

  if (!context.mounted) {
    if (kDebugMode) print('showInsuranceDialog: context not mounted at start');
    return;
  }

  final normalizedType = insuranceType.toLowerCase();
  if (kDebugMode) print('showInsuranceDialog: normalized type=$normalizedType');

  // Authenticate user
  try {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      final userCredential = await auth.signInAnonymously();
      if (kDebugMode) print('Signed in anonymously: ${userCredential.user?.uid}');
    } else {
      if (kDebugMode) print('User already authenticated: ${auth.currentUser?.uid}');
    }
  } catch (e, stackTrace) {
    if (kDebugMode) print('Failed to sign in anonymously: $e\n$stackTrace');
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Authentication failed. Please try again.')),
    );
    return;
  }

  // Set dialog state
  final dialogState = context.read<DialogState>();
  try {
    dialogState.setCurrentType(normalizedType);
    await dialogState.loadProgress(normalizedType);
    dialogState.setCurrentStep(step);
    if (kDebugMode) print('showInsuranceDialog: dialog state set successfully');
  } catch (e, stackTrace) {
    if (kDebugMode) print('Error setting dialog state: $e\n$stackTrace');
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Error initializing dialog. Cannot proceed.')),
    );
    return;
  }

  // Show loading dialog and fetch configs
  BuildContext? loadingContext;
  Map<String, List<DialogStepConfig>> configs;
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        loadingContext = dialogContext;
        return const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading insurance options'),
        );
      },
    );
    if (kDebugMode) print('showInsuranceDialog: loading dialog shown');

    configs = await getInsuranceConfigs(normalizedType).timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        if (kDebugMode) print('getInsuranceConfigs timed out for type: $normalizedType');
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Loading options timed out. Using default options.')),
        );
        return _defaultConfigs(normalizedType);
      },
    );
    if (kDebugMode) print('Fetched configs for $normalizedType: ${configs.keys.toList()}');
  } catch (e, stackTrace) {
    if (kDebugMode) print('Error in getInsuranceConfigs: $e\n$stackTrace');
    configs = _defaultConfigs(normalizedType);
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Failed to load options. Using default options.')),
    );
  } finally {
    if (loadingContext != null && loadingContext!.mounted) {
      Navigator.of(loadingContext!).pop();
      if (kDebugMode) print('showInsuranceDialog: loading dialog closed');
    }
  }

  if (!context.mounted) {
    if (kDebugMode) print('showInsuranceDialog: context not mounted after configs');
    return;
  }

  // Validate configs
  if (!configs.containsKey(normalizedType) || configs[normalizedType]!.isEmpty) {
    if (kDebugMode) print('Invalid insurance type or no configs: $normalizedType');
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('Invalid insurance type: $normalizedType')),
    );
    return;
  }

  final configList = configs[normalizedType]!;
  if (step >= configList.length) {
    if (kDebugMode) print('Invalid step: $step for type: $normalizedType');
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Invalid step in insurance process')),
    );
    return;
  }

  final config = configList[step];

  // Show insurance dialog
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async {
          if (kDebugMode) print('Dialog dismissed for ${config.title}');
          dialogState.saveProgress(normalizedType, step);
          return true;
        },
        child: GenericInsuranceDialog(
          insuranceType: normalizedType,
          step: step,
          config: config,
          dialogState: dialogState,
          onCancel: () {
            if (kDebugMode) print('Cancel pressed for ${config.title}');
            dialogState.saveProgress(normalizedType, step);
            Navigator.of(dialogContext).pop();
          },
          onBack: step > 0
              ? () {
                  if (kDebugMode) print('Back pressed for ${config.title}');
                  dialogState.saveProgress(normalizedType, step);
                  Navigator.of(dialogContext).pop();
                  showInsuranceDialog(
                    context,
                    normalizedType,
                    step: step - 1,
                    onFinalSubmit: onFinalSubmit,
                    scaffoldMessengerKey: scaffoldMessengerKey,
                  );
                }
              : null,
          onSubmit: () async {
            if (kDebugMode) print('Submit pressed for ${config.title}, responses: ${dialogState.responses}');
            dialogState.saveProgress(normalizedType, step + 1);
            Navigator.of(dialogContext).pop();
            if (step + 1 < configList.length) {
              if (kDebugMode) print('Navigating to next step: ${step + 1}');
              await showInsuranceDialog(
                context,
                normalizedType,
                step: step + 1,
                onFinalSubmit: onFinalSubmit,
                scaffoldMessengerKey: scaffoldMessengerKey,
              );
            }
          },
          onFinalSubmit: onFinalSubmit,
          showInsuredItemDialog: (BuildContext context, PolicyType policyType, PolicySubtype subtype, CoverageType coverageType) async {
            final state = context.findAncestorStateOfType<_InsuranceHomeScreenState>();
            if (state != null) {
              await state._showInsuredItemDialog(context, policyType, subtype, coverageType);
            }
          },
        ),
      ),
    );
    if (kDebugMode) print('GenericInsuranceDialog closed');
  } catch (e, stackTrace) {
    if (kDebugMode) print('Error showing GenericInsuranceDialog: $e\n$stackTrace');
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Failed to display insurance options')),
    );
  }
}


Future<void> _handleFinalSubmit(
  BuildContext context,
  String normalizedType,
  DialogState dialogState,
  void Function(BuildContext, String, String, String)? onFinalSubmit,
  GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
) async {
  try {
    final policyTypes = await retryOperation(
      InsuranceHomeScreen.getPolicyTypes,
      3,
      delay: const Duration(seconds: 1),
    ).timeout(const Duration(seconds: 5), onTimeout: () {
      if (kDebugMode) print('Policy types timeout; using default');
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Failed to load policy types. Using default')),
      );
      return [PolicyType(id: '1', name: normalizedType, description: '')];
    });

    final policyType = policyTypes.firstWhere(
      (t) => t.name.toLowerCase() == normalizedType,
      orElse: () => PolicyType(id: normalizedType, name: normalizedType, description: ''),
    );

    final subtypeName = dialogState.responses['subtype'] ?? '';
    final subtypes = await retryOperation(
      () => InsuranceHomeScreen.getPolicySubtypes(policyType.id),
      3,
      delay: const Duration(seconds: 1),
    ).timeout(const Duration(seconds: 5), onTimeout: () {
      if (kDebugMode) print('Subtypes timeout; using default');
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Failed to load subtypes. Using default')),
      );
      return [PolicySubtype(id: '1', name: 'Standard', policyTypeId: policyType.id, description: '')];
    });

    final subtype = subtypes.firstWhere(
      (s) => s.name == subtypeName,
      orElse: () => PolicySubtype(
        id: subtypeName,
        name: subtypeName,
        policyTypeId: policyType.id,
        description: '',
      ),
    );

    final coverageName = dialogState.responses['coverage_type'] ?? '';
    final coverageTypes = await retryOperation(
      () => InsuranceHomeScreen.getCoverageTypes(subtype.id),
      3,
      delay: const Duration(seconds: 1),
    ).timeout(const Duration(seconds: 5), onTimeout: () {
      if (kDebugMode) print('Coverage types timeout; using default');
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Failed to load coverage types. Using default')),
      );
      return [CoverageType(id: '1', name: 'Basic', description: '')];
    });

    final coverageType = coverageTypes.firstWhere(
      (c) => c.name == coverageName,
      orElse: () => CoverageType(id: coverageName, name: coverageName, description: ''),
    );

    if (context.mounted) {
      final state = context.findAncestorStateOfType<_InsuranceHomeScreenState>();
      if (state != null) {
        if (kDebugMode) print('Showing insured item dialog');
        await state._showInsuredItemDialog(context, policyType, subtype, coverageType);
        dialogState.resetForNewCycle();
      } else {
        if (kDebugMode) print('Could not find _InsuranceHomeScreenState');
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Unable to proceed with insured item')),
        );
      }
    }
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('Error in final submit: $e\n$stackTrace');
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Error completing submission. Please try again')),
      );
    }
  }
}

// Default configurations
Map<String, List<DialogStepConfig>> _defaultConfigs(String normalizedType) {
  if (kDebugMode) print('Using default configs for $normalizedType');
  return {
    normalizedType: [
      DialogStepConfig(
        title: 'Select ${normalizedType.replaceAll('_', ' ').toUpperCase()} Options',
        fields: [
          FieldConfig(
            key: 'company',
            label: 'Insurance Company',
            type: 'dropdown',
            options: ['AIG', 'Cigna', 'UnitedHealth'],
            validator: (value) => value?.isNotEmpty == true ? null : 'Please select a company',
          ),
          FieldConfig(
            key: 'subtype',
            label: 'Policy Subtype',
            type: 'dropdown',
            options: ['Standard', 'Premium'],
            validator: (value) => value?.isNotEmpty == true ? null : 'Please select a subtype',
          ),
          FieldConfig(
            key: 'coverage_type',
            label: 'Coverage Type',
            type: 'dropdown',
            options: ['Basic', 'Comprehensive'],
            validator: (value) => value?.isNotEmpty == true ? null : 'Please select a coverage type',
          ),
        ],
        nextStep: 'details',
        pdfTemplateKeySource: 'type',
        customCallback: (context, dialogState) async {
          if (kDebugMode) print('Default config callback for $normalizedType');
        },
      ),
      DialogStepConfig(
        title: 'Personal Details',
        fields: [
          FieldConfig(
            key: 'name',
            label: 'Full Name',
            validator: (value) => value?.isNotEmpty == true ? null : 'Name is required',
          ),
          FieldConfig(
            key: 'email',
            label: 'Email Address',
            keyboardType: TextInputType.emailAddress,
            validator: (value) => value?.isNotEmpty == true &&
                    RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(value!)
                ? null
                : 'Valid email is required',
          ),
        ],
        nextStep: 'summary',
        customCallback: null,
      ),
      DialogStepConfig(
        title: 'Summary',
        fields: [],
        customCallback: (context, dialogState) async {
          if (kDebugMode) print('Summary callback: ${dialogState.responses}');
          final name = dialogState.responses['name'] ?? '';
          final email = dialogState.responses['email'] ?? '';
          if (name.isEmpty || email.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Name and Email are required'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    ],
  };
}

void _showCompletionDialog(
  BuildContext context,
  String type,
  Policy policy,
  String? pdfTemplateKey,
  void Function(BuildContext, String, String, String)? onFinalSubmit,
) {
  final dialogState = context.read<DialogState>();
  final colorProvider = context.watch<ColorProvider>();

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        'Submission Complete',
        style: GoogleFonts.lora(
          color: const Color(0xFF1B263B),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        'Policy created for ${policy.type.name}. Would you like to start a new submission?',
        style: GoogleFonts.roboto(color: const Color(0xFF1B263B)),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (kDebugMode) {
              print('Close pressed for completion dialog');
            }
            Navigator.pop(dialogContext);
            if (onFinalSubmit != null) {
              onFinalSubmit(
                context,
                policy.type.name,
                policy.subtype.name,
                policy.coverageType.name,
              );
            }
          },
          child: Text(
            'Close',
            style: GoogleFonts.roboto(color: const Color(0xFFD3D3D3)),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (kDebugMode) {
              print('Starting new submission');
            }
            dialogState.resetForNewCycle();
            Navigator.pop(dialogContext);
            showInsuranceDialog(
              context,
              type,
              step: 0,
              onFinalSubmit: onFinalSubmit,
              scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorProvider.color,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            'New Submission',
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class DialogController {
  final DialogState dialogState;
  int currentStep = 0;
  String insuranceType;
  String pdfTemplateKey;

  DialogController({
    required this.dialogState,
    required this.insuranceType,
    required this.pdfTemplateKey,
  });

  Future<void> showNextStep(BuildContext context) async {
    final configs = await getInsuranceConfigs(insuranceType);
    if (currentStep < configs[insuranceType]!.length) {
      await showInsuranceDialog(
        context,
        insuranceType,
        step: currentStep,
        onFinalSubmit: null, // Handle separately
        scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
      );
      currentStep++;
    }
  }

  void goBack(BuildContext context) {
    if (currentStep > 0) {
      currentStep--;
      showNextStep(context);
    }
  }
}

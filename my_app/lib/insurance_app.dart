import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:my_app/Models/Insured_item.dart';
import 'package:my_app/Models/company.dart';
import 'package:my_app/Models/cover.dart';
import 'package:my_app/Models/field_definition.dart';
import 'package:my_app/Models/pdf_template.dart';
import 'package:my_app/Models/policy.dart';
import 'package:my_app/Providers/theme_provider.dart';
import 'package:my_app/Screens/cover_screen.dart';
import 'package:my_app/Screens/notifications_screen.dart';
import 'package:my_app/Screens/pdf_preview.dart';
import 'package:my_app/Services/webview.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf_text/pdf_text.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_render/pdf_render.dart' as pdf;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart'; // For elegant typography
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Correct import for url_launcher

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

  var pdfTemplateKeys;

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
  static Future<List<PolicyType>> getPolicyTypes() async {
    // Fetch from Firestore
    final snapshot =
        await FirebaseFirestore.instance.collection('policy_types').get();
    return snapshot.docs.map((doc) => PolicyType.fromJson(doc.data())).toList();
  }

  static Future<List<PolicySubtype>> getPolicySubtypes(
      String policyTypeId) async {
    // Fetch subtypes for a policy type
    final snapshot = await FirebaseFirestore.instance
        .collection('policy_subtypes')
        .where('policyTypeId', isEqualTo: policyTypeId)
        .get();
    return snapshot.docs
        .map((doc) => PolicySubtype.fromJson(doc.data()))
        .toList();
  }

  static Future<List<CoverageType>> getCoverageTypes() async {
    // Fetch coverage types
    final snapshot =
        await FirebaseFirestore.instance.collection('coverage_types').get();
    return snapshot.docs
        .map((doc) => CoverageType.fromJson(doc.data()))
        .toList();
  }

  static Future<PDFTemplate?> getPDFTemplate(String pdfTemplateKey) async {
    // Fetch PDFTemplate by key
    final doc = await FirebaseFirestore.instance
        .collection('pdf_templates')
        .doc(pdfTemplateKey)
        .get();
    return doc.exists ? PDFTemplate.fromJson(doc.data()!) : null;
  }

  @override
  State<InsuranceHomeScreen> createState() => _InsuranceHomeScreenState();

  static Future<List<Company>> loadCompanies() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('companies').get();
    return snapshot.docs.map((doc) => Company.fromJson(doc.data())).toList();
  }
}

class _InsuranceHomeScreenState extends State<InsuranceHomeScreen> {
  List<InsuredItem> insuredItems = [];
  List<Cover> covers = [];
  List<Quote> quotes = [];
  List<Company> companies = [];
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
  static const String stripeSecretKey = 'your-stripe-secret-key-here';
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

  static const Color blueGreen = Color(0xFF26A69A);
  static const Color orange = Color(0xFFFFA726);

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

  late String pdfTemplateKey;

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
      isDesktop = !kIsWeb && MediaQuery.of(context).size.width > 600; // Example threshold

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

  Future<void> _saveInsuredItems() async {
    final key = encrypt.Key.fromLength(32);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(
      jsonEncode(insuredItems.map((item) => item.toJson()).toList()),
      iv: iv,
    );
    await secureStorage.write(key: 'insured_items', value: encrypted.base64);
  }

  Future<void> _uploadLogbook() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _logbookFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _uploadPreviousPolicy() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _previousPolicyFile = File(result.files.single.path!);
        autofillFromPreviousPolicy(
            _previousPolicyFile!, extractedData, selectedCompany);
      });
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
      print('Error in autofillFromPreviousPolicy: $e');
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
      print('Error in autofillFromLogbook: $e');
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
              const SnackBar(content: Text('Please sign in to view policies')),
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
        print('No quotes found for user $userId.');
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

  Future<void> _saveQuotes() async {
    final key = encrypt.Key.fromLength(32);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(
      jsonEncode(
        quotes
            .map(
              (quote) => {
                'id': quote.id,
                'type': quote.type,
                'subtype': quote.subtype,
                'company': quote.company,
                'premium': quote.premium,
                'formData': quote.formData,
                'generatedAt': quote.generatedAt.toIso8601String(),
              },
            )
            .toList(),
      ),
      iv: iv,
    );
    await secureStorage.write(key: 'quotes', value: encrypted.base64);
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
    if (chatbotTemplate == null || !chatbotTemplate.containsKey('states')) {
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
        setState(() {
          insuredItems.add(insuredItem);
        });
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
        setState(() {
          currentState = 'quote_process';
          chatMessages.add({
            'sender': 'bot',
            'text':
                'Your ${type.toUpperCase()} quote ($subtype) has been generated.',
          });
        });
        return;
      }

      // Proceed with payment (original flow)
      // Create Cover
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
      );

      // Save cover to Firestore
      await FirebaseFirestore.instance
          .collection('covers')
          .doc(cover.id)
          .set(cover.toJson());
      setState(() {
        covers.add(cover);
      });

      // Handle PDF generation
      File? pdfFile;
      if (cachedPdfTemplates.isNotEmpty &&
          cachedPdfTemplates.containsKey(pdfTemplateKey)) {
        pdfFile = await _fillPdfTemplate(
          pdfTemplateKey,
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

      setState(() {
        final index = covers.indexWhere((c) => c.id == cover.id);
        covers[index] = cover.copyWith(
          status: paymentStatus == 'completed'
              ? CoverStatus.active
              : CoverStatus.pending,
          paymentStatus: paymentStatus,
        );
      });

      // Update chatbot state and UI
      setState(() {
        currentState = type == 'medical' ? 'health_process' : 'pdf_process';
        chatMessages.add({
          'sender': 'bot',
          'text':
              'Your ${type.toUpperCase()} cover ($subtype) has been created. Payment status: $paymentStatus.',
        });
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Cover created, payment $paymentStatus${pdfFile == null ? ', no PDF generated' : ''}'),
          ),
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
      print('Paystack auto-billing error: $e');
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

  String _buildSelectItemMessage() {
    String items = insuredItems
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value.type}')
        .join('\n');
    String newOption = '${insuredItems.length + 1}. Enter new details';
    return chatbotTemplate['states']['select_item']['message']
        .replaceAll('{items}', items.isEmpty ? 'No items' : items)
        .replaceAll('{new_option}', newOption);
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
        return _buildHomeScreen(context);
      case 1:
        return _buildQuotesScreen();
      case 2:
        return _buildUpcomingScreen();
      case 3:
        return _buildMyAccountScreen(context);
      default:
        return _buildHomeScreen(context);
    }
  }

  Widget _buildHomeScreen(BuildContext context) {
    return Consumer2<ColorProvider, DialogState>(
      builder: (context, colorProvider, dialogState, _) {
        return FutureBuilder<List<PolicyType>>(
          future: InsuranceHomeScreen.getPolicyTypes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final policyTypes = snapshot.data ?? [];
            final currentType = dialogState.currentType;
            final dialogIndex = dialogState.currentStep;

            return CustomScrollView(
              slivers: [
                if (!kIsWeb)
                  SliverAppBar(
                    pinned: true,
                    title: Text('BIMA GUARDIAN', style: GoogleFonts.lora()),
                    backgroundColor: blueGreen,
                    actions: [
                      if (userRole == UserRole.admin)
                        IconButton(
                          icon: Icon(Icons.admin_panel_settings,
                              color: colorProvider.color),
                          onPressed: () =>
                              Navigator.pushNamed(context, '/admin'),
                          tooltip: 'Admin Panel',
                        ),
                      Stack(
                        children: [
                          IconButton(
                            icon: Icon(Icons.notifications,
                                color: colorProvider.color),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NotificationsScreen(
                                      notifications: notifications),
                                ),
                              );
                            },
                            tooltip: 'Notifications',
                          ),
                          if (notifications.isNotEmpty)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: orange,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                    minWidth: 16, minHeight: 16),
                                child: Text(
                                  '${notifications.length}',
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.save, color: colorProvider.color),
                        onPressed: () {
                          if (dialogState.currentType.isNotEmpty) {
                            dialogState.saveProgress(
                                dialogState.currentType, dialogIndex);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Progress saved')),
                            );
                          }
                        },
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
                          height: 180.0,
                          autoPlay: true,
                          autoPlayInterval: const Duration(seconds: 3),
                          enlargeCenterPage: true,
                          viewportFraction: 0.9,
                          aspectRatio: 2.0,
                        ),
                        items: [
                          'assets/banners/promo1.jpg',
                          'assets/banners/promo2.jpg',
                          'assets/banners/promo3.jpg',
                        ].map((imagePath) {
                          return Container(
                            width: MediaQuery.of(context).size.width,
                            margin: const EdgeInsets.symmetric(horizontal: 5.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: AssetImage(imagePath),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      if (currentType.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: FutureBuilder<
                              Map<String, List<DialogStepConfig>>>(
                            future: getInsuranceConfigs(
                                currentType, pdfTemplateKey),
                            builder: (context, snapshot) {
                              final dialogCount =
                                  snapshot.data?[currentType]?.length ?? 1;
                              return LinearProgressIndicator(
                                value: (dialogIndex + 1) / dialogCount,
                                backgroundColor: blueGreen.withOpacity(0.3),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(orange),
                                semanticsLabel:
                                    'Progress: ${(dialogIndex + 1) / dialogCount * 100}%',
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Select Your Insurance Cover',
                          style: GoogleFonts.lora(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1B263B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: policyTypes.length,
                        itemBuilder: (context, index) {
                          final policyType = policyTypes[index];
                          final icon = getIconFromString(policyType.icon) ??
                              _fallbackIcon(policyType.name.toLowerCase());
                          return GestureDetector(
                            onTap: () {
                              colorProvider.setColor(orange);
                              showInsuranceDialog(
                                context,
                                policyType.name.toLowerCase(), pdfTemplateKey,
                                onFinalSubmit:
                                    null, // Handled by _handleCoverSubmission
                              );
                            },
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    icon,
                                    size: 40,
                                    color: colorProvider.color,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    policyType.name.toUpperCase(),
                                    style: GoogleFonts.roboto(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF1B263B),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
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
        );
      },
    );
  }

// Icon mapping and fallback (unchanged)
  IconData? getIconFromString(String? iconName) {
    if (iconName == null) return null;
    switch (iconName.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'health':
        return Icons.local_hospital;
      case 'travel':
        return Icons.flight;
      case 'property':
        return Icons.home;
      case 'wiba':
        return Icons.work;
      default:
        return Icons.car_repair_outlined;
    }
  }

  IconData _fallbackIcon(String type) {
    switch (type.toLowerCase()) {
      case 'motor':
        return Icons.directions_car;
      case 'medical':
        return Icons.local_hospital;
      case 'travel':
        return Icons.flight;
      case 'property':
        return Icons.home;
      case 'wiba':
        return Icons.work;
      default:
        return Icons.car_repair_outlined;
    }
  }

// Helper method to fetch policy types and subtypes from Firestore
  Future<Map<String, List<PolicySubtype>>>
      _fetchPolicyTypesAndSubtypes() async {
    final policyTypes = await InsuranceHomeScreen.getPolicyTypes();
    final Map<String, List<PolicySubtype>> result = {};

    for (var type in policyTypes) {
      final subtypes = await InsuranceHomeScreen.getPolicySubtypes(type.id);
      result[type.name.toLowerCase()] = subtypes;
    }

    return result;
  }

  // Quotes screen
  Widget _buildQuotesScreen() {
    return ListView.builder(
      padding: EdgeInsets.all(16.0),
      itemCount: quotes.length,
      itemBuilder: (context, index) {
        final quote = quotes[index];
        return Card(
          elevation: 2,
          margin: EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(
              '${quote.type} - ${quote.subtype}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Premium: KES ${quote.premium.toStringAsFixed(2)}'),
            trailing: Text(
              '${quote.generatedAt.day}/${quote.generatedAt.month}/${quote.generatedAt.year}',
            ),
          ),
        );
      },
    );
  }

  // Upcoming screen (policies nearing expiration)
  Widget _buildUpcomingScreen() {
    final upcomingPolicies = policies.where((policy) {
      if (policy.endDate == null) return false;
      final daysUntilExpiration =
          policy.endDate!.difference(DateTime.now()).inDays;
      return daysUntilExpiration <= 30 && daysUntilExpiration > 0;
    }).toList();

    return ListView.builder(
      padding: EdgeInsets.all(16.0),
      itemCount: upcomingPolicies.length,
      itemBuilder: (context, index) {
        final policy = upcomingPolicies[index];
        final daysUntilExpiration =
            policy.endDate!.difference(DateTime.now()).inDays;
        return Card(
          elevation: 2,
          margin: EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(
              '${policy.type} - ${policy.subtype}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Expires in $daysUntilExpiration days'),
            trailing: Icon(Icons.warning_amber),
          ),
        );
      },
    );
  }

  Widget _buildMyAccountScreen(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Account',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.description),
            title: Text('Policy Reports'),
            onTap: () => Navigator.pushNamed(context, '/policy_report'),
          ),
          ListTile(
            leading: Icon(Icons.brightness_6),
            title: Text('Toggle Theme'),
            trailing: Switch(
              value: themeProvider.themeMode == ThemeMode.dark,
              onChanged: (value) {
                themeProvider.toggleTheme(value);
              },
            ),
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Log Out'),
            onTap: () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (kDebugMode) {
                  print('User signed out');
                }
                // Optionally, sign in anonymously again
                await FirebaseAuth.instance.signInAnonymously();
              } catch (e) {
                if (kDebugMode) {
                  print('Error signing out: $e');
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error signing out: $e'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // Mock fetch methods for Trending Topics and Blogs
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isDesktop = constraints.maxWidth > 800;

          return Row(
            children: [
              // Left side: Navigation Drawer for desktop
              if (isDesktop)
                Container(
                  width: 250,
                  color: Colors.blueGrey,
                  child: Column(
                    children: [
                      const SizedBox(height: 50),
                      ListTile(
                        leading: const Icon(Icons.home, size: 30),
                        title: const Text("Home"),
                        onTap: () => _onItemTapped(0),
                      ),
                      ListTile(
                        leading: const Icon(Icons.request_quote, size: 30),
                        title: const Text("Quotes"),
                        onTap: () => _onItemTapped(1),
                      ),
                      ListTile(
                        leading: const Icon(Icons.hourglass_bottom_outlined,
                            size: 30),
                        title: const Text("Upcoming"),
                        onTap: () => _onItemTapped(2),
                      ),
                      ListTile(
                        leading: const Icon(Icons.account_circle, size: 30),
                        title: const Text("My Account"),
                        onTap: () => _onItemTapped(3),
                      ),
                      if (userRole == UserRole.admin)
                        ListTile(
                          leading:
                              const Icon(Icons.admin_panel_settings, size: 30),
                          title: const Text("Admin Panel"),
                          onTap: () => Navigator.pushNamed(context, '/admin'),
                        ),
                    ],
                  ),
                ),
              // Main content
              Expanded(child: _getSelectedScreen()),
              // Right side: Trending topics and Blogs for desktop
              if (isDesktop)
                Container(
                  width: 250,
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[200],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Trending in Insurance",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      trendingTopics.isNotEmpty
                          ? ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: trendingTopics.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                    title: Text(trendingTopics[index]));
                              },
                            )
                          : const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 20),
                      const Text(
                        "Learn more about Insurance",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      blogPosts.isNotEmpty
                          ? ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: blogPosts.length,
                              itemBuilder: (context, index) {
                                return ListTile(title: Text(blogPosts[index]));
                              },
                            )
                          : const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () => _showChatBottomSheet(context),
              tooltip: 'Open Chatbot',
              child: const Icon(Icons.chat, size: 30),
            )
          : null,
      appBar: kIsWeb 
          ? AppBar(
              title: const Text('BIMA GUARDIAN'),
              actions: [
                if (isDesktop)
                  // Only notification icon for desktop
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications, size: 20),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NotificationsScreen(
                                notifications: notifications,
                              ),
                            ),
                          );
                        },
                        tooltip: 'Notifications',
                      ),
                      if (notifications.isNotEmpty)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${notifications.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                if (!isDesktop) ...[
                  // Full actions for non-desktop web
                  IconButton(
                    icon: const Icon(Icons.home, size: 20),
                    onPressed: () => _onItemTapped(0),
                    tooltip: 'Home',
                  ),
                  IconButton(
                    icon: const Icon(Icons.request_quote, size: 20),
                    onPressed: () => _onItemTapped(1),
                    tooltip: 'Quotes',
                  ),
                  IconButton(
                    icon: const Icon(Icons.hourglass_bottom_outlined, size: 20),
                    onPressed: () => _onItemTapped(2),
                    tooltip: 'Upcoming',
                  ),
                  IconButton(
                    icon: const Icon(Icons.account_circle, size: 20),
                    onPressed: () => _onItemTapped(3),
                    tooltip: 'My Account',
                  ),
                  if (userRole == UserRole.admin)
                    IconButton(
                      icon: const Icon(Icons.admin_panel_settings, size: 20),
                      onPressed: () => Navigator.pushNamed(context, '/admin'),
                      tooltip: 'Admin Panel',
                    ),
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications, size: 20),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NotificationsScreen(
                                notifications: notifications,
                              ),
                            ),
                          );
                        },
                        tooltip: 'Notifications',
                      ),
                      if (notifications.isNotEmpty)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${notifications.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            )
          : null,
      bottomNavigationBar: kIsWeb
          ? null
          : BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home, size: 30),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.request_quote, size: 30),
                  label: 'Quotes',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.hourglass_bottom_outlined, size: 30),
                  label: 'Upcoming',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_circle, size: 30),
                  label: 'My Account',
                ),
              ],
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
                  const Text(
                    'Chat with BIMA Bot',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                                pdfTemplateKey,
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
    final insuranceHomeScreen = InsuranceHomeScreen();

    // Fetch pdfTemplateKey
    String? pdfTemplateKey;
    if (coverageType.pdfTemplateKey != null) {
      pdfTemplateKey = coverageType.pdfTemplateKey;
    } else if (subtype.pdfTemplateKey != null) {
      pdfTemplateKey = subtype.pdfTemplateKey;
    } else {
      pdfTemplateKey = type.pdfTemplateKey;
    }

    const List<String> inpatientLimits = [
      '100000',
      '500000',
      '1000000',
      '2000000'
    ];
    const List<String> medicalServices = [
      'general',
      'surgery',
      'dental',
      'optical',
      'maternity'
    ];
    const List<String> underwriters = [
      'Aetna',
      'Cigna',
      'UnitedHealth',
      'Humana',
      'Kaiser'
    ];
    const List<String> vehicleTypes = [
      'private',
      'commercial',
      'motorcycle',
      'psv'
    ];

    // Field definitions
    final Map<String, FieldDefinition> travelFields = {
      'name': FieldDefinition(
        expectedType: ExpectedType.name,
        validator: (value) =>
            value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
                ? null
                : 'Invalid name',
      ),
      'email': FieldDefinition(
        expectedType: ExpectedType.email,
        validator: (value) => value.isEmpty ||
                RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                    .hasMatch(value)
            ? null
            : 'Invalid email',
      ),
      'phone': FieldDefinition(
        expectedType: ExpectedType.phone,
        validator: (value) =>
            value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)
                ? null
                : 'Invalid phone number',
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
          return val != null && val >= 1
              ? null
              : 'Must have at least 1 traveler';
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
            value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
                ? null
                : 'Invalid name',
      ),
      'email': FieldDefinition(
        expectedType: ExpectedType.email,
        validator: (value) => value.isEmpty ||
                RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                    .hasMatch(value)
            ? null
            : 'Invalid email',
      ),
      'phone': FieldDefinition(
        expectedType: ExpectedType.phone,
        validator: (value) =>
            value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)
                ? null
                : 'Invalid phone number',
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
          return val != null && val >= 1
              ? null
              : 'Must have at least 1 employee';
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
        validator: (value) => [
          'construction',
          'manufacturing',
          'services',
          'retail'
        ].contains(value)
            ? null
            : 'Invalid industry type',
      ),
    };

    final Map<String, FieldDefinition> propertyFields = {
      'name': FieldDefinition(
        expectedType: ExpectedType.name,
        validator: (value) =>
            value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
                ? null
                : 'Invalid name',
      ),
      'email': FieldDefinition(
        expectedType: ExpectedType.email,
        validator: (value) => value.isEmpty ||
                RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                    .hasMatch(value)
            ? null
            : 'Invalid email',
      ),
      'phone': FieldDefinition(
        expectedType: ExpectedType.phone,
        validator: (value) =>
            value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)
                ? null
                : 'Invalid phone number',
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
        validator: (value) => [
          'residential',
          'commercial',
          'industrial',
          'landlord'
        ].contains(value)
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
            value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
                ? null
                : 'Invalid name',
      ),
      'email': FieldDefinition(
        expectedType: ExpectedType.email,
        validator: (value) => value.isEmpty ||
                RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                    .hasMatch(value)
            ? null
            : 'Invalid email',
      ),
      'phone': FieldDefinition(
        expectedType: ExpectedType.phone,
        validator: (value) =>
            value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)
                ? null
                : 'Invalid phone number',
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
          return val != null && val >= 0 && val <= 120
              ? null
              : 'Invalid spouse age';
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
          return val != null && val >= 1
              ? null
              : 'At least 1 beneficiary is required';
        },
      ),
      'inpatient_limit': FieldDefinition(
        expectedType: ExpectedType.text,
        validator: (value) => value.isEmpty || inpatientLimits.contains(value)
            ? null
            : 'Invalid inpatient limit',
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
          return services.every((s) => medicalServices.contains(s))
              ? null
              : 'Invalid medical services';
        },
      ),
      'underwriters': FieldDefinition(
        expectedType: ExpectedType.list,
        listItemType: ExpectedType.text,
        validator: (value) {
          if (value.isEmpty) return null;
          var selected = value.split(', ').map((s) => s.trim()).toList();
          return selected.length <= 3 &&
                  selected.every((s) => underwriters.contains(s))
              ? null
              : 'Select up to 3 valid underwriters';
        },
      ),
    };

    final Map<String, FieldDefinition> motorFields = {
      'name': FieldDefinition(
        expectedType: ExpectedType.name,
        validator: (value) =>
            value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
                ? null
                : 'Invalid name',
      ),
      'email': FieldDefinition(
        expectedType: ExpectedType.email,
        validator: (value) => value.isEmpty ||
                RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                    .hasMatch(value)
            ? null
            : 'Invalid email',
      ),
      'phone': FieldDefinition(
        expectedType: ExpectedType.phone,
        validator: (value) =>
            value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)
                ? null
                : 'Invalid phone number',
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
        validator: (value) => value.isEmpty || vehicleTypes.contains(value)
            ? null
            : 'Invalid vehicle type',
      ),
    };

    // Fetch fields from PDFTemplate or use fieldMap
    Map<String, FieldDefinition> fields = {};
    if (pdfTemplateKey != null) {
      final pdfTemplate =
          await InsuranceHomeScreen.getPDFTemplate(pdfTemplateKey);
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
          }[type.name.toLowerCase()] ??
          {};
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
                          borderSide:
                              const BorderSide(color: Color(0xFFD3D3D3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFD3D3D3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF8B0000)),
                        ),
                      ),
                      value: insuredItemId,
                      items: insuredItems
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                '${item.details['name'] ?? 'Item'} (${item.type.toUpperCase()})',
                                style:
                                    const TextStyle(color: Color(0xFF1B263B)),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => insuredItemId = value),
                    ),
                  if (!createNew)
                    CheckboxListTile(
                      title: const Text(
                        'Create New Insured Item',
                        style: TextStyle(color: Color(0xFF1B263B)),
                      ),
                      value: createNew,
                      onChanged: (value) =>
                          setDialogState(() => createNew = value ?? false),
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
                          onSubmit: (details) => _showCompanyDialog(
                            context,
                            type.name,
                            subtype.name,
                            coverageType.name,
                            details,
                          ),
                          onAutofillPreviousPolicy: autofillFromPreviousPolicy,
                          onAutofillLogbook: autofillFromLogbook,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B0000), // Red
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

  void _showCompanyDialog(
    BuildContext context,
    String type,
    String subtype,
    String coverageType,
    Map<String, String> details,
  ) {
    final eligibleCompanies = companies
        .where(
          (c) => c.pdfTemplateKeys.any(
            (key) => cachedPdfTemplates.containsKey(key),
          ),
        )
        .toList();
    String companyId =
        eligibleCompanies.isNotEmpty ? eligibleCompanies[0].id : '';
    String pdfTemplateKey = eligibleCompanies.isNotEmpty
        ? eligibleCompanies[0].pdfTemplateKeys[0]
        : 'default';

    if (eligibleCompanies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No companies with compatible PDF templates available',
            style: GoogleFonts.roboto(color: Colors.white),
          ),
          backgroundColor: Color(0xFF8B0000),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: Text(
                'Select Insurance Company',
                style: GoogleFonts.lora(
                  color: Color(0xFF1B263B),
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
                      labelStyle: GoogleFonts.roboto(color: Color(0xFFD3D3D3)),
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
                        borderSide: BorderSide(color: Color(0xFF8B0000)),
                      ),
                    ),
                    value: companyId,
                    items: eligibleCompanies
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.name!,
                              style:
                                  GoogleFonts.roboto(color: Color(0xFF1B263B)),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(() {
                      companyId = value ?? companyId;
                      final company = eligibleCompanies.firstWhere(
                        (c) => c.id == companyId,
                      );
                      pdfTemplateKey = company.pdfTemplateKeys[0];
                    }),
                  ),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'PDF Template',
                      labelStyle: GoogleFonts.roboto(color: Color(0xFFD3D3D3)),
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
                        borderSide: BorderSide(color: Color(0xFF8B0000)),
                      ),
                    ),
                    value: pdfTemplateKey,
                    items: eligibleCompanies
                        .firstWhere((c) => c.id == companyId)
                        .pdfTemplateKeys
                        .map(
                          (key) => DropdownMenuItem(
                            value: key,
                            child: Text(
                              key,
                              style:
                                  GoogleFonts.roboto(color: Color(0xFF1B263B)),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(
                        () => pdfTemplateKey = value ?? pdfTemplateKey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.roboto(color: Color(0xFFD3D3D3)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
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
                    backgroundColor: Color(0xFF8B0000),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
        if (kDebugMode) {
          print('No user authenticated for loading user details.');
        }
        setState(() {
          userDetails = {};
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists && doc['details'] != null) {
        final key = encrypt.Key.fromLength(32);
        final iv = encrypt.IV.fromLength(16);
        final encrypter = encrypt.Encrypter(encrypt.AES(key));
        final decrypted = encrypter.decrypt64(doc['details'] as String, iv: iv);
        setState(() {
          userDetails = Map<String, String>.from(jsonDecode(decrypted));
        });
      } else {
        if (kDebugMode) {
          print('No user details found for user $userId.');
        }
        setState(() {
          userDetails = {};
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user details: $e');
      }
      setState(() {
        userDetails = {};
      });
    }
  }
}

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

  void saveProgress(String type, int step) {
    if (kDebugMode) {
      print(
          'Saving progress: type=$type, step=$step, responses=$_responses, insuredItemId=$_insuredItemId, companyId=$_companyId');
    }
    // Save to Firestore if needed
  }
}

Future<Map<String, List<DialogStepConfig>>> getInsuranceConfigs(
    dynamic pdfTemplateKey, dynamic type) async {
  final policyTypes = await InsuranceHomeScreen.getPolicyTypes();
  final companies = await InsuranceHomeScreen.loadCompanies();
  final Map<String, List<DialogStepConfig>> configs = {};
  final insuranceHomeScreen = InsuranceHomeScreen();

  // Helper lists
  const List<String> inpatientLimits = [
    '100000',
    '500000',
    '1000000',
    '2000000'
  ];
  const List<String> medicalServices = [
    'general',
    'surgery',
    'dental',
    'optical',
    'maternity'
  ];
  const List<String> underwriters = [
    'Aetna',
    'Cigna',
    'UnitedHealth',
    'Humana',
    'Kaiser'
  ];
  const List<String> vehicleTypes = [
    'private',
    'commercial',
    'motorcycle',
    'psv'
  ];

  // Field definitions
  final Map<String, FieldDefinition> travelFields = {
    'name': FieldDefinition(
      expectedType: ExpectedType.name,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
              ? null
              : 'Invalid name',
    ),
    'email': FieldDefinition(
      expectedType: ExpectedType.email,
      validator: (value) => value.isEmpty ||
              RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                  .hasMatch(value)
          ? null
          : 'Invalid email',
    ),
    'phone': FieldDefinition(
      expectedType: ExpectedType.phone,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)
              ? null
              : 'Invalid phone number',
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
          value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
              ? null
              : 'Invalid name',
    ),
    'email': FieldDefinition(
      expectedType: ExpectedType.email,
      validator: (value) => value.isEmpty ||
              RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                  .hasMatch(value)
          ? null
          : 'Invalid email',
    ),
    'phone': FieldDefinition(
      expectedType: ExpectedType.phone,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)
              ? null
              : 'Invalid phone number',
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
      validator: (value) => [
        'construction',
        'manufacturing',
        'services',
        'retail'
      ].contains(value)
          ? null
          : 'Invalid industry type',
    ),
  };

  final Map<String, FieldDefinition> propertyFields = {
    'name': FieldDefinition(
      expectedType: ExpectedType.name,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
              ? null
              : 'Invalid name',
    ),
    'email': FieldDefinition(
      expectedType: ExpectedType.email,
      validator: (value) => value.isEmpty ||
              RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                  .hasMatch(value)
          ? null
          : 'Invalid email',
    ),
    'phone': FieldDefinition(
      expectedType: ExpectedType.phone,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)
              ? null
              : 'Invalid phone number',
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
      validator: (value) => [
        'residential',
        'commercial',
        'industrial',
        'landlord'
      ].contains(value)
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
          value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
              ? null
              : 'Invalid name',
    ),
    'email': FieldDefinition(
      expectedType: ExpectedType.email,
      validator: (value) => value.isEmpty ||
              RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                  .hasMatch(value)
          ? null
          : 'Invalid email',
    ),
    'phone': FieldDefinition(
      expectedType: ExpectedType.phone,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)
              ? null
              : 'Invalid phone number',
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
        return val != null && val >= 0 && val <= 120
            ? null
            : 'Invalid spouse age';
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
        return val != null && val >= 1
            ? null
            : 'At least 1 beneficiary is required';
      },
    ),
    'inpatient_limit': FieldDefinition(
      expectedType: ExpectedType.text,
      validator: (value) => value.isEmpty || inpatientLimits.contains(value)
          ? null
          : 'Invalid inpatient limit',
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
        return services.every((s) => medicalServices.contains(s))
            ? null
            : 'Invalid medical services';
      },
    ),
    'underwriters': FieldDefinition(
      expectedType: ExpectedType.list,
      listItemType: ExpectedType.text,
      validator: (value) {
        if (value.isEmpty) return null;
        var selected = value.split(', ').map((s) => s.trim()).toList();
        return selected.length <= 3 &&
                selected.every((s) => underwriters.contains(s))
            ? null
            : 'Select up to 3 valid underwriters';
      },
    ),
  };

  final Map<String, FieldDefinition> motorFields = {
    'name': FieldDefinition(
      expectedType: ExpectedType.name,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
              ? null
              : 'Invalid name',
    ),
    'email': FieldDefinition(
      expectedType: ExpectedType.email,
      validator: (value) => value.isEmpty ||
              RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                  .hasMatch(value)
          ? null
          : 'Invalid email',
    ),
    'phone': FieldDefinition(
      expectedType: ExpectedType.phone,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)
              ? null
              : 'Invalid phone number',
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
      validator: (value) => value.isEmpty || vehicleTypes.contains(value)
          ? null
          : 'Invalid vehicle type',
    ),
  };

  for (var policyType in policyTypes) {
    final subtypes = await InsuranceHomeScreen.getPolicySubtypes(policyType.id);
    final coverageTypes = await InsuranceHomeScreen.getCoverageTypes();
    final companyOptions = companies.map((c) => c.name).toList();

    final subtypeOptions = subtypes.map((s) => s.name).toList();
    final coverageOptions = coverageTypes.map((c) => c.name).toList();

    final typeName = policyType.name.toLowerCase();
    // Fetch fields from PDFTemplate or use fieldMap
    Map<String, FieldDefinition> fields = {};
    if (pdfTemplateKey != null) {
      final pdfTemplate =
          await InsuranceHomeScreen.getPDFTemplate(pdfTemplateKey);
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
          }[type.name.toLowerCase()] ??
          {};
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
            validator: (value) =>
                value != null ? null : 'Please select a subtype',
          ),
          if (typeName == 'medical')
            FieldConfig(
              key: 'beneficiaries',
              label: 'Number of Beneficiaries (Min 3)',
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                int? val = int.tryParse(value);
                return val != null && val >= 3
                    ? null
                    : 'Minimum 3 beneficiaries';
              },
              dependsOnKey: 'subtype',
              dependsOnValue: 'corporate',
            ),
        ],
        customValidator: (responses) {
          if (typeName == 'medical' && responses['subtype'] == 'corporate') {
            int? val = int.tryParse(responses['beneficiaries'] ?? '');
            return val != null && val >= 3;
          }
          return true;
        },
        nextStep: 'coverage',
        pdfTemplateKeySource: 'type',
        customCallback: (context, dialogState) async {
          return; // Ensure non-null return
        },
      ),
      DialogStepConfig(
        title: 'Select Coverage Type',
        fields: [
          FieldConfig(
            key: 'coverage_type',
            label: 'Coverage Type',
            type: 'dropdown',
            options: coverageOptions,
            validator: (value) =>
                value != null ? null : 'Please select a coverage type',
          ),
        ],
        nextStep: typeName == 'medical' ? 'personal_info' : 'insured_item',
        pdfTemplateKeySource: 'coverage',
        customCallback: (context, dialogState) async {
          return; // Ensure non-null return
        },
      ),
      if (typeName == 'medical')
        DialogStepConfig(
          title: 'Personal and Family Information',
          fields: [
            FieldConfig(
              key: 'name',
              label: 'Name',
              validator: (value) =>
                  medicalFields['name']!.validator!(value ?? ''),
            ),
            FieldConfig(
              key: 'email',
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              validator: (value) =>
                  medicalFields['email']!.validator!(value ?? ''),
            ),
            FieldConfig(
              key: 'phone',
              label: 'Phone Number',
              keyboardType: TextInputType.phone,
              validator: (value) =>
                  medicalFields['phone']!.validator!(value ?? ''),
            ),
            FieldConfig(
              key: 'age',
              label: 'Client Age',
              keyboardType: TextInputType.number,
              validator: (value) =>
                  medicalFields['age']!.validator!(value ?? ''),
            ),
            FieldConfig(
              key: 'has_spouse',
              label: 'Has Spouse',
              type: 'checkbox',
              initialValue: 'No',
            ),
            FieldConfig(
              key: 'spouse_age',
              label: 'Spouse Age',
              keyboardType: TextInputType.number,
              isRequired: false,
              validator: (value) => value != null && value.isNotEmpty
                  ? medicalFields['spouse_age']!.validator!(value)
                  : null,
              dependsOnKey: 'has_spouse',
              dependsOnValue: 'Yes',
            ),
            FieldConfig(
              key: 'has_children',
              label: 'Has Children',
              type: 'checkbox',
              initialValue: 'No',
            ),
            FieldConfig(
              key: 'children_count',
              label: 'Number of Children',
              keyboardType: TextInputType.number,
              isRequired: false,
              validator: (value) => value != null && value.isNotEmpty
                  ? medicalFields['children_count']!.validator!(value)
                  : null,
              dependsOnKey: 'has_children',
              dependsOnValue: 'Yes',
            ),
            FieldConfig(
              key: 'pre_existing_conditions',
              label: 'Pre-existing Conditions (Enter none if none)',
              validator: (value) => medicalFields['pre_existing_conditions']!
                  .validator!(value ?? ''),
            ),
            FieldConfig(
              key: 'inpatient_limit',
              label: 'Inpatient Limit',
              type: 'dropdown',
              options: inpatientLimits,
              validator: (value) =>
                  medicalFields['inpatient_limit']!.validator!(value ?? ''),
            ),
            FieldConfig(
              key: 'outpatient_limit',
              label: 'Outpatient Limit',
              keyboardType: TextInputType.number,
              validator: (value) =>
                  medicalFields['outpatient_limit']!.validator!(value ?? ''),
            ),
            FieldConfig(
              key: 'dental_limit',
              label: 'Dental Limit',
              keyboardType: TextInputType.number,
              validator: (value) =>
                  medicalFields['dental_limit']!.validator!(value ?? ''),
            ),
            FieldConfig(
              key: 'optical_limit',
              label: 'Optical Limit',
              keyboardType: TextInputType.number,
              validator: (value) =>
                  medicalFields['optical_limit']!.validator!(value ?? ''),
            ),
            FieldConfig(
              key: 'maternity_limit',
              label: 'Maternity Limit',
              keyboardType: TextInputType.number,
              validator: (value) =>
                  medicalFields['maternity_limit']!.validator!(value ?? ''),
            ),
            FieldConfig(
              key: 'medical_services',
              label: 'Medical Services (comma-separated)',
              type: 'dropdown',
              options: medicalServices,
              isMultiSelect: true,
              validator: (value) =>
                  medicalFields['medical_services']!.validator!(value ?? ''),
            ),
            FieldConfig(
              key: 'underwriters',
              label: 'Underwriters (up to 3, comma-separated)',
              type: 'dropdown',
              options: underwriters,
              isMultiSelect: true,
              validator: (value) =>
                  medicalFields['underwriters']!.validator!(value ?? ''),
            ),
          ],
          nextStep: 'insured_item',
          pdfTemplateKeySource: 'subtype',
          customCallback: (context, dialogState) async {
            return; // Ensure non-null return
          },
        ),
      DialogStepConfig(
        title: 'Select Insured Item',
        fields: [],
        nextStep: 'company',
        pdfTemplateKeySource: 'coverage',
        customCallback: (context, dialogState) async {
          final type = dialogState.currentType;
          final subtype = dialogState.responses['subtype'] ?? '';
          final coverageType = dialogState.responses['coverage_type'] ?? '';
          String? pdfTemplateKey;

          // Fetch pdfTemplateKey
          if (coverageType.isNotEmpty) {
            final coverageTypes = await InsuranceHomeScreen.getCoverageTypes();
            pdfTemplateKey = coverageTypes
                .firstWhere((c) => c.name == coverageType,
                    orElse: () =>
                        CoverageType(id: '', name: '', description: ''))
                .pdfTemplateKey;
          }
          if (pdfTemplateKey == null && subtype.isNotEmpty) {
            final subtypes = await InsuranceHomeScreen.getPolicySubtypes(type);
            pdfTemplateKey = subtypes
                .firstWhere((s) => s.name == subtype,
                    orElse: () => PolicySubtype(
                        id: '', name: '', policyTypeId: '', description: ''))
                .pdfTemplateKey;
          }
          if (pdfTemplateKey == null) {
            final policyTypes = await InsuranceHomeScreen.getPolicyTypes();
            pdfTemplateKey = policyTypes
                .firstWhere((t) => t.name.toLowerCase() == type,
                    orElse: () => PolicyType(id: '', name: '', description: ''))
                .pdfTemplateKey;
          }

          // Fetch fields from PDFTemplate or use fieldMap
          Map<String, FieldDefinition> fields = {};
          if (pdfTemplateKey != null) {
            final pdfTemplate =
                await InsuranceHomeScreen.getPDFTemplate(pdfTemplateKey);
            if (pdfTemplate != null) {
              fields = pdfTemplate.fields;
            }
          }

          // Navigate to CoverDetailScreen
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CoverDetailScreen(
                type: type,
                subtype: subtype,
                coverageType: coverageType,
                insuredItem: dialogState.insuredItemId != null
                    ? (context
                                .findAncestorStateOfType<
                                    _InsuranceHomeScreenState>()
                                ?.insuredItems ??
                            [])
                        .firstWhere(
                        (item) => item.id == dialogState.insuredItemId,
                        orElse: () => InsuredItem(
                            id: '', type: '', details: {}, vehicleType: ''),
                      )
                    : null,
                fields: fields,
                onSubmit: (details) {
                  dialogState.setInsuredItemId(details['insured_item_id']);
                  dialogState.responses.addAll(details);
                },
                onAutofillPreviousPolicy: (File file,
                    Map<String, String>? detailsMap, String? policyNumber) {
                  // Handle autofill
                },
                onAutofillLogbook:
                    (File file, Map<String, String>? detailsMap) {
                  // Handle autofill
                },
              ),
            ),
          );
          return; // Ensure non-null return
        },
      ),
      DialogStepConfig(
        title: 'Select Insurance Company',
        fields: [
          FieldConfig(
            key: 'company_id',
            label: 'Company',
            type: 'dropdown',
            options: companyOptions,
            validator: (value) =>
                value != null ? null : 'Please select a company',
          ),
          FieldConfig(
            key: 'pdf_template_key',
            label: 'PDF Template',
            type: 'dropdown',
            options: [], // Populated in GenericInsuranceDialog
            validator: (value) =>
                value != null ? null : 'Please select a template',
          ),
        ],
        pdfTemplateKeySource: null,
        customCallback: (context, dialogState) async {
          return; // Ensure non-null return
        },
      ),
    ];
  }

  return configs;
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

  var customCallback; // 'policy', 'type', 'subtype', 'coverage'

  DialogStepConfig({
    required this.title,
    required this.fields,
    this.nextStep,
    this.customValidator,
    this.pdfTemplateKeySource,
    required customCallback,
  });
}

// Dialog configuration

// Generic dialog widget with progress indicator
class GenericInsuranceDialog extends StatelessWidget {
  final String insuranceType;
  final int step;
  final DialogStepConfig config;
  final DialogState dialogState;
  final VoidCallback onCancel;
  final VoidCallback? onBack;
  final VoidCallback onSubmit;
  final Function(BuildContext, String, String, String)? onFinalSubmit;

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
  });

  Future<List<FieldConfig>> _getFields(BuildContext context) async {
    if (config.title == 'Select Insurance Company') {
      final companies = await InsuranceHomeScreen.loadCompanies();
      final companyId = dialogState.responses['company_id'];
      final selectedCompany = companies.firstWhere(
        (c) => c.id == companyId,
        orElse: () => companies.isNotEmpty
            ? companies[0]
            : Company(id: '', name: '', pdfTemplateKeys: []),
      );

      return [
        FieldConfig(
          key: 'company_id',
          label: 'Company',
          type: 'dropdown',
          options: companies.map((c) => c.name).toList(),
          validator: (value) =>
              value != null ? null : 'Please select a company',
          initialValue:
              selectedCompany.name.isNotEmpty ? selectedCompany.name : null,
        ),
        FieldConfig(
          key: 'pdf_template_key',
          label: 'PDF Template',
          type: 'dropdown',
          options: selectedCompany.pdfTemplateKeys,
          validator: (value) =>
              value != null ? null : 'Please select a template',
          initialValue: selectedCompany.pdfTemplateKeys.isNotEmpty
              ? selectedCompany.pdfTemplateKeys[0]
              : null,
        ),
      ];
    }

    return config.fields;
  }

  @override
  Widget build(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    final colorProvider = context.watch<ColorProvider>();
    final insuranceHomeScreen = InsuranceHomeScreen();

    if (config.customCallback != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        config.customCallback!(context, dialogState);
      });
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<FieldConfig>>(
      future: _getFields(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AlertDialog(
              content: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to load fields: ${snapshot.error}'),
            actions: [
              TextButton(onPressed: onCancel, child: const Text('Close'))
            ],
          );
        }

        final fields = snapshot.data ?? config.fields;

        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            config.title,
            style: GoogleFonts.lora(
              color: const Color(0xFF1B263B),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: fields.map((field) {
                  if (field.dependsOnKey != null &&
                      dialogState.responses[field.dependsOnKey!] !=
                          field.dependsOnValue) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: FormFieldWidget(
                      config: field,
                      value: dialogState.responses[field.key] ??
                          field.initialValue,
                      onChanged: (value) {
                        dialogState.updateResponse(field.key, value);
                        if (field.key == 'company_id' && value.isNotEmpty) {
                          dialogState.setCompanyId(value);
                        }
                        if (field.key == 'subtype' && value != 'corporate') {
                          dialogState.updateResponse('beneficiaries', '');
                        }
                        if (field.key == 'has_spouse' && value == 'No') {
                          dialogState.updateResponse('spouse_age', '');
                        }
                        if (field.key == 'has_children' && value == 'No') {
                          dialogState.updateResponse('children_count', '');
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
            if (onBack != null)
              TextButton(
                onPressed: onBack,
                child: Text(
                  'Back',
                  style: GoogleFonts.roboto(color: const Color(0xFFD3D3D3)),
                ),
              ),
            TextButton(
              onPressed: onCancel,
              child: Text(
                'Cancel',
                style: GoogleFonts.roboto(color: const Color(0xFFD3D3D3)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate() &&
                    (config.customValidator == null ||
                        config.customValidator!(dialogState.responses))) {
                  dialogState.saveProgress(insuranceType, step);
                  if (config.title == 'Select Insurance Company' &&
                      onFinalSubmit != null) {
                    final type = insuranceType;
                    final subtype = dialogState.responses['subtype'] ?? '';
                    final coverageType =
                        dialogState.responses['coverage_type'] ?? '';
                    final companyId = dialogState.responses['company_id'] ?? '';
                    final pdfTemplateKey =
                        dialogState.responses['pdf_template_key'] ?? '';
                    final details =
                        Map<String, String>.from(dialogState.responses);
                    if (dialogState.insuredItemId != null) {
                      details['insured_item_id'] = dialogState.insuredItemId!;
                    }
                    await (context
                        .findAncestorStateOfType<_InsuranceHomeScreenState>()
                        ?.handleCoverSubmission(
                          context,
                          type,
                          subtype,
                          coverageType,
                          companyId,
                          pdfTemplateKey,
                          details,
                        ));
                    dialogState.resetForNewCycle();
                  } else {
                    onSubmit();
                  }
                } else {
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
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorProvider.color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                config.title == 'Select Insurance Company' ? 'Submit' : 'Next',
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

void showInsuranceDialog(
  BuildContext context,
  String insuranceType,
  dynamic pdfTemplateKey, {
  int step = 0,
  void Function(BuildContext, String, String, String)? onFinalSubmit,
}) async {
  final normalizedType = insuranceType.toLowerCase();
  final dialogState = context.read<DialogState>();
  dialogState.setCurrentType(normalizedType);
  dialogState.setCurrentStep(step);

  final configs = await getInsuranceConfigs(pdfTemplateKey, insuranceType);
  if (!configs.containsKey(normalizedType)) {
    if (kDebugMode) {
      print('Invalid insurance type: $normalizedType');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invalid insurance type: $normalizedType')),
    );
    return;
  }

  final configList = configs[normalizedType]!;
  if (step >= configList.length) {
    if (kDebugMode) {
      print('Invalid step: $step for type: $normalizedType');
    }
    return;
  }

  final config = configList[step];

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => GenericInsuranceDialog(
      insuranceType: normalizedType,
      step: step,
      config: config,
      dialogState: dialogState,
      onCancel: () {
        if (kDebugMode) {
          print('Cancel pressed for ${config.title}');
        }
        Navigator.pop(dialogContext);
      },
      onBack: step > 0
          ? () {
              if (kDebugMode) {
                print('Back pressed for ${config.title}');
              }
              Navigator.pop(dialogContext);
              showInsuranceDialog(context, normalizedType, pdfTemplateKey,
                  step: step - 1, onFinalSubmit: onFinalSubmit);
            }
          : null,
      onSubmit: () async {
        if (kDebugMode) {
          print(
              'Navigating from ${config.title}, responses: ${dialogState.responses}');
        }
        Navigator.pop(dialogContext);
        if (step + 1 < configList.length) {
          showInsuranceDialog(context, normalizedType, pdfTemplateKey,
              step: step + 1, onFinalSubmit: onFinalSubmit);
        } else {
          // Fetch pdfTemplateKey for Policy
          String? pdfTemplateKey = dialogState.responses['pdfTemplateKey'];
          final subtypeName = dialogState.responses['subtype'] ?? '';
          final coverageName = dialogState.responses['coverage_type'] ?? '';

          final policyTypes = await InsuranceHomeScreen.getPolicyTypes();
          final policyType = policyTypes.firstWhere(
            (t) => t.name.toLowerCase() == normalizedType,
            orElse: () => PolicyType(
                id: normalizedType, name: normalizedType, description: ''),
          );

          final subtypes =
              await InsuranceHomeScreen.getPolicySubtypes(policyType.id);
          final subtype = subtypes.firstWhere(
            (s) => s.name == subtypeName,
            orElse: () => PolicySubtype(
                id: subtypeName,
                name: subtypeName,
                policyTypeId: policyType.id,
                description: ''),
          );

          final coverageTypes = await InsuranceHomeScreen.getCoverageTypes();
          final coverageType = coverageTypes.firstWhere(
            (c) => c.name == coverageName,
            orElse: () => CoverageType(
                id: coverageName, name: coverageName, description: ''),
          );

          final policy = Policy(
            id: const Uuid().v4(),
            insuredItemId: dialogState.responses['insured_item'] ?? '',
            companyId: 'default_company',
            type: policyType,
            subtype: subtype,
            coverageType: coverageType,
            status: CoverStatus.active,
            endDate: DateTime.now().add(const Duration(days: 365)),
            pdfTemplateKey: pdfTemplateKey,
          );

          _showCompletionDialog(
              context, normalizedType, policy, pdfTemplateKey, onFinalSubmit);
        }
      },
    ),
  );
}

void _showCompletionDialog(
  BuildContext context,
  String type,
  Policy policy,
  pdfTemplateKey,
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
            showInsuranceDialog(context, type, pdfTemplateKey,
                step: 0, onFinalSubmit: onFinalSubmit);
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

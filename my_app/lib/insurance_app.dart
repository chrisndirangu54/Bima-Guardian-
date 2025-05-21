import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_app/Models/Insured_item.dart';
import 'package:my_app/Models/company.dart';
import 'package:my_app/Models/cover.dart';
import 'package:my_app/Models/field_definition.dart';
import 'package:my_app/Models/pdf_template.dart';
import 'package:my_app/Models/policy.dart';
import 'package:my_app/Screens/cover_screen.dart';
import 'package:my_app/Screens/pdf_preview.dart';
import 'package:pdf_render/pdf_render_widgets.dart';
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
import 'package:fl_chart/fl_chart.dart' as charts;
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;

enum UserRole { admin, regular }

enum CoverStatus { active, inactive, extended, nearingExpiration, expired }

enum ExpectedType { text, number, email, phone, date, custom }

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

  Future<void> toJson() async {}
}

class InsuranceHomeScreen extends StatefulWidget {
  const InsuranceHomeScreen({super.key});

  @override
  State<InsuranceHomeScreen> createState() => _InsuranceHomeScreenState();
}

class _InsuranceHomeScreenState extends State<InsuranceHomeScreen> {
  List<InsuredItem> insuredItems = [];
  List<Cover> covers = [];
  List<Quote> quotes = [];
  List<Quote> companies = [];

  bool isLoading = false;
  Map<String, PDFTemplate> cachedPdfTemplates = {};
  Map<String, String> userDetails = {};
  List<Map<String, String>> chatMessages = [];
  TextEditingController chatController = TextEditingController();
  String currentState = 'start';
  Map<String, dynamic> chatbotTemplate = {};
  Map<String, String> formResponses = {};
  int currentFieldIndex = 0;
  UserRole userRole = UserRole.regular;
  final secureStorage = const FlutterSecureStorage();
  String? selectedInsuredItemId;
  String? selectedQuoteId;
  static const String openAiApiKey = 'your-openai-api-key-here';
  static const String mpesaApiKey = 'your-mpesa-api-key-here';
  static const String stripeSecretKey = 'your-stripe-secret-key-here';
  List<Policy> policies = [];

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

  final List<String> _vehicleTypes = [
    'Private',
    'Commercial',
    'PSV',
    'Motorcycle',
    'Tuk Tuk',
    'Special Classes',
  ];

  final List<String> _inpatientLimits = [
    'KES 500,000',
    'KES 1,000,000',
    'KES 2,000,000',
    'KES 3,000,000',
    'KES 4,000,000',
    'KES 5,000,000',
    'KES 10,000,000',
  ];

  final List<String> _medicalServices = [
    'Outpatient',
    'Dental & Optical',
    'Maternity',
  ];

  final List<String> _underwriters = [
    'Jubilee Health',
    'Old Mutual',
    'AAR',
    'CIC General',
    'APA',
    'Madison',
    'Britam',
    'First Assurance',
    'Pacis',
  ];

  // Updated baseFields to remove vehicle_value, regno, property_value and add health-specific fields
  final Map<String, FieldDefinition> baseFields = {
    'name': FieldDefinition(
      expectedType: 'Name',
      validator:
          (value) =>
              value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
                  ? null
                  : 'Invalid name',
    ),
    'email': FieldDefinition(
      expectedType: 'email',
      validator:
          (value) =>
              value.isEmpty ||
                      RegExp(
                        r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                      ).hasMatch(value)
                  ? null
                  : 'Invalid email',
    ),
    'phone': FieldDefinition(
      expectedType: 'phone',
      validator:
          (value) =>
              value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)
                  ? null
                  : 'Invalid phone number',
    ),
    'age': FieldDefinition(
      expectedType: 'number',
      validator: (value) {
        if (value.isEmpty) return null;
        int? val = int.tryParse(value);
        return val != null && val >= 0 && val <= 120 ? null : 'Invalid age';
      },
    ),
    'spouse_age': FieldDefinition(
      expectedType: 'number',
      validator: (value) {
        if (value.isEmpty) return null;
        int? val = int.tryParse(value);
        return val != null && val >= 0 && val <= 120
            ? null
            : 'Invalid spouse age';
      },
    ),
    'children_count': FieldDefinition(
      expectedType: 'number',
      validator: (value) {
        if (value.isEmpty) return null;
        int? val = int.tryParse(value);
        return val != null && val >= 0 ? null : 'Invalid number of children';
      },
    ),
    'health_condition': FieldDefinition(
      expectedType: 'text',
      validator: (value) => null,
    ),
  };

  @override
  void initState() {
    super.initState();
    _loadCachedPdfTemplates();
    _loadUserDetails();
    _loadInsuredItems();
    _loadPolicies();
    _loadQuotes();
    _loadChatbotTemplate();
    _startChatbot();
    _checkUserRole();
    _setupFirebaseMessaging();
    _checkCoverExpirations();
    _autofillUserDetails();
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

  Future<void> _loadInsuredItems() async {
    String? data = await secureStorage.read(key: 'insured_items');
    if (data != null) {
      final key = encrypt.Key.fromLength(32);
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final decrypted = encrypter.decrypt64(data, iv: iv);
      setState(() {
        insuredItems =
            (jsonDecode(decrypted) as List)
                .map((item) => InsuredItem.fromJson(item))
                .toList();
      });
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
        _autofillFromPreviousPolicy(_previousPolicyFile!);
      });
    }
  }

  Future<void> _autofillFromPreviousPolicy(File pdfFile) async {
    try {
      PDFDoc doc = await PDFDoc.fromPath(pdfFile.path);
      String text = await doc.text;
      // Simulate extracting data from PDF (in practice, use regex or NLP)
      // For demo, assume text contains key-value pairs like "Name: John Doe"
      final lines = text.split('\n');
      final extracted = <String, String>{};
      for (var line in lines) {
        if (line.contains('Name:')) {
          extracted['name'] = line.split(':').last.trim();
        }
        if (line.contains('Email:')) {
          extracted['email'] = line.split(':').last.trim();
        }
        if (line.contains('Phone:')) {
          extracted['phone'] = line.split(':').last.trim();
        }
        if (line.contains('Registration Number:')) {
          extracted['regno'] = line.split(':').last.trim();
        }
        if (line.contains('Vehicle Value:')) {
          extracted['vehicle_value'] = line.split(':').last.trim();
        }
        if (line.contains('Chassis Number:')) {
          extracted['chassis_number'] = line.split(':').last.trim();
        }
        if (line.contains('KRA Pin:')) {
          extracted['kra_pin'] = line.split(':').last.trim();
        }
      }
      setState(() {
        _nameController.text = extracted['name'] ?? _nameController.text;
        _emailController.text = extracted['email'] ?? _emailController.text;
        _phoneController.text = extracted['phone'] ?? _phoneController.text;
        _chassisNumberController.text =
            extracted['chassis_number'] ?? _chassisNumberController.text;
        _kraPinController.text = extracted['kra_pin'] ?? _kraPinController.text;
        if (extracted['regno'] != null) {
          formResponses['regno'] = extracted['regno']!;
        }
        if (extracted['vehicle_value'] != null) {
          formResponses['vehicle_value'] = extracted['vehicle_value']!;
        }
      });
    } catch (e) {
      print('Error autofilling from previous policy: $e');
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.notification?.body ?? 'New notification'),
        ),
      );
    });
  }

  Future<void> _loadPolicies() async {
    String? data = await secureStorage.read(key: 'policies');
    final key = encrypt.Key.fromLength(32);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final decrypted = encrypter.decrypt64(data!, iv: iv);
    setState(() {
      policies =
          (jsonDecode(decrypted) as List)
              .map(
                (item) => Policy(
                  id: item['id'],
                  type: item['type'],
                  subtype: item['subtype'],
                  companyId: item['company'],
                  status: CoverStatus.values[item['status']],
                  insuredItemId: '',
                  coverageType: '',
                  pdfTemplateKey: '',
                  endDate: null,
                ),
              )
              .toList();
    });
  }

  Future<void> _loadQuotes() async {
    String? data = await secureStorage.read(key: 'quotes');
    final key = encrypt.Key.fromLength(32);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final decrypted = encrypter.decrypt64(data!, iv: iv);
    setState(() {
      quotes =
          (jsonDecode(decrypted) as List)
              .map(
                (item) => Quote(
                  id: item['id'],
                  type: item['type'],
                  subtype: item['subtype'],
                  company: item['company'],
                  premium: item['premium'].toDouble(),
                  formData: Map<String, String>.from(item['formData']),
                  generatedAt: DateTime.parse(item['generatedAt']),
                ),
              )
              .toList();
    });
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
        final daysUntilExpiration = cover.expirationDate.difference(now).inDays;
        if (daysUntilExpiration <= 0 && cover.status != CoverStatus.expired) {
          setState(() {
            covers =
                covers
                    .map(
                      (c) =>
                          c.id == cover.id
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
            covers =
                covers
                    .map(
                      (c) =>
                          c.id == cover.id
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

  void _loadChatbotTemplate() {
    chatbotTemplate = {
      'states': {
        'start': {
          'message': 'Hi! 😊 Let’s assist you. What would you like to do?',
          'options': [
            {'text': 'Generate a quote', 'next': 'vehicle_type'},
            {'text': 'Fill a form', 'next': 'select_item'},
            {'text': 'Explore insurance', 'next': 'insurance'},
            {'text': 'Add insured item', 'next': 'add_item'},
            {'text': 'View policies', 'next': 'view_policies'},
          ],
        },
        'vehicle_type': {
          'message':
              'Please select your vehicle type:\n' +
              _vehicleTypes
                  .asMap()
                  .entries
                  .map((e) => '${e.key + 1}. ${e.value}')
                  .join('\n'),
          'options':
              _vehicleTypes
                  .map((type) => {'text': type, 'next': 'quote_type'})
                  .toList(),
        },
        'quote_type': {
          'message':
              'Choose an insurance type for your quote:\n1. Auto Insurance\n2. Home Insurance\n3. Health Insurance',
          'options': [
            {'text': 'Auto Insurance', 'next': 'quote_auto_subtype'},
            {'text': 'Home Insurance', 'next': 'quote_home_subtype'},
            {'text': 'Health Insurance', 'next': 'health_inpatient_limit'},
          ],
        },
        'health_inpatient_limit': {
          'message':
              'Please select your preferred Inpatient Limit:\n' +
              _inpatientLimits
                  .asMap()
                  .entries
                  .map((e) => '${e.key + 1}. ${e.value}')
                  .join('\n'),
          'options':
              _inpatientLimits
                  .map(
                    (limit) => {
                      'text': limit,
                      'next': 'health_medical_services',
                    },
                  )
                  .toList(),
        },
        'health_medical_services': {
          'message':
              'Which medical services would you like included? (Select numbers, e.g., 1,2):\n' +
              _medicalServices
                  .asMap()
                  .entries
                  .map((e) => '${e.key + 1}. ${e.value}')
                  .join('\n'),
          'next': 'health_personal_info',
        },
        'health_personal_info': {
          'fields': [
            {'name': 'age', 'prompt': 'What is the client’s age?'},
            {
              'name': 'has_spouse',
              'prompt': 'Do you have a spouse? (1. Yes, 2. No)',
            },
            {
              'name': 'spouse_age',
              'prompt': 'Please provide the spouse’s age:',
            },
            {
              'name': 'has_children',
              'prompt': 'Do you have children? (1. Yes, 2. No)',
            },
            {
              'name': 'children_count',
              'prompt': 'How many children would be covered under this policy?',
            },
          ],
          'next': 'health_underwriters',
        },
        'health_underwriters': {
          'message':
              'Select up to three preferred insurance underwriters (e.g., 1,2,3):\n' +
              _underwriters
                  .asMap()
                  .entries
                  .map((e) => '${e.key + 1}. ${e.value}')
                  .join('\n'),
          'next': 'quote_filling',
        },
        'add_item': {
          'message': 'What type of item to insure? (car, home, medical)',
          'next': 'add_vehicle_type',
        },
        'add_vehicle_type': {
          'message':
              'Please select the vehicle type:\n' +
              _vehicleTypes
                  .asMap()
                  .entries
                  .map((e) => '${e.key + 1}. ${e.value}')
                  .join('\n'),
          'options':
              _vehicleTypes
                  .map((type) => {'text': type, 'next': 'add_item_details'})
                  .toList(),
        },
        'add_item_details': {
          'fields': [
            {'name': 'name', 'prompt': 'Please enter your name for the item:'},
            {
              'name': 'email',
              'prompt': 'Please enter your email for the item:',
            },
            {
              'name': 'phone',
              'prompt': 'Please enter your phone for the item:',
            },
            {
              'name': 'chassis_number',
              'prompt': 'Please enter the chassis number:',
            },
            {'name': 'kra_pin', 'prompt': 'Please enter the KRA pin:'},
            {
              'name': 'regno',
              'prompt': 'Please enter the registration number (if applicable):',
            },
            {
              'name': 'vehicle_value',
              'prompt': 'Please enter the vehicle value (if applicable):',
            },
            {
              'name': 'property_value',
              'prompt': 'Please enter the property value (if applicable):',
            },
          ],
          'next': 'add_item_upload',
        },
        'add_item_upload': {
          'message':
              'Please upload the logbook and previous policy (if any):\n1. Upload Logbook\n2. Upload Previous Policy\n3. Skip',
          'options': [
            {'text': 'Upload Logbook', 'next': 'add_item_logbook'},
            {'text': 'Upload Previous Policy', 'next': 'add_item_policy'},
            {'text': 'Skip', 'next': 'add_item_summary'},
          ],
        },
        'add_item_logbook': {
          'message':
              'Logbook uploaded. Proceed to upload previous policy or skip?\n1. Upload Previous Policy\n2. Skip',
          'options': [
            {'text': 'Upload Previous Policy', 'next': 'add_item_policy'},
            {'text': 'Skip', 'next': 'add_item_summary'},
          ],
        },
        'add_item_policy': {
          'message': 'Previous policy uploaded. Proceed to summary?',
          'next': 'add_item_summary',
        },
        'pdf_filling': {'fields': [], 'next': 'pdf_summary'},
        'pdf_upload': {
          'message':
              'Before filling the PDF, please upload the logbook and previous policy (if any):\n1. Upload Logbook\n2. Upload Previous Policy\n3. Skip',
          'options': [
            {'text': 'Upload Logbook', 'next': 'pdf_logbook'},
            {'text': 'Upload Previous Policy', 'next': 'pdf_policy'},
            {'text': 'Skip', 'next': 'pdf_filling_continue'},
          ],
        },
        'pdf_logbook': {
          'message':
              'Logbook uploaded. Upload previous policy or skip?\n1. Upload Previous Policy\n2. Skip',
          'options': [
            {'text': 'Upload Previous Policy', 'next': 'pdf_policy'},
            {'text': 'Skip', 'next': 'pdf_filling_continue'},
          ],
        },
        'pdf_policy': {
          'message': 'Previous policy uploaded. Proceed?',
          'next': 'pdf_filling_continue',
        },
        'pdf_filling_continue': {'fields': [], 'next': 'pdf_summary'},
        'pdf_missing_fields': {
          'message': 'Please provide the value for the missing field:',
          'next': 'pdf_summary',
        },
        'pdf_summary': {
          'message': 'Here’s what you’ve entered:\n{fields}\nIs this correct?',
          'options': [
            {'text': 'Yes', 'next': 'pdf_process'},
            {'text': 'No', 'next': 'pdf_filling'},
          ],
        },
        'pdf_process': {
          'message':
              'Great! Your form is being processed. You’ll hear back soon.',
          'next': 'start',
        },
      },
    };
  }

  void _startChatbot() {
    var startState = chatbotTemplate['states']['start'];
    String message =
        startState['message'] +
        '\n' +
        startState['options']
            .asMap()
            .entries
            .map((e) => '${e.key + 1}. ${e.value['text']}')
            .join('\n');
    setState(() {
      chatMessages.add({'sender': 'bot', 'text': message});
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
        builder:
            (context) => AlertDialog(
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

  // Add the corrected _fillPdfTemplate function here
  Future<File?> _fillPdfTemplate(
    String templateKey,
    Map<String, String> formData,
    Map<String, PDFTemplate> cachedPdfTemplates,
    Map<String, FieldDefinition> baseFields,
  ) async {
    try {
      PDFTemplate? template = cachedPdfTemplates[templateKey];
      final directory = await getApplicationDocumentsDirectory();
      final templateFile = File(
        '${directory.path}/pdf_templates/$templateKey.pdf',
      );

      if (!await templateFile.exists()) {
        // This part handles picking and saving a new template if it doesn't exist
        // You might need to pass context or a way to show the file picker
        // For this function to be self-contained, let's assume the template file exists
        // ScaffoldMessenger.of(null!).showSnackBar(const SnackBar(content: Text('PDF template not found locally.'))); // Placeholder, needs context
        return null;
      }

      final pdfBytes = await templateFile.readAsBytes();
      // Use pdf_render to open the existing PDF template
      final pdfDoc = await pdf.PdfDocument.openData(pdfBytes);

      // Create a new pdf document using the pdf package for drawing content
      final outputPdf = pw.Document();

      // Iterate through each page of the original PDF template
      for (int i = 0; i < pdfDoc.pageCount; i++) {
        // Get the page (0-indexed in pdf_render)
        // Corrected: Await the page first
        final page = await pdfDoc.getPage(
          i + 1,
        ); // pdf_render pages are 1-indexed for getPage

        // Render the page content as an image
        final pageImage = await page.render();

        // Add the rendered page image to the output PDF
        // Corrected: Add a null check for pageImage before accessing bytes
        if (pageImage != null) {
          outputPdf.addPage(
            pw.Page(
              build: (pw.Context context) {
                return pw.Stack(
                  children: [
                    // Add the original page image as the background
                    pw.Image(
                      pw.MemoryImage(pageImage.pixels), // Access bytes property
                      width: pageImage.width.toDouble(),
                      height: pageImage.height.toDouble(),
                    ),
                    // Overlay the form data based on coordinates
                    ...formData.entries.map((entry) {
                      // Assuming template and its coordinates are available
                      final coord = template?.coordinates[entry.key];
                      // Check if coordinates exist for this field and page
                      if (coord != null &&
                          coord['page'] == (i + 1).toDouble()) {
                        // Compare with 1-indexed page
                        return pw.Positioned(
                          left: coord['x']!,
                          top: coord['y']!,
                          child: pw.Text(
                            entry.value,
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        );
                      }
                      return pw.SizedBox(); // Return an empty widget if no coordinates for this field/page
                    }).toList(),
                  ],
                );
              },
            ),
          );
        } else {
          // Handle case where page rendering failed (e.g., add a blank page or error message)
          print('Warning: Failed to render page ${i + 1}');
          outputPdf.addPage(
            pw.Page(
              build:
                  (pw.Context context) => pw.Center(
                    child: pw.Text('Error rendering page ${i + 1}'),
                  ),
            ),
          );
        }
      }
      await pdfDoc.dispose(); // Close the original document

      // Save the newly created PDF with overlaid text
      // Ensure the reports directory exists before writing
      final reportsDirectory = Directory('${directory.path}/reports');
      if (!await reportsDirectory.exists()) {
        await reportsDirectory.create(recursive: true);
      }
      final filePath = '${reportsDirectory.path}/filled_$templateKey.pdf';

      // Corrected: Save the outputPdf (pw.Document)
      await File(filePath).writeAsBytes(await outputPdf.save());

      return File(filePath); // Return the saved file
    } catch (e) {
      print('Error filling PDF template: $e');
      // Placeholder, needs context
      // ScaffoldMessenger.of(null!).showSnackBar(SnackBar(content: Text('Failed to fill PDF: $e')));
      return null;
    }
  }

  Future<File?> _generateQuotePdf(Quote quote) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build:
            (pw.Context context) => pw.Column(
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
    double factor = calculator['factor'].toDouble();
    double value =
        double.tryParse(
          formData['vehicle_value'] ?? formData['property_value'] ?? '0',
        ) ??
        0;
    return basePremium + (value * factor);
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

  Future<bool> _initiateStripePayment(double amount, bool autoBilling) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        headers: {
          'Authorization': 'Bearer $stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': (amount * 100).toInt().toString(),
          'currency': 'kes',
          'payment_method_types[]': 'card',
        },
      );

      if (response.statusCode == 200) {
        final paymentIntent = jsonDecode(response.body);
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: paymentIntent['client_secret'],
            merchantDisplayName: 'Insurance App',
          ),
        );
        await Stripe.instance.presentPaymentSheet();
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stripe Payment Failed: ${response.body}')),
        );
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Stripe payment error: $e');
      }
      return false;
    }
  }

  Future<void> _scheduleStripeAutoBilling(Cover cover) async {
    try {
      final customerResponse = await http.post(
        Uri.parse('https://api.stripe.com/v1/customers'),
        headers: {
          'Authorization': 'Bearer $stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'email': cover.formData!['email'],
          'name': cover.formData!['name'],
        },
      );

      if (customerResponse.statusCode == 200) {
        final customer = jsonDecode(customerResponse.body);
        final customerId = customer['id'];

        final subscriptionResponse = await http.post(
          Uri.parse('https://api.stripe.com/v1/subscriptions'),
          headers: {
            'Authorization': 'Bearer $stripeSecretKey',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'customer': customerId,
            'items[0][price]': 'your-stripe-price-id',
            'billing_cycle_anchor':
                cover.billingFrequency == 'monthly' ? 'month' : 'year',
          },
        );

        if (subscriptionResponse.statusCode == 200) {
          final subscription = jsonDecode(subscriptionResponse.body);
          final key = encrypt.Key.fromLength(32);
          final iv = encrypt.IV.fromLength(16);
          final encrypter = encrypt.Encrypter(encrypt.AES(key));
          final encrypted = encrypter.encrypt(
            jsonEncode({
              'coverId': cover.id,
              'customerId': customerId,
              'subscriptionId': subscription['id'],
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
    } catch (e) {
      print('Stripe auto-billing error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set up auto-billing: $e')),
      );
    }
  }

  Future<void> _sendEmail(
    String company,
    String insuranceType,
    String insuranceSubtype,
    Map<String, String> formData,
    File filledPdf,
  ) async {
    final smtpServer = gmail(
      'your-email@gmail.com',
      'your-app-specific-password',
    );

    final message =
        mailer.Message()
          ..from = const mailer.Address('your-email@gmail.com', 'Insurance App')
          ..recipients.add(
            policyCalculators[insuranceType]![insuranceSubtype]!['companyA']!['email'],
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

  Future<void> _handleChatInput(String input) async {
    setState(() {
      chatMessages.add({'sender': 'user', 'text': input});
    });

    var currentStateData = chatbotTemplate['states'][currentState];

    if (currentState == 'pdf_missing_fields') {
      final missingFields = formResponses['missing_fields']!.split(',');
      final currentIndex = int.parse(
        formResponses['current_missing_field_index']!,
      );
      final templateKey = 'default';
      final template = cachedPdfTemplates[templateKey];
      final fieldDef = template!.fields[missingFields[currentIndex]]!;
      final error = fieldDef.validator(input);

      if (error == null) {
        formResponses[missingFields[currentIndex]] = input;
        if (currentIndex + 1 < missingFields.length) {
          setState(() {
            formResponses['current_missing_field_index'] =
                (currentIndex + 1).toString();
            chatMessages.add({
              'sender': 'bot',
              'text':
                  'Please provide the value for ${missingFields[currentIndex + 1]} (Type: ${template.fields[missingFields[currentIndex + 1]]!.expectedType.toString().split('.').last}${template.fields[missingFields[currentIndex + 1]]!.isSuggested ? ', AI-Suggested' : ''}):',
            });
          });
        } else {
          formResponses.remove('missing_fields');
          formResponses.remove('current_missing_field_index');
          File? filledPdf = await _fillPdfTemplate(templateKey, formResponses);
          if (filledPdf != null && await _previewPdf(filledPdf)) {
            await _sendEmail(
              'companyA',
              formResponses['type'] ?? 'auto',
              formResponses['subtype'] ?? 'comprehensive',
              formResponses,
              filledPdf,
            );
          }
          setState(() {
            currentState = 'pdf_process';
            chatMessages.add({
              'sender': 'bot',
              'text': chatbotTemplate['states']['pdf_process']['message'],
            });
          });
        }
      } else {
        setState(() {
          chatMessages.add({
            'sender': 'bot',
            'text':
                'Error: $error. Please provide a valid value for ${missingFields[currentIndex]} (Type: ${fieldDef.expectedType.toString().split('.').last}${fieldDef.isSuggested ? ', AI-Suggested' : ''}):',
          });
        });
      }
    } else if (currentState == 'pdf_filling') {
      if (currentFieldIndex == 0) {
        setState(() {
          currentState = 'pdf_upload';
          chatMessages.add({
            'sender': 'bot',
            'text':
                'Before filling the PDF, please upload the logbook and previous policy (if any):\n1. Upload Logbook\n2. Upload Previous Policy\n3. Skip',
          });
        });
      } else {
        var fields = currentStateData['fields'];
        if (currentFieldIndex < fields.length) {
          var field = fields[currentFieldIndex];
          String fieldName = field['name'];
          String? error = baseFields[fieldName]?.validator(input);

          if (error == null) {
            formResponses[fieldName] = input;
            currentFieldIndex++;
            if (currentFieldIndex < fields.length) {
              setState(() {
                chatMessages.add({
                  'sender': 'bot',
                  'text': fields[currentFieldIndex]['prompt'],
                });
              });
            } else {
              String summary = formResponses.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join('\n');
              String nextMessage =
                  currentStateData['next']['message'].replaceAll(
                    '{fields}',
                    summary,
                  ) +
                  '\n' +
                  currentStateData['next']['options']
                      .asMap()
                      .entries
                      .map((e) => '${e.key + 1}. ${e.value['text']}')
                      .join('\n');
              setState(() {
                currentState = 'pdf_summary';
                chatMessages.add({'sender': 'bot', 'text': nextMessage});
              });
            }
          } else {
            setState(() {
              chatMessages.add({
                'sender': 'bot',
                'text': 'Error: $error. Please try again.',
              });
              chatMessages.add({'sender': 'bot', 'text': field['prompt']});
            });
          }
        }
      }
    } else if (currentState == 'vehicle_type') {
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= _vehicleTypes.length) {
        setState(() {
          formResponses['vehicle_type'] = _vehicleTypes[choice - 1];
          currentState = 'quote_type';
          chatMessages.add({
            'sender': 'bot',
            'text':
                currentStateData['options'][choice - 1]['next']['message'] +
                '\n' +
                currentStateData['options'][choice - 1]['next']['options']
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value['text']}')
                    .join('\n'),
          });
        });
      } else {
        _showError();
      }
    } else if (currentState == 'health_inpatient_limit') {
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= _inpatientLimits.length) {
        setState(() {
          formResponses['inpatient_limit'] = _inpatientLimits[choice - 1];
          currentState = 'health_medical_services';
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['options'][choice - 1]['next']['message'],
          });
        });
      } else {
        _showError();
      }
    } else if (currentState == 'health_medical_services') {
      final choices =
          input
              .split(',')
              .map((e) => int.tryParse(e.trim()))
              .where((e) => e != null)
              .toList();
      if (choices.every((c) => c! > 0 && c! <= _medicalServices.length)) {
        setState(() {
          _selectedMedicalServices =
              choices.map((c) => _medicalServices[c! - 1]).toList();
          formResponses['medical_services'] = _selectedMedicalServices.join(
            ', ',
          );
          currentState = 'health_personal_info';
          currentStateData = chatbotTemplate['states']['health_personal_info'];
          currentFieldIndex = 0;
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['fields'][0]['prompt'],
          });
        });
      } else {
        _showError();
      }
    } else if (currentState == 'health_personal_info') {
      var fields = currentStateData['fields'];
      if (currentFieldIndex < fields.length) {
        var field = fields[currentFieldIndex];
        String fieldName = field['name'];
        String? error;

        if (fieldName == 'has_spouse' || fieldName == 'has_children') {
          if (input == '1' || input == '2') {
            formResponses[fieldName] = input == '1' ? 'Yes' : 'No';
            if (fieldName == 'has_spouse' && input == '2') {
              currentFieldIndex += 2;
            } else if (fieldName == 'has_children' && input == '2') {
              currentFieldIndex += 2;
            } else {
              currentFieldIndex++;
            }
          } else {
            error = 'Please select 1 for Yes or 2 for No';
          }
        } else {
          error = baseFields[fieldName]?.validator(input);
          if (error == null) {
            formResponses[fieldName] = input;
            currentFieldIndex++;
          }
        }

        if (currentFieldIndex < fields.length) {
          setState(() {
            chatMessages.add({
              'sender': 'bot',
              'text': fields[currentFieldIndex]['prompt'],
            });
          });
        } else {
          setState(() {
            currentState = 'health_underwriters';
            chatMessages.add({
              'sender': 'bot',
              'text': currentStateData['next']['message'],
            });
          });
        }
        if (error != null) {
          setState(() {
            chatMessages.add({
              'sender': 'bot',
              'text': 'Error: $error. Please try again.',
            });
            chatMessages.add({'sender': 'bot', 'text': field['prompt']});
          });
        }
      }
    } else if (currentState == 'health_underwriters') {
      final choices =
          input
              .split(',')
              .map((e) => int.tryParse(e.trim()))
              .where((e) => e != null)
              .toList();
      if (choices.length <= 3 &&
          choices.every((c) => c! > 0 && c! <= _underwriters.length)) {
        setState(() {
          _selectedUnderwriters =
              choices.map((c) => _underwriters[c! - 1]).toList();
          formResponses['underwriters'] = _selectedUnderwriters.join(', ');
          currentState = 'quote_filling';
          currentStateData = chatbotTemplate['states']['quote_filling'];
          currentStateData['fields'] =
              baseFields.keys
                  .where(
                    (key) =>
                        !['age', 'spouse_age', 'children_count'].contains(key),
                  )
                  .map(
                    (key) => {
                      'name': key,
                      'prompt': 'Please enter your $key for health quote:',
                    },
                  )
                  .toList();
          currentFieldIndex = 0;
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['fields'][0]['prompt'],
          });
        });
      } else {
        setState(() {
          chatMessages.add({
            'sender': 'bot',
            'text':
                'You can only select up to three underwriters. Please try again.',
          });
        });
      }
    } else if (currentState == 'add_vehicle_type') {
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= _vehicleTypes.length) {
        setState(() {
          formResponses['vehicle_type'] = _vehicleTypes[choice - 1];
          currentState = 'add_item_details';
          currentStateData = chatbotTemplate['states']['add_item_details'];
          currentFieldIndex = 0;
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['fields'][0]['prompt'],
          });
        });
      } else {
        _showError();
      }
    } else if (currentState == 'add_item_details') {
      var fields = currentStateData['fields'];
      if (currentFieldIndex < fields.length) {
        var field = fields[currentFieldIndex];
        String fieldName = field['name'];
        String? error =
            baseFields[fieldName]?.validator(input) ??
            (fieldName == 'chassis_number' ||
                    fieldName == 'kra_pin' ||
                    fieldName == 'regno' ||
                    fieldName == 'vehicle_value' ||
                    fieldName == 'property_value'
                ? null
                : 'Invalid input');

        if (error == null) {
          formResponses[fieldName] = input;
          currentFieldIndex++;
          if (currentFieldIndex < fields.length) {
            setState(() {
              chatMessages.add({
                'sender': 'bot',
                'text': fields[currentFieldIndex]['prompt'],
              });
            });
          } else {
            setState(() {
              currentState = 'add_item_upload';
              chatMessages.add({
                'sender': 'bot',
                'text':
                    currentStateData['next']['message'] +
                    '\n' +
                    currentStateData['next']['options']
                        .asMap()
                        .entries
                        .map((e) => '${e.key + 1}. ${e.value['text']}')
                        .join('\n'),
              });
            });
          }
        } else {
          setState(() {
            chatMessages.add({
              'sender': 'bot',
              'text': 'Error: $error. Please try again.',
            });
            chatMessages.add({'sender': 'bot', 'text': field['prompt']});
          });
        }
      }
    } else if (currentState == 'add_item_logbook') {
      int? choice = int.tryParse(input);
      if (choice == 1) {
        await _uploadPreviousPolicy();
        setState(() {
          currentState = 'add_item_policy';
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['options'][0]['next']['message'],
          });
        });
      } else if (choice == 2) {
        setState(() {
          currentState = 'add_item_summary';
          String summary = formResponses.entries
              .map((e) => '${e.key}: ${e.value}')
              .join('\n');
          chatMessages.add({
            'sender': 'bot',
            'text':
                currentStateData['options'][1]['next']['message'].replaceAll(
                  '{fields}',
                  summary,
                ) +
                '\n' +
                currentStateData['options'][1]['next']['options']
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value['text']}')
                    .join('\n'),
          });
        });
      } else {
        _showError();
      }
    } else if (currentState == 'add_item_policy') {
      setState(() {
        currentState = 'add_item_summary';
        String summary = formResponses.entries
            .map((e) => '${e.key}: ${e.value}')
            .join('\n');
        chatMessages.add({
          'sender': 'bot',
          'text':
              currentStateData['next']['message'].replaceAll(
                '{fields}',
                summary,
              ) +
              '\n' +
              currentStateData['next']['options']
                  .asMap()
                  .entries
                  .map((e) => '${e.key + 1}. ${e.value['text']}')
                  .join('\n'),
        });
      });
    } else if (currentState == 'add_item_summary') {
      int? choice = int.tryParse(input);
      if (choice == 1) {
        insuredItems.add(
          InsuredItem(
            id: Uuid().v4(),
            type: formResponses['type'] ?? 'unknown',
            vehicleType: formResponses['vehicle_type'] ?? '',
            details: Map<String, String>.from(formResponses)..removeWhere(
              (key, _) => [
                'vehicle_value',
                'regno',
                'property_value',
                'chassis_number',
                'kra_pin',
              ].contains(key),
            ),
            vehicleValue: formResponses['vehicle_value'],
            regno: formResponses['regno'],
            propertyValue: formResponses['property_value'],
            chassisNumber: formResponses['chassis_number'],
            kraPin: formResponses['kra_pin'],
            logbookPath: _logbookFile?.path,
            previousPolicyPath: _previousPolicyFile?.path,
          ),
        );
        await _saveInsuredItems();
        setState(() {
          currentState = 'select_item';
          formResponses.clear();
          _logbookFile = null;
          _previousPolicyFile = null;
          chatMessages.add({
            'sender': 'bot',
            'text': _buildSelectItemMessage(),
          });
        });
      } else if (choice == 2) {
        setState(() {
          currentState = 'start';
          formResponses.clear();
          _logbookFile = null;
          _previousPolicyFile = null;
          chatMessages.add({
            'sender': 'bot',
            'text':
                chatbotTemplate['states']['start']['message'] +
                '\n' +
                chatbotTemplate['states']['start']['options']
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value['text']}')
                    .join('\n'),
          });
        });
      } else {
        _showError();
      }
    } else if (currentState == 'pdf_upload') {
      int? choice = int.tryParse(input);
      if (choice == 1) {
        await _uploadLogbook();
        setState(() {
          currentState = 'pdf_logbook';
          chatMessages.add({
            'sender': 'bot',
            'text':
                'Logbook uploaded. Upload previous policy or skip?\n1. Upload Previous Policy\n2. Skip',
          });
        });
      } else if (choice == 2) {
        await _uploadPreviousPolicy();
        setState(() {
          currentState = 'pdf_policy';
          chatMessages.add({
            'sender': 'bot',
            'text': 'Previous policy uploaded. Proceed?',
          });
        });
      } else if (choice == 3) {
        setState(() {
          currentState = 'pdf_filling_continue';
          currentStateData = chatbotTemplate['states']['pdf_filling'];
          currentFieldIndex = 0;
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['fields'][0]['prompt'],
          });
        });
      } else {
        _showError();
      }
    } else if (currentState == 'pdf_logbook') {
      int? choice = int.tryParse(input);
      if (choice == 1) {
        await _uploadPreviousPolicy();
        setState(() {
          currentState = 'pdf_policy';
          chatMessages.add({
            'sender': 'bot',
            'text': 'Previous policy uploaded. Proceed?',
          });
        });
      } else if (choice == 2) {
        setState(() {
          currentState = 'pdf_filling_continue';
          currentStateData = chatbotTemplate['states']['pdf_filling'];
          currentFieldIndex = 0;
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['fields'][0]['prompt'],
          });
        });
      } else {
        _showError();
      }
    } else if (currentState == 'pdf_policy') {
      setState(() {
        currentState = 'pdf_filling_continue';
        currentStateData = chatbotTemplate['states']['pdf_filling'];
        currentFieldIndex = 0;
        chatMessages.add({
          'sender': 'bot',
          'text': currentStateData['fields'][0]['prompt'],
        });
      });
    } else if (currentState == 'pdf_filling_continue') {
      var fields = currentStateData['fields'];
      if (currentFieldIndex < fields.length) {
        var field = fields[currentFieldIndex];
        String fieldName = field['name'];
        String? error = baseFields[fieldName]?.validator(input);

        if (error == null) {
          formResponses[fieldName] = input;
          currentFieldIndex++;
          if (currentFieldIndex < fields.length) {
            setState(() {
              chatMessages.add({
                'sender': 'bot',
                'text': fields[currentFieldIndex]['prompt'],
              });
            });
          } else {
            String summary = formResponses.entries
                .map((e) => '${e.key}: ${e.value}')
                .join('\n');
            String nextMessage =
                currentStateData['next']['message'].replaceAll(
                  '{fields}',
                  summary,
                ) +
                '\n' +
                currentStateData['next']['options']
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value['text']}')
                    .join('\n');
            setState(() {
              currentState = 'pdf_summary';
              chatMessages.add({'sender': 'bot', 'text': nextMessage});
            });
          }
        } else {
          setState(() {
            chatMessages.add({
              'sender': 'bot',
              'text': 'Error: $error. Please try again.',
            });
            chatMessages.add({'sender': 'bot', 'text': field['prompt']});
          });
        }
      }
    }

    chatController.clear();
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

  void _showError() {
    setState(() {
      chatMessages.add({
        'sender': 'bot',
        'text': 'Invalid input. Please try again.',
      });
    });
  }

  Future<void> _saveCovers() async {
    final storage = FlutterSecureStorage();
    await storage.write(
      key: 'covers',
      value: jsonEncode(covers.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> _loadCovers() async {
    final storage = FlutterSecureStorage();
    final data = await storage.read(key: 'covers');
    if (data != null) {
      setState(() {
        covers =
            (jsonDecode(data) as List).map((c) => Cover.fromJson(c)).toList();
      });
    }
  }

  Future<void> _saveCompanies() async {
    final storage = FlutterSecureStorage();
    await storage.write(
      key: 'companies',
      value: jsonEncode(companies.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> _loadCompanies() async {
    final storage = FlutterSecureStorage();
    final data = await storage.read(key: 'companies');
    if (data != null) {
      setState(() {
        companies =
            (jsonDecode(data) as List)
                .map((c) => Company.fromJson(c))
                .cast<Quote>()
                .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final policyTypes = {
      'motor': [
        'commercial',
        'psv',
        'psv_uber',
        'private',
        'tuk_tuk',
        'special_classes',
      ],
      'medical': ['inpatient', 'outpatient', 'maternity', 'dental', 'optical'],
      'travel': ['single_trip', 'multi_trip', 'student', 'senior_citizen'],
      'property': ['residential', 'commercial', 'industrial', 'landlord'],
      'wiba': ['standard', 'enhanced', 'contractor', 'small_business'],
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insurance Cover Selection'),
        actions: [
          if (userRole == UserRole.admin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => Navigator.pushNamed(context, '/admin'),
            ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => Navigator.pushNamed(context, '/policy_report'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Insurance Cover',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: policyTypes.keys.length,
                  itemBuilder: (context, index) {
                    final type = policyTypes.keys.toList()[index];
                    return Card(
                      child: InkWell(
                        onTap:
                            () => _showSubtypeDialog(
                              context,
                              type,
                              policyTypes[type]!,
                            ),
                        child: Center(
                          child: Text(
                            type.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: chatMessages.length,
              itemBuilder: (context, index) {
                final message = chatMessages[index];
                return ListTile(
                  title: Text(
                    message['text']!,
                    style: TextStyle(
                      color:
                          message['text']!.contains('Nearing Expiration')
                              ? Colors.yellow[800]
                              : message['text']!.contains('Expired')
                              ? Colors.red
                              : Colors.black,
                    ),
                  ),
                  subtitle: Text(message['sender'] == 'bot' ? 'Bot' : 'You'),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: chatController,
                    decoration: const InputDecoration(
                      hintText: 'Type your response...',
                    ),
                    onSubmitted: _handleChatInput,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _handleChatInput(chatController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Dialog to select subtype
  void _showSubtypeDialog(
    BuildContext context,
    String type,
    List<String> subtypes,
  ) {
    String subtype = subtypes[0];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Select $type Subtype'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: '$type Subtype'),
                    value: subtype,
                    items:
                        subtypes
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s.replaceAll('_', ' ').toUpperCase(),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) =>
                            setDialogState(() => subtype = value ?? subtype),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _showCoverageDialog(context, type, subtype);
                  },
                  child: const Text('Next'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dialog to select coverage type
  void _showCoverageDialog(BuildContext context, String type, String subtype) {
    String coverageType = 'comprehensive';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Coverage Type'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Coverage Type',
                    ),
                    value: coverageType,
                    items:
                        ['comprehensive', 'third_party']
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c.replaceAll('_', ' ').toUpperCase(),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) => setDialogState(
                          () => coverageType = value ?? coverageType,
                        ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _showInsuredItemDialog(
                      context,
                      type,
                      subtype,
                      coverageType,
                    );
                  },
                  child: const Text('Next'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dialog to select or create InsuredItem
  void _showInsuredItemDialog(
    BuildContext context,
    String type,
    String subtype,
    String coverageType,
  ) {
    String? insuredItemId;
    bool createNew = insuredItems.isEmpty;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select or Create Insured Item'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!createNew)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Existing Insured Item',
                      ),
                      value: insuredItemId,
                      items:
                          insuredItems
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(
                                    '${item.details['name'] ?? 'Item'} (${item.vehicleType.isNotEmpty ? item.vehicleType : item.type})',
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (value) =>
                              setDialogState(() => insuredItemId = value),
                    ),
                  if (!createNew)
                    CheckboxListTile(
                      title: const Text('Create New Insured Item'),
                      value: createNew,
                      onChanged:
                          (value) =>
                              setDialogState(() => createNew = value ?? false),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => CoverDetailScreen(
                              type: type,
                              subtype: subtype,
                              coverageType: coverageType,
                              insuredItem:
                                  insuredItemId != null
                                      ? insuredItems.firstWhere(
                                        (item) => item.id == insuredItemId,
                                      )
                                      : null,
                              onSubmit:
                                  (details) => _showCompanyDialog(
                                    context,
                                    type,
                                    subtype,
                                    coverageType,
                                    details,
                                  ),
                            ),
                      ),
                    );
                  },
                  child: const Text('Next'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dialog to select company
  void _showCompanyDialog(
    BuildContext context,
    String type,
    String subtype,
    String coverageType,
    Map<String, String> details,
  ) {
    // Filter companies with PDF templates supporting the coverage type
    final eligibleCompanies =
        companies
            .where(
              (c) => c.pdfTemplateKeys.any(
                (key) => cachedPdfTemplates.containsKey(key),
              ),
            )
            .toList();
    String companyId =
        eligibleCompanies.isNotEmpty ? eligibleCompanies[0].id : '';
    String pdfTemplateKey =
        eligibleCompanies.isNotEmpty
            ? eligibleCompanies[0].pdfTemplateKeys[0]
            : 'default';

    if (eligibleCompanies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No companies with compatible PDF templates available'),
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
              title: const Text('Select Insurance Company'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Company'),
                    value: companyId,
                    items:
                        eligibleCompanies
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name!),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) => setDialogState(() {
                          companyId = value ?? companyId;
                          final company = eligibleCompanies.firstWhere(
                            (c) => c.id == companyId,
                          );
                          pdfTemplateKey = company.pdfTemplateKeys[0];
                        }),
                  ),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'PDF Template',
                    ),
                    value: pdfTemplateKey,
                    items:
                        eligibleCompanies
                            .firstWhere((c) => c.id == companyId)
                            .pdfTemplateKeys
                            .map(
                              (key) => DropdownMenuItem(
                                value: key,
                                child: Text(key),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) => setDialogState(
                          () => pdfTemplateKey = value ?? pdfTemplateKey,
                        ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _handleCoverSubmission(
                      context,
                      type,
                      subtype,
                      coverageType,
                      companyId,
                      pdfTemplateKey,
                      details,
                    );
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Handle cover submission
  Future<void> _handleCoverSubmission(
    BuildContext context,
    String type,
    String subtype,
    String coverageType,
    String companyId,
    String pdfTemplateKey,
    Map<String, String> details,
  ) async {
    InsuredItem insuredItem;
    if (details['insured_item_id'] != null &&
        details['insured_item_id']!.isNotEmpty) {
      insuredItem = insuredItems.firstWhere(
        (item) => item.id == details['insured_item_id'],
      );
    } else {
      insuredItem = InsuredItem(
        id: Uuid().v4(),
        type: type,
        vehicleType: type == 'motor' ? subtype : '',
        details: details,
        vehicleValue: details['vehicle_value'],
        regno: details['regno'],
        propertyValue: details['property_value'],
        chassisNumber: details['chassis_number'],
        kraPin: details['kra_pin'],
        logbookPath: details['logbook_path'],
        previousPolicyPath: details['previous_policy_path'],
      );
      setState(() {
        insuredItems.add(insuredItem);
      });
      await _saveInsuredItems();
    }

    final cover = Cover(
      id: Uuid().v4(),
      insuredItemId: insuredItem.id,
      companyId: companyId,
      type: type,
      subtype: subtype,
      coverageType: coverageType,
      status: 'pending',
      expirationDate: DateTime.now().add(const Duration(days: 365)),
      pdfTemplateKey: pdfTemplateKey,
      paymentStatus: 'pending',
      startDate: DateTime.now().add(const Duration(days: 365)),
      formData: {},
      premium: null,
      billingFrequency: null,
    );

    setState(() {
      covers.add(cover);
    });
    await _saveCovers();

    final pdfFile = await _fillPdfTemplate(pdfTemplateKey, details);
    if (pdfFile != null && await _previewPdf(pdfFile)) {
      await _sendEmail(companyId, type, subtype, details, pdfFile);
    }

    // Initialize payment
    final paymentStatus = await _initializePayment(
      cover.id,
      details['vehicle_value'] ?? details['property_value'] ?? '1000',
    );
    setState(() {
      final index = covers.indexWhere((c) => c.id == cover.id);
      covers[index] = Cover(
        id: cover.id,
        insuredItemId: cover.insuredItemId,
        companyId: cover.companyId,
        type: cover.type,
        subtype: cover.subtype,
        coverageType: cover.coverageType,
        status: paymentStatus == 'completed' ? 'active' : 'pending',
        expirationDate: cover.expirationDate,
        pdfTemplateKey: cover.pdfTemplateKey,
        paymentStatus: paymentStatus,
        formData: {},
        startDate: DateTime.now().add(const Duration(days: 365)),
        premium: null,
        billingFrequency: null,
      );
    });
    await _saveCovers();

    setState(() {
      currentState = 'pdf_process';
      chatMessages.add({
        'sender': 'bot',
        'text':
            'Your ${type.toUpperCase()} cover ($subtype, $coverageType) has been created. Payment status: $paymentStatus.',
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cover created, PDF processed, payment $paymentStatus'),
      ),
    );
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
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/pdf_templates.json');
    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString());
      cachedPdfTemplates = data.map(
        (key, value) => MapEntry(key, PDFTemplate.fromJson(value)),
      );
    }
  }

  Future<void> _loadUserDetails() async {
    try {
      String? encrypted = await secureStorage.read(key: 'user_details');
      final key = encrypt.Key.fromLength(32);
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final decrypted = encrypter.decrypt64(encrypted!, iv: iv);
      setState(() {
        userDetails = Map<String, String>.from(jsonDecode(decrypted));
      });
    } catch (e) {
      print('Error loading user details: $e');
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_text/pdf_text.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_render/pdf_render.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseMessaging.instance.requestPermission();
  Stripe.publishableKey = 'your-stripe-publishable-key';
  await Stripe.instance.applySettings();
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
        '/policy_report': (context) => const PolicyReportScreen(),
      },
    );
  }
}

enum UserRole { admin, regular }
enum PolicyStatus { active, inactive, extended, nearingExpiration, expired }

class FieldDefinition {
  final String expectedType;
  final String? Function(String) validator;

  FieldDefinition({required this.expectedType, required this.validator});
}

class PDFTemplate {
  final Map<String, FieldDefinition> fields;
  final Map<String, String> fieldMappings;
  final Map<String, Map<String, double>> coordinates;

  PDFTemplate({required this.fields, required this.fieldMappings, required this.coordinates});

  Map<String, dynamic> toJson() => {
        'fields': fields.map((key, value) => MapEntry(key, {'expectedType': value.expectedType})),
        'fieldMappings': fieldMappings,
        'coordinates': coordinates,
      };

  factory PDFTemplate.fromJson(Map<String, dynamic> json) => PDFTemplate(
        fields: (json['fields'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, FieldDefinition(expectedType: value['expectedType'], validator: (v) => null)),
        ),
        fieldMappings: Map<String, String>.from(json['fieldMappings']),
        coordinates: (json['coordinates'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, Map<String, double>.from(value)),
        ),
      );
}

class InsuredItem {
  final String id;
  final String type;
  final Map<String, String> details;

  InsuredItem({required this.id, required this.type, required this.details});
}

class Policy {
  final String id;
  final String type;
  final String subtype;
  final String company;
  PolicyStatus status;
  final DateTime startDate;
  DateTime? endDate;
  final Map<String, String> formData;
  final double premium;
  final String billingFrequency;

  Policy({
    required this.id,
    required this.type,
    required this.subtype,
    required this.company,
    required this.status,
    required this.startDate,
    this.endDate,
    required this.formData,
    required this.premium,
    required this.billingFrequency,
  });

  Policy copyWith({PolicyStatus? status, DateTime? endDate}) {
    return Policy(
      id: id,
      type: type,
      subtype: subtype,
      company: company,
      status: status ?? this.status,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      formData: formData,
      premium: premium,
      billingFrequency: billingFrequency,
    );
  }
}

class Quote {
  final String id;
  final String type;
  final String subtype;
  final String company;
  final double premium;
  final Map<String, String> formData;
  final DateTime generatedAt;

  Quote({
    required this.id,
    required this.type,
    required this.subtype,
    required this.company,
    required this.premium,
    required this.formData,
    required this.generatedAt,
  });
}

class InsuranceHomeScreen extends StatefulWidget {
  const InsuranceHomeScreen({super.key});

  @override
  State<InsuranceHomeScreen> createState() => _InsuranceHomeScreenState();
}

class _InsuranceHomeScreenState extends State<InsuranceHomeScreen> {
  List<Map<String, dynamic>> extractedForms = [];
  List<InsuredItem> insuredItems = [];
  List<Policy> policies = [];
  List<Quote> quotes = [];
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

  final Map<String, FieldDefinition> baseFields = {
    'name': FieldDefinition(
      expectedType: 'text',
      validator: (value) => value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value) ? null : 'Invalid name',
    ),
    'email': FieldDefinition(
      expectedType: 'email',
      validator: (value) => value.isEmpty || RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(value)
          ? null
          : 'Invalid email',
    ),
    'phone': FieldDefinition(
      expectedType: 'phone',
      validator: (value) => value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value) ? null : 'Invalid phone number',
    ),
    'regno': FieldDefinition(
      expectedType: 'text',
      validator: (value) => value.isEmpty || RegExp(r'^[A-Za-z0-9]+$').hasMatch(value) ? null : 'Invalid RegNo',
    ),
    'vehicle_value': FieldDefinition(
      expectedType: 'number',
      validator: (value) {
        if (value.isEmpty) return null;
        int? val = int.tryParse(value);
        return val != null && val >= 0 ? null : 'Invalid vehicle value';
      },
    ),
    'property_value': FieldDefinition(
      expectedType: 'number',
      validator: (value) {
        if (value.isEmpty) return null;
        int? val = int.tryParse(value);
        return val != null && val >= 0 ? null : 'Invalid property value';
      },
    ),
    'health_condition': FieldDefinition(
      expectedType: 'text',
      validator: (value) => null,
    ),
  };

  final Map<String, Map<String, Map<String, dynamic>>> policyCalculators = {
    'auto': {
      'comprehensive': {
        'companyA': {'email': 'companyA@example.com', 'basePremium': 1000, 'factor': 0.05},
        'companyB': {'email': 'companyB@example.com', 'basePremium': 900, 'factor': 0.04},
      },
      'third_party': {
        'companyA': {'email': 'companyA@example.com', 'basePremium': 600, 'factor': 0.02},
      },
    },
    'home': {
      'fire': {
        'companyA': {'email': 'companyA@example.com', 'basePremium': 800, 'factor': 0.03},
      },
      'flood': {
        'companyA': {'email': 'companyA@example.com', 'basePremium': 850, 'factor': 0.035},
      },
    },
    'health': {
      'inpatient': {
        'companyA': {'email': 'companyA@example.com', 'basePremium': 1200, 'factor': 0.06},
      },
      'outpatient': {
        'companyA': {'email': 'companyA@example.com', 'basePremium': 1000, 'factor': 0.05},
      },
    },
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
    _checkPolicyExpirations();
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
        SnackBar(content: Text(message.notification?.body ?? 'New notification')),
      );
    });
  }

  Future<void> _loadInsuredItems() async {
    String? data = await secureStorage.read(key: 'insured_items');
    if (data != null) {
      final key = encrypt.Key.fromLength(32);
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final decrypted = encrypter.decrypt64(data, iv: iv);
      setState(() {
        insuredItems = (jsonDecode(decrypted) as List)
            .map((item) => InsuredItem(
                  id: item['id'],
                  type: item['type'],
                  details: Map<String, String>.from(item['details']),
                ))
            .toList();
      });
    }
  }

  Future<void> _saveInsuredItems() async {
    final key = encrypt.Key.fromLength(32);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(jsonEncode(insuredItems.map((item) => {
          'id': item.id,
          'type': item.type,
          'details': item.details,
        }).toList()), iv: iv);
    await secureStorage.write(key: 'insured_items', value: encrypted.base64);
  }

  Future<void> _loadPolicies() async {
    String? data = await secureStorage.read(key: 'policies');
    if (data != null) {
      final key = encrypt.Key.fromLength(32);
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final decrypted = encrypter.decrypt64(data, iv: iv);
      setState(() {
        policies = (jsonDecode(decrypted) as List)
            .map((item) => Policy(
                  id: item['id'],
                  type: item['type'],
                  subtype: item['subtype'],
                  company: item['company'],
                  status: PolicyStatus.values[item['status']],
                  startDate: DateTime.parse(item['startDate']),
                  endDate: item['endDate'] != null ? DateTime.parse(item['endDate']) : null,
                  formData: Map<String, String>.from(item['formData']),
                  premium: item['premium'].toDouble(),
                  billingFrequency: item['billingFrequency'],
                ))
            .toList();
      });
    }
  }

  Future<void> _savePolicies() async {
    final key = encrypt.Key.fromLength(32);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(jsonEncode(policies.map((policy) => {
          'id': policy.id,
          'type': policy.type,
          'subtype': policy.subtype,
          'company': policy.company,
          'status': policy.status.index,
          'startDate': policy.startDate.toIso8601String(),
          'endDate': policy.endDate?.toIso8601String(),
          'formData': policy.formData,
          'premium': policy.premium,
          'billingFrequency': policy.billingFrequency,
        }).toList()), iv: iv);
    await secureStorage.write(key: 'policies', value: encrypted.base64);
  }

  Future<void> _loadQuotes() async {
    String? data = await secureStorage.read(key: 'quotes');
    if (data != null) {
      final key = encrypt.Key.fromLength(32);
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final decrypted = encrypter.decrypt64(data, iv: iv);
      setState(() {
        quotes = (jsonDecode(decrypted) as List)
            .map((item) => Quote(
                  id: item['id'],
                  type: item['type'],
                  subtype: item['subtype'],
                  company: item['company'],
                  premium: item['premium'].toDouble(),
                  formData: Map<String, String>.from(item['formData']),
                  generatedAt: DateTime.parse(item['generatedAt']),
                ))
            .toList();
      });
    }
  }

  Future<void> _saveQuotes() async {
    final key = encrypt.Key.fromLength(32);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(jsonEncode(quotes.map((quote) => {
          'id': quote.id,
          'type': quote.type,
          'subtype': quote.subtype,
          'company': quote.company,
          'premium': quote.premium,
          'formData': quote.formData,
          'generatedAt': quote.generatedAt.toIso8601String(),
        }).toList()), iv: iv);
    await secureStorage.write(key: 'quotes', value: encrypted.base64);
  }

  Future<void> _checkPolicyExpirations() async {
    final now = DateTime.now();
    for (var policy in policies) {
      if (policy.endDate != null) {
        final daysUntilExpiration = policy.endDate!.difference(now).inDays;
        if (daysUntilExpiration <= 0 && policy.status != PolicyStatus.expired) {
          setState(() {
            policies = policies.map((p) => p.id == policy.id ? p.copyWith(status: PolicyStatus.expired) : p).toList();
          });
          await FirebaseMessaging.instance.sendMessage(
            to: '/topics/policy_updates',
            data: {'policy_id': policy.id, 'message': 'Policy ${policy.id} has expired'},
          );
        } else if (daysUntilExpiration <= 30 && policy.status != PolicyStatus.nearingExpiration) {
          setState(() {
            policies = policies.map((p) => p.id == policy.id ? p.copyWith(status: PolicyStatus.nearingExpiration) : p).toList();
          });
          await FirebaseMessaging.instance.sendMessage(
            to: '/topics/policy_updates',
            data: {'policy_id': policy.id, 'message': 'Policy ${policy.id} is nearing expiration'},
          );
        }
      }
    }
    await _savePolicies();
  }

  void _loadChatbotTemplate() {
    chatbotTemplate = {
      'states': {
        'start': {
          'message': 'Hi! 😊 Let’s assist you. What would you like to do?',
          'options': [
            {'text': 'Generate a quote', 'next': 'quote_type'},
            {'text': 'Fill a form', 'next': 'select_item'},
            {'text': 'Explore insurance', 'next': 'insurance'},
            {'text': 'Add insured item', 'next': 'add_item'},
            {'text': 'View policies', 'next': 'view_policies'},
          ],
        },
        'quote_type': {
          'message': 'Choose an insurance type for your quote:\n1. Auto Insurance\n2. Home Insurance\n3. Health Insurance',
          'options': [
            {'text': 'Auto Insurance', 'next': 'quote_auto_subtype'},
            {'text': 'Home Insurance', 'next': 'quote_home_subtype'},
            {'text': 'Health Insurance', 'next': 'quote_health_subtype'},
          ],
        },
        'quote_auto_subtype': {
          'message': 'Choose a subtype:\n1. Comprehensive\n2. Third Party',
          'options': [
            {'text': 'Comprehensive', 'next': 'quote_filling'},
            {'text': 'Third Party', 'next': 'quote_filling'},
          ],
        },
        'quote_home_subtype': {
          'message': 'Choose a subtype:\n1. Fire\n2. Flood',
          'options': [
            {'text': 'Fire', 'next': 'quote_filling'},
            {'text': 'Flood', 'next': 'quote_filling'},
          ],
        },
        'quote_health_subtype': {
          'message': 'Choose a subtype:\n1. Inpatient\n2. Outpatient',
          'options': [
            {'text': 'Inpatient', 'next': 'quote_filling'},
            {'text': 'Outpatient', 'next': 'quote_filling'},
          ],
        },
        'quote_filling': {
          'fields': [],
          'next': 'quote_summary',
        },
        'quote_summary': {
          'message': 'Here’s your quote:\n{quote}\n1. Accept and pay\n2. Reject\n3. Save as PDF',
          'options': [
            {'text': 'Accept and pay', 'next': 'payment_method'},
            {'text': 'Reject', 'next': 'start'},
            {'text': 'Save as PDF', 'next': 'quote_pdf'},
          ],
        },
        'quote_pdf': {
          'message': 'Quote PDF generated and saved. Check your documents folder.',
          'next': 'start',
        },
        'payment_method': {
          'message': 'Choose a payment method:\n1. Credit Card (Stripe)\n2. MPESA',
          'options': [
            {'text': 'Credit Card', 'next': 'stripe_payment'},
            {'text': 'MPESA', 'next': 'mpesa_payment'},
          ],
        },
        'stripe_payment': {
          'message': 'Please enter your credit card details in the form.',
          'next': 'stripe_confirm',
        },
        'stripe_confirm': {
          'message': 'Payment of {amount} via credit card confirmed. Set up auto-billing? (1. Yes, 2. No)',
          'options': [
            {'text': 'Yes', 'next': 'stripe_process'},
            {'text': 'No', 'next': 'stripe_process'},
          ],
        },
        'stripe_process': {
          'message': 'Payment processed. Policy activated!{auto_billing}',
          'next': 'start',
        },
        'mpesa_payment': {
          'message': 'Enter your MPESA phone number (e.g., +2547XXXXXXXX):',
          'next': 'mpesa_confirm',
        },
        'mpesa_confirm': {
          'message': 'Payment of {amount} initiated to {phone}. Confirm payment?',
          'options': [
            {'text': 'Yes', 'next': 'mpesa_process'},
            {'text': 'No', 'next': 'start'},
          ],
        },
        'mpesa_process': {
          'message': 'Payment processed. Policy activated!',
          'next': 'start',
        },
        'select_item': {
          'message': 'Select an insured item or enter new details:\n{items}\n{new_option}',
          'next': 'pdf_filling',
        },
        'add_item': {
          'message': 'What type of item to insure? (car, home, medical)',
          'next': 'add_item_details',
        },
        'add_item_details': {
          'fields': [],
          'next': 'add_item_summary',
        },
        'add_item_summary': {
          'message': 'Here’s your item details:\n{fields}\nSave this item?',
          'options': [
            {'text': 'Yes', 'next': 'select_item'},
            {'text': 'No', 'next': 'start'},
          ],
        },
        'pdf_filling': {
          'fields': [],
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
          'message': 'Great! Your form is being processed. You’ll hear back soon.',
          'next': 'start',
        },
        'insurance': {
          'message': 'Choose an insurance type:\n1. Auto Insurance\n2. Home Insurance\n3. Health Insurance',
          'options': [
            {'text': 'Auto Insurance', 'next': 'auto_insurance'},
            {'text': 'Home Insurance', 'next': 'home_insurance'},
            {'text': 'Health Insurance', 'next': 'health_insurance'},
          ],
        },
        'auto_insurance': {
          'message': 'Auto Insurance details:\n1. Comprehensive\n2. Third Party\nChoose an option or go back (3)',
          'options': [
            {'text': 'Comprehensive', 'next': 'quote_type'},
            {'text': 'Third Party', 'next': 'quote_type'},
            {'text': 'Back', 'next': 'insurance'},
          ],
        },
        'home_insurance': {
          'message': 'Home Insurance details:\n1. Fire\n2. Flood\nChoose an option or go back (3)',
          'options': [
            {'text': 'Fire', 'next': 'quote_type'},
            {'text': 'Flood', 'next': 'quote_type'},
            {'text': 'Back', 'next': 'insurance'},
          ],
        },
        'health_insurance': {
          'message': 'Health Insurance details:\n1. Inpatient\n2. Outpatient\nChoose an option or go back (3)',
          'options': [
            {'text': 'Inpatient', 'next': 'quote_type'},
            {'text': 'Outpatient', 'next': 'quote_type'},
            {'text': 'Back', 'next': 'insurance'},
          ],
        },
        'view_policies': {
          'message': 'Your policies:\n{policies}\nSelect a policy number or go back.',
          'next': 'policy_details',
        },
        'policy_details': {
          'message': 'Policy Details:\n{details}\nExport as PDF?',
          'options': [
            {'text': 'Yes', 'next': 'export_policy'},
            {'text': 'No', 'next': 'start'},
          ],
        },
        'export_policy': {
          'message': 'Policy exported as PDF. Check your documents folder.',
          'next': 'start',
        },
      },
    };
  }

  void _startChatbot() {
    var startState = chatbotTemplate['states']['start'];
    String message = startState['message'] +
        '\n' +
        startState['options'].asMap().entries.map((e) => '${e.key + 1}. ${e.value['text']}').join('\n');
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
              'content': 'You are an expert at validating form data. Given the text of a filled PDF, check if fields like name, email, phone, etc., are correctly filled. Return a JSON object with a boolean "valid" and a "message" explaining any issues.'
            },
            {
              'role': 'user',
              'content': 'Validate this PDF text:\n\n$text'
            }
          ],
          'max_tokens': 200,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = jsonDecode(data['choices'][0]['message']['content']);
        if (!result['valid']) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ChatGPT Validation Failed: ${result['message']}')));
        }
        return result['valid'];
      }
      return false;
    } catch (e) {
      print('ChatGPT validation error: $e');
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

  Future<File?> _fillPdfTemplate(String templateKey, Map<String, String> formData) async {
    try {
      PDFTemplate? template = cachedPdfTemplates[templateKey];
      final directory = await getApplicationDocumentsDirectory();
      final templateFile = File('${directory.path}/pdf_templates/$templateKey.pdf');

      if (!await templateFile.exists()) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (result == null || result.files.single.path == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No PDF template selected')));
          return null;
        }
        String filePath = result.files.single.path!;
        await File(filePath).copy(templateFile.path);
        template = PDFTemplate(
          fields: baseFields,
          fieldMappings: {
            'name': 'ClientName',
            'email': 'ClientEmail',
            'phone': 'ClientPhone',
            'regno': 'RegistrationNumber',
            'vehicle_value': 'VehicleValue',
            'property_value': 'PropertyValue',
            'health_condition': 'HealthCondition',
          },
          coordinates: {
            'name': {'page': 1, 'x': 100, 'y': 700},
            'email': {'page': 1, 'x': 100, 'y': 670},
            'phone': {'page': 1, 'x': 100, 'y': 640},
            'regno': {'page': 1, 'x': 100, 'y': 610},
            'vehicle_value': {'page': 2, 'x': 100, 'y': 580},
            'property_value': {'page': 2, 'x': 100, 'y': 580},
            'health_condition': {'page': 2, 'x': 100, 'y': 550},
          },
        );
        cachedPdfTemplates[templateKey] = template;
        await _savePdfTemplates();
      }

      final pdfBytes = await templateFile.readAsBytes();
      final pdfDoc = await PdfDocument.openData(pdfBytes);
      final form = pdfDoc.form;

      bool isFillable = form != null && form.fields.isNotEmpty;

      if (isFillable) {
        for (var entry in formData.entries) {
          String pdfFieldName = template!.fieldMappings[entry.key] ?? entry.key;
          final field = form!.findField(pdfFieldName);
          if (field != null) {
            field.setValue(entry.value);
          }
        }
      } else {
        final pdf = pw.Document();
        for (int i = 1; i <= pdfDoc.pageCount; i++) {
          final page = pdfDoc.getPage(i);
          final pageContent = await page.render();
          pdf.addPage(
            pw.Page(
              build: (pw.Context context) {
                return pw.Stack(
                  children: [
                    pw.Image(pw.RawImage(
                      bytes: pageContent.bytes,
                      width: pageContent.width,
                      height: pageContent.height,
                    )),
                    ...formData.entries.map((entry) {
                      final coord = template!.coordinates[entry.key];
                      if (coord != null && coord['page'] == i) {
                        return pw.Positioned(
                          left: coord['x']!,
                          top: coord['y']!,
                          child: pw.Text(
                            entry.value,
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        );
                      }
                      return pw.SizedBox();
                    }).toList(),
                  ],
                );
              },
            ),
          );
        }
        pdfDoc = pdf.document;
      }

      final filledFile = File('${directory.path}/filled_$templateKey.pdf');
      final filledBytes = await pdfDoc.save();
      await filledFile.writeAsBytes(filledBytes);

      return filledFile;
    } catch (e) {
      print('Error filling PDF template: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fill PDF: $e')));
      return null;
    }
  }

  Future<File?> _generateQuotePdf(Quote quote) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Insurance Quote', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('Quote ID: ${quote.id}'),
            pw.Text('Type: ${quote.type}'),
            pw.Text('Subtype: ${quote.subtype}'),
            pw.Text('Company: ${quote.company}'),
            pw.Text('Premium: KES ${quote.premium.toStringAsFixed(2)}'),
            pw.Text('Generated: ${quote.generatedAt}'),
            pw.SizedBox(height: 20),
            pw.Text('Details:', style: pw.TextStyle(fontSize: 16)),
            ...quote.formData.entries.map((e) => pw.Text('${e.key}: ${e.value}')),
          ],
        ),
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/quote_${quote.id}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<double> _calculatePremium(String type, String subtype, Map<String, String> formData) async {
    final calculator = policyCalculators[type]?[subtype]?['companyA'];
    if (calculator == null) return 0.0;
    double basePremium = calculator['basePremium'].toDouble();
    double factor = calculator['factor'].toDouble();
    double value = double.tryParse(formData['vehicle_value'] ?? formData['property_value'] ?? '0') ?? 0;
    return basePremium + (value * factor);
  }

  Future<bool> _initiateMpesaPayment(String phoneNumber, double amount) async {
    try {
      final response = await http.post(
        Uri.parse('https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest'),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('MPESA Payment Failed: ${response.body}')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stripe Payment Failed: ${response.body}')));
        return false;
      }
    } catch (e) {
      print('Stripe payment error: $e');
      return false;
    }
  }

  Future<void> _scheduleStripeAutoBilling(Policy policy) async {
    try {
      final customerResponse = await http.post(
        Uri.parse('https://api.stripe.com/v1/customers'),
        headers: {
          'Authorization': 'Bearer $stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'email': policy.formData['email'],
          'name': policy.formData['name'],
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
            'billing_cycle_anchor': policy.billingFrequency == 'monthly' ? 'month' : 'year',
          },
        );

        if (subscriptionResponse.statusCode == 200) {
          final subscription = jsonDecode(subscriptionResponse.body);
          final key = encrypt.Key.fromLength(32);
          final iv = encrypt.IV.fromLength(16);
          final encrypter = encrypt.Encrypter(encrypt.AES(key));
          final encrypted = encrypter.encrypt(
            jsonEncode({
              'policyId': policy.id,
              'customerId': customerId,
              'subscriptionId': subscription['id'],
              'amount': policy.premium,
              'frequency': policy.billingFrequency,
            }),
            iv: iv,
          );
          await secureStorage.write(key: 'billing_${policy.id}', value: encrypted.base64);
        }
      }
    } catch (e) {
      print('Stripe auto-billing error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to set up auto-billing: $e')));
    }
  }

  Future<void> _sendEmail(String company, String insuranceType, String insuranceSubtype, Map<String, String> formData, File filledPdf) async {
    final smtpServer = gmail('your-email@gmail.com', 'your-app-specific-password');

    final message = Message()
      ..from = const Address('your-email@gmail.com', 'Insurance App')
      ..recipients.add(policyCalculators[insuranceType]![insuranceSubtype]!['companyA']!['email'])
      ..subject = 'Insurance Form Submission: $insuranceSubtype ($insuranceType)'
      ..html = '<h3>Form Submission Details</h3><ul>' +
          formData.entries.map((e) => '<li>${e.key}: ${e.value}</li>').join('') +
          '</ul>'
      ..attachments.add(FileAttachment(filledPdf, fileName: 'filled_form.pdf'));

    try {
      final sendReport = await send(message, smtpServer);
      print('Email sent: ${sendReport.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form details and PDF sent to company email')));
      _logAction('Email sent to $company for $insuranceSubtype ($insuranceType)');
    } catch (e) {
      print('Error sending email: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send email')));
      _logAction('Email failed: $e');
    }
  }

  void _logAction(String action) async {
    final directory = await getApplicationDocumentsDirectory();
    final logFile = File('${directory.path}/app.log');
    await logFile.writeAsString('${DateTime.now()}: $action\n', mode: FileMode.append);
  }

  Future<void> _handleChatInput(String input) async {
    setState(() {
      chatMessages.add({'sender': 'user', 'text': input});
    });

    var currentStateData = chatbotTemplate['states'][currentState];

    if (currentState == 'quote_type') {
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= currentStateData['options'].length) {
        setState(() {
          currentState = currentStateData['options'][choice - 1]['next'];
          formResponses['type'] = currentStateData['options'][choice - 1]['text'].toLowerCase().replaceAll(' insurance', '');
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                chatbotTemplate['states'][currentState]['options'].asMap().entries.map((e) => '${e.key + 1}. ${e.value['text']}').join('\n'),
          });
        });
      } else {
        _showError();
      }
    } else if (currentState.contains('quote_') && currentState.endsWith('_subtype')) {
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= currentStateData['options'].length) {
        setState(() {
          currentState = 'quote_filling';
          formResponses['subtype'] = currentStateData['options'][choice - 1]['text'].toLowerCase();
          currentStateData = chatbotTemplate['states']['quote_filling'];
          currentStateData['fields'] = baseFields.keys
              .map((key) => {'name': key, 'prompt': 'Please enter your $key for ${formResponses['type']} quote:'})
              .toList();
          currentFieldIndex = 0;
          chatMessages.add({'sender': 'bot', 'text': currentStateData['fields'][0]['prompt']});
        });
      } else {
        _showError();
      }
    } else if (currentState == 'quote_filling') {
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
              chatMessages.add({'sender': 'bot', 'text': fields[currentFieldIndex]['prompt']});
            });
          } else {
            double premium = await _calculatePremium(formResponses['type']!, formResponses['subtype']!, formResponses);
            Quote quote = Quote(
              id: Uuid().v4(),
              type: formResponses['type']!,
              subtype: formResponses['subtype']!,
              company: 'companyA',
              premium: premium,
              formData: Map<String, String>.from(formResponses),
              generatedAt: DateTime.now(),
            );
            quotes.add(quote);
            await _saveQuotes();
            selectedQuoteId = quote.id;
            String quoteSummary =
                'Type: ${quote.type}\nSubtype: ${quote.subtype}\nPremium: KES ${quote.premium.toStringAsFixed(2)}\nDetails:\n' +
                    quote.formData.entries.map((e) => '${e.key}: ${e.value}').join('\n');
            String nextMessage = currentStateData['next']['message'].replaceAll('{quote}', quoteSummary) +
                '\n' +
                currentStateData['next']['options'].asMap().entries.map((e) => '${e.key + 1}. ${e.value['text']}').join('\n');
            setState(() {
              currentState = 'quote_summary';
              chatMessages.add({'sender': 'bot', 'text': nextMessage});
            });
          }
        } else {
          setState(() {
            chatMessages.add({'sender': 'bot', 'text': 'Error: $error. Please try again.'});
            chatMessages.add({'sender': 'bot', 'text': field['prompt']});
          });
        }
      }
    } else if (currentState == 'quote_summary') {
      int? choice = int.tryParse(input);
      if (choice == 1) {
        setState(() {
          currentState = 'payment_method';
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['next']['message'] +
                '\n' +
                currentStateData['next']['options'].asMap().entries.map((e) => '${e.key + 1}. ${e.value['text']}').join('\n'),
          });
        });
      } else if (choice == 2) {
        setState(() {
          currentState = 'start';
          formResponses.clear();
          selectedQuoteId = null;
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states']['start']['message'] +
                '\n' +
                chatbotTemplate['states']['start']['options'].asMap().entries.map((e) => '${e.key + 1}. ${e.value['text']}').join('\n'),
          });
        });
      } else if (choice == 3) {
        Quote? quote = quotes.firstWhereOrNull((q) => q.id == selectedQuoteId);
        if (quote != null) {
          await _generateQuotePdf(quote);
          setState(() {
            currentState = 'quote_pdf';
            chatMessages.add({'sender': 'bot', 'text': currentStateData['next']['message']});
          });
        } else {
          _showError();
        }
      } else {
        _showError();
      }
    } else if (currentState == 'payment_method') {
      int? choice = int.tryParse(input);
      if (choice == 1) {
        setState(() {
          currentState = 'stripe_payment';
          chatMessages.add({'sender': 'bot', 'text': currentStateData['next']['message']});
        });
        Quote? quote = quotes.firstWhereOrNull((q) => q.id == selectedQuoteId);
        if (quote != null) {
          await _initiateStripePayment(quote.premium, false);
        }
      } else if (choice == 2) {
        setState(() {
          currentState = 'mpesa_payment';
          chatMessages.add({'sender': 'bot', 'text': currentStateData['next']['message']});
        });
      } else {
        _showError();
      }
    } else if (currentState == 'stripe_payment') {
      setState(() {
        currentState = 'stripe_confirm';
        Quote? quote = quotes.firstWhereOrNull((q) => q.id == selectedQuoteId);
        if (quote != null) {
          String message = currentStateData['next']['message'].replaceAll('{amount}', 'KES ${quote.premium.toStringAsFixed(2)}');
          message += '\n' +
              currentStateData['next']['options'].asMap().entries.map((e) => '${e.key + 1}. ${e.value['text']}').join('\n');
          chatMessages.add({'sender': 'bot', 'text': message});
        } else {
          _showError();
        }
      });
    } else if (currentState == 'stripe_confirm') {
      int? choice = int.tryParse(input);
      Quote? quote = quotes.firstWhereOrNull((q) => q.id == selectedQuoteId);
      if (quote != null && (choice == 1 || choice == 2)) {
        bool autoBilling = choice == 1;
        Policy policy = Policy(
          id: Uuid().v4(),
          type: quote.type,
          subtype: quote.subtype,
          company: quote.company,
          status: PolicyStatus.active,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(Duration(days: 365)),
          formData: Map<String, String>.from(quote.formData),
          premium: quote.premium,
          billingFrequency: 'annually',
        );
        policies.add(policy);
        await _savePolicies();
        if (autoBilling) {
          await _scheduleStripeAutoBilling(policy);
        }
        await FirebaseMessaging.instance.subscribeToTopic('policy_updates');
        setState(() {
          currentState = 'stripe_process';
          String message = currentStateData['next']['message'].replaceAll(
              '{auto_billing}', autoBilling ? '\nAuto-billing enabled.' : '');
          chatMessages.add({'sender': 'bot', 'text': message});
        });
      } else {
        _showError();
      }
    } else if (currentState == 'mpesa_payment') {
      if (RegExp(r'^\+2547\d{8}$').hasMatch(input)) {
        Quote? quote = quotes.firstWhereOrNull((q) => q.id == selectedQuoteId);
        if (quote != null) {
          setState(() {
            currentState = 'mpesa_confirm';
            formResponses['phone'] = input;
            String message = currentStateData['next']['message']
                .replaceAll('{amount}', 'KES ${quote.premium.toStringAsFixed(2)}')
                .replaceAll('{phone}', input);
            message += '\n' +
                currentStateData['next']['options'].asMap().entries.map((e) => '${e.key + 1}. ${e.value['text']}').join('\n');
            chatMessages.add({'sender': 'bot', 'text': message});
          });
        } else {
          _showError();
        }
      } else {
        setState(() {
          chatMessages.add({'sender': 'bot', 'text': 'Invalid phone number. Please enter a valid MPESA number (e.g., +2547XXXXXXXX).'});
        });
      }
    } else if (currentState == 'mpesa_confirm') {
      int? choice = int.tryParse(input);
      if (choice == 1) {
        Quote? quote = quotes.firstWhereOrNull((q) => q.id == selectedQuoteId);
        if (quote != null && await _initiateMpesaPayment(formResponses['phone']!, quote.premium)) {
          Policy policy = Policy(
            id: Uuid().v4(),
            type: quote.type,
            subtype: quote.subtype,
            company: quote.company,
            status: PolicyStatus.active,
            startDate: DateTime.now(),
            endDate: DateTime.now().add(Duration(days: 365)),
            formData: Map<String, String>.from(quote.formData),
            premium: quote.premium,
            billingFrequency: 'annually',
          );
          policies.add(policy);
          await _savePolicies();
          await FirebaseMessaging.instance.subscribeToTopic('policy_updates');
          setState(() {
            currentState = 'mpesa_process';
            chatMessages.add({'sender': 'bot', 'text': currentStateData['next']['message']});
          });
        } else {
          _showError();
        }
      } else if (choice == 2) {
        setState(() {
          currentState = 'start';
          formResponses.clear();
          selectedQuoteId = null;
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states']['start']['message'] +
                '\n' +
                chatbotTemplate['states']['start']['options'].asMap().entries.map((e) => '${e.key + 1}. ${e.value['text']}').join('\n'),
          });
        });
      } else {
        _showError();
      }
    } else if (currentState == 'select_item') {
      int? choice = int.tryParse(input);
      if (choice != null && choice <= insuredItems.length) {
        selectedInsuredItemId = insuredItems[choice - 1].id;
        formResponses = Map<String, String>.from(insuredItems[choice - 1].details);
        setState(() {
          currentState = 'pdf_filling';
          currentFieldIndex = 0;
          currentStateData['fields'] = baseFields.keys
              .map((key) => {'name': key, 'prompt': 'Please enter your $key:'})
              .toList();
          chatMessages.add({'sender': 'bot', 'text': currentStateData['fields'][0]['prompt']});
        });
      } else if (choice == insuredItems.length + 1) {
        setState(() {
          currentState = 'add_item';
          chatMessages.add({'sender': 'bot', 'text': currentStateData['message']});
        });
      } else {
        _showError();
      }
    } else if (currentState == 'add_item') {
      if (['car', 'home', 'medical'].contains(input.toLowerCase())) {
        setState(() {
          currentState = 'add_item_details';
          currentStateData['fields'] = baseFields.keys
              .map((key) => {'name': key, 'prompt': 'Please enter $key for ${input.toLowerCase()}:'})
              .toList();
          currentFieldIndex = 0;
          chatMessages.add({'sender': 'bot', 'text': currentStateData['fields'][0]['prompt']});
          formResponses['type'] = input.toLowerCase();
        });
      } else {
        _showError();
      }
    } else if (currentState == 'add_item_details') {
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
              chatMessages.add({'sender': 'bot', 'text': fields[currentFieldIndex]['prompt']});
            });
          } else {
            String summary = formResponses.entries.map((e) => '${e.key}: ${e.value}').join('\n');
            String nextMessage = currentStateData['next']['message'].replaceAll('{fields}', summary) +
                '\n' +
                currentStateData['next']['options'].asMap().entries.map((e) => '${e.key + 1}. ${e.value['text']}').join('\n');
            setState(() {
              currentState = 'add_item_summary';
              chatMessages.add({'sender': 'bot', 'text': nextMessage});
            });
          }
        } else {
          setState(() {
            chatMessages.add({'sender': 'bot', 'text': 'Error: $error. Please try again.'});
            chatMessages.add({'sender': 'bot', 'text': field['prompt']});
          });
        }
      }
    } else if (currentState == 'add_item_summary') {
      int? choice = int.tryParse(input);
      if (choice == 1) {
        insuredItems.add(InsuredItem(
          id: Uuid().v4(),
          type: formResponses['type'] ?? 'unknown',
          details: Map<String, String>.from(formResponses),
        ));
        await _saveInsuredItems();
        setState(() {
          currentState = 'select_item';
          formResponses.clear();
          chatMessages.add({'sender': 'bot', 'text': _buildSelectItemMessage()});
        });
      } else if (choice == 2) {
        setState(() {
          currentState = 'start';
          formResponses.clear();
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states']['start']['message'] +
                '\n' +
                chatbotTemplate['states']['start']['options'].asMap().entries.map((e) => '${e.key + 1}. ${e.value['text']}').join('\n'),
          });
        });
      } else {
        _showError();
      }
    } else if (currentState == 'pdf_filling') {
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
              chatMessages.add({'sender': 'bot', 'text': fields[currentFieldIndex]['prompt']});
            });
          } else {
            String summary = formResponses.entries.map((e) => '${e.key}: ${e.value}').join('\n');
            String nextMessage = currentStateData['next']['message'].replaceAll('{fields}', summary) +
                '\n' +
                currentStateData['next']['options'].asMap().entries.map((e) => '${e.key + 1}. ${e.value['text']}').join('\n');
            setState(() {
              currentState = 'pdf_summary';
              chatMessages.add({'sender': 'bot', 'text': nextMessage});
            });
          }
        } else {
          setState(() {
            chatMessages.add({'sender': 'bot', 'text': 'Error: $error. Please try again.'});
            chatMessages.add({'sender': 'bot', 'text': field['prompt']});
          });
        }
      }
    } else if (currentState == 'pdf_summary') {
      int? choice = int.tryParse(input);
      if (choice == 1) {
        File? filledPdf = await _fillPdfTemplate('default', formResponses);
        if (filledPdf != null && await _previewPdf(filledPdf)) {
          await _sendEmail('companyA', formResponses['type'] ?? 'auto', formResponses['subtype'] ?? 'comprehensive', formResponses, filledPdf);
        }
        setState(() {
          currentState = 'pdf_process';
          chatMessages.add({'sender': 'bot', 'text': currentStateData['next']['message']});
        });
      } else if (choice == 2) {
        currentFieldIndex = 0;
        setState(() {
          currentState = 'pdf_filling';
          chatMessages.add({'sender': 'bot', 'text': currentStateData['fields'][0]['prompt']});
        });
      } else {
        _showError();
      }
    } else if (currentState == 'view_policies') {
      int? choice = int.tryParse(input);
      if (choice != null && choice <= policies.length) {
        Policy policy = policies[choice - 1];
        String statusColor = policy.status == PolicyStatus.nearingExpiration
            ? ' (Nearing Expiration - Yellow)'
            : policy.status == PolicyStatus.expired
                ? ' (Expired - Red)'
                : '';
        String details =
            'Type: ${policy.type}\nSubtype: ${policy.subtype}\nCompany: ${policy.company}\nStatus: ${policy.status}$statusColor\nStart: ${policy.startDate}\nEnd: ${policy.endDate ?? 'N/A'}\nPremium: KES ${policy.premium.toStringAsFixed(2)}';
        String nextMessage = currentStateData['message'].replaceAll('{details}', details) +
            '\n' +
            currentStateData['next']['options'].asMap().entries.map((e) => '${e.key + 1}. ${e.value['text']}').join('\n');
        setState(() {
          currentState = 'policy_details';
          currentFieldIndex = choice;
          chatMessages.add({'sender': 'bot', 'text': nextMessage});
        });
      } else {
        setState(() {
          currentState = 'start';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states']['start']['message'] +
                '\n' +
                chatbotTemplate['states']['start']['options'].asMap().entries.map((e) => '${e.key + 1}. ${e.value['text']}').join('\n'),
          });
        });
      }
    } else if (currentState == 'policy_details') {
      int? choice = int.tryParse(input);
      if (choice == 1) {
        await _exportPolicy(policies[currentFieldIndex - 1]);
        setState(() {
          currentState = 'export_policy';
          chatMessages.add({'sender': 'bot', 'text': currentStateData['next']['message']});
        });
      } else {
        setState(() {
          currentState = 'start';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states']['start']['message'] +
                '\n' +
                chatbotTemplate['states']['start']['options'].asMap().entries.map((e) => '${e.key + 1}. ${e.value['text']}').join('\n'),
          });
        });
      }
    } else if (currentStateData['options'] != null) {
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= currentStateData['options'].length) {
        var selectedOption = currentStateData['options'][choice - 1];
        setState(() {
          currentState = selectedOption['next'];
          if (currentState == 'select_item') {
            chatMessages.add({'sender': 'bot', 'text': _buildSelectItemMessage()});
          } else if (currentState == 'view_policies') {
            String policyList = policies.asMap().entries.map((e) {
              Policy p = e.value;
              String statusColor = p.status == PolicyStatus.nearingExpiration
                  ? ' (Nearing Expiration - Yellow)'
                  : p.status == PolicyStatus.expired
                      ? ' (Expired - Red)'
                      : '';
              return '${e.key + 1}. ${p.type} - ${p.subtype}$statusColor';
            }).join('\n');
            chatMessages.add({
              'sender': 'bot',
              'text': currentStateData['message'].replaceAll('{policies}', policyList.isEmpty ? 'No policies' : policyList),
            });
          } else {
            chatMessages.add({
              'sender': 'bot',
              'text': currentStateData['message'] +
                  '\n' +
                  currentStateData['options'].asMap().entries.map((e) => '${e.key + 1}. ${e.value['text']}').join('\n'),
            });
          }
        });
      } else {
        _showError();
      }
    } else {
      _showError();
    }

    chatController.clear();
  }

  String _buildSelectItemMessage() {
    String items = insuredItems.asMap().entries.map((e) => '${e.key +1}. ${e.value.type}').join('\n');
    String newOption = '${insuredItems.length + 1}. Enter new details';
    return chatbotTemplate['states']['select_item']['message']
        .replaceAll('{items}', items.isEmpty ? 'No items' : items)
        .replaceAll('{new_option}', newOption);
  }

  void _showError() {
    setState(() {
      chatMessages.add({'sender': 'bot', 'text': 'Invalid input. Please try again.'});
    });
  }

  Future<void> _exportPolicy(Policy policy) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          children: [
            pw.Text('Policy Report', style: pw.TextStyle(fontSize: 24)),
            pw.SizedBox(height: 20),
            pw.Text('Type: ${policy.type}'),
            pw.Text('Subtype: ${policy.subtype}'),
            pw.Text('Company: ${policy.company}'),
            pw.Text('Status: ${policy.status}'),
            pw.Text('Start Date: ${policy.startDate}'),
            if (policy.endDate != null) pw.Text('End Date: ${policy.endDate}'),
            pw.Text('Premium: KES ${policy.premium.toStringAsFixed(2)}'),
            pw.Text('Billing Frequency: ${policy.billingFrequency}'),
            pw.SizedBox(height: 20),
            pw.Text('Form Data:', style: pw.TextStyle(fontSize: 16)),
            ...policy.formData.entries.map((e) => pw.Text('${e.key}: ${e.value}')),
          ],
        ),
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/policy_${policy.id}.pdf');
    await file.writeAsBytes(await pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insurance Form Extractor'),
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
          Expanded(
            child: ListView.builder(
              itemCount: chatMessages.length,
              itemBuilder: (context, index) {
                final message = chatMessages[index];
                return ListTile(
                  title: Text(
                    message['text']!,
                    style: TextStyle(
                      color: message['text']!.contains('Nearing Expiration')
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
                    decoration: const InputDecoration(hintText: 'Type your response...'),
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

  Future<void> _savePdfTemplates() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/pdf_templates.json');
    await file.writeAsString(jsonEncode(cachedPdfTemplates.map((key, value) => MapEntry(key, value.toJson()))));
  }

  Future<void> _loadCachedPdfTemplates() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/pdf_templates.json');
    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString());
      cachedPdfTemplates = data.map((key, value) => MapEntry(key, PDFTemplate.fromJson(value)));
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
    } catch (e) {
      print('Error saving user details: $e');
    }
  }

  Future<void> _loadUserDetails() async {
    try {
      String? encrypted = await secureStorage.read(key: 'user_details');
      if (encrypted != null) {
        final key = encrypt.Key.fromLength(32);
        final iv = encrypt.IV.fromLength(16);
        final encrypter = encrypt.Encrypter(encrypt.AES(key));
        final decrypted = encrypter.decrypt64(encrypted, iv: iv);
        setState(() {
          userDetails = Map<String, String>.from(jsonDecode(decrypted));
        });
      }
    } catch (e) {
      print('Error loading user details: $e');
    }
  }
}

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  List<Policy> policies = [];
  Map<String, PDFTemplate> cachedPdfTemplates = {};
  final secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadPolicies();
    _loadCachedPdfTemplates();
  }

  Future<void> _loadPolicies() async {
    String? data = await secureStorage.read(key: 'policies');
    if (data != null) {
      final key = encrypt.Key.fromLength(32);
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final decrypted = encrypter.decrypt64(data, iv: iv);
      setState(() {
        policies = (jsonDecode(decrypted) as List)
            .map((item) => Policy(
                  id: item['id'],
                  type: item['type'],
                  subtype: item['subtype'],
                  company: item['company'],
                  status: PolicyStatus.values[item['status']],
                  startDate: DateTime.parse(item['startDate']),
                  endDate: item['endDate'] != null ? DateTime.parse(item['endDate']) : null,
                  formData: Map<String, String>.from(item['formData']),
                  premium: item['premium'].toDouble(),
                  billingFrequency: item['billingFrequency'],
                ))
            .toList();
      });
    }
  }

  Future<void> _savePolicies() async {
    final key = encrypt.Key.fromLength(32);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(jsonEncode(policies.map((policy) => {
          'id': policy.id,
          'type': policy.type,
          'subtype': policy.subtype,
          'company': policy.company,
          'status': policy.status.index,
          'startDate': policy.startDate.toIso8601String(),
          'endDate': policy.endDate?.toIso8601String(),
          'formData': policy.formData,
          'premium': policy.premium,
          'billingFrequency': policy.billingFrequency,
        }).toList()), iv: iv);
    await secureStorage.write(key: 'policies', value: encrypted.base64);
  }

  Future<void> _loadCachedPdfTemplates() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/pdf_templates.json');
    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString());
      cachedPdfTemplates = data.map((key, value) => MapEntry(key, PDFTemplate.fromJson(value)));
    }
  }

  Future<void> _savePdfTemplates() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/pdf_templates.json');
    await file.writeAsString(jsonEncode(cachedPdfTemplates.map((key, value) => MapEntry(key, value.toJson()))));
  }

  Future<void> _uploadPdfTemplate() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      String templateKey = result.files.single.name.split('.').first;
      final directory = await getApplicationDocumentsDirectory();
      final templateFile = File('${directory.path}/pdf_templates/$templateKey.pdf');
      await File(filePath).copy(templateFile.path);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfCoordinateEditor(
            pdfPath: templateFile.path,
            onSave: (coordinates) {
              cachedPdfTemplates[templateKey] = PDFTemplate(
                fields: {
                  'name': FieldDefinition(
                    expectedType: 'text',
                    validator: (value) => value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value) ? null : 'Invalid name',
                  ),
                  'email': FieldDefinition(
                    expectedType: 'email',
                    validator: (value) => value.isEmpty || RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(value)
                        ? null
                        : 'Invalid email',
                  ),
                  'phone': FieldDefinition(
                    expectedType: 'phone',
                    validator: (value) => value.isEmpty || RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value) ? null : 'Invalid phone number',
                  ),
                  'regno': FieldDefinition(
                    expectedType: 'text',
                    validator: (value) => value.isEmpty || RegExp(r'^[A-Za-z0-9]+$').hasMatch(value) ? null : 'Invalid RegNo',
                  ),
                  'vehicle_value': FieldDefinition(
                    expectedType: 'number',
                    validator: (value) {
                      if (value.isEmpty) return null;
                      int? val = int.tryParse(value);
                      return val != null && val >= 0 ? null : 'Invalid vehicle value';
                    },
                  ),
                  'property_value': FieldDefinition(
                    expectedType: 'number',
                    validator: (value) {
                      if (value.isEmpty) return null;
                      int? val = int.tryParse(value);
                      return val != null && val >= 0 ? null : 'Invalid property value';
                    },
                  ),
                  'health_condition': FieldDefinition(
                    expectedType: 'text',
                    validator: (value) => null,
                  ),
                },
                fieldMappings: {
                  'name': 'ClientName',
                  'email': 'ClientEmail',
                  'phone': 'ClientPhone',
                  'regno': 'RegistrationNumber',
                  'vehicle_value': 'VehicleValue',
                  'property_value': 'PropertyValue',
                  'health_condition': 'HealthCondition',
                },
                coordinates: coordinates,
              );
              _savePdfTemplates();
              setState(() {});
            },
          ),
        ),
      );
    }
  }

  Future<void> _updatePolicyStatus(Policy policy, PolicyStatus newStatus) async {
    setState(() {
      policies = policies.map((p) {
        if (p.id == policy.id) {
          return Policy(
            id: p.id,
            type: p.type,
            subtype: p.subtype,
            company: p.company,
            status: newStatus,
            startDate: p.startDate,
            endDate: newStatus == PolicyStatus.extended ? p.endDate?.add(Duration(days: 365)) : p.endDate,
            formData: p.formData,
            premium: p.premium,
            billingFrequency: p.billingFrequency,
          );
        }
        return p;
      }).toList();
    });
    await _savePolicies();
    await FirebaseMessaging.instance.sendMessage(
      to: '/topics/policy_updates',
      data: {'policy_id': policy.id, 'new_status': newStatus.toString()},
    );
  }

  Future<void> _notifyPolicyExpiration(Policy policy) async {
    await FirebaseMessaging.instance.sendMessage(
      to: '/topics/policy_updates',
      data: {
        'policy_id': policy.id,
        'message': 'Reminder: Policy ${policy.id} (${policy.type} - ${policy.subtype}) is ${policy.status == PolicyStatus.expired ? 'expired' : 'nearing expiration'}'
      },
    );
  }

  List<charts.Series<MapEntry<DateTime, int>, DateTime>> _createPolicyTrendData() {
    final data = groupBy(policies, (Policy p) => DateTime(p.startDate.year, p.startDate.month))
        .entries
        .map((e) => MapEntry(e.key, e.value.length));
    return [
      charts.Series<MapEntry<DateTime, int>, DateTime>(
        id: 'Policies',
        data: data.toList(),
        domainFn: (datum, _) => datum.key,
        measureFn: (datum, _) => datum.value,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _uploadPdfTemplate,
              child: const Text('Upload PDF Template'),
            ),
            const SizedBox(height: 20),
            const Text('PDF Templates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cachedPdfTemplates.length,
              itemBuilder: (context, index) {
                final templateKey = cachedPdfTemplates.keys.elementAt(index);
                return ListTile(
                  title: Text(templateKey),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      final directory = await getApplicationDocumentsDirectory();
                      final file = File('${directory.path}/pdf_templates/$templateKey.pdf');
                      if (await file.exists()) {
                        await file.delete();
                        setState(() {
                          cachedPdfTemplates.remove(templateKey);
                        });
                        await _savePdfTemplates();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Template $templateKey deleted')),
                        );
                      }
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text('Policies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: policies.length,
              itemBuilder: (context, index) {
                final policy = policies[index];
                return ListTile(
                  title: Text('${policy.type} - ${policy.subtype}'),
                  subtitle: Text(
                    'Status: ${policy.status} | End: ${policy.endDate ?? 'N/A'}',
                    style: TextStyle(
                      color: policy.status == PolicyStatus.nearingExpiration
                          ? Colors.yellow[800]
                          : policy.status == PolicyStatus.expired
                              ? Colors.red
                              : null,
                    ),
                  ),
                  trailing: DropdownButton<PolicyStatus>(
                    value: policy.status,
                    items: PolicyStatus.values
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status.toString().split('.').last),
                            ))
                        .toList(),
                    onChanged: (newStatus) async {
                      if (newStatus != null) {
                        await _updatePolicyStatus(policy, newStatus);
                        if (newStatus == PolicyStatus.nearingExpiration || newStatus == PolicyStatus.expired) {
                          await _notifyPolicyExpiration(policy);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Policy status updated to $newStatus')),
                        );
                      }
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text('Policy Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(
              height: 200,
              child: charts.TimeSeriesChart(
                _createPolicyTrendData(),
                animate: true,
                dateTimeFactory: const charts.LocalDateTimeFactory(),
                behaviors: [charts.SeriesLegend()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PdfCoordinateEditor extends StatefulWidget {
  final String pdfPath;
  final Function(Map<String, Map<String, double>>) onSave;

  const PdfCoordinateEditor({super.key, required this.pdfPath, required this.onSave});

  @override
  State<PdfCoordinateEditor> createState() => _PdfCoordinateEditorState();
}

class _PdfCoordinateEditorState extends State<PdfCoordinateEditor> {
  PdfDocument? _pdfDocument;
  int _currentPage = 1;
  String? _selectedField;
  Map<String, Map<String, double>> _coordinates = {};
  final List<String> _fields = [
    'name',
    'email',
    'phone',
    'regno',
    'vehicle_value',
    'property_value',
    'health_condition'
  ];

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final file = File(widget.pdfPath);
      final bytes = await file.readAsBytes();
      _pdfDocument = await PdfDocument.openData(bytes);
      setState(() {});
    } catch (e) {
      print('Error loading PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load PDF: $e')));
    }
  }

  void _onTap(Offset position) {
    if (_selectedField != null) {
      setState(() {
        _coordinates[_selectedField!] = {
          'page': _currentPage.toDouble(),
          'x': position.dx,
          'y': position.dy,
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Coordinates set for $_selectedField on page $_currentPage')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit PDF Coordinates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              widget.onSave(_coordinates);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          DropdownButton<String>(
            hint: const Text('Select Field'),
            value: _selectedField,
            items: _fields
                .map((field) => DropdownMenuItem(
                      value: field,
                      child: Text(field),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedField = value;
              });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_left),
                onPressed: _currentPage > 1
                    ? () {
                        setState(() {
                          _currentPage--;
                        });
                      }
                    : null,
              ),
              Text('Page $_currentPage'),
              IconButton(
                icon: const Icon(Icons.arrow_right),
                onPressed: _pdfDocument != null && _currentPage < _pdfDocument!.pageCount
                    ? () {
                        setState(() {
                          _currentPage++;
                        });
                      }
                    : null,
              ),
            ],
          ),
          Expanded(
            child: _pdfDocument == null
                ? const Center(child: CircularProgressIndicator())
                : GestureDetector(
                    onTapUp: (details) => _onTap(details.localPosition),
                    child: PdfPreview(
                      file: File(widget.pdfPath),
                      initialPage: _currentPage,
                      allowPinchZoom: true,
                      allowSwipeNavigation: false,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class PolicyReportScreen extends StatefulWidget {
  const PolicyReportScreen({super.key});

  @override
  State<PolicyReportScreen> createState() => _PolicyReportScreenState();
}

class _PolicyReportScreenState extends State<PolicyReportScreen> {
  List<Policy> policies = [];
  final secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadPolicies();
  }

  Future<void> _loadPolicies() async {
    String? data = await secureStorage.read(key: 'policies');
    if (data != null) {
      final key = encrypt.Key.fromLength(32);
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final decrypted = encrypter.decrypt64(data, iv: iv);
      setState(() {
        policies = (jsonDecode(decrypted) as List)
            .map((item) => Policy(
                  id: item['id'],
                  type: item['type'],
                  subtype: item['subtype'],
                  company: item['company'],
                  status: PolicyStatus.values[item['status']],
                  startDate: DateTime.parse(item['startDate']),
                  endDate: item['endDate'] != null ? DateTime.parse(item['endDate']) : null,
                  formData: Map<String, String>.from(item['formData']),
                  premium: item['premium'].toDouble(),
                  billingFrequency: item['billingFrequency'],
                ))
            .toList();
      });
    }
  }

  Future<void> _exportAllPolicies() async {
    final pdf = pw.Document();
    for (var policy in policies) {
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Policy Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Policy ID: ${policy.id}'),
              pw.Text('Type: ${policy.type}'),
              pw.Text('Subtype: ${policy.subtype}'),
              pw.Text('Company: ${policy.company}'),
              pw.Text('Status: ${policy.status}'),
              pw.Text('Start Date: ${policy.startDate}'),
              if (policy.endDate != null) pw.Text('End Date: ${policy.endDate}'),
              pw.Text('Premium: KES ${policy.premium.toStringAsFixed(2)}'),
              pw.Text('Billing Frequency: ${policy.billingFrequency}'),
              pw.SizedBox(height: 20),
              pw.Text('Form Data:', style: pw.TextStyle(fontSize: 16)),
              ...policy.formData.entries.map((e) => pw.Text('${e.key}: ${e.value}')),
            ],
          ),
        ),
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/all_policies_report.pdf');
    await file.writeAsBytes(await pdf.save());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All policies exported as PDF')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Policy Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportAllPolicies,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: policies.length,
        itemBuilder: (context, index) {
          final policy = policies[index];
          return Card(
            child: ListTile(
              title: Text('${policy.type} - ${policy.subtype}'),
              subtitle: Text(
                'Status: ${policy.status}\nEnd: ${policy.endDate ?? 'N/A'}\nPremium: KES ${policy.premium.toStringAsFixed(2)}',
                style: TextStyle(
                  color: policy.status == PolicyStatus.nearingExpiration
                      ? Colors.yellow[800]
                      : policy.status == PolicyStatus.expired
                          ? Colors.red
                          : null,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () async {
                  final pdf = pw.Document();
                  pdf.addPage(
                    pw.Page(
                      build: (pw.Context context) => pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Policy Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 20),
                          pw.Text('Policy ID: ${policy.id}'),
                          pw.Text('Type: ${policy.type}'),
                          pw.Text('Subtype: ${policy.subtype}'),
                          pw.Text('Company: ${policy.company}'),
                          pw.Text('Status: ${policy.status}'),
                          pw.Text('Start Date: ${policy.startDate}'),
                          if (policy.endDate != null) pw.Text('End Date: ${policy.endDate}'),
                          pw.Text('Premium: KES ${policy.premium.toStringAsFixed(2)}'),
                          pw.Text('Billing Frequency: ${policy.billingFrequency}'),
                          pw.SizedBox(height: 20),
                          pw.Text('Form Data:', style: pw.TextStyle(fontSize: 16)),
                          ...policy.formData.entries.map((e) => pw.Text('${e.key}: ${e.value}')),
                        ],
                      ),
                    ),
                  );

                  final directory = await getApplicationDocumentsDirectory();
                  final file = File('${directory.path}/policy_${policy.id}.pdf');
                  await file.writeAsBytes(await pdf.save());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Policy ${policy.id} exported as PDF')),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class PdfPreview extends StatelessWidget {
  final File file;
  final int initialPage;
  final bool allowPinchZoom;
  final bool allowSwipeNavigation;

  const PdfPreview({
    super.key,
    required this.file,
    this.initialPage = 1,
    this.allowPinchZoom = true,
    this.allowSwipeNavigation = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PdfDocument>(
      future: PdfDocument.openFile(file.path),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading PDF: ${snapshot.error}'));
        }
        final pdfDoc = snapshot.data!;
        return PdfViewer(
          document: pdfDoc,
          initialPage: initialPage,
          zoomSteps: allowPinchZoom ? 2 : 0,
          panEnabled: allowSwipeNavigation,
        );
      },
    );
  }
}
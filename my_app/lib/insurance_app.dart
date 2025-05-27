import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:google_fonts/google_fonts.dart'; // For elegant typography
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
// Add this import

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

  @override
  State<InsuranceHomeScreen> createState() => _InsuranceHomeScreenState();
}

class _InsuranceHomeScreenState extends State<InsuranceHomeScreen> {
  List<InsuredItem> insuredItems = [];
  List<Cover> covers = [];
  List<Quote> quotes = [];
  List<Quote> companies = [];
  List<Map<String, dynamic>> notifications = []; // Changed from List<dynamic>
  bool isLoading = false;
  Map<String, PDFTemplate> cachedPdfTemplates = {};
  Map<String, String> userDetails = {};
  List<Map<String, String>> chatMessages = [];
  TextEditingController chatController = TextEditingController();
  String currentState = 'start';
  Map<String, dynamic> chatbotTemplate = {};
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

  IconData getIcon(String option) {
    option = option.toLowerCase();
    if (option.contains('private')) return Icons.directions_car_outlined;
    if (option.contains('commercial')) return Icons.local_shipping_outlined;
    if (option.contains('psv') || option.contains('psv_uber')) {
      return Icons.directions_bus_outlined;
    }
    if (option.contains('tuk_tuk')) return Icons.two_wheeler_outlined;
    if (option.contains('special_classes')) {
      return Icons.directions_car_filled_outlined;
    }
    if (option.contains('corporate')) return Icons.business_outlined;
    if (option.contains('individual')) return Icons.person_outlined;
    if (option.contains('family')) return Icons.group_outlined;
    if (option.contains('single_trip')) return Icons.flight_outlined;
    if (option.contains('multi_trip')) return Icons.flight_takeoff_outlined;
    if (option.contains('student')) return Icons.school_outlined;
    if (option.contains('senior_citizen')) return Icons.elderly_outlined;
    if (option.contains('residential') ||
        option.contains('home') ||
        option.contains('house')) {
      return Icons.home_outlined;
    }
    if (option.contains('commercial_property') ||
        option.contains('commercial')) {
      return Icons.storefront_outlined;
    }
    if (option.contains('industrial')) return Icons.factory_outlined;
    if (option.contains('landlord')) return Icons.real_estate_agent_outlined;
    if (option.contains('standard')) return Icons.work_outline;
    if (option.contains('enhanced')) return Icons.security_outlined;
    if (option.contains('contractor')) return Icons.construction_outlined;
    if (option.contains('small_business')) return Icons.store_outlined;
    if (option.contains('apartment')) return Icons.apartment_outlined;
    if (option.contains('500,000') ||
        option.contains('1,000,000') ||
        option.contains('2,000,000')) {
      return Icons.monetization_on_outlined;
    }
    if (option.contains('construction')) return Icons.construction_outlined;
    if (option.contains('manufacturing')) return Icons.factory_outlined;
    if (option.contains('services')) return Icons.room_service_outlined;
    if (option.contains('retail')) return Icons.store_outlined;
    return Icons.category_outlined;
  }

  static const List<String> _vehicleTypes = [
    'Private',
    'Commercial',
    'PSV',
    'Motorcycle',
    'Tuk Tuk',
    'Special Classes',
  ];

  static const List<String> _inpatientLimits = [
    'KES 500,000',
    'KES 1,000,000',
    'KES 2,000,000',
    'KES 3,000,000',
    'KES 4,000,000',
    'KES 5,000,000',
    'KES 10,000,000',
  ];

  static const List<String> _medicalServices = [
    'Outpatient',
    'Dental & Optical',
    'Maternity',
  ];

  static const List<String> _underwriters = [
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
      expectedType: ExpectedType.name,
      validator: (value) =>
          value.isEmpty || RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
              ? null
              : 'Invalid name',
    ),
    'email': FieldDefinition(
      expectedType: ExpectedType.email,
      validator: (value) => value.isEmpty ||
              RegExp(
                r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
              ).hasMatch(value)
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
    'health_condition': FieldDefinition(
      expectedType: ExpectedType.text,
      validator: (value) => null,
    ),
  };

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
              RegExp(
                r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
              ).hasMatch(value)
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
              RegExp(
                r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
              ).hasMatch(value)
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
        'retail',
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
              RegExp(
                r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
              ).hasMatch(value)
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
        'landlord',
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
      validator: (value) {
        if (value.isEmpty) return null;
        return RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
            ? null
            : 'Invalid name';
      },
    ),
    'email': FieldDefinition(
      expectedType: ExpectedType.email,
      validator: (value) {
        if (value.isEmpty) return null;
        return RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                .hasMatch(value)
            ? null
            : 'Invalid email';
      },
    ),
    'phone': FieldDefinition(
      expectedType: ExpectedType.phone,
      validator: (value) {
        if (value.isEmpty) return null;
        return RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)
            ? null
            : 'Invalid phone number';
      },
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
      validator: (value) => null, // Optional free-text field
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
      validator: (value) {
        if (value.isEmpty) return null;
        return _inpatientLimits.contains(value)
            ? null
            : 'Invalid inpatient limit';
      },
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
      expectedType: ExpectedType.text,
      validator: (value) {
        if (value.isEmpty) return null;
        var services = value.split(', ').map((s) => s.trim()).toList();
        return services.every((s) => _medicalServices.contains(s))
            ? null
            : 'Invalid medical services';
      },
    ),
    'underwriters': FieldDefinition(
      expectedType: ExpectedType.text,
      validator: (value) {
        if (value.isEmpty) return null;
        var selected = value.split(', ').map((s) => s.trim()).toList();
        return selected.length <= 3 &&
                selected.every((s) => _underwriters.contains(s))
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
              RegExp(
                r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
              ).hasMatch(value)
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
      validator: (value) =>
          _vehicleTypes.contains(value) ? null : 'Invalid vehicle type',
    ),
  };

  var _selectedIndex;

  String? selectedCompany;

  Map<String, String>? extractedData;

  @override
  void initState() {
    super.initState();
    _loadCachedPdfTemplates();
    _loadUserDetails();
    _loadInsuredItems();
    _loadPolicies();
    _loadQuotes();
    _loadNotifications(); // Add this
    fetchTrendingTopics();
    fetchBlogPosts();
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
    final key = encrypt.Key.fromLength(32);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final decrypted = encrypter.decrypt64(data, iv: iv);
    setState(() {
      insuredItems = (jsonDecode(decrypted) as List)
          .map((item) => InsuredItem.fromJson(item))
          .toList();
    });
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

  Future<void> _loadNotifications() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (kDebugMode) {
          print('No user authenticated for loading notifications.');
        }
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(userId)
          .collection('user_notifications')
          .get();

      setState(() {
        notifications = snapshot.docs.map((doc) => doc.data()).toList();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading notifications: $e');
      }
      setState(() {
        notifications = [];
      });
    }
  }

  Future<void> _loadPolicies() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (kDebugMode) {
          print('No user authenticated for loading policies.');
        }
        setState(() {
          policies = [];
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('policies')
          .doc(userId)
          .collection('user_policies')
          .get();

      setState(() {
        policies = snapshot.docs
            .map(
              (doc) => Policy(
                id: doc['id'] as String,
                type: doc['type'] as String,
                subtype: doc['subtype'] as String,
                companyId: doc['companyId'] as String,
                status: CoverStatus.values.firstWhere(
                  (e) => e.toString() == doc['status'],
                  orElse: () => CoverStatus.active,
                ),
                insuredItemId: doc['insuredItemId'] as String? ?? '',
                coverageType: doc['coverageType'] as String? ?? '',
                pdfTemplateKey: doc['pdfTemplateKey'] as String? ?? '',
                endDate: doc['endDate'] != null
                    ? (doc['endDate'] as Timestamp).toDate()
                    : null,
              ),
            )
            .toList();
      });

      if (policies.isEmpty && kDebugMode) {
        if (kDebugMode) {
          print('No policies found for user $userId.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading policies: $e');
      }
      setState(() {
        policies = [];
      });
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

  void _loadChatbotTemplate() {
    chatbotTemplate = {
      'states': {
        'start': {
          'message': 'Hi! 😊 Let’s assist you. What would you like to do?',
          'options': [
            {'text': 'Generate a quote', 'next': 'insurance_type'},
            {'text': 'Fill a form', 'next': 'select_item'},
            {'text': 'Explore insurance', 'next': 'insurance'},
            {'text': 'Add insured item', 'next': 'add_item'},
            {'text': 'View policies', 'next': 'view_policies'},
          ],
        },
        'insurance_type': {
          'message':
              'What type of insurance would you like?\n1. Motor\n2. Medical\n3. Travel\n4. Property\n5. WIBA',
          'options': [
            {'text': 'Motor', 'next': 'vehicle_type'},
            {'text': 'Medical', 'next': 'medical_policy_type'},
            {'text': 'Travel', 'next': 'travel_subtype'},
            {'text': 'Property', 'next': 'property_type'},
            {'text': 'WIBA', 'next': 'wiba_subtype'},
          ],
        },
        // Motor States
        'vehicle_type': {
          'message':
              'Please select your vehicle type:\n${_vehicleTypes.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
          'options': _vehicleTypes
              .map((type) => {'text': type, 'next': 'quote_auto_subtype'})
              .toList(),
        },
        'quote_auto_subtype': {
          'message': 'Please select the motor insurance subtype:\n${[
            'commercial',
            'psv',
            'psv_uber',
            'private',
            'tuk_tuk',
            'special_classes'
          ].asMap().entries.map((e) => '${e.key + 1}. ${e.value.replaceAll('_', ' ')}').join('\n')}',
          'options': [
            'commercial',
            'psv',
            'psv_uber',
            'private',
            'tuk_tuk',
            'special_classes',
          ]
              .map((type) => {'text': type, 'next': 'quote_motor_coverage'})
              .toList(),
        },
        'quote_motor_coverage': {
          'message':
              'Please select the coverage type:\n1. Comprehensive\n2. Third Party',
          'options': [
            {'text': 'Comprehensive', 'next': 'quote_filling'},
            {'text': 'Third Party', 'next': 'quote_filling'},
          ],
        },
        // Medical States
        'medical_policy_type': {
          'message':
              'Is this an Individual or Corporate medical policy?\n1. Individual\n2. Corporate',
          'options': [
            {'text': 'Individual', 'next': 'health_inpatient_limit'},
            {'text': 'Corporate', 'next': 'health_beneficiaries'},
          ],
        },
        'health_beneficiaries': {
          'message':
              'How many beneficiaries will be covered? (Minimum 3 for Corporate)',
          'next': 'health_inpatient_limit',
        },
        'health_inpatient_limit': {
          'message':
              'Please select your preferred Inpatient Limit:\n${_inpatientLimits.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
          'options': _inpatientLimits
              .map(
                (limit) => {
                  'text': limit,
                  'next': 'health_outpatient_limit',
                },
              )
              .toList(),
        },
        'health_outpatient_limit': {
          'message':
              'Please enter your preferred Outpatient Limit (KES, e.g., 100000):',
          'next': 'health_dental_limit',
        },
        'health_dental_limit': {
          'message':
              'Please enter your preferred Dental Limit (KES, e.g., 50000):',
          'next': 'health_optical_limit',
        },
        'health_optical_limit': {
          'message':
              'Please enter your preferred Optical Limit (KES, e.g., 30000):',
          'next': 'health_maternity_limit',
        },
        'health_maternity_limit': {
          'message':
              'Please enter your preferred Maternity Limit (KES, e.g., 150000):',
          'next': 'health_medical_services',
        },
        'health_medical_services': {
          'message':
              'Which medical services would you like included? (Select numbers, e.g., 1,2):\n${_medicalServices.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
          'next': 'health_personal_info',
        },
        'health_personal_info': {
          'fields': [
            {'name': 'name', 'prompt': 'What is your name?'},
            {'name': 'email', 'prompt': 'What is your email?'},
            {'name': 'phone', 'prompt': 'What is your phone number?'},
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
            {
              'name': 'pre_existing_conditions',
              'prompt':
                  'Any pre-existing medical conditions? (Enter none if none):',
            },
          ],
          'next': 'health_underwriters',
        },
        'health_underwriters': {
          'message':
              'Select up to three preferred insurance underwriters (e.g., 1,2,3):\n${_underwriters.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
          'next': 'health_summary',
        },
        'health_summary': {
          'message':
              'Here’s what you’ve entered:\n{fields}\nIs this correct?\n1. Yes\n2. No',
          'options': [
            {'text': 'Yes', 'next': 'health_process'},
            {'text': 'No', 'next': 'health_personal_info'},
          ],
        },
        'health_process': {
          'message':
              'Great! Your medical insurance request is being processed.',
          'next': 'start',
        },
        // Travel States
        'travel_subtype': {
          'message': 'Please select the travel insurance subtype:\n${[
            'single_trip',
            'multi_trip',
            'student',
            'senior_citizen'
          ].asMap().entries.map((e) => '${e.key + 1}. ${e.value.replaceAll('_', ' ')}').join('\n')}',
          'options': ['single_trip', 'multi_trip', 'student', 'senior_citizen']
              .map((type) => {'text': type, 'next': 'travel_details'})
              .toList(),
        },
        'travel_details': {
          'fields': [
            {'name': 'name', 'prompt': 'What is your name?'},
            {'name': 'email', 'prompt': 'What is your email?'},
            {'name': 'phone', 'prompt': 'What is your phone number?'},
            {
              'name': 'destination',
              'prompt': 'What is your travel destination?',
            },
            {
              'name': 'travel_start_date',
              'prompt': 'Enter travel start date (YYYY-MM-DD):',
            },
            {
              'name': 'travel_end_date',
              'prompt': 'Enter travel end date (YYYY-MM-DD):',
            },
            {
              'name': 'number_of_travelers',
              'prompt': 'How many travelers are covered?',
            },
            {
              'name': 'coverage_limit',
              'prompt': 'Enter preferred coverage limit (KES):',
            },
          ],
          'next': 'travel_summary',
        },
        'travel_summary': {
          'message':
              'Here’s what you’ve entered:\n{fields}\nIs this correct?\n1. Yes\n2. No',
          'options': [
            {'text': 'Yes', 'next': 'travel_process'},
            {'text': 'No', 'next': 'travel_details'},
          ],
        },
        'travel_process': {
          'message': 'Great! Your travel insurance request is being processed.',
          'next': 'start',
        },
        // Property States
        'property_type': {
          'message': 'Please select the property type:\n${[
            'residential',
            'commercial',
            'industrial',
            'landlord'
          ].asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
          'options': ['residential', 'commercial', 'industrial', 'landlord']
              .map((type) => {'text': type, 'next': 'quote_home_subtype'})
              .toList(),
        },
        'quote_home_subtype': {
          'message': 'Please select the property insurance subtype:\n${[
            'residential',
            'commercial',
            'industrial',
            'landlord'
          ].asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
          'options': [
            'residential',
            'commercial',
            'industrial',
            'landlord',
          ].map((type) => {'text': type, 'next': 'quote_filling'}).toList(),
        },
        // WIBA States
        'wiba_subtype': {
          'message': 'Please select the WIBA subtype:\n${[
            'standard',
            'enhanced',
            'contractor',
            'small_business'
          ].asMap().entries.map((e) => '${e.key + 1}. ${e.value.replaceAll('_', ' ')}').join('\n')}',
          'options': [
            'standard',
            'enhanced',
            'contractor',
            'small_business',
          ].map((type) => {'text': type, 'next': 'wiba_details'}).toList(),
        },
        'wiba_details': {
          'fields': [
            {'name': 'name', 'prompt': 'What is your name?'},
            {'name': 'email', 'prompt': 'What is your email?'},
            {'name': 'phone', 'prompt': 'What is your phone number?'},
            {'name': 'business_name', 'prompt': 'What is the business name?'},
            {
              'name': 'number_of_employees',
              'prompt': 'How many employees are covered?',
            },
            {
              'name': 'coverage_limit',
              'prompt': 'Enter preferred coverage limit (KES):',
            },
            {
              'name': 'industry_type',
              'prompt':
                  'Select industry type (construction, manufacturing, services, retail):',
            },
          ],
          'next': 'wiba_summary',
        },
        'wiba_summary': {
          'message':
              'Here’s what you’ve entered:\n{fields}\nIs this correct?\n1. Yes\n2. No',
          'options': [
            {'text': 'Yes', 'next': 'wiba_process'},
            {'text': 'No', 'next': 'wiba_details'},
          ],
        },
        'wiba_process': {
          'message': 'Great! Your WIBA insurance request is being processed.',
          'next': 'start',
        },
        // Quote Filling
        'quote_filling': {
          'fields':
              [], // Dynamically set in _handleChatInput based on insurance type
          'next': 'quote_summary',
        },
        'quote_summary': {
          'message':
              'Here’s what you’ve entered:\n{fields}\nIs this correct?\n1. Yes\n2. No',
          'options': [
            {'text': 'Yes', 'next': 'quote_process'},
            {'text': 'No', 'next': 'quote_filling'},
          ],
        },
        'quote_process': {
          'message': 'Your quote has been generated and sent for processing.',
          'next': 'start',
        },
        // Add Item States
        'add_item': {
          'message':
              'What type of item to insure?\n1. Car\n2. Property\n3. Medical\n4. Travel\n5. WIBA',
          'options': [
            {'text': 'Car', 'next': 'add_vehicle_type'},
            {'text': 'Property', 'next': 'add_property_type'},
            {'text': 'Medical', 'next': 'add_medical_type'},
            {'text': 'Travel', 'next': 'add_travel_type'},
            {'text': 'WIBA', 'next': 'add_wiba_type'},
          ],
        },
        'add_vehicle_type': {
          'message':
              'Please select the vehicle type:\n${_vehicleTypes.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
          'options': _vehicleTypes
              .map((type) => {'text': type, 'next': 'add_item_details'})
              .toList(),
        },
        'add_property_type': {
          'message': 'Please select the property type:\n${[
            'residential',
            'commercial',
            'industrial',
            'landlord'
          ].asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
          'options': ['residential', 'commercial', 'industrial', 'landlord']
              .map((type) => {'text': type, 'next': 'add_item_details'})
              .toList(),
        },
        'add_medical_type': {
          'message':
              'Is this an Individual or Corporate medical policy?\n1. Individual\n2. Corporate',
          'options': [
            {'text': 'Individual', 'next': 'add_item_details'},
            {'text': 'Corporate', 'next': 'health_beneficiaries'},
          ],
        },
        'add_travel_type': {
          'message': 'Please select the travel insurance subtype:\n${[
            'single_trip',
            'multi_trip',
            'student',
            'senior_citizen'
          ].asMap().entries.map((e) => '${e.key + 1}. ${e.value.replaceAll('_', ' ')}').join('\n')}',
          'options': ['single_trip', 'multi_trip', 'student', 'senior_citizen']
              .map((type) => {'text': type, 'next': 'add_item_details'})
              .toList(),
        },
        'add_wiba_type': {
          'message': 'Please select the WIBA subtype:\n${[
            'standard',
            'enhanced',
            'contractor',
            'small_business'
          ].asMap().entries.map((e) => '${e.key + 1}. ${e.value.replaceAll('_', ' ')}').join('\n')}',
          'options': ['standard', 'enhanced', 'contractor', 'small_business']
              .map((type) => {'text': type, 'next': 'add_item_details'})
              .toList(),
        },
        'add_item_details': {
          'fields':
              [], // Dynamically set in _handleChatInput based on insurance type
          'next': 'add_item_upload',
        },
        'add_item_upload': {
          'message':
              'Please upload relevant documents (if any):\n1. Upload Logbook (Motor)\n2. Upload Previous Policy\n3. Skip',
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
        'add_item_summary': {
          'message':
              'Here’s what you’ve entered:\n{fields}\nIs this correct?\n1. Yes\n2. No',
          'options': [
            {'text': 'Yes', 'next': 'add_item_process'},
            {'text': 'No', 'next': 'add_item_details'},
          ],
        },
        'add_item_process': {
          'message': 'Your insured item has been added successfully.',
          'next': 'start',
        },
        // PDF Filling States
        'select_item': {
          'message':
              'Please select an insured item or add a new one:\n{items}\n{new_option}',
          'options': [], // Dynamically set in _handleChatInput
        },
        'pdf_filling': {
          'fields': [], // Dynamically set in _handleChatInput
          'next': 'pdf_upload',
        },
        'pdf_upload': {
          'message':
              'Before filling the PDF, please upload relevant documents (if any):\n1. Upload Logbook (Motor)\n2. Upload Previous Policy\n3. Skip',
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
        'pdf_filling_continue': {
          'fields': [], // Dynamically set in _handleChatInput
          'next': 'pdf_summary',
        },
        'pdf_missing_fields': {
          'message': 'Please provide the value for the missing field:',
          'next': 'pdf_summary',
        },
        'pdf_summary': {
          'message':
              'Here’s what you’ve entered:\n{fields}\nIs this correct?\n1. Yes\n2. No',
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
        // View Policies
        'view_policies': {
          'message':
              'Here are your policies:\n{policies}\nWhat would you like to do next?',
          'next': 'start',
        },
      },
    };
  }

  void _startChatbot() {
    var startState = chatbotTemplate['states']['start'];
    String message = startState['message'] +
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
    Map<String, PDFTemplate> cachedPdfTemplates,
    String insuranceType,
    BuildContext context,
  ) async {
    try {
      PDFTemplate? template = cachedPdfTemplates[templateKey];
      if (template == null) {
        print('Template not found for key: $templateKey');
        if (kIsWeb) {
          print(
              'No PDF templates available on web; consider adding default templates');
        }
        // Fallback: Use a default template with minimal coordinates
        template = PDFTemplate(
          coordinates: formData.keys.fold<Map<String, Map<String, double>>>({},
              (map, key) {
            map[key] = {
              'page': 1.0,
              'x': 50.0,
              'y': 50.0
            }; // Default coordinates
            return map;
          }),
          fields: {},
          fieldMappings: {},
          policyType: '',
          policySubtype: '',
          templateKey: '',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Using default PDF template due to missing configuration')),
          );
        }
      }

      final directory = await getApplicationDocumentsDirectory();
      final templateFile =
          File('${directory.path}/pdf_templates/$templateKey.pdf');
      if (!await templateFile.exists()) {
        print('Template file does not exist: ${templateFile.path}');
        if (kIsWeb) {
          print(
              'PDF template files are not supported on web without asset loading');
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF template file not found')),
          );
        }
        return null;
      }

      final pdfBytes = await templateFile.readAsBytes();
      final pdfDoc = await pdf.PdfDocument.openData(pdfBytes);
      final outputPdf = pw.Document();

      Map<String, FieldDefinition> fields;
      switch (insuranceType.toLowerCase()) {
        case 'motor':
          fields = motorFields;
          break;
        case 'medical':
          fields = medicalFields;
          break;
        case 'property':
          fields = propertyFields;
          break;
        case 'travel':
          fields = travelFields;
          break;
        case 'wiba':
          fields = wibaFields;
          break;
        default:
          fields = motorFields;
          print(
              'Unknown insurance type: $insuranceType, using motorFields as fallback');
      }

      for (int i = 0; i < pdfDoc.pageCount; i++) {
        final page = await pdfDoc.getPage(i + 1);
        // Skip image rendering on web due to PdfPageImage limitations
        outputPdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Stack(
                children: [
                  // Placeholder: No background image on web
                  pw.Container(
                    width: page.width.toDouble(),
                    height: page.height.toDouble(),
                    color: PdfColors.white,
                  ),
                  ...formData.entries.map((entry) {
                    final coord = template!.coordinates[entry.key];
                    if (coord != null && coord['page'] == (i + 1).toDouble()) {
                      String? error =
                          fields[entry.key]!.validator!(entry.value);
                      if (error != null) {
                        print('Validation error for ${entry.key}: $error');
                      }
                      return pw.Positioned(
                        left: coord['x']!,
                        top: coord['y']!,
                        child: pw.Text(
                          entry.value,
                          style: pw.TextStyle(
                            font: pw.Font.helvetica(),
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                    return pw.SizedBox();
                  }),
                ],
              );
            },
          ),
        );
      }
      await pdfDoc.dispose();

      final reportsDirectory = Directory('${directory.path}/reports');
      if (!await reportsDirectory.exists()) {
        await reportsDirectory.create(recursive: true);
      }
      final filePath = '${reportsDirectory.path}/filled_$templateKey.pdf';
      final outputFile = File(filePath);
      await outputFile.writeAsBytes(await outputPdf.save());
      return outputFile;
    } catch (e) {
      print('Error filling PDF template: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fill PDF: $e')),
        );
      }
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

  Future<void> _handleChatInput(String input) async {
    setState(() {
      chatMessages.add({'sender': 'user', 'text': input});
    });

    var currentStateData = chatbotTemplate['states'][currentState];
    Map<String, FieldDefinition> fields;
    String? insuranceType = formResponses['insurance_type'];
    switch (insuranceType) {
      case 'Motor':
        fields = motorFields;
        break;
      case 'Medical':
        fields = medicalFields;
        break;
      case 'Property':
        fields = propertyFields;
        break;
      default:
        fields = motorFields; // Fallback for initial states
    }

    if (currentState == 'start') {
      int? choice = int.tryParse(input);
      if (choice != null &&
          choice >= 1 &&
          choice <= currentStateData['options'].length) {
        setState(() {
          currentState = currentStateData['options'][choice - 1]['next'];
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                (chatbotTemplate['states'][currentState]['options']
                        ?.asMap()
                        .entries
                        .map((e) => '${e.key + 1}. ${e.value['text']}')
                        .join('\n') ??
                    ''),
          });
        });
      } else {
        _showError(
          'Please select a valid option (1-${currentStateData['options'].length}).',
        );
      }
    } else if (currentState == 'insurance_type') {
      int? choice = int.tryParse(input);
      if (choice != null && choice >= 1 && choice <= 3) {
        setState(() {
          formResponses['insurance_type'] =
              ['Motor', 'Medical', 'Property'][choice - 1];
          currentState = [
            'vehicle_type',
            'medical_policy_type',
            'property_type'
          ][choice - 1];
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                (chatbotTemplate['states'][currentState]['options']
                        ?.asMap()
                        .entries
                        .map((e) => '${e.key + 1}. ${e.value['text']}')
                        .join('\n') ??
                    ''),
          });
        });
      } else {
        _showError(
          'Please select 1 for Motor, 2 for Medical, or 3 for Property.',
        );
      }
    } else if (currentState == 'vehicle_type' && insuranceType == 'Motor') {
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= _vehicleTypes.length) {
        setState(() {
          formResponses['vehicle_type'] = _vehicleTypes[choice - 1];
          currentState = 'quote_type';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                currentStateData['options'][choice - 1]['next']['options']
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value['text']}')
                    .join('\n'),
          });
        });
      } else {
        _showError(
          'Please select a valid vehicle type (1-${_vehicleTypes.length}).',
        );
      }
    } else if (currentState == 'property_type' && insuranceType == 'Property') {
      int? choice = int.tryParse(input);
      List<String> propertyTypes = [
        'residential',
        'commercial',
        'industrial',
        'landlord',
      ];
      if (choice != null && choice > 0 && choice <= propertyTypes.length) {
        setState(() {
          formResponses['property_type'] = propertyTypes[choice - 1];
          currentState = 'quote_type';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                chatbotTemplate['states'][currentState]['options']
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value['text']}')
                    .join('\n'),
          });
        });
      } else {
        _showError(
          'Please select a valid property type (1-${propertyTypes.length}).',
        );
      }
    } else if (currentState == 'quote_type') {
      int? choice = int.tryParse(input);
      if (choice != null && choice >= 1 && choice <= 3) {
        setState(() {
          formResponses['quote_type'] = [
            'Auto Insurance',
            'Home Insurance',
            'Health Insurance'
          ][choice - 1];
          currentState = [
            'quote_auto_subtype',
            'quote_home_subtype',
            'health_inpatient_limit',
          ][choice - 1];
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                (chatbotTemplate['states'][currentState]['options']
                        ?.asMap()
                        .entries
                        .map((e) => '${e.key + 1}. ${e.value['text']}')
                        .join('\n') ??
                    ''),
          });
        });
      } else {
        _showError(
          'Please select 1 for Auto, 2 for Home, or 3 for Health Insurance.',
        );
      }
    } else if (currentState == 'quote_auto_subtype' &&
        insuranceType == 'Motor') {
      List<String> subtypes = [
        'commercial',
        'psv',
        'psv_uber',
        'private',
        'tuk_tuk',
        'special_classes',
      ];
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= subtypes.length) {
        setState(() {
          formResponses['subtype'] = subtypes[choice - 1];
          currentState = 'quote_filling';
          currentStateData = chatbotTemplate['states'][currentState];
          currentStateData['fields'] = motorFields.keys
              .where((key) => !['vehicle_type'].contains(key))
              .map(
                (key) => {
                  'name': key,
                  'prompt': 'Please enter your $key for motor quote:',
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
        _showError(
          'Please select a valid motor subtype (1-${subtypes.length}).',
        );
      }
    } else if (currentState == 'quote_home_subtype' &&
        insuranceType == 'Property') {
      List<String> subtypes = [
        'residential',
        'commercial',
        'industrial',
        'landlord',
      ];
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= subtypes.length) {
        setState(() {
          formResponses['subtype'] = subtypes[choice - 1];
          currentState = 'quote_filling';
          currentStateData = chatbotTemplate['states'][currentState];
          currentStateData['fields'] = propertyFields.keys
              .where((key) => !['property_type'].contains(key))
              .map(
                (key) => {
                  'name': key,
                  'prompt': 'Please enter your $key for property quote:',
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
        _showError(
          'Please select a valid property subtype (1-${subtypes.length}).',
        );
      }
    } else if (currentState == 'quote_filling') {
      var fieldsList = currentStateData['fields'];
      if (currentFieldIndex < fieldsList.length) {
        var field = fieldsList[currentFieldIndex];
        String fieldName = field['name'];
        String? error = fields[fieldName]!.validator!(input);

        if (error == null) {
          formResponses[fieldName] = input;
          currentFieldIndex++;
          if (currentFieldIndex < fieldsList.length) {
            setState(() {
              chatMessages.add({
                'sender': 'bot',
                'text': fieldsList[currentFieldIndex]['prompt'],
              });
            });
          } else {
            String summary = formResponses.entries
                .map((e) => '${e.key}: ${e.value}')
                .join('\n');
            setState(() {
              currentState = 'quote_summary';
              chatMessages.add({
                'sender': 'bot',
                'text':
                    'Here’s what you’ve entered:\n$summary\nIs this correct?\n1. Yes\n2. No',
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
    } else if (currentState == 'quote_summary') {
      int? choice = int.tryParse(input);
      if (choice == 1) {
        double premium = await _calculatePremium(
          formResponses['insurance_type']!.toLowerCase(),
          formResponses['subtype']!,
          formResponses,
        );
        Quote quote = Quote(
          id: Uuid().v4(),
          type: formResponses['insurance_type']!.toLowerCase(),
          subtype: formResponses['subtype']!,
          company: _selectedUnderwriters.isNotEmpty
              ? _selectedUnderwriters[0]
              : 'default',
          premium: premium,
          formData: Map<String, String>.from(formResponses),
          generatedAt: DateTime.now(),
        );
        setState(() {
          quotes.add(quote);
          currentState = 'quote_process';
          chatMessages.add({
            'sender': 'bot',
            'text': 'Your quote has been generated and sent for processing.',
          });
        });
        await _saveQuotes();
        File? quotePdf = await _generateQuotePdf(quote);
        if (quotePdf != null) {
          await _sendEmail(
            quote.company,
            quote.type,
            quote.subtype,
            quote.formData,
            quotePdf,
          );
        }
      } else if (choice == 2) {
        setState(() {
          currentState = 'quote_filling';
          currentFieldIndex = 0;
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['fields'][0]['prompt'],
          });
        });
      } else {
        _showError('Please select 1 for Yes or 2 for No.');
      }
    } else if (currentState == 'medical_policy_type' &&
        insuranceType == 'Medical') {
      int? choice = int.tryParse(input);
      if (choice != null && choice >= 1 && choice <= 2) {
        setState(() {
          formResponses['policy_type'] =
              choice == 1 ? 'Individual' : 'Corporate';
          currentState =
              choice == 1 ? 'health_inpatient_limit' : 'health_beneficiaries';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                (chatbotTemplate['states'][currentState]['options']
                        ?.asMap()
                        .entries
                        .map((e) => '${e.key + 1}. ${e.value['text']}')
                        .join('\n') ??
                    ''),
          });
        });
      } else {
        _showError('Please select 1 for Individual or 2 for Corporate.');
      }
    } else if (currentState == 'health_beneficiaries' &&
        insuranceType == 'Medical') {
      String? error = medicalFields['beneficiaries']!.validator!(input);
      if (error == null) {
        setState(() {
          formResponses['beneficiaries'] = input;
          currentState = 'health_inpatient_limit';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                chatbotTemplate['states'][currentState]['options']
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value['text']}')
                    .join('\n'),
          });
        });
      } else {
        setState(() {
          chatMessages.add({
            'sender': 'bot',
            'text': 'Error: $error. Please try again.',
          });
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['message'],
          });
        });
      }
    } else if (currentState == 'health_inpatient_limit' &&
        insuranceType == 'Medical') {
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= _inpatientLimits.length) {
        setState(() {
          formResponses['inpatient_limit'] = _inpatientLimits[choice - 1];
          currentState = 'health_outpatient_limit';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'],
          });
        });
      } else {
        _showError(
          'Please select a valid inpatient limit (1-${_inpatientLimits.length}).',
        );
      }
    } else if (currentState == 'health_outpatient_limit' &&
        insuranceType == 'Medical') {
      String? error = medicalFields['outpatient_limit']!.validator!(input);
      if (error == null) {
        setState(() {
          formResponses['outpatient_limit'] = input;
          currentState = 'health_dental_limit';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'],
          });
        });
      } else {
        setState(() {
          chatMessages.add({
            'sender': 'bot',
            'text': 'Error: $error. Please try again.',
          });
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['message'],
          });
        });
      }
    } else if (currentState == 'health_dental_limit' &&
        insuranceType == 'Medical') {
      String? error = medicalFields['dental_limit']!.validator!(input);
      if (error == null) {
        setState(() {
          formResponses['dental_limit'] = input;
          currentState = 'health_optical_limit';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'],
          });
        });
      } else {
        setState(() {
          chatMessages.add({
            'sender': 'bot',
            'text': 'Error: $error. Please try again.',
          });
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['message'],
          });
        });
      }
    } else if (currentState == 'health_optical_limit' &&
        insuranceType == 'Medical') {
      String? error = medicalFields['optical_limit']!.validator!(input);
      if (error == null) {
        setState(() {
          formResponses['optical_limit'] = input;
          currentState = 'health_maternity_limit';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'],
          });
        });
      } else {
        setState(() {
          chatMessages.add({
            'sender': 'bot',
            'text': 'Error: $error. Please try again.',
          });
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['message'],
          });
        });
      }
    } else if (currentState == 'health_maternity_limit' &&
        insuranceType == 'Medical') {
      String? error = medicalFields['maternity_limit']!.validator!(input);
      if (error == null) {
        setState(() {
          formResponses['maternity_limit'] = input;
          currentState = 'health_medical_services';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'],
          });
        });
      } else {
        setState(() {
          chatMessages.add({
            'sender': 'bot',
            'text': 'Error: $error. Please try again.',
          });
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['message'],
          });
        });
      }
    } else if (currentState == 'health_medical_services' &&
        insuranceType == 'Medical') {
      final choices = input
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .where((e) => e != null)
          .toList();
      if (choices.every((c) => c! > 0 && c <= _medicalServices.length)) {
        setState(() {
          _selectedMedicalServices =
              choices.map((c) => _medicalServices[c! - 1]).toList();
          formResponses['medical_services'] = _selectedMedicalServices.join(
            ', ',
          );
          currentState = 'health_personal_info';
          currentStateData = chatbotTemplate['states'][currentState];
          currentFieldIndex = 0;
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['fields'][0]['prompt'],
          });
        });
      } else {
        _showError('Please select valid medical services (e.g., 1,2).');
      }
    } else if (currentState == 'health_personal_info' &&
        insuranceType == 'Medical') {
      var fieldsList = currentStateData['fields'];
      if (currentFieldIndex < fieldsList.length) {
        var field = fieldsList[currentFieldIndex];
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
          error = medicalFields[fieldName]!.validator!(input);
          if (error == null) {
            formResponses[fieldName] = input;
            currentFieldIndex++;
          }
        }

        if (currentFieldIndex < fieldsList.length) {
          setState(() {
            chatMessages.add({
              'sender': 'bot',
              'text': fieldsList[currentFieldIndex]['prompt'],
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
    } else if (currentState == 'health_underwriters' &&
        insuranceType == 'Medical') {
      final choices = input
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .where((e) => e != null)
          .toList();
      if (choices.length <= 3 &&
          choices.every((c) => c! > 0 && c <= _underwriters.length)) {
        setState(() {
          _selectedUnderwriters =
              choices.map((c) => _underwriters[c! - 1]).toList();
          formResponses['underwriters'] = _selectedUnderwriters.join(', ');
          currentState = 'health_summary';
          String summary = formResponses.entries
              .map((e) => '${e.key}: ${e.value}')
              .join('\n');
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['next']['message'].replaceAll(
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
      } else {
        _showError('Select up to 3 valid underwriters (e.g., 1,2,3).');
      }
    } else if (currentState == 'health_summary' && insuranceType == 'Medical') {
      int? choice = int.tryParse(input);
      if (choice == 1) {
        double premium = await _calculatePremium(
          'medical',
          formResponses['policy_type'] == 'Corporate'
              ? 'corporate'
              : 'individual',
          formResponses,
        );
        Quote quote = Quote(
          id: Uuid().v4(),
          type: 'medical',
          subtype: formResponses['policy_type'] == 'Corporate'
              ? 'corporate'
              : 'individual',
          company: _selectedUnderwriters.isNotEmpty
              ? _selectedUnderwriters[0]
              : 'default',
          premium: premium,
          formData: Map<String, String>.from(formResponses),
          generatedAt: DateTime.now(),
        );
        setState(() {
          quotes.add(quote);
          currentState = 'health_process';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'],
          });
        });
        await _saveQuotes();
        File? quotePdf = await _generateQuotePdf(quote);
        if (quotePdf != null) {
          await _sendEmail(
            quote.company,
            quote.type,
            quote.subtype,
            quote.formData,
            quotePdf,
          );
        }
      } else if (choice == 2) {
        setState(() {
          currentState = 'health_personal_info';
          currentFieldIndex = 0;
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['fields'][0]['prompt'],
          });
        });
      } else {
        _showError('Please select 1 for Yes or 2 for No.');
      }
    } else if (currentState == 'add_item') {
      int? choice = int.tryParse(input);
      List<String> itemTypes = ['car', 'home', 'medical'];
      if (choice != null && choice > 0 && choice <= itemTypes.length) {
        setState(() {
          formResponses['item_type'] = itemTypes[choice - 1];
          formResponses['insurance_type'] = itemTypes[choice - 1] == 'car'
              ? 'Motor'
              : itemTypes[choice - 1] == 'home'
                  ? 'Property'
                  : 'Medical';
          currentState = itemTypes[choice - 1] == 'car'
              ? 'add_vehicle_type'
              : itemTypes[choice - 1] == 'home'
                  ? 'add_property_type'
                  : 'add_medical_type';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                (chatbotTemplate['states'][currentState]['options']
                        ?.asMap()
                        .entries
                        .map((e) => '${e.key + 1}. ${e.value['text']}')
                        .join('\n') ??
                    ''),
          });
        });
      } else {
        _showError('Please select 1 for car, 2 for home, or 3 for medical.');
      }
    } else if (currentState == 'add_vehicle_type' && insuranceType == 'Motor') {
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= _vehicleTypes.length) {
        setState(() {
          formResponses['vehicle_type'] = _vehicleTypes[choice - 1];
          currentState = 'add_item_details';
          currentStateData = chatbotTemplate['states'][currentState];
          currentStateData['fields'] = motorFields.keys
              .map(
                (key) => {
                  'name': key,
                  'prompt': 'Please enter your $key for the vehicle:',
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
        _showError(
          'Please select a valid vehicle type (1-${_vehicleTypes.length}).',
        );
      }
    } else if (currentState == 'add_property_type' &&
        insuranceType == 'Property') {
      List<String> propertyTypes = [
        'residential',
        'commercial',
        'industrial',
        'landlord',
      ];
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= propertyTypes.length) {
        setState(() {
          formResponses['property_type'] = propertyTypes[choice - 1];
          currentState = 'add_item_details';
          currentStateData = chatbotTemplate['states'][currentState];
          currentStateData['fields'] = propertyFields.keys
              .map(
                (key) => {
                  'name': key,
                  'prompt': 'Please enter your $key for the property:',
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
        _showError(
          'Please select a valid property type (1-${propertyTypes.length}).',
        );
      }
    } else if (currentState == 'add_medical_type' &&
        insuranceType == 'Medical') {
      int? choice = int.tryParse(input);
      List<String> medicalTypes = ['individual', 'corporate'];
      if (choice != null && choice > 0 && choice <= medicalTypes.length) {
        setState(() {
          formResponses['policy_type'] = medicalTypes[choice - 1];
          currentState = medicalTypes[choice - 1] == 'corporate'
              ? 'health_beneficiaries'
              : 'add_item_details';
          currentStateData = chatbotTemplate['states'][currentState];
          if (currentState == 'add_item_details') {
            currentStateData['fields'] = medicalFields.keys
                .where(
                  (key) => ![
                    'inpatient_limit',
                    'outpatient_limit',
                    'dental_limit',
                    'optical_limit',
                    'maternity_limit',
                    'medical_services',
                    'underwriters',
                    'beneficiaries',
                  ].contains(key),
                )
                .map(
                  (key) => {
                    'name': key,
                    'prompt': 'Please enter your $key for medical item:',
                  },
                )
                .toList();
            currentFieldIndex = 0;
          }
          chatMessages.add({
            'sender': 'bot',
            'text': currentStateData['message'] +
                '\n' +
                (currentStateData['options']
                        ?.asMap()
                        .entries
                        .map((e) => '${e.key + 1}. ${e.value['text']}')
                        .join('\n') ??
                    currentStateData['fields']?[0]['prompt'] ??
                    ''),
          });
        });
      } else {
        _showError('Please select 1 for Individual or 2 for Corporate.');
      }
    } else if (currentState == 'add_item_details') {
      var fieldsList = currentStateData['fields'];
      if (currentFieldIndex < fieldsList.length) {
        var field = fieldsList[currentFieldIndex];
        String fieldName = field['name'];
        String? error = fields[fieldName]!.validator!(input);

        if (error == null) {
          formResponses[fieldName] = input;
          currentFieldIndex++;
          if (currentFieldIndex < fieldsList.length) {
            setState(() {
              chatMessages.add({
                'sender': 'bot',
                'text': fieldsList[currentFieldIndex]['prompt'],
              });
            });
          } else {
            setState(() {
              currentState = 'add_item_upload';
              chatMessages.add({
                'sender': 'bot',
                'text': currentStateData['next']['message'] +
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
    } else if (currentState == 'add_item_upload') {
      int? choice = int.tryParse(input);
      if (choice != null && choice >= 1 && choice <= 3) {
        if (choice == 1) {
          await _uploadLogbook();
          setState(() {
            currentState = 'add_item_logbook';
            chatMessages.add({
              'sender': 'bot',
              'text': chatbotTemplate['states'][currentState]['message'] +
                  '\n' +
                  chatbotTemplate['states'][currentState]['options']
                      .asMap()
                      .entries
                      .map((e) => '${e.key + 1}. ${e.value['text']}')
                      .join('\n'),
            });
          });
        } else if (choice == 2) {
          await _uploadPreviousPolicy();
          setState(() {
            currentState = 'add_item_policy';
            chatMessages.add({
              'sender': 'bot',
              'text': chatbotTemplate['states'][currentState]['message'],
            });
          });
        } else {
          setState(() {
            currentState = 'add_item_summary';
            String summary = formResponses.entries
                .map((e) => '${e.key}: ${e.value}')
                .join('\n');
            chatMessages.add({
              'sender': 'bot',
              'text':
                  chatbotTemplate['states'][currentState]['message'].replaceAll(
                        '{fields}',
                        summary,
                      ) +
                      '\n' +
                      chatbotTemplate['states'][currentState]['options']
                          .asMap()
                          .entries
                          .map((e) => '${e.key + 1}. ${e.value['text']}')
                          .join('\n'),
            });
          });
        }
      } else {
        _showError(
          'Please select 1 to upload logbook, 2 for previous policy, or 3 to skip.',
        );
      }
    } else if (currentState == 'add_item_logbook') {
      int? choice = int.tryParse(input);
      if (choice != null && choice >= 1 && choice <= 2) {
        if (choice == 1) {
          await _uploadPreviousPolicy();
          setState(() {
            currentState = 'add_item_policy';
            chatMessages.add({
              'sender': 'bot',
              'text': chatbotTemplate['states'][currentState]['message'],
            });
          });
        } else {
          setState(() {
            currentState = 'add_item_summary';
            String summary = formResponses.entries
                .map((e) => '${e.key}: ${e.value}')
                .join('\n');
            chatMessages.add({
              'sender': 'bot',
              'text':
                  chatbotTemplate['states'][currentState]['message'].replaceAll(
                        '{fields}',
                        summary,
                      ) +
                      '\n' +
                      chatbotTemplate['states'][currentState]['options']
                          .asMap()
                          .entries
                          .map((e) => '${e.key + 1}. ${e.value['text']}')
                          .join('\n'),
            });
          });
        }
      } else {
        _showError('Please select 1 to upload previous policy or 2 to skip.');
      }
    } else if (currentState == 'add_item_policy') {
      setState(() {
        currentState = 'add_item_summary';
        String summary =
            formResponses.entries.map((e) => '${e.key}: ${e.value}').join('\n');
        chatMessages.add({
          'sender': 'bot',
          'text': chatbotTemplate['states'][currentState]['message'].replaceAll(
                '{fields}',
                summary,
              ) +
              '\n' +
              chatbotTemplate['states'][currentState]['options']
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
            type: formResponses['insurance_type']!.toLowerCase(),
            vehicleType: insuranceType == 'Motor'
                ? formResponses['vehicle_type'] ?? ''
                : '',
            details: Map<String, String>.from(formResponses)
              ..removeWhere(
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
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                chatbotTemplate['states'][currentState]['options']
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value['text']}')
                    .join('\n'),
          });
        });
      } else {
        _showError('Please select 1 to confirm or 2 to cancel.');
      }
    } else if (currentState == 'select_item') {
      int? choice = int.tryParse(input);
      if (choice != null && choice > 0 && choice <= insuredItems.length + 1) {
        if (choice <= insuredItems.length) {
          setState(() {
            selectedInsuredItemId = insuredItems[choice - 1].id;
            currentState = 'pdf_filling';
            currentStateData = chatbotTemplate['states'][currentState];
            currentStateData['fields'] = fields.keys
                .map(
                  (key) => {
                    'name': key,
                    'prompt': 'Please enter your $key for the form:',
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
            currentState = 'add_item';
            chatMessages.add({
              'sender': 'bot',
              'text': chatbotTemplate['states'][currentState]['message'] +
                  '\n' +
                  chatbotTemplate['states'][currentState]['options']
                      .asMap()
                      .entries
                      .map((e) => '${e.key + 1}. ${e.value['text']}')
                      .join('\n'),
            });
          });
        }
      } else {
        _showError(
          'Please select a valid item or ${insuredItems.length + 1} for new details.',
        );
      }
    } else if (currentState == 'pdf_filling') {
      if (currentFieldIndex == 0) {
        setState(() {
          currentState = 'pdf_upload';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'] +
                '\n' +
                chatbotTemplate['states'][currentState]['options']
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value['text']}')
                    .join('\n'),
          });
        });
      } else {
        var fieldsList = currentStateData['fields'];
        if (currentFieldIndex < fieldsList.length) {
          var field = fieldsList[currentFieldIndex];
          String fieldName = field['name'];
          String? error = fields[fieldName]!.validator!(input);

          if (error == null) {
            formResponses[fieldName] = input;
            currentFieldIndex++;
            if (currentFieldIndex < fieldsList.length) {
              setState(() {
                chatMessages.add({
                  'sender': 'bot',
                  'text': fieldsList[currentFieldIndex]['prompt'],
                });
              });
            } else {
              String summary = formResponses.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join('\n');
              setState(() {
                currentState = 'pdf_summary';
                chatMessages.add({
                  'sender': 'bot',
                  'text': currentStateData['next']['message'].replaceAll(
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
    } else if (currentState == 'pdf_upload') {
      int? choice = int.tryParse(input);
      if (choice != null && choice >= 1 && choice <= 3) {
        if (choice == 1) {
          await _uploadLogbook();
          setState(() {
            currentState = 'pdf_logbook';
            chatMessages.add({
              'sender': 'bot',
              'text': chatbotTemplate['states'][currentState]['message'] +
                  '\n' +
                  chatbotTemplate['states'][currentState]['options']
                      .asMap()
                      .entries
                      .map((e) => '${e.key + 1}. ${e.value['text']}')
                      .join('\n'),
            });
          });
        } else if (choice == 2) {
          await _uploadPreviousPolicy();
          setState(() {
            currentState = 'pdf_policy';
            chatMessages.add({
              'sender': 'bot',
              'text': chatbotTemplate['states'][currentState]['message'],
            });
          });
        } else {
          setState(() {
            currentState = 'pdf_filling_continue';
            currentStateData = chatbotTemplate['states'][currentState];
            currentStateData['fields'] = fields.keys
                .map(
                  (key) => {
                    'name': key,
                    'prompt': 'Please enter your $key for the form:',
                  },
                )
                .toList();
            currentFieldIndex = 0;
            chatMessages.add({
              'sender': 'bot',
              'text': currentStateData['fields'][0]['prompt'],
            });
          });
        }
      } else {
        _showError(
          'Please select 1 to upload logbook, 2 for previous policy, or 3 to skip.',
        );
      }
    } else if (currentState == 'pdf_logbook') {
      int? choice = int.tryParse(input);
      if (choice != null && choice >= 1 && choice <= 2) {
        if (choice == 1) {
          await _uploadPreviousPolicy();
          setState(() {
            currentState = 'pdf_policy';
            chatMessages.add({
              'sender': 'bot',
              'text': chatbotTemplate['states'][currentState]['message'],
            });
          });
        } else {
          setState(() {
            currentState = 'pdf_filling_continue';
            currentStateData = chatbotTemplate['states'][currentState];
            currentStateData['fields'] = fields.keys
                .map(
                  (key) => {
                    'name': key,
                    'prompt': 'Please enter your $key for the form:',
                  },
                )
                .toList();
            currentFieldIndex = 0;
            chatMessages.add({
              'sender': 'bot',
              'text': currentStateData['fields'][0]['prompt'],
            });
          });
        }
      } else {
        _showError('Please select 1 to upload previous policy or 2 to skip.');
      }
    } else if (currentState == 'pdf_policy') {
      setState(() {
        currentState = 'pdf_filling_continue';
        currentStateData = chatbotTemplate['states'][currentState];
        currentStateData['fields'] = fields.keys
            .map(
              (key) => {
                'name': key,
                'prompt': 'Please enter your $key for the form:',
              },
            )
            .toList();
        currentFieldIndex = 0;
        chatMessages.add({
          'sender': 'bot',
          'text': currentStateData['fields'][0]['prompt'],
        });
      });
    } else if (currentState == 'pdf_filling_continue') {
      var fieldsList = currentStateData['fields'];
      if (currentFieldIndex < fieldsList.length) {
        var field = fieldsList[currentFieldIndex];
        String fieldName = field['name'];
        String? error = fields[fieldName]!.validator!(input);

        if (error == null) {
          formResponses[fieldName] = input;
          currentFieldIndex++;
          if (currentFieldIndex < fieldsList.length) {
            setState(() {
              chatMessages.add({
                'sender': 'bot',
                'text': fieldsList[currentFieldIndex]['prompt'],
              });
            });
          } else {
            String summary = formResponses.entries
                .map((e) => '${e.key}: ${e.value}')
                .join('\n');
            setState(() {
              currentState = 'pdf_summary';
              chatMessages.add({
                'sender': 'bot',
                'text': currentStateData['next']['message'].replaceAll(
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
    } else if (currentState == 'pdf_missing_fields') {
      final missingFields = formResponses['missing_fields']!.split(',');
      final currentIndex = int.parse(
        formResponses['current_missing_field_index']!,
      );
      final templateKey = 'default';
      final template = cachedPdfTemplates[templateKey];
      final fieldDef = template!.fields[missingFields[currentIndex]]!;
      final error = fieldDef.validator!(input);

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
          File? filledPdf = await _fillPdfTemplate(
            templateKey,
            formResponses,
            cachedPdfTemplates,
            insuranceType!,
            context,
          );
          if (filledPdf != null && await _previewPdf(filledPdf)) {
            await _sendEmail(
              'companyA',
              formResponses['insurance_type']?.toLowerCase() ?? 'auto',
              formResponses['subtype'] ?? 'comprehensive',
              formResponses,
              filledPdf,
            );
          }
          setState(() {
            currentState = 'pdf_process';
            chatMessages.add({
              'sender': 'bot',
              'text': chatbotTemplate['states'][currentState]['message'],
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
    } else if (currentState == 'pdf_summary') {
      int? choice = int.tryParse(input);
      if (choice == 1) {
        File? filledPdf = await _fillPdfTemplate(
          'default',
          formResponses,
          cachedPdfTemplates,
          insuranceType!,
          context,
        );
        if (filledPdf != null && await _previewPdf(filledPdf)) {
          await _sendEmail(
            'companyA',
            formResponses['insurance_type']?.toLowerCase() ?? 'auto',
            formResponses['subtype'] ?? 'comprehensive',
            formResponses,
            filledPdf,
          );
        }
        setState(() {
          currentState = 'pdf_process';
          chatMessages.add({
            'sender': 'bot',
            'text': chatbotTemplate['states'][currentState]['message'],
          });
        });
      } else if (choice == 2) {
        setState(() {
          currentState = 'pdf_filling';
          currentStateData = chatbotTemplate['states'][currentState];
          currentStateData['fields'] = fields.keys
              .map(
                (key) => {
                  'name': key,
                  'prompt': 'Please enter your $key for the form:',
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
        _showError('Please select 1 for Yes or 2 for No.');
      }
    } else if (currentState == 'view_policies') {
      String policiesSummary = policies.isEmpty
          ? 'No policies found.'
          : policies
              .asMap()
              .entries
              .map(
                (e) =>
                    '${e.key + 1}. ${e.value.type} (${e.value.subtype}) - ${e.value.status}',
              )
              .join('\n');
      setState(() {
        currentState = 'start';
        chatMessages.add({
          'sender': 'bot',
          'text': 'Your policies:\n$policiesSummary\n\n' +
              chatbotTemplate['states'][currentState]['message'] +
              '\n' +
              chatbotTemplate['states'][currentState]['options']
                  .asMap()
                  .entries
                  .map((e) => '${e.key + 1}. ${e.value['text']}')
                  .join('\n'),
        });
      });
    } else {
      _showError('Invalid state or input. Please try again.');
    }

    chatController.clear();
  }

  void _showError(String message) {
    setState(() {
      chatMessages.add({'sender': 'bot', 'text': message});
    });
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
        companies = (jsonDecode(data) as List)
            .map((c) => Company.fromJson(c))
            .cast<Quote>()
            .toList();
      });
    }
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
    final policyTypes = {
      'motor': [
        'commercial',
        'psv',
        'psv_uber',
        'private',
        'tuk_tuk',
        'special_classes'
      ],
      'medical': ['individual', 'corporate'],
      'travel': ['single_trip', 'multi_trip', 'student', 'senior_citizen'],
      'property': ['residential', 'commercial', 'industrial', 'landlord'],
      'wiba': ['standard', 'enhanced', 'contractor', 'small_business'],
    };

    return Consumer2<ColorProvider, DialogState>(
      builder: (context, colorProvider, dialogState, _) {
        final dialogCount = dialogState.responses['insurance_type'] != null
            ? dialogRegistry[dialogState.responses['insurance_type']]?.length ??
                1
            : 1;
        final dialogIndex = dialogState.responses['dialog_index'] != null
            ? int.tryParse(dialogState.responses['dialog_index'] ?? '0') ?? 0
            : 0;

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
                      onPressed: () => Navigator.pushNamed(context, '/admin'),
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
                      if (dialogState.responses['insurance_type'] != null) {
                        dialogState.saveProgress(
                          dialogState.responses['insurance_type']!,
                          dialogIndex,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Progress saved')));
                      }
                    },
                    tooltip: 'Save progress',
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: colorProvider.color),
                    onPressed: () async {
                      final resumed = await dialogState.resumeProgress(context);
                      if (!resumed) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('No saved progress found')));
                      }
                    },
                    tooltip: 'Resume progress',
                  ),
                  IconButton(
                    icon: Icon(Icons.clear, color: colorProvider.color),
                    onPressed: () async {
                      await dialogState.clearProgress();
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Progress cleared')));
                    },
                    tooltip: 'Clear progress',
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
                      autoPlayInterval: Duration(seconds: 3),
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
                        margin: EdgeInsets.symmetric(horizontal: 5.0),
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
                  SizedBox(height: 16),
                  if (dialogState.responses['insurance_type'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: LinearProgressIndicator(
                        value: (dialogIndex + 1) / dialogCount,
                        backgroundColor: blueGreen.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(orange),
                        semanticsLabel:
                            'Progress: ${(dialogIndex + 1) / dialogCount * 100}%',
                      ),
                    ),
                  SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Select Your Insurance Cover',
                      style: GoogleFonts.lora(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B263B),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: policyTypes.keys.length,
                    itemBuilder: (context, index) {
                      final type = policyTypes.keys.toList()[index];
                      return GestureDetector(
                        onTap: () {
                          colorProvider.setColor(orange);
                          showCoverDialog(context, type, 0);
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
                                getIcon(type),
                                size: 40,
                                color: colorProvider.color,
                              ),
                              SizedBox(height: 8),
                              Text(
                                type.toUpperCase(),
                                style: GoogleFonts.roboto(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1B263B),
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
        bool isDesktop = constraints.maxWidth > 800; // Landscape check for desktop

        return Row(
          children: [
            // Left side: AppBar-like Navigation Drawer for desktop, nothing for mobile
            if (isDesktop)
              Container(
                width: 250,
                color: Colors.blueGrey,
                child: Column(
                  children: [
                    SizedBox(height: 50), // Padding
                    ListTile(
                      leading: Icon(Icons.home, size: 30), // Increased icon size
                      title: Text("Home"),
                      onTap: () => _onItemTapped(0),
                    ),
                    ListTile(
                      leading: Icon(Icons.request_quote, size: 30), // Increased icon size
                      title: Text("Quotes"),
                      onTap: () => _onItemTapped(1),
                    ),
                    ListTile(
                      leading: Icon(Icons.hourglass_bottom_outlined, size: 30), // Increased icon size
                      title: Text("Upcoming"),
                      onTap: () => _onItemTapped(2),
                    ),
                    ListTile(
                      leading: Icon(Icons.account_circle, size: 30), // Increased icon size
                      title: Text("My Account"),
                      onTap: () => _onItemTapped(3),
                    ),
                    if (userRole == UserRole.admin)
                      ListTile(
                        leading: Icon(Icons.admin_panel_settings, size: 30), // Increased icon size
                        title: Text("Admin Panel"),
                        onTap: () => Navigator.pushNamed(context, '/admin'),
                      ),
                  ],
                ),
              ),
            // Main content (middle) - Displays the selected screen
            Expanded(child: _getSelectedScreen()),
            // Right side: Trending topics and Blogs for desktop
            if (isDesktop)
              Container(
                width: 250,
                padding: EdgeInsets.all(16),
                color: Colors.grey[200],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Trending in Insurance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    trendingTopics.isNotEmpty
                        ? ListView.builder(
                            shrinkWrap: true,
                            itemCount: trendingTopics.length,
                            itemBuilder: (context, index) {
                              return ListTile(title: Text(trendingTopics[index]));
                            },
                          )
                        : Center(child: CircularProgressIndicator()),

                    SizedBox(height: 20),
                    Text("Learn more about Insurance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    blogPosts.isNotEmpty
                        ? ListView.builder(
                            shrinkWrap: true,
                            itemCount: blogPosts.length,
                            itemBuilder: (context, index) {
                              return ListTile(title: Text(blogPosts[index]));
                            },
                          )
                        : Center(child: CircularProgressIndicator()),
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
            child: const Icon(Icons.chat, size: 30), // Increased icon size
          )
        : null,
    appBar: kIsWeb
        ? AppBar(
            title: const Text('BIMA GUARDIAN'),
            actions: [
              IconButton(
                icon: const Icon(Icons.home, size: 20), // Increased icon size
                onPressed: () => _onItemTapped(0),
                tooltip: 'Home',
              ),
              IconButton(
                icon: const Icon(Icons.request_quote, size: 20), // Increased icon size
                onPressed: () => _onItemTapped(1),
                tooltip: 'Quotes',
              ),
              IconButton(
                icon: const Icon(Icons.hourglass_bottom_outlined, size: 20), // Increased icon size
                onPressed: () => _onItemTapped(2),
                tooltip: 'Upcoming',
              ),
              IconButton(
                icon: const Icon(Icons.account_circle, size: 20), // Increased icon size
                onPressed: () => _onItemTapped(3),
                tooltip: 'My Account',
              ),
              if (userRole == UserRole.admin)
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings, size: 20), // Increased icon size
                  onPressed: () => Navigator.pushNamed(context, '/admin'),
                  tooltip: 'Admin Panel',
                ),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, size: 20), // Increased icon size
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
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${notifications.length}',
                          style: const TextStyle(
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
                icon: Icon(Icons.home, size: 30), // Increased icon size
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.request_quote, size: 30), // Increased icon size
                label: 'Quotes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.hourglass_bottom_outlined, size: 30), // Increased icon size
                label: 'Upcoming',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_circle, size: 30), // Increased icon size
                label: 'My Account',
              ),
            ],
          ),
  );
}
  

  // Helper to get field map based on insurance type
  Map<String, FieldDefinition> _getFieldMap(String type) {
    switch (type) {
      case 'motor':
        return motorFields;
      case 'medical':
        return medicalFields;
      case 'travel':
        return travelFields;
      case 'property':
        return propertyFields;
      case 'wiba':
        return wibaFields;
      default:
        return motorFields; // Fallback
    }
  }

  void _showChatBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chat with Us',
                      style: GoogleFonts.lora(
                        color: Color(0xFF1B263B),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Color(0xFFD3D3D3),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 400, // Fixed height to prevent overflow
                child: ListView.builder(
                  itemCount: chatMessages.length,
                  itemBuilder: (context, index) {
                    final message = chatMessages[index];
                    return ListTile(
                      title: Text(
                        message['text']!,
                        style: GoogleFonts.roboto(
                          color: message['text']!.contains('Nearing Expiration')
                              ? Colors.yellow[800]
                              : message['text']!.contains('Expired')
                                  ? Color(0xFF8B0000)
                                  : Color(0xFF1B263B),
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        message['sender'] == 'bot' ? 'Bot' : 'You',
                        style: GoogleFonts.roboto(
                          color: Color(0xFFD3D3D3),
                          fontSize: 12,
                        ),
                      ),
                      tileColor: message['sender'] == 'bot'
                          ? Color(0xFFD3D3D3).withOpacity(0.2)
                          : Colors.white,
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8.0),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: chatController,
                        decoration: InputDecoration(
                          hintText: 'Type your message...',
                          hintStyle: GoogleFonts.roboto(
                            color: Color(0xFFD3D3D3),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Color(0xFFD3D3D3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Color(0xFFD3D3D3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Color(0xFF8B0000),
                            ),
                          ),
                        ),
                        style: GoogleFonts.roboto(
                          color: Color(0xFF1B263B),
                        ),
                        onSubmitted: (value) {
                          _handleChatInput(value);
                          chatController.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.send,
                        color: Color(0xFF8B0000),
                      ),
                      onPressed: () {
                        _handleChatInput(chatController.text);
                        chatController.clear();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showInsuredItemDialog(
    BuildContext context,
    String type,
    String subtype,
    String coverageType,
  ) {
    String? insuredItemId;
    bool createNew = insuredItems.isEmpty;
    Map<String, FieldDefinition> fields = _getFieldMap(type);

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
                'Select or Create Insured Item',
                style: GoogleFonts.lora(
                  color: Color(0xFF1B263B),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!createNew)
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Existing Insured Item',
                        labelStyle:
                            GoogleFonts.roboto(color: Color(0xFFD3D3D3)),
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
                      value: insuredItemId,
                      items: insuredItems
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                '${item.details['name'] ?? 'Item'} (${item.type.toUpperCase()})',
                                style: GoogleFonts.roboto(
                                    color: Color(0xFF1B263B)),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => insuredItemId = value),
                    ),
                  if (!createNew)
                    CheckboxListTile(
                      title: Text(
                        'Create New Insured Item',
                        style: GoogleFonts.roboto(color: Color(0xFF1B263B)),
                      ),
                      value: createNew,
                      onChanged: (value) =>
                          setDialogState(() => createNew = value ?? false),
                      activeColor: Color(0xFF8B0000),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CoverDetailScreen(
                          type: type,
                          subtype: subtype,
                          coverageType: coverageType,
                          insuredItem: insuredItemId != null
                              ? insuredItems.firstWhere(
                                  (item) => item.id == insuredItemId,
                                )
                              : null,
                          fields: fields,
                          onSubmit: (details) => _showCompanyDialog(
                            context,
                            type,
                            subtype,
                            coverageType,
                            details,
                          ),
                          onAutofillPreviousPolicy:
                              autofillFromPreviousPolicy, // Now compatible
                          onAutofillLogbook:
                              autofillFromLogbook, // New callback
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
                  child: Text(
                    'Next',
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

  Future<void> _handleCoverSubmission(
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
        insuredItem = insuredItems.firstWhere(
          (item) => item.id == details['insured_item_id'],
          orElse: () => throw Exception('Insured item not found'),
        );
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
        setState(() {
          insuredItems.add(insuredItem);
        });
        await _saveInsuredItems();
      }

      // Calculate premium
      double premium = await _calculatePremium(type, subtype, details);

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

      setState(() {
        covers.add(cover);
      });
      await _saveCovers();

      // Handle PDF generation
      File? pdfFile;
      if (cachedPdfTemplates.isNotEmpty &&
          cachedPdfTemplates.containsKey(pdfTemplateKey)) {
        pdfFile = await _fillPdfTemplate(
          pdfTemplateKey,
          details,
          cachedPdfTemplates,
          type,
          context,
        );
        if (pdfFile != null && await _previewPdf(pdfFile)) {
          await _sendEmail(companyId, type, subtype, details, pdfFile);
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
        // Optionally, generate a fallback PDF
        pdfFile = await _generateFallbackPdf(type, subtype, details);
        if (pdfFile != null) {
          await _sendEmail(companyId, type, subtype, details, pdfFile);
        }
      }

      // Initialize payment
      final paymentStatus = await _initializePayment(
        cover.id,
        premium.toString(),
      );

      // Update cover status
      setState(() {
        final index = covers.indexWhere((c) => c.id == cover.id);
        covers[index] = cover.copyWith(
          status: paymentStatus == 'completed'
              ? CoverStatus.active
              : CoverStatus.pending,
          paymentStatus: paymentStatus,
        );
      });
      await _saveCovers();

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
class DialogState with ChangeNotifier {
  static const formResponses = {};
  Map<String, String> _responses = Map.from(formResponses);

  Map<String, String> get responses => _responses;

  void updateResponse(String key, String value) {
    _responses[key] = value;
    notifyListeners();
  }

  void clearResponses() {
    _responses.clear();
    notifyListeners();
  }

  Future<void> saveProgress(String insuranceType, int dialogIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('insurance_type', insuranceType);
      await prefs.setInt('dialog_index', dialogIndex);
      await prefs.setStringList('response_keys', _responses.keys.toList());
      await prefs.setStringList('response_values', _responses.values.toList());
    } catch (e) {
      print('Error saving progress: $e');
    }
  }

  Future<bool> resumeProgress(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final insuranceType = prefs.getString('insurance_type');
      final dialogIndex = prefs.getInt('dialog_index');
      final keys = prefs.getStringList('response_keys');
      final values = prefs.getStringList('response_values');
      if (insuranceType != null &&
          dialogIndex != null &&
          keys != null &&
          values != null &&
          keys.length == values.length) {
        _responses = Map.fromEntries(
            keys.asMap().entries.map((e) => MapEntry(e.value, values[e.key])));
        notifyListeners();
        showCoverDialog(context, insuranceType, dialogIndex);
        return true;
      }
      return false;
    } catch (e) {
      print('Error resuming progress: $e');
      return false;
    }
  }

  Future<void> clearProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('insurance_type');
      await prefs.remove('dialog_index');
      await prefs.remove('response_keys');
      await prefs.remove('response_values');
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing progress: $e');
      }
    }
  }
}

// Dialog configuration
class CoverDialogConfig {
  final String title;
  final List<String>? gridOptions;
  final String? gridResponseKey;
  final String? gridSemanticsPrefix;
  final List<Map<String, dynamic>>? formFields;
  final bool Function(Map<String, String>)? customValidator;
  final void Function(BuildContext, Map<String, String>)? onSubmit;
  final String Function(Map<String, String>)? nextDialog;
  final String submitButtonText;
  final List<Widget> Function(BuildContext, DialogState)?
      additionalContentBuilder;
  final void Function(BuildContext)? onValidationError;

  CoverDialogConfig({
    required this.title,
    this.gridOptions,
    this.gridResponseKey,
    this.gridSemanticsPrefix,
    this.formFields,
    this.customValidator,
    this.onSubmit,
    this.nextDialog,
    this.submitButtonText = 'Next',
    this.additionalContentBuilder,
    this.onValidationError,
  });
}

const List<String> _vehicleTypes = [
  'Private',
  'Commercial',
  'PSV',
  'Motorcycle',
  'Tuk Tuk',
  'Special Classes',
];

const List<String> _inpatientLimits = [
  'KES 500,000',
  'KES 1,000,000',
  'KES 2,000,000',
  'KES 3,000,000',
  'KES 4,000,000',
  'KES 5,000,000',
  'KES 10,000,000',
];

const List<String> _medicalServices = [
  'Outpatient',
  'Dental & Optical',
  'Maternity',
];

const List<String> _underwriters = [
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

final Map<String, FieldDefinition> homeFields = {
  'name': FieldDefinition(
    expectedType: ExpectedType.name,
    validator: (value) {
      if (value.isEmpty) return null;
      return RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
          ? null
          : 'Invalid name';
    },
  ),
  'email': FieldDefinition(
    expectedType: ExpectedType.email,
    validator: (value) {
      if (value.isEmpty) return null;
      return RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
              .hasMatch(value)
          ? null
          : 'Invalid email';
    },
  ),
  'phone': FieldDefinition(
    expectedType: ExpectedType.phone,
    validator: (value) {
      if (value.isEmpty) return null;
      return RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)
          ? null
          : 'Invalid phone number';
    },
  ),
  'value': FieldDefinition(
    expectedType: ExpectedType.number,
    validator: (value) {
      if (value.isEmpty) return null;
      double? val = double.tryParse(value);
      return val != null && val > 0 ? null : 'Invalid property value';
    },
  ),
  'location': FieldDefinition(
    expectedType: ExpectedType.text,
    validator: (value) {
      if (value.isEmpty) return null;
      return RegExp(r'^[A-Za-z0-9\s\,\.\-]+$').hasMatch(value)
          ? null
          : 'Invalid location (use letters, numbers, commas, or periods)';
    },
  ),
};

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
            RegExp(
              r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
            ).hasMatch(value)
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
            RegExp(
              r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
            ).hasMatch(value)
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
      'retail',
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
            RegExp(
              r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
            ).hasMatch(value)
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
      'landlord',
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
    validator: (value) {
      if (value.isEmpty) return null;
      return RegExp(r'^[A-Za-z\s\-\.]+$').hasMatch(value)
          ? null
          : 'Invalid name';
    },
  ),
  'email': FieldDefinition(
    expectedType: ExpectedType.email,
    validator: (value) {
      if (value.isEmpty) return null;
      return RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
              .hasMatch(value)
          ? null
          : 'Invalid email';
    },
  ),
  'phone': FieldDefinition(
    expectedType: ExpectedType.phone,
    validator: (value) {
      if (value.isEmpty) return null;
      return RegExp(r'^[+\d\s\-\(\)]{8,15}$').hasMatch(value)
          ? null
          : 'Invalid phone number';
    },
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
    validator: (value) => null, // Optional free-text field
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
    validator: (value) {
      if (value.isEmpty) return null;
      return _inpatientLimits.contains(value)
          ? null
          : 'Invalid inpatient limit';
    },
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
    expectedType: ExpectedType.text,
    validator: (value) {
      if (value.isEmpty) return null;
      var services = value.split(', ').map((s) => s.trim()).toList();
      return services.every((s) => _medicalServices.contains(s))
          ? null
          : 'Invalid medical services';
    },
  ),
  'underwriters': FieldDefinition(
    expectedType: ExpectedType.text,
    validator: (value) {
      if (value.isEmpty) return null;
      var selected = value.split(', ').map((s) => s.trim()).toList();
      return selected.length <= 3 &&
              selected.every((s) => _underwriters.contains(s))
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
            RegExp(
              r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
            ).hasMatch(value)
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
    validator: (value) =>
        _vehicleTypes.contains(value) ? null : 'Invalid vehicle type',
  ),
};

final Map<String, List<CoverDialogConfig>> dialogRegistry = {
  'motor': [
    CoverDialogConfig(
      title: 'Select Motor Subtype',
      gridOptions: [
        'commercial',
        'psv',
        'psv_uber',
        'private',
        'tuk_tuk',
        'special_classes'
      ],
      gridResponseKey: 'subtype',
      gridSemanticsPrefix: 'Motor Subtype',
      submitButtonText: 'Next',
      nextDialog: (responses) => 'coverage_type',
    ),
    CoverDialogConfig(
      title: 'Select Coverage Type',
      gridOptions: ['comprehensive', 'third_party'],
      gridResponseKey: 'coverage_type',
      gridSemanticsPrefix: 'Coverage Type',
      submitButtonText: 'Next',
      nextDialog: (responses) => 'insured_item',
    ),
  ],
  'medical': [
    CoverDialogConfig(
      title: 'Select Medical Subtype',
      gridOptions: ['individual', 'corporate', 'family'],
      gridResponseKey: 'subtype',
      gridSemanticsPrefix: 'Medical Subtype',
      submitButtonText: 'Next',
      formFields: [
        {
          'key': 'beneficiaries',
          'label': 'Number of Beneficiaries (Min 3)',
          'keyboardType': TextInputType.number,
          'validator': (value) =>
              medicalFields['beneficiaries']!.validator!(value ?? ''),
          'condition': (responses) => responses['subtype'] == 'corporate',
        },
      ],
      customValidator: (responses) =>
          responses['subtype'] != 'corporate' ||
          (int.tryParse(responses['beneficiaries'] ?? '') ?? 0) >= 3,
      onValidationError: (context) =>
          ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Corporate policies require at least 3 beneficiaries'),
        ),
      ),
      nextDialog: (responses) => responses['subtype'] == 'corporate'
          ? 'corporate_coverage'
          : 'coverage_options',
    ),
    CoverDialogConfig(
      title: 'Select Coverage Options for Individual/Family',
      gridOptions: _inpatientLimits,
      gridResponseKey: 'inpatient_limit',
      gridSemanticsPrefix: 'Inpatient Limit',
      submitButtonText: 'Next',
      nextDialog: (responses) => 'personal_info',
    ),
    CoverDialogConfig(
      title: 'Enter Personal and Family Information',
      submitButtonText: 'Next',
      formFields: [
        {
          'key': 'name',
          'label': 'Name',
          'validator': (value) =>
              medicalFields['name']!.validator!(value ?? ''),
        },
        {
          'key': 'email',
          'label': 'Email',
          'keyboardType': TextInputType.emailAddress,
          'validator': (value) =>
              medicalFields['email']!.validator!(value ?? ''),
        },
        {
          'key': 'phone',
          'label': 'Phone Number',
          'keyboardType': TextInputType.phone,
          'validator': (value) =>
              medicalFields['phone']!.validator!(value ?? ''),
        },
        {
          'key': 'age',
          'label': 'Client Age',
          'keyboardType': TextInputType.number,
          'validator': (value) => medicalFields['age']!.validator!(value ?? ''),
        },
        {
          'key': 'pre_existing_conditions',
          'label': 'Pre-existing Conditions (Enter none if none)',
          'validator': (value) =>
              medicalFields['pre_existing_conditions']!.validator!(value ?? ''),
        },
      ],
      additionalContentBuilder: (context, state) {
        state.responses['has_spouse'] ??= 'No';
        state.responses['has_children'] ??= 'No';
        return [
          CheckboxListTile(
            title: Text('Has Spouse', style: GoogleFonts.roboto()),
            value: state.responses['has_spouse'] == 'Yes',
            onChanged: (value) {
              state.updateResponse('has_spouse', value == true ? 'Yes' : 'No');
              if (!value!) state.updateResponse('spouse_age', '');
            },
            activeColor: const Color(0xFF26A69A),
          ),
          if (state.responses['has_spouse'] == 'Yes')
            DynamicForm(
              formKey: GlobalKey<FormState>(),
              fields: [
                {
                  'key': 'spouse_age',
                  'label': 'Spouse Age',
                  'keyboardType': TextInputType.number,
                  'validator': (value) =>
                      medicalFields['spouse_age']!.validator!(value ?? ''),
                },
              ],
              responses: state.responses,
              onFieldChanged: state.updateResponse,
            ),
          CheckboxListTile(
            title: Text('Has Children', style: GoogleFonts.roboto()),
            value: state.responses['has_children'] == 'Yes',
            onChanged: (value) {
              state.updateResponse(
                  'has_children', value == true ? 'Yes' : 'No');
              if (!value!) state.updateResponse('children_count', '');
            },
            activeColor: const Color(0xFF26A69A),
          ),
          if (state.responses['has_children'] == 'Yes')
            DynamicForm(
              formKey: GlobalKey<FormState>(),
              fields: [
                {
                  'key': 'children_count',
                  'label': 'Number of Children',
                  'keyboardType': TextInputType.number,
                  'validator': (value) =>
                      medicalFields['children_count']!.validator!(value ?? ''),
                },
              ],
              responses: state.responses,
              onFieldChanged: state.updateResponse,
            ),
        ];
      },
      nextDialog: (responses) => 'insured_item',
    ),
    CoverDialogConfig(
      title: 'Enter Corporate Coverage Details',
      submitButtonText: 'Next',
      formFields: [
        {
          'key': 'inpatient_limit',
          'label': 'Inpatient Limit (KES)',
          'keyboardType': TextInputType.number,
          'validator': (value) {
            if (value.isEmpty) return 'Required';
            double? val = double.tryParse(value);
            return val != null && val > 0 ? null : 'Invalid limit';
          },
        },
        {
          'key': 'outpatient_limit',
          'label': 'Outpatient Limit (KES)',
          'keyboardType': TextInputType.number,
          'validator': (value) {
            if (value.isEmpty) return 'Required';
            double? val = double.tryParse(value);
            return val != null && val > 0 ? null : 'Invalid limit';
          },
        },
        {
          'key': 'dental_limit',
          'label': 'Dental Limit (KES)',
          'keyboardType': TextInputType.number,
          'validator': (value) {
            if (value.isEmpty) return 'Required';
            double? val = double.tryParse(value);
            return val != null && val > 0 ? null : 'Invalid limit';
          },
        },
        {
          'key': 'optical_limit',
          'label': 'Optical Limit (KES)',
          'keyboardType': TextInputType.number,
          'validator': (value) {
            if (value.isEmpty) return 'Required';
            double? val = double.tryParse(value);
            return val != null && val > 0 ? null : 'Invalid limit';
          },
        },
        {
          'key': 'maternity_limit',
          'label': 'Maternity Limit (KES)',
          'keyboardType': TextInputType.number,
          'validator': (value) {
            if (value.isEmpty) return 'Required';
            double? val = double.tryParse(value);
            return val != null && val > 0 ? null : 'Invalid limit';
          },
        },
        {
          'key': 'preferred_underwriters',
          'label': 'Preferred Underwriters (comma-separated)',
          'validator': (value) {
            if (value.isEmpty) return 'Required';
            var selected = value.split(',').map((s) => s.trim()).toList();
            return selected.every((s) => _underwriters.contains(s))
                ? null
                : 'Invalid underwriters';
          },
        },
      ],
      nextDialog: (responses) => 'insured_item',
    ),
  ],
  'travel': [
    CoverDialogConfig(
      title: 'Select Travel Subtype',
      gridOptions: ['single_trip', 'multi_trip', 'student', 'senior_citizen'],
      gridResponseKey: 'subtype',
      gridSemanticsPrefix: 'Travel Subtype',
      submitButtonText: 'Next',
      nextDialog: (responses) => 'coverage_details',
    ),
    CoverDialogConfig(
      title: 'Travel Coverage Details',
      submitButtonText: 'Next',
      formFields: [
        {
          'key': 'destination',
          'label': 'Destination',
          'validator': (value) =>
              travelFields['destination']!.validator!(value ?? ''),
        },
        {
          'key': 'travel_start_date',
          'label': 'Travel Start Date (YYYY-MM-DD)',
          'validator': (value) =>
              travelFields['travel_start_date']!.validator!(value ?? ''),
        },
        {
          'key': 'travel_end_date',
          'label': 'Travel End Date (YYYY-MM-DD)',
          'validator': (value) =>
              travelFields['travel_end_date']!.validator!(value ?? ''),
        },
        {
          'key': 'number_of_travelers',
          'label': 'Number of Travelers',
          'keyboardType': TextInputType.number,
          'validator': (value) =>
              travelFields['number_of_travelers']!.validator!(value ?? ''),
        },
        {
          'key': 'coverage_limit',
          'label': 'Coverage Limit (KES)',
          'keyboardType': TextInputType.number,
          'validator': (value) =>
              travelFields['coverage_limit']!.validator!(value ?? ''),
        },
      ],
      nextDialog: (responses) => 'insured_item',
    ),
  ],
  'property': [
    CoverDialogConfig(
      title: 'Select Property Subtype',
      gridOptions: ['residential', 'commercial', 'industrial', 'landlord'],
      gridResponseKey: 'subtype',
      gridSemanticsPrefix: 'Property Subtype',
      submitButtonText: 'Next',
      nextDialog: (responses) => 'coverage_details',
    ),
    CoverDialogConfig(
      title: 'Property Coverage Details',
      submitButtonText: 'Next',
      formFields: [
        {
          'key': 'property_value',
          'label': 'Property Value (KES)',
          'keyboardType': TextInputType.number,
          'validator': (value) =>
              propertyFields['property_value']!.validator!(value ?? ''),
        },
        {
          'key': 'property_location',
          'label': 'Property Location',
          'validator': (value) =>
              propertyFields['property_location']!.validator!(value ?? ''),
        },
        {
          'key': 'deed_number',
          'label': 'Deed Number',
          'validator': (value) =>
              propertyFields['deed_number']!.validator!(value ?? ''),
        },
        {
          'key': 'construction_year',
          'label': 'Construction Year',
          'keyboardType': TextInputType.number,
          'validator': (value) =>
              propertyFields['construction_year']!.validator!(value ?? ''),
        },
      ],
      nextDialog: (responses) => 'insured_item',
    ),
  ],
  'wiba': [
    CoverDialogConfig(
      title: 'Select WIBA Subtype',
      gridOptions: ['standard', 'enhanced', 'contractor', 'small_business'],
      gridResponseKey: 'subtype',
      gridSemanticsPrefix: 'WIBA Subtype',
      submitButtonText: 'Next',
      nextDialog: (responses) => 'coverage_details',
    ),
    CoverDialogConfig(
      title: 'WIBA Coverage Details',
      submitButtonText: 'Next',
      formFields: [
        {
          'key': 'business_name',
          'label': 'Business Name',
          'validator': (value) =>
              wibaFields['business_name']!.validator!(value ?? ''),
        },
        {
          'key': 'number_of_employees',
          'label': 'Number of Employees',
          'keyboardType': TextInputType.number,
          'validator': (value) =>
              wibaFields['number_of_employees']!.validator!(value ?? ''),
        },
        {
          'key': 'coverage_limit',
          'label': 'Coverage Limit (KES)',
          'keyboardType': TextInputType.number,
          'validator': (value) =>
              wibaFields['coverage_limit']!.validator!(value ?? ''),
        },
      ],
      gridOptions: ['construction', 'manufacturing', 'services', 'retail'],
      gridResponseKey: 'industry_type',
      gridSemanticsPrefix: 'Industry Type',
      nextDialog: (responses) => 'insured_item',
    ),
  ],
};

// Generic dialog widget with progress indicator
class GenericDialog extends StatefulWidget {
  final String title;
  final Widget content;
  final VoidCallback onSubmit;
  final String submitButtonText;
  final String insuranceType;
  final int dialogIndex;

  const GenericDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onSubmit,
    this.submitButtonText = 'Next',
    required this.insuranceType,
    required this.dialogIndex,
  });

  @override
  _GenericDialogState createState() => _GenericDialogState();
}

class _GenericDialogState extends State<GenericDialog> {
  bool _isLoading = false;
  static const Color blueGreen = Color(0xFF26A69A);
  static const Color orange = Color(0xFFFFA726);

  void _handleSubmit() async {
    setState(() => _isLoading = true);
    try {
      if (kDebugMode) {
        print(
            'Next button pressed for ${widget.title}, dialogIndex: ${widget.dialogIndex}');
      }
      widget.onSubmit();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dialogCount = dialogRegistry[widget.insuranceType]?.length ?? 1;
    if (kDebugMode) {
      print(
          'Rendering GenericDialog: ${widget.title}, dialogIndex: ${widget.dialogIndex}');
    }
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Stack(
              children: [
                Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: AppBar(
                    title: Text(
                      widget.title,
                      style: GoogleFonts.lora(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1B263B),
                      ),
                    ),
                    leading: widget.dialogIndex > 0
                        ? IconButton(
                            icon: Icon(Icons.arrow_back,
                                color: context.watch<ColorProvider>().color),
                            onPressed: () {
                              if (kDebugMode) {
                                print(
                                    'Back button pressed for ${widget.title}');
                              }
                              showCoverDialog(context, widget.insuranceType,
                                  widget.dialogIndex - 1);
                            },
                            tooltip: 'Back',
                          )
                        : null,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    actions: [
                      IconButton(
                        icon: Icon(Icons.save,
                            color: context.watch<ColorProvider>().color),
                        onPressed: () {
                          if (kDebugMode) {
                            print('Save button pressed for ${widget.title}');
                          }
                          context.read<DialogState>().saveProgress(
                              widget.insuranceType, widget.dialogIndex);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Progress saved')),
                            );
                          }
                        },
                        tooltip: 'Save progress',
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            color: context.watch<ColorProvider>().color),
                        onPressed: () {
                          if (kDebugMode) {
                            print('Close button pressed for ${widget.title}');
                          }
                          Navigator.pop(context);
                        },
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  body: SafeArea(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: 16 +
                              MediaQuery.of(context).viewInsets.bottom +
                              80,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            widget.content,
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 48, // Fixed height for buttons
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: TextButton(
                                      onPressed: () {
                                        if (kDebugMode) {
                                          print(
                                              'Cancel button pressed for ${widget.title}');
                                        }
                                        Navigator.pop(context);
                                      },
                                      child: Text(
                                        'Cancel',
                                        style: GoogleFonts.roboto(
                                            color: context
                                                .watch<ColorProvider>()
                                                .color),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: ElevatedButton(
                                      onPressed:
                                          _isLoading ? null : _handleSubmit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: context
                                            .watch<ColorProvider>()
                                            .color,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        minimumSize: const Size(100, 40),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              widget.submitButtonText,
                                              style: GoogleFonts.roboto(
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  bottomNavigationBar: LinearProgressIndicator(
                    value: (widget.dialogIndex + 1) / dialogCount,
                    backgroundColor: blueGreen.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(orange),
                    minHeight: 8,
                    semanticsLabel:
                        'Progress: ${((widget.dialogIndex + 1) / dialogCount * 100).toStringAsFixed(0)}%',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Reusable parallax grid widget
class ParallaxGrid extends StatelessWidget {
  final List<String> options;
  final String selectedOption;
  final Function(String) onOptionSelected;
  final String semanticsPrefix;
  static const Color blueGreen = Color(0xFF26A69A);
  static const Color orange = Color(0xFFFFA726);

  IconData getIcon(String option) {
    option = option.toLowerCase();
    if (kDebugMode) {
      print('Assigning icon for option: $option');
    }
    if (option == 'individual') return Icons.person_outlined;
    if (option == 'corporate') return Icons.business_outlined;
    if (option == 'family') return Icons.group_outlined;
    if (option.contains('private')) return Icons.directions_car_outlined;
    if (option.contains('commercial')) return Icons.local_shipping_outlined;
    if (option.contains('psv') || option.contains('psv_uber')) {
      return Icons.directions_bus_outlined;
    }
    if (option.contains('tuk_tuk')) return Icons.two_wheeler_outlined;
    if (option.contains('special_classes')) {
      return Icons.directions_car_filled_outlined;
    }
    if (option.contains('single_trip')) return Icons.flight_outlined;
    if (option.contains('multi_trip')) return Icons.flight_takeoff_outlined;
    if (option.contains('student')) return Icons.school_outlined;
    if (option.contains('senior_citizen')) return Icons.elderly_outlined;
    if (option.contains('residential') ||
        option.contains('home') ||
        option.contains('house')) {
      return Icons.home_outlined;
    }
    if (option.contains('commercial_property') ||
        option.contains('commercial')) {
      return Icons.storefront_outlined;
    }
    if (option.contains('industrial')) return Icons.factory_outlined;
    if (option.contains('landlord')) return Icons.real_estate_agent_outlined;
    if (option.contains('standard')) return Icons.work_outline;
    if (option.contains('enhanced')) return Icons.security_outlined;
    if (option.contains('contractor')) return Icons.construction_outlined;
    if (option.contains('small_business')) return Icons.store_outlined;
    if (option.contains('apartment')) return Icons.apartment_outlined;
    if (option.contains('500,000') ||
        option.contains('1,000,000') ||
        option.contains('2,000,000')) {
      return Icons.monetization_on_outlined;
    }
    if (option.contains('construction')) return Icons.construction_outlined;
    if (option.contains('manufacturing')) return Icons.factory_outlined;
    if (option.contains('services')) return Icons.room_service_outlined;
    if (option.contains('retail')) return Icons.store_outlined;
    if (kDebugMode) {
      print('Using fallback icon for: $option');
    }
    return Icons.category_outlined;
  }

  const ParallaxGrid({
    super.key,
    required this.options,
    required this.selectedOption,
    required this.onOptionSelected,
    this.semanticsPrefix = 'Option',
  });

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final crossAxisCount = screenWidth > 600 ? 3 : 2; // Dynamic columns
        final itemCount = options.length;
        // Calculate aspect ratio based on item count and available space
        final childAspectRatio =
            itemCount > 4 ? 2.0 : 1.4; // More vertical space
        // Dynamic padding based on screen size
        final padding = screenWidth * 0.03;
        // Dynamic icon size based on cell width
        final iconSize =
            (constraints.maxWidth / crossAxisCount * 0.25).clamp(18.0, 28.0);

        return CustomScrollView(
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          shrinkWrap: true,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.all(padding),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: padding,
                  crossAxisSpacing: padding,
                  childAspectRatio: childAspectRatio,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final option = options[index];
                    final isSelected = selectedOption == option;
                    final scrollOffset = scrollController.hasClients
                        ? scrollController.offset
                        : 0.0;
                    final parallaxOffset =
                        (index % 2 == 0 ? 1 : -1) * scrollOffset * 0.05;
                    return Transform.translate(
                      offset: Offset(parallaxOffset, 0),
                      child: Semantics(
                        label:
                            '$semanticsPrefix: ${option.replaceAll('_', ' ')}',
                        selected: isSelected,
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (kDebugMode) {
                              print('Tapped option: $option');
                            }
                            HapticFeedback.lightImpact();
                            context.read<ColorProvider>().setColor(orange);
                            onOptionSelected(option);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              constraints: BoxConstraints(
                                minHeight:
                                    MediaQuery.of(context).size.height * 0.1,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(
                                        width: 2,
                                        color: context
                                            .watch<ColorProvider>()
                                            .color)
                                    : null,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withOpacity(isSelected ? 0.2 : 0.1),
                                    blurRadius: isSelected ? 4 : 2,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(padding),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      getIcon(option),
                                      size: iconSize,
                                      color:
                                          context.watch<ColorProvider>().color,
                                    ),
                                    SizedBox(height: padding * 0.5),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          option
                                              .replaceAll('_', ' ')
                                              .toUpperCase(),
                                          style: GoogleFonts.roboto(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF1B263B),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: options.length,
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
        children: fields
            .asMap()
            .entries
            .where((entry) =>
                entry.value['condition'] == null ||
                entry.value['condition'](responses))
            .map((entry) {
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

void showCoverDialog(
  BuildContext context,
  String insuranceType,
  int dialogIndex, {
  Map<String, dynamic>? extraParams,
}) {
  final dialogState = context.read<DialogState>();
  dialogState.updateResponse('insurance_type', insuranceType);
  final configs = dialogRegistry[insuranceType.toLowerCase()];
  if (configs == null || dialogIndex >= configs.length || dialogIndex < 0) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid dialog configuration')),
      );
    }
    if (kDebugMode) {
      print(
          'Invalid dialog: insuranceType=$insuranceType, dialogIndex=$dialogIndex');
    }
    return;
  }

  final config = configs[dialogIndex];
  final formKey = GlobalKey<FormState>();
  String selectedOption = config.gridOptions?.isNotEmpty == true
      ? (dialogState.responses[config.gridResponseKey!] ??
          config.gridOptions![0])
      : '';

  if (kDebugMode) {
    print(
        'Showing dialog: ${config.title}, index: $dialogIndex, insuranceType: $insuranceType');
  }

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => GenericDialog(
      title: config.title,
      submitButtonText: config.submitButtonText,
      insuranceType: insuranceType,
      dialogIndex: dialogIndex,
      content: LayoutBuilder(
        builder: (context, constraints) {
          final padding = MediaQuery.of(context).size.width * 0.03;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (config.gridOptions != null)
                ParallaxGrid(
                  options: config.gridOptions!,
                  selectedOption: selectedOption,
                  onOptionSelected: (option) {
                    selectedOption = option;
                    if (config.gridResponseKey != null) {
                      dialogState.updateResponse(
                          config.gridResponseKey!, option);
                      if (kDebugMode) {
                        print('Selected $option for ${config.gridResponseKey}');
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Selected: ${option.replaceAll('_', ' ')}')),
                      );
                    }
                  },
                  semanticsPrefix: config.gridSemanticsPrefix ?? 'Option',
                ),
              if (config.formFields != null)
                Padding(
                  padding: EdgeInsets.only(top: padding),
                  child: SizedBox(
                    height: constraints.maxHeight * 0.4,
                    child: SingleChildScrollView(
                      child: DynamicForm(
                        formKey: formKey,
                        fields: config.formFields!,
                        responses: dialogState.responses,
                        onFieldChanged: dialogState.updateResponse,
                      ),
                    ),
                  ),
                ),
              if (config.additionalContentBuilder != null)
                Padding(
                  padding: EdgeInsets.only(top: padding),
                  child: Column(
                    children:
                        config.additionalContentBuilder!(context, dialogState),
                  ),
                ),
            ],
          );
        },
      ),
      onSubmit: () {
        if (!(formKey.currentState?.validate() ?? true)) {
          if (kDebugMode) {
            print('Form validation failed for ${config.title}');
          }
          config.onValidationError?.call(context);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please correct form errors')),
            );
          }
          return;
        }
        if (config.customValidator != null &&
            !config.customValidator!(dialogState.responses)) {
          if (kDebugMode) {
            print('Custom validation failed for ${config.title}');
          }
          config.onValidationError?.call(context);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Validation failed')),
            );
          }
          return;
        }
        if (config.gridResponseKey != null &&
            dialogState.responses[config.gridResponseKey!] == null) {
          if (kDebugMode) {
            print('No subtype selected for ${config.gridResponseKey}');
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select a subtype')),
            );
          }
          return;
        }
        if (kDebugMode) {
          print(
              'Navigating from ${config.title}, responses: ${dialogState.responses}');
        }
        Navigator.pop(dialogContext);
        if (config.onSubmit != null) {
          config.onSubmit!(context, dialogState.responses);
        } else if (config.nextDialog != null) {
          final next = config.nextDialog!(dialogState.responses);
          if (next == 'insured_item') {
            if (context.mounted) {
              _InsuranceHomeScreenState()._showInsuredItemDialog(
                context,
                dialogState.responses['insurance_type']!,
                dialogState.responses['subtype']!,
                dialogState.responses['coverage_type'] ?? 'custom',
              );
            }
          } else {
            final nextIndex = configs.indexWhere(
                (c) => c.title.toLowerCase().contains(next.toLowerCase()));
            if (nextIndex >= 0 && context.mounted) {
              showCoverDialog(context, insuranceType, nextIndex,
                  extraParams: extraParams);
            } else if (context.mounted) {
              if (kDebugMode) {
                print('Invalid nextIndex: $nextIndex for next: $next');
              }
              _InsuranceHomeScreenState()._showInsuredItemDialog(
                context,
                dialogState.responses['insurance_type']!,
                dialogState.responses['subtype']!,
                dialogState.responses['coverage_type'] ?? 'custom',
              );
            }
          }
        } else if (dialogIndex + 1 < configs.length && context.mounted) {
          showCoverDialog(context, insuranceType, dialogIndex + 1,
              extraParams: extraParams);
        } else if (context.mounted) {
          _InsuranceHomeScreenState()._showInsuredItemDialog(
            context,
            dialogState.responses['insurance_type']!,
            dialogState.responses['subtype']!,
            dialogState.responses['coverage_type'] ?? 'custom',
          );
        }
      },
    ),
  );
}

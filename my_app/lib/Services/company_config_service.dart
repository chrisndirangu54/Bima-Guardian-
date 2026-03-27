import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyRateCard {
  final String companyId;
  final String insuranceType;
  final String insuranceSubtype;
  final double basePremium;
  final Map<String, double> fieldRates;
  final Map<String, double> flatAdjustments;
  final double minimumPremium;
  final String currency;

  const CompanyRateCard({
    required this.companyId,
    required this.insuranceType,
    required this.insuranceSubtype,
    required this.basePremium,
    required this.fieldRates,
    required this.flatAdjustments,
    required this.minimumPremium,
    this.currency = 'KES',
  });

  factory CompanyRateCard.fromJson(Map<String, dynamic> json) {
    return CompanyRateCard(
      companyId: (json['companyId'] ?? '').toString(),
      insuranceType: (json['insuranceType'] ?? '').toString(),
      insuranceSubtype: (json['insuranceSubtype'] ?? '').toString(),
      basePremium: (json['basePremium'] as num?)?.toDouble() ?? 0,
      fieldRates: Map<String, double>.from(
        (json['fieldRates'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      flatAdjustments: Map<String, double>.from(
        (json['flatAdjustments'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      minimumPremium: (json['minimumPremium'] as num?)?.toDouble() ?? 0,
      currency: (json['currency'] ?? 'KES').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'companyId': companyId,
        'insuranceType': insuranceType,
        'insuranceSubtype': insuranceSubtype,
        'basePremium': basePremium,
        'fieldRates': fieldRates,
        'flatAdjustments': flatAdjustments,
        'minimumPremium': minimumPremium,
        'currency': currency,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class QuoteTemplateSection {
  final String label;
  final String fieldKey;
  final String prefix;
  final String suffix;

  const QuoteTemplateSection({
    required this.label,
    required this.fieldKey,
    this.prefix = '',
    this.suffix = '',
  });

  factory QuoteTemplateSection.fromJson(Map<String, dynamic> json) {
    return QuoteTemplateSection(
      label: (json['label'] ?? '').toString(),
      fieldKey: (json['fieldKey'] ?? '').toString(),
      prefix: (json['prefix'] ?? '').toString(),
      suffix: (json['suffix'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'fieldKey': fieldKey,
        'prefix': prefix,
        'suffix': suffix,
      };
}

class CompanyQuoteTemplate {
  final String companyId;
  final String insuranceType;
  final String insuranceSubtype;
  final String title;
  final String footer;
  final List<QuoteTemplateSection> sections;
  final String? pdfTemplateKey;
  final bool useOriginalLayout;

  const CompanyQuoteTemplate({
    required this.companyId,
    required this.insuranceType,
    required this.insuranceSubtype,
    required this.title,
    required this.footer,
    required this.sections,
    this.pdfTemplateKey,
    this.useOriginalLayout = false,
  });

  factory CompanyQuoteTemplate.fromJson(Map<String, dynamic> json) {
    return CompanyQuoteTemplate(
      companyId: (json['companyId'] ?? '').toString(),
      insuranceType: (json['insuranceType'] ?? '').toString(),
      insuranceSubtype: (json['insuranceSubtype'] ?? '').toString(),
      title: (json['title'] ?? 'Insurance Quote').toString(),
      footer: (json['footer'] ?? '').toString(),
      sections: ((json['sections'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(QuoteTemplateSection.fromJson)
          .toList()),
      pdfTemplateKey: json['pdfTemplateKey']?.toString(),
      useOriginalLayout: json['useOriginalLayout'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'companyId': companyId,
        'insuranceType': insuranceType,
        'insuranceSubtype': insuranceSubtype,
        'title': title,
        'footer': footer,
        'sections': sections.map((s) => s.toJson()).toList(),
        'pdfTemplateKey': pdfTemplateKey,
        'useOriginalLayout': useOriginalLayout,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class CompanyConfigService {
  CompanyConfigService._();

  static final _db = FirebaseFirestore.instance;

  static String normalize(String value) => value.trim().toLowerCase();

  static String buildDocId(String companyId, String type, String subtype) =>
      '${normalize(companyId)}_${normalize(type)}_${normalize(subtype)}';

  static Future<void> upsertRateCard(CompanyRateCard card) async {
    await _db
        .collection('company_rate_cards')
        .doc(buildDocId(card.companyId, card.insuranceType, card.insuranceSubtype))
        .set(card.toJson(), SetOptions(merge: true));
  }

  static Future<void> upsertQuoteTemplate(CompanyQuoteTemplate template) async {
    await _db
        .collection('company_quote_templates')
        .doc(buildDocId(template.companyId, template.insuranceType, template.insuranceSubtype))
        .set(template.toJson(), SetOptions(merge: true));
  }

  static Future<CompanyRateCard?> fetchRateCard(
    String companyId,
    String insuranceType,
    String insuranceSubtype,
  ) async {
    final doc = await _db
        .collection('company_rate_cards')
        .doc(buildDocId(companyId, insuranceType, insuranceSubtype))
        .get();

    if (!doc.exists || doc.data() == null) return null;
    return CompanyRateCard.fromJson(doc.data()!);
  }

  static Future<CompanyQuoteTemplate?> fetchQuoteTemplate(
    String companyId,
    String insuranceType,
    String insuranceSubtype,
  ) async {
    final doc = await _db
        .collection('company_quote_templates')
        .doc(buildDocId(companyId, insuranceType, insuranceSubtype))
        .get();

    if (!doc.exists || doc.data() == null) return null;
    return CompanyQuoteTemplate.fromJson(doc.data()!);
  }

  static double calculatePremium(
    CompanyRateCard card,
    Map<String, String> formData,
  ) {
    double premium = card.basePremium;

    for (final entry in card.fieldRates.entries) {
      final raw = (formData[entry.key] ?? '0').replaceAll('KES', '').replaceAll(',', '').trim();
      final value = double.tryParse(raw) ?? 0;
      premium += value * entry.value;
    }

    premium += card.flatAdjustments.values.fold(0.0, (sum, item) => sum + item);

    if (premium < card.minimumPremium) {
      return card.minimumPremium;
    }
    return premium;
  }

  static Map<String, dynamic> rateCardJsonTemplate({
    required String companyId,
    required String insuranceType,
    required String insuranceSubtype,
  }) => {
        'companyId': companyId,
        'insuranceType': insuranceType,
        'insuranceSubtype': insuranceSubtype,
        'currency': 'KES',
        'basePremium': 10000,
        'minimumPremium': 5000,
        'fieldRates': {
          'vehicle_value': 0.01,
          'coverage_limit': 0.0001,
        },
        'flatAdjustments': {
          'processing_fee': 500,
        },
      };

  static Map<String, dynamic> quoteTemplateJsonTemplate({
    required String companyId,
    required String insuranceType,
    required String insuranceSubtype,
  }) => {
        'companyId': companyId,
        'insuranceType': insuranceType,
        'insuranceSubtype': insuranceSubtype,
        'title': '$companyId ${insuranceType.toUpperCase()} Quote',
        'footer': 'Generated by Bima Guardian',
        'pdfTemplateKey': 'company_a_motor_quote_layout',
        'useOriginalLayout': true,
        'sections': [
          {'label': 'Policy Type', 'fieldKey': 'policy_type', 'prefix': '', 'suffix': ''},
          {'label': 'Policy Subtype', 'fieldKey': 'policy_subtype', 'prefix': '', 'suffix': ''},
          {'label': 'Company', 'fieldKey': 'company', 'prefix': '', 'suffix': ''},
          {'label': 'Premium', 'fieldKey': 'premium', 'prefix': 'KES ', 'suffix': ''},
        ],
      };

  static CompanyRateCard rateCardFromFlexibleInput({
    required String companyId,
    required String insuranceType,
    required String insuranceSubtype,
    required String extension,
    required String rawContent,
  }) {
    final normalizedExtension = extension.toLowerCase();
    if (normalizedExtension == 'json') {
      final json = _safeJsonMap(rawContent);
      return CompanyRateCard.fromJson({
        ...json,
        'companyId': json['companyId'] ?? companyId,
        'insuranceType': json['insuranceType'] ?? insuranceType,
        'insuranceSubtype': json['insuranceSubtype'] ?? insuranceSubtype,
      });
    }

    if (normalizedExtension == 'csv' || normalizedExtension == 'txt') {
      final lines = rawContent
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final fieldRates = <String, double>{};
      final flatAdjustments = <String, double>{};
      double basePremium = 0;
      double minimumPremium = 0;

      for (final line in lines) {
        final parts = line.split(',');
        if (parts.length < 2) continue;

        final key = parts[0].trim();
        final value = double.tryParse(parts[1].trim()) ?? 0;

        if (key == 'basePremium') {
          basePremium = value;
        } else if (key == 'minimumPremium') {
          minimumPremium = value;
        } else if (key.startsWith('flat.')) {
          flatAdjustments[key.replaceFirst('flat.', '')] = value;
        } else {
          fieldRates[key] = value;
        }
      }

      return CompanyRateCard(
        companyId: companyId,
        insuranceType: insuranceType,
        insuranceSubtype: insuranceSubtype,
        basePremium: basePremium,
        minimumPremium: minimumPremium,
        fieldRates: fieldRates,
        flatAdjustments: flatAdjustments,
      );
    }

    throw FormatException(
      'Unsupported rate card format: $extension. Upload JSON, CSV, or TXT or pre-convert server-side.',
    );
  }

  static CompanyQuoteTemplate quoteTemplateFromFlexibleInput({
    required String companyId,
    required String insuranceType,
    required String insuranceSubtype,
    required String extension,
    required String rawContent,
  }) {
    final normalizedExtension = extension.toLowerCase();
    if (normalizedExtension == 'json') {
      final json = _safeJsonMap(rawContent);
      return CompanyQuoteTemplate.fromJson({
        ...json,
        'companyId': json['companyId'] ?? companyId,
        'insuranceType': json['insuranceType'] ?? insuranceType,
        'insuranceSubtype': json['insuranceSubtype'] ?? insuranceSubtype,
      });
    }

    final placeholders = RegExp(r'\{\{([a-zA-Z0-9_]+)\}\}')
        .allMatches(rawContent)
        .map((m) => m.group(1))
        .whereType<String>()
        .toSet()
        .toList();

    final sections = placeholders
        .map(
          (field) => QuoteTemplateSection(
            label: field.replaceAll('_', ' ').toUpperCase(),
            fieldKey: field,
          ),
        )
        .toList();

    return CompanyQuoteTemplate(
      companyId: companyId,
      insuranceType: insuranceType,
      insuranceSubtype: insuranceSubtype,
      title: '$companyId ${insuranceType.toUpperCase()} Quote',
      footer: 'Generated by Bima Guardian',
      sections: sections,
    );
  }

  static Map<String, dynamic> _safeJsonMap(String rawContent) {
    try {
      final dynamic decoded = const JsonDecoder().convert(rawContent);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      if (kDebugMode) {
        print('Failed parsing JSON content');
      }
    }
    throw const FormatException('Invalid JSON format.');
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;

class GeminiService {
  static const String apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyC9l-r597J799tIcTthyISAwX5t4z3r6A4',
  );
  static const String freeTierModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.1-flash-lite',
  );
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static Uri _generateContentUri() =>
      Uri.parse('$_baseUrl/$freeTierModel:generateContent');

  static Future<String> generateText({
    required String prompt,
    int maxOutputTokens = 1000,
    bool jsonResponse = false,
  }) async {
    return generateContent(
      parts: [
        {'text': prompt},
      ],
      maxOutputTokens: maxOutputTokens,
      jsonResponse: jsonResponse,
    );
  }

  static Future<String> generateFromImage({
    required String prompt,
    required String base64Image,
    String mimeType = 'image/jpeg',
    int maxOutputTokens = 1000,
    bool jsonResponse = false,
  }) async {
    return generateContent(
      parts: [
        {'text': prompt},
        {
          'inline_data': {
            'mime_type': mimeType,
            'data': base64Image,
          },
        },
      ],
      maxOutputTokens: maxOutputTokens,
      jsonResponse: jsonResponse,
    );
  }

  static Future<String> generateContent({
    required List<Map<String, dynamic>> parts,
    int maxOutputTokens = 1000,
    bool jsonResponse = false,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key is missing.');
    }

    final response = await http.post(
      _generateContentUri(),
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': parts,
          }
        ],
        'generationConfig': {
          'maxOutputTokens': maxOutputTokens,
          if (jsonResponse) 'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API error (HTTP ${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini API returned no candidates: ${response.body}');
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final responseParts = content?['parts'] as List<dynamic>?;
    final text = responseParts
        ?.whereType<Map<String, dynamic>>()
        .map((part) => part['text'] as String? ?? '')
        .join('')
        .trim();

    if (text == null || text.isEmpty) {
      throw Exception('Gemini API returned no text: ${response.body}');
    }

    return text;
  }

  static String cleanJsonText(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
    }
    return cleaned.trim();
  }
}

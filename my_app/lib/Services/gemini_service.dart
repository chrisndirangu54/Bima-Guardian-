import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thin wrapper around the Gemini generateContent REST endpoint.
///
/// Authentication uses the `x-goog-api-key` request header.
/// The model is configurable at build time via `--dart-define=GEMINI_MODEL=…`
/// and the key via `--dart-define=GEMINI_API_KEY=…`.
class GeminiService {
  // ── Configuration ──────────────────────────────────────────────────────────

  /// Resolved at build time; falls back to the free-tier lite model.
  static const String _model = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.5-flash-lite', // ← closest valid model to your request
  );

  /// Resolved at build time.  Supply via `--dart-define=GEMINI_API_KEY=<key>`.
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // ── Internal helpers ────────────────────────────────────────────────────────

  static Uri _endpointUri() =>
      Uri.parse('$_baseUrl/$_model:generateContent');

  static Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'x-goog-api-key': _apiKey,
      };

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Generate text from a plain-text [prompt].
static Future<String> generateText({
  required String prompt,
  int maxOutputTokens = 1000,
  bool jsonResponse = false,
}) =>
      generateContent(
        parts: [
          {'text': prompt},
        ],
        maxOutputTokens: maxOutputTokens,
        jsonResponse: jsonResponse,
      );

  /// Generate text from a [prompt] + a base64-encoded inline [base64Image].
  static Future<String> generateFromImage({
    required String prompt,
    required String base64Image,
    String mimeType = 'image/jpeg',
    int maxOutputTokens = 1000,
    bool jsonResponse = false,
  }) =>
      generateContent(
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

  /// Core method — assembles the request body and calls the REST API.
  ///
  /// [parts] follows the Gemini `Part` schema; each entry is either
  /// `{'text': '…'}` or `{'inline_data': {…}}`.
  static Future<String> generateContent({
    required List<Map<String, dynamic>> parts,
    int maxOutputTokens = 1000,
    bool jsonResponse = false,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'Gemini API key is missing. '
        'Pass --dart-define=GEMINI_API_KEY=<key> at build time.',
      );
    }

    final body = jsonEncode({
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
    });

    final response = await http.post(
      _endpointUri(),
      headers: _headers(),
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API error (HTTP ${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;

    if (candidates == null || candidates.isEmpty) {
      throw Exception(
        'Gemini API returned no candidates: ${response.body}',
      );
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final responseParts = content?['parts'] as List<dynamic>?;

    final text = responseParts
        ?.whereType<Map<String, dynamic>>()
        .map((part) => part['text'] as String? ?? '')
        .join()
        .trim();

    if (text == null || text.isEmpty) {
      throw Exception('Gemini API returned no text: ${response.body}');
    }

    return text;
  }

  // ── Utility ─────────────────────────────────────────────────────────────────

  /// Strips Markdown code fences that Gemini sometimes wraps around JSON.
  static String cleanJsonText(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '');
    }
    return cleaned.trim();
  }
}
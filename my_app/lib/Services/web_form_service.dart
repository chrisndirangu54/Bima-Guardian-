import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/Models/extracted_form_field.dart';

class WebFormService {
  static const String _anthropicUrl = 'https://api.anthropic.com/v1/messages';

  static const String domExtractionScript = r'''
(function() {
  var forms = Array.from(document.querySelectorAll('form'));
  var best = forms.reduce(function(a, b) {
    return b.querySelectorAll('input,select,textarea').length >
           a.querySelectorAll('input,select,textarea').length ? b : a;
  }, document.body);

  var html = best.innerHTML;

  if (html.length > 10000) html = html.substring(0, 10000);

  return JSON.stringify({
    title: document.title || '',
    html: html
  });
})();
''';

  static Future<WebFormSchema> extractFormFieldsFromHtml(
    String url,
    String html,
  ) async {
    final response = await http.post(
      Uri.parse(_anthropicUrl),
      headers: {
        'Content-Type': 'application/json',
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': 'claude-sonnet-4-20250514',
        'max_tokens': 1500,
        'messages': [
          {
            'role': 'user',
            'content': '''Analyze the HTML below and extract every interactive form field.
Return ONLY a valid JSON object — no markdown, no explanation, no backticks.

Rules:
- Include every input, select, textarea, and checkbox you find.
- For "type", use one of: text | email | phone | number | select | checkbox | textarea | password | date
- For "mappedKey", use dot notation that describes the field semantically:
    user.name | user.email | user.phone | billing.address | shipping.city |
    payment.card_number | auth.password | general.message  etc.
- For "cssSelector", prefer attribute selectors like [name="x"] or #id over
    positional selectors like form > div:nth-child(3) > input.
- "options" is an array of option values for select/radio fields; empty otherwise.
- "required" is true only when the field is explicitly marked required.

Schema:
{
  "title": "<page or form title>",
  "fields": [
    {
      "id": "<name or id attribute value>",
      "label": "<human-readable label>",
      "type": "text|email|phone|number|select|checkbox|textarea|password|date",
      "required": true|false,
      "options": [],
      "placeholder": "<placeholder text or null>",
      "mappedKey": "<semantic dot-key>",
      "cssSelector": "<precise CSS selector>"
    }
  ]
}

HTML:
$html''',
          }
        ],
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
          'Claude API error (HTTP ${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final rawText = (data['content'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join('');

    final clean = rawText
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    try {
      final schema = jsonDecode(clean) as Map<String, dynamic>;
      return WebFormSchema.fromJson(url, schema);
    } catch (e) {
      throw Exception(
          'Failed to parse Claude response as JSON.\nRaw:\n$clean\n\nError: $e');
    }
  }

  static String generateFillScript(
    List<ExtractedFormField> fields,
    Map<String, String> values,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('(function() {');
    buffer.writeln("  'use strict';");

    buffer.writeln('''
  function setNativeValue(el, value) {
    var tracker = el._valueTracker;
    if (tracker) tracker.setValue('');
    var proto = Object.getOwnPropertyDescriptor(
      el.tagName === 'TEXTAREA'
        ? window.HTMLTextAreaElement.prototype
        : window.HTMLInputElement.prototype,
      'value'
    );
    if (proto && proto.set) {
      proto.set.call(el, value);
    } else {
      el.value = value;
    }
    el.dispatchEvent(new Event('input',  { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }
''');

    for (final field in fields) {
      final value = values[field.id];
      if (value == null || value.isEmpty) continue;

      final esc = value
          .replaceAll('\\', '\\\\')
          .replaceAll("'", "\\'")
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '');

      final sel =
          field.cssSelector.replaceAll('\\', '\\\\').replaceAll("'", "\\'");

      switch (field.type) {
        case 'checkbox':
          buffer.writeln('''
  (function() {
    var el = document.querySelector('$sel');
    if (!el) return;
    var checked = ${value == 'true' ? 'true' : 'false'};
    if (el.checked !== checked) {
      el.checked = checked;
      el.dispatchEvent(new Event('change', { bubbles: true }));
    }
  })();''');
          break;

        case 'select':
          buffer.writeln('''
  (function() {
    var el = document.querySelector('$sel');
    if (!el) return;
    var target = '$esc';
    for (var i = 0; i < el.options.length; i++) {
      if (el.options[i].value === target || el.options[i].text === target) {
        el.selectedIndex = i;
        el.dispatchEvent(new Event('change', { bubbles: true }));
        break;
      }
    }
  })();''');
          break;

        default:
          buffer.writeln('''
  (function() {
    var el = document.querySelector('$sel');
    if (!el) return;
    setNativeValue(el, '$esc');
    el.dispatchEvent(new Event('blur', { bubbles: true }));
  })();''');
      }
    }

    buffer.writeln('})();');
    return buffer.toString();
  }

  static Map<String, List<ExtractedFormField>> groupByCategory(
      List<ExtractedFormField> fields) {
    final map = <String, List<ExtractedFormField>>{};
    for (final f in fields) {
      final category =
          f.mappedKey.contains('.') ? f.mappedKey.split('.').first : 'general';
      map.putIfAbsent(category, () => []).add(f);
    }
    return map;
  }

  static void log(String message) {
    if (kDebugMode) print('[WebFormService] $message');
  }
}

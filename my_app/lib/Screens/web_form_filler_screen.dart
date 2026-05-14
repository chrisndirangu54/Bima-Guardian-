import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/Models/extracted_form_field.dart';
import 'package:my_app/Services/web_form_service.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _kNavy = Color(0xFF1B263B);
const _kRed = Color(0xFF8B0000);
const _kTeal = Color(0xFF1D4E63);
const _kGrey = Color(0xFFD3D3D3);
const _kBg = Color(0xFFF9F9F9);

class WebFormFillerScreen extends StatefulWidget {
  const WebFormFillerScreen({super.key});

  @override
  State<WebFormFillerScreen> createState() => _WebFormFillerScreenState();
}

class _WebFormFillerScreenState extends State<WebFormFillerScreen>
    with SingleTickerProviderStateMixin {
  int _step = 0;

  final _urlController = TextEditingController();
  String? _urlError;

  WebViewController? _webController;
  bool _pageLoaded = false;

  bool _extracting = false;
  String? _extractError;

  WebFormSchema? _schema;
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _checkboxValues = {};
  final Map<String, String?> _dropdownValues = {};

  bool _injecting = false;
  bool _injected = false;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _urlController.dispose();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    _pulse.dispose();
    super.dispose();
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _step = _step == 3 ? 2 : _step - 1;
      _injected = false;
    });
  }

  void _loadUrl() {
    var url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _urlError = 'Please enter a URL');
      return;
    }
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }

    _urlController.text = url;
    setState(() => _urlError = null);

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0.0.0 Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() => _pageLoaded = false);
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _pageLoaded = true);
          },
          onWebResourceError: (err) => WebFormService.log(
            'WebView resource error: ${err.description}',
          ),
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() {
      _webController = controller;
      _pageLoaded = false;
      _extracting = false;
      _extractError = null;
      _step = 1;
    });
  }

  Future<void> _extractFields() async {
    if (_webController == null) return;

    setState(() {
      _extracting = true;
      _extractError = null;
    });

    try {
      final raw = await _webController!
          .runJavaScriptReturningResult(WebFormService.domExtractionScript);

      String jsonStr = raw.toString();
      if (jsonStr.startsWith('"') && jsonStr.endsWith('"')) {
        jsonStr = jsonDecode(jsonStr) as String;
      }

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final html = decoded['html']?.toString() ?? '';

      if (html.trim().isEmpty) {
        throw Exception(
          'No form HTML found on this page. '
          'Make sure the form is visible before extracting.',
        );
      }

      WebFormService.log('Extracted ${html.length} chars of HTML from WebView');

      final schema = await WebFormService.extractFormFieldsFromHtml(
        _urlController.text.trim(),
        html,
      );

      if (!mounted) return;

      if (schema.fields.isEmpty) {
        throw Exception(
          'Gemini found no form fields on this page. '
          'Try scrolling to the form first and extracting again.',
        );
      }

      _textControllers.forEach((_, c) => c.dispose());
      _textControllers.clear();
      _checkboxValues.clear();
      _dropdownValues.clear();

      for (final field in schema.fields) {
        switch (field.type) {
          case 'checkbox':
            _checkboxValues[field.id] = false;
            break;
          case 'select':
            _dropdownValues[field.id] =
                field.options.isNotEmpty ? field.options.first : null;
            break;
          default:
            _textControllers[field.id] = TextEditingController();
        }
      }

      setState(() {
        _schema = schema;
        _extracting = false;
        _step = 2;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _extractError = e.toString();
        _extracting = false;
      });
    }
  }

  Future<void> _injectAndPreview() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_webController == null || _schema == null) return;

    setState(() {
      _step = 3;
      _injected = false;
      _injecting = true;
    });

    await _runInjection();
  }

  Future<void> _runInjection() async {
    if (_webController == null || _schema == null) return;

    final values = <String, String>{};
    for (final field in _schema!.fields) {
      switch (field.type) {
        case 'checkbox':
          values[field.id] = (_checkboxValues[field.id] ?? false) ? 'true' : 'false';
          break;
        case 'select':
          values[field.id] = _dropdownValues[field.id] ?? '';
          break;
        default:
          values[field.id] = _textControllers[field.id]?.text ?? '';
      }
    }

    final script = WebFormService.generateFillScript(_schema!.fields, values);

    try {
      await _webController!.runJavaScript(script);
      if (!mounted) return;
      setState(() {
        _injected = true;
        _injecting = false;
      });
    } catch (e) {
      WebFormService.log('Injection error: $e');
      if (!mounted) return;
      setState(() => _injecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _appBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: switch (_step) {
          0 => _buildUrlStep(),
          1 => _buildWebViewStep(isPreview: false),
          2 => _buildFillStep(),
          3 => _buildWebViewStep(isPreview: true),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: _kNavy, size: 18),
        onPressed: _back,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Web Form Filler',
            style: GoogleFonts.lora(
              color: _kNavy,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          _StepIndicator(current: _step),
        ],
      ),
    );
  }

  Widget _buildUrlStep() {
    return ListView(
      key: const ValueKey(0),
      padding: const EdgeInsets.all(24),
      children: [
        const _SectionHeader(
          icon: Icons.language_outlined,
          title: 'Target Website',
          subtitle: 'Enter any URL. The page loads in a real browser — '
              'Cloudflare and CAPTCHAs are handled natively.',
        ),
        const SizedBox(height: 24),
        _StyledField(
          controller: _urlController,
          label: 'Page URL',
          hint: 'https://example.com/checkout',
          keyboardType: TextInputType.url,
          icon: Icons.link_rounded,
          errorText: _urlError,
          onSubmitted: (_) => _loadUrl(),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Open in Browser',
          icon: Icons.open_in_browser_rounded,
          color: _kRed,
          onTap: _loadUrl,
        ),
        const SizedBox(height: 32),
        const _HowItWorks(),
      ],
    );
  }

  Widget _buildWebViewStep({required bool isPreview}) {
    return Column(
      key: ValueKey(isPreview ? 3 : 1),
      children: [
        Container(
          color: _kNavy,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _urlController.text,
                  style: GoogleFonts.roboto(color: Colors.white60, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isPreview && _pageLoaded && !_extracting)
                _CompactButton(
                  label: 'Extract Fields',
                  icon: Icons.auto_awesome,
                  color: Colors.amberAccent,
                  onTap: _extractFields,
                ),
              if (!isPreview && _extracting)
                const _SpinnerLabel(label: 'Extracting…'),
              if (isPreview && _injected)
                _CompactButton(
                  label: 'Re-fill',
                  icon: Icons.auto_fix_high,
                  color: Colors.greenAccent,
                  onTap: _runInjection,
                ),
              if (isPreview && _injecting)
                const _SpinnerLabel(label: 'Filling…'),
            ],
          ),
        ),
        if (!_pageLoaded)
          LinearProgressIndicator(
            backgroundColor: _kNavy.withOpacity(0.1),
            color: _kRed,
            minHeight: 2,
          ),
        if (!isPreview && _extractError != null) _ErrorBanner(message: _extractError!),
        if (!isPreview)
          _InfoBanner(
            message: _pageLoaded
                ? 'Page loaded. Scroll to your form, solve any CAPTCHA, '
                    'then tap "Extract Fields".'
                : 'Loading page…',
          ),
        if (isPreview && _injected)
          const _SuccessBanner(
            message: 'Fields filled! Review the form, then submit normally.',
          ),
        Expanded(
          child: _webController != null
              ? WebViewWidget(controller: _webController!)
              : const Center(child: CircularProgressIndicator(color: _kRed)),
        ),
      ],
    );
  }

  Widget _buildFillStep() {
    final schema = _schema!;
    final grouped = WebFormService.groupByCategory(schema.fields);

    return Form(
      key: _formKey,
      child: ListView(
        key: const ValueKey(2),
        padding: const EdgeInsets.all(24),
        children: [
          _SectionHeader(
            icon: Icons.edit_note_rounded,
            title: schema.title.isNotEmpty ? schema.title : 'Fill Form',
            subtitle: '${schema.fields.length} field(s) detected by AI. '
                'Fill in your details — they will be injected into the live page.',
          ),
          const SizedBox(height: 20),
          ...grouped.entries.expand((entry) => [
                _CategoryChip(label: entry.key),
                const SizedBox(height: 12),
                ...entry.value.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildFieldWidget(f),
                  ),
                ),
                const SizedBox(height: 4),
              ]),
          const SizedBox(height: 8),
          _PrimaryButton(
            label: 'Auto-Fill & Preview',
            icon: Icons.send_rounded,
            color: _kTeal,
            onTap: _injectAndPreview,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _step = 1),
              icon: const Icon(Icons.refresh, size: 15, color: _kGrey),
              label: Text(
                'Re-extract fields',
                style: GoogleFonts.roboto(color: _kGrey, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldWidget(ExtractedFormField field) {
    switch (field.type) {
      case 'checkbox':
        return _CheckboxField(
          field: field,
          value: _checkboxValues[field.id] ?? false,
          onChanged: (v) => setState(() => _checkboxValues[field.id] = v),
        );
      case 'select':
        return _DropdownField(
          field: field,
          value: _dropdownValues[field.id],
          onChanged: (v) => setState(() => _dropdownValues[field.id] = v),
        );
      case 'date':
        return _DateField(field: field, controller: _textControllers[field.id]!);
      case 'email':
        return _StyledField(
          controller: _textControllers[field.id]!,
          label: field.label,
          hint: field.placeholder ?? 'you@example.com',
          required: field.required,
          keyboardType: TextInputType.emailAddress,
          icon: Icons.email_outlined,
          validator: (v) {
            if (field.required && (v == null || v.isEmpty)) {
              return '${field.label} is required';
            }
            if (v != null && v.isNotEmpty && !v.contains('@')) {
              return 'Enter a valid email';
            }
            return null;
          },
        );
      case 'phone':
        return _StyledField(
          controller: _textControllers[field.id]!,
          label: field.label,
          hint: field.placeholder ?? '+254 700 000000',
          required: field.required,
          keyboardType: TextInputType.phone,
          icon: Icons.phone_outlined,
        );
      case 'number':
        return _StyledField(
          controller: _textControllers[field.id]!,
          label: field.label,
          hint: field.placeholder,
          required: field.required,
          keyboardType: TextInputType.number,
          icon: Icons.tag_rounded,
        );
      case 'password':
        return _StyledField(
          controller: _textControllers[field.id]!,
          label: field.label,
          hint: field.placeholder,
          required: field.required,
          obscureText: true,
          icon: Icons.lock_outline_rounded,
        );
      case 'textarea':
        return _StyledField(
          controller: _textControllers[field.id]!,
          label: field.label,
          hint: field.placeholder,
          required: field.required,
          maxLines: 4,
          icon: Icons.notes_rounded,
        );
      default:
        return _StyledField(
          controller: _textControllers[field.id]!,
          label: field.label,
          hint: field.placeholder,
          required: field.required,
          icon: Icons.text_fields_rounded,
        );
    }
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  static const _labels = ['URL', 'Load', 'Fill', 'Preview'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length, (i) {
        final done = i < current;
        final active = i == current;
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? _kTeal
                      : active
                          ? _kRed
                          : _kGrey,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                _labels[i],
                style: GoogleFonts.roboto(
                  fontSize: 9,
                  color: active ? _kNavy : _kGrey,
                  fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _kRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _kRed, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.lora(
                  color: _kNavy,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: GoogleFonts.roboto(color: _kGrey, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? errorText;
  final bool required;
  final TextInputType keyboardType;
  final IconData icon;
  final bool obscureText;
  final int maxLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  const _StyledField({
    this.controller,
    required this.label,
    this.hint,
    this.errorText,
    this.required = false,
    this.keyboardType = TextInputType.text,
    required this.icon,
    this.obscureText = false,
    this.maxLines = 1,
    this.validator,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      onFieldSubmitted: onSubmitted,
      style: GoogleFonts.roboto(color: _kNavy, fontSize: 14),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        errorText: errorText,
        labelStyle: GoogleFonts.roboto(color: _kGrey, fontSize: 13),
        hintStyle: GoogleFonts.roboto(color: _kGrey.withOpacity(0.6), fontSize: 13),
        prefixIcon: Icon(icon, color: _kGrey, size: 18),
        filled: true,
        fillColor: _kBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _kGrey.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kRed, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: validator ??
          (v) {
            if (required && (v == null || v.isEmpty)) {
              return '$label is required';
            }
            return null;
          },
    );
  }
}

class _DropdownField extends StatelessWidget {
  final ExtractedFormField field;
  final String? value;
  final ValueChanged<String?> onChanged;
  const _DropdownField({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: field.required ? '${field.label} *' : field.label,
        labelStyle: GoogleFonts.roboto(color: _kGrey, fontSize: 13),
        prefixIcon: const Icon(
          Icons.arrow_drop_down_circle_outlined,
          color: _kGrey,
          size: 18,
        ),
        filled: true,
        fillColor: _kBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _kGrey.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kTeal, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      items: field.options
          .map(
            (o) => DropdownMenuItem(
              value: o,
              child: Text(o, style: GoogleFonts.roboto(color: _kNavy, fontSize: 14)),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: (v) => field.required && v == null ? '${field.label} is required' : null,
    );
  }
}

class _CheckboxField extends StatelessWidget {
  final ExtractedFormField field;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CheckboxField({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kBg,
          border: Border.all(color: _kGrey.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: _kTeal,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                field.required ? '${field.label} *' : field.label,
                style: GoogleFonts.roboto(color: _kNavy, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final ExtractedFormField field;
  final TextEditingController controller;
  const _DateField({required this.field, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: GoogleFonts.roboto(color: _kNavy, fontSize: 14),
      decoration: InputDecoration(
        labelText: field.required ? '${field.label} *' : field.label,
        labelStyle: GoogleFonts.roboto(color: _kGrey, fontSize: 13),
        prefixIcon: const Icon(Icons.calendar_today_outlined, color: _kGrey, size: 18),
        filled: true,
        fillColor: _kBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _kGrey.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kTeal, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: _kTeal,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: _kNavy,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          controller.text =
              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        }
      },
      validator: (v) => field.required && (v == null || v.isEmpty)
          ? '${field.label} is required'
          : null,
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  const _CategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _kNavy.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.roboto(
          color: _kNavy,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.roboto(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _CompactButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CompactButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.roboto(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpinnerLabel extends StatelessWidget {
  final String label;
  const _SpinnerLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(color: Colors.white60, strokeWidth: 1.5),
        ),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.roboto(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;
  const _InfoBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _kNavy.withOpacity(0.04),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _kTeal, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: GoogleFonts.roboto(color: _kNavy, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  final String message;
  const _SuccessBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.green.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.roboto(color: Colors.green.shade800, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _kRed.withOpacity(0.05),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: _kRed, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: GoogleFonts.roboto(color: _kRed, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        Icons.open_in_browser_rounded,
        'Page loads in a real WebView — Cloudflare & CAPTCHAs handled natively'
      ),
      (
        Icons.auto_awesome_outlined,
        'JS extracts the live, fully-rendered DOM (no http.get)'
      ),
      (Icons.auto_awesome, 'Gemini AI classifies every field with CSS selectors'),
      (Icons.edit_outlined, 'You fill a clean, validated Flutter form'),
      (
        Icons.send_rounded,
        'Values are injected back into the exact same WebView'
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kNavy.withOpacity(0.03),
        border: Border.all(color: _kGrey.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it works',
            style: GoogleFonts.lora(
              color: _kNavy,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...steps.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(s.$1, color: _kTeal, size: 15),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.$2,
                      style: GoogleFonts.roboto(color: _kNavy, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

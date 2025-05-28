import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DMVICWebViewPage extends StatefulWidget {
  final String email;
  final String password;
  final String registrationNumber;
  final String vehicleType;

  const DMVICWebViewPage({
    super.key,
    required this.email,
    required this.password,
    required this.registrationNumber,
    required this.vehicleType,
  });

  @override
  _DMVICWebViewPageState createState() => _DMVICWebViewPageState();
}

class _DMVICWebViewPageState extends State<DMVICWebViewPage> {
  late final WebViewController _controller;
  bool _hasInjectedLogin = false;
  bool _hasClickedMotor = false;
  bool _hasFilledMotorForm = false;

  /// Controller to capture the user-entered CAPTCHA text.
  final TextEditingController _captchaController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'CaptchaChannel',
        onMessageReceived: (JavaScriptMessage message) {
            // MESSAGE_RECEIVED: message.message contains the CAPTCHA image's `src`.
            _showCaptchaDialog(message.message);
          },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            // ─────────────────────────────────────────────
            // STEP 1: LOGIN PAGE (with CAPTCHA)
            // ─────────────────────────────────────────────
            if (!_hasInjectedLogin && url.contains("/#/login")) {
              _hasInjectedLogin = true;

              // Delay ~500ms for Angular to render the CAPTCHA <img> & input.
              await Future.delayed(const Duration(milliseconds: 500));

              // 1A. SCRAPE the CAPTCHA IMAGE SRC and post it via CaptchaChannel.
              final String captureCaptchaScript = '''
                (function() {
                  // Adjust selector if DMVIC uses a different ID/class for the CAPTCHA <img>:
                  var img = document.querySelector('#captchaImage, img[alt="CAPTCHA"], .captcha-img');
                  if (img && img.src) {
                    CaptchaChannel.postMessage(img.src);
                  }
                })();
              ''';
              await _controller.runJavaScript(captureCaptchaScript);

              // 1B. ALSO autofill email & password, but DO NOT click login yet.
              // We'll wait until the user enters CAPTCHA.
              final String autofillCredentialsScript = '''
                (function() {
                  // Locate username/email input by formControlName or other attribute:
                  var emailInput = document.querySelector('[formControlName="email"], [formControlName="userName"], #email');
                  // Locate password input:
                  var passwordInput = document.querySelector('[formControlName="password"], #password');
                  if (emailInput && passwordInput) {
                    emailInput.value = '${widget.email}';
                    emailInput.dispatchEvent(new Event('input'));
                    passwordInput.value = '${widget.password}';
                    passwordInput.dispatchEvent(new Event('input'));
                  }
                  // We DO NOT click the login button here; wait for CAPTCHA input.
                })();
              ''';
              await _controller.runJavaScript(autofillCredentialsScript);
            }

            // ─────────────────────────────────────────────
            // STEP 2: LANDING PAGE → CLICK “Motor” (once)
            // ─────────────────────────────────────────────
            if (!_hasClickedMotor && url.contains("/#/landing")) {
              _hasClickedMotor = true;

              // Wait ~500ms for Angular to render the six‐tile grid:
              await Future.delayed(const Duration(milliseconds: 500));

              // Click the element whose innerText is exactly "Motor":
              final String clickMotorScript = '''
                (function() {
                  var all = document.querySelectorAll('*');
                  var motorEl = null;
                  all.forEach(function(el) {
                    if (el.innerText && el.innerText.trim().toLowerCase() === 'motor') {
                      motorEl = el;
                    }
                  });
                  if (motorEl) {
                    motorEl.click();
                  }
                })();
              ''';
              await _controller.runJavaScript(clickMotorScript);
            }

            // ─────────────────────────────────────────────
            // STEP 3: MOTOR FORM → Auto-Fill & Submit (once)
            // ─────────────────────────────────────────────
            if (_hasClickedMotor && !_hasFilledMotorForm && url.contains("/#/landing")) {
              _hasFilledMotorForm = true;

              // Wait ~500ms for Angular to render the Motor form controls:
              await Future.delayed(const Duration(milliseconds: 500));

              // Fill "registrationNumber" & "vehicleType", then click submit:
              final String fillMotorFormScript = '''
                (function() {
                  var regInput = document.querySelector('[formControlName="registrationNumber"], #registrationNumber');
                  var typeSelect = document.querySelector('[formControlName="vehicleType"], #vehicleType');
                  var submitBtn = document.querySelector('button[type="submit"], button.proceed-button');
                  if (regInput && typeSelect) {
                    regInput.value = '${widget.registrationNumber}';
                    regInput.dispatchEvent(new Event('input'));
                    typeSelect.value = '${widget.vehicleType}';
                    typeSelect.dispatchEvent(new Event('change'));
                  }
                  if (submitBtn) {
                    submitBtn.click();
                  }
                })();
              ''';
              await _controller.runJavaScript(fillMotorFormScript);

              // Show a success dialog once Motor form is submitted:
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Success'),
                      content: const Text(
                        'You have successfully logged in, selected “Motor,” and submitted your application on DMVIC.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    );
                  },
                );
              }
            }
          },
        ),
      )
      // Step 0: Start at the login route:
      ..loadRequest(Uri.parse('https://www.dmvic.com/#/login'));
  }



  /// Shows a Flutter dialog with the CAPTCHA image and a TextField for user entry.
  void _showCaptchaDialog(String captchaImageUrl) {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // force entry
      builder: (context) {
        return AlertDialog(
          title: const Text('Please Solve CAPTCHA'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Display the CAPTCHA image:
              Image.network(captchaImageUrl),
              const SizedBox(height: 12),
              // Input for the CAPTCHA text:
              TextField(
                controller: _captchaController,
                decoration: const InputDecoration(
                  labelText: 'Enter CAPTCHA text',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final String captchaValue = _captchaController.text.trim();
                if (captchaValue.isEmpty) {
                  // If empty, do nothing or show error:
                  return;
                }

                // Inject JS to fill the CAPTCHA field and click Login:
                final String fillCaptchaAndLogin = '''
                  (function() {
                    // Adjust selectors if DMVIC uses custom IDs or formControlName for CAPTCHA input:
                    var captchaInput = document.querySelector('[formControlName="captcha"], #captchaInput');
                    if (captchaInput) {
                      captchaInput.value = '$captchaValue';
                      captchaInput.dispatchEvent(new Event('input'));
                    }
                    // Finally, click the login button:
                    var loginBtn = document.querySelector('button[type="submit"], button.login-button');
                    if (loginBtn) {
                      loginBtn.click();
                    }
                  })();
                ''';
                await _controller.runJavaScript(fillCaptchaAndLogin);

                // Close the CAPTCHA dialog immediately:
                Navigator.of(context).pop();
              },
              child: const Text('Submit CAPTCHA'),
            ),
          ],
        );
      },
    );
  }

  @override                                              
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DMVIC Kenya – Motor Certificate'),
      ),
      body: WebViewWidget(
        controller: _controller,
      ),
    );
  }

  @override
  void dispose() {
    _captchaController.dispose();
    super.dispose();
  }
}


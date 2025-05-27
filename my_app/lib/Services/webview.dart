import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter/webview_flutter.dart' show WebViewController;

class DMVICWebViewPage extends StatefulWidget {
  final String registrationNumber;
  final String vehicleType;

  DMVICWebViewPage({required this.registrationNumber, required this.vehicleType});

  @override
  _DMVICWebViewPageState createState() => _DMVICWebViewPageState();
}

class _DMVICWebViewPageState extends State<DMVICWebViewPage> {
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    // Initialize WebView
    WebView.platform = const AndroidWebView();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('DMVIC Kenya'),
      ),
      body: WebView(
        initialUrl: 'https://dmvic.kenya.gov.ke',
        onWebViewCreated: (WebViewController webViewController) {
          _controller = webViewController;
        },
        javascriptMode: JavaScriptMode.unrestricted,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // After opening DMVIC, autofill the form with registration number and vehicle type (if needed)
          String autofillScript = '''
            document.getElementById('registration_number').value = '${widget.registrationNumber}';
            document.getElementById('vehicle_type').value = '${widget.vehicleType}';
          ''';
          // Execute JavaScript to autofill form fields
          await _controller.runJavascript(autofillScript);
        },
        child: Icon(Icons.save),
      ),
    );
  }
}

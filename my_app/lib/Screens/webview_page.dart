import 'package:flutter/material.dart';

class WebViewPage extends StatelessWidget {
  final String url;
  const WebViewPage({required this.url, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: WebView(initialUrl: url), // Using webview_flutter package
    );
  }
}

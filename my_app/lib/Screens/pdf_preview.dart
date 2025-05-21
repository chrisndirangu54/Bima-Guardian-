import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_render/pdf_render.dart' as pdf;
import 'package:pdf_render/pdf_render_widgets.dart';

class PdfPreview extends StatefulWidget {
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
  State<PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<PdfPreview> {
  late Future<pdf.PdfDocument> _pdfDocumentFuture;

  @override
  void initState() {
    super.initState();
    _pdfDocumentFuture = pdf.PdfDocument.openFile(widget.file.path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<pdf.PdfDocument>(
      future: _pdfDocumentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          print('Error loading PDF: ${snapshot.error}');
          return Center(child: Text('Error loading PDF: ${snapshot.error}'));
        }
        if (snapshot.data == null) {
          return const Center(child: Text('PDF data is null'));
        }

        final pdfDoc = snapshot.data!;
        return PdfViewer(
          doc: pdfDoc,
          // Pass initialPage, zoomSteps, and panEnabled within PdfViewerParams
          params: PdfViewerParams(panEnabled: widget.allowSwipeNavigation),
        );
      },
    );
  }
}

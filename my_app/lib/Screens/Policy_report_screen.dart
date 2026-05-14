import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_app/Models/cover.dart';
import 'package:my_app/Models/policy.dart';
import 'package:my_app/insurance_app.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

class CoverReportScreen extends StatefulWidget {
  const CoverReportScreen({super.key});

  @override
  State<CoverReportScreen> createState() => _CoverReportScreenState();
}

class _CoverReportScreenState extends State<CoverReportScreen> {
  List<Cover> covers = [];

  @override
  void initState() {
    super.initState();
    _loadCovers();
  }

  // FIX 1: Added mounted guard before setState to prevent async gap crash
  Future<void> _loadCovers() async {
    try {
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('covers').get();

      if (!mounted) return;

      setState(() {
        covers = snapshot.docs.map((doc) {
          final item = doc.data() as Map<String, dynamic>;
          return Cover(
            id: doc.id,
            name: item['name'],
            type: item['type'],
            subtype: item['subtype'],
            companyId: item['company'],
            // FIX 2: Null-safe fallback for status index to prevent RangeError
            status: CoverStatus.values[item['status'] ?? 0],
            startDate: DateTime.parse(item['startDate']),
            formData: Map<String, String>.from(item['formData']),
            // FIX 3: Null-safe fallback for premium to prevent force-unwrap crash
            premium: (item['premium'] as num?)?.toDouble() ?? 0.0,
            billingFrequency: item['billingFrequency'],
            coverageType: item['coverageType'],
            insuredItemId: item['insuredItemId'],
            pdfTemplateKey: item['pdfTemplateKey'],
            expirationDate: item['endDate'] != null
                ? DateTime.parse(item['endDate'])
                : null,
            paymentStatus: '',
          );
        }).toList();
      });
    } catch (e) {
      // FIX 4: Replaced print with debugPrint (stripped in release builds)
      debugPrint('Error loading covers: $e');
    }
  }

  // FIX 5: Extracted shared PDF page builder to eliminate duplicated logic
  pw.Page _buildPdfPage(Cover cover) {
    return pw.Page(
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Policy Report',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Cover ID: ${cover.id}'),
          pw.Text('Type: ${cover.type}'),
          pw.Text('Subtype: ${cover.subtype}'),
          pw.Text('Company: ${cover.companyId}'),
          pw.Text('Status: ${cover.status}'),
          pw.Text('Start Date: ${cover.startDate}'),
          // FIX 6: Consistently use expirationDate — endDate was the wrong field
          if (cover.expirationDate != null)
            pw.Text('End Date: ${cover.expirationDate}'),
          pw.Text(
            'Premium: KES ${(cover.premium ?? 0.0).toStringAsFixed(2)}',
          ),
          pw.Text('Billing Frequency: ${cover.billingFrequency}'),
          pw.SizedBox(height: 20),
          pw.Text('Form Data:', style: pw.TextStyle(fontSize: 16)),
          // Null-safe spread on formData entries
          ...?cover.formData?.entries
              .map((e) => pw.Text('${e.key}: ${e.value}')),
        ],
      ),
    );
  }

  // FIX 7: Wrapped in try/catch and added mounted guard after await
  Future<void> _exportAllPolicies() async {
    try {
      final pdf = pw.Document();
      for (var cover in covers) {
        pdf.addPage(_buildPdfPage(cover));
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/all_policies_report.pdf');
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All policies exported as PDF')),
      );
    } catch (e) {
      debugPrint('Error exporting all policies: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  // FIX 8: Extracted individual cover export into its own method (same fixes applied)
  Future<void> _exportSingleCover(Cover cover) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(_buildPdfPage(cover));

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/policy_${cover.id}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cover ${cover.id} exported as PDF')),
      );
    } catch (e) {
      debugPrint('Error exporting cover ${cover.id}: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Policy Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportAllPolicies,
          ),
        ],
      ),
      body: covers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: covers.length,
              itemBuilder: (context, index) {
                final cover = covers[index];
                return Card(
                  child: ListTile(
                    title: Text('${cover.type} - ${cover.subtype}'),
                    subtitle: Text(
                      // FIX 6 (continued): expirationDate used consistently
                      'Status: ${cover.status}\n'
                      'End: ${cover.expirationDate ?? 'N/A'}\n'
                      'Premium: KES ${(cover.premium ?? 0.0).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: cover.status == CoverStatus.nearingExpiration
                            ? Colors.yellow[800]
                            : cover.status == CoverStatus.expired
                                ? Colors.red
                                : null,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.picture_as_pdf),
                      onPressed: () => _exportSingleCover(cover),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  List<Policy> policies = [];
  final secureStorage = const FlutterSecureStorage();
  List<Cover> covers = [];

  @override
  void initState() {
    super.initState();
    _loadCovers();
  }

Future<void> _loadCovers() async {
  try {
    // Reference to the Firestore collection
    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('covers')
        .get();

    setState(() {
      covers = snapshot.docs
          .map((doc) {
            final item = doc.data() as Map<String, dynamic>;
            return Cover(
              id: doc.id,
              name: item['name'],
              type: item['type'],
              subtype: item['subtype'],
              companyId: item['company'],
              status: CoverStatus.values[item['status']],
              startDate: DateTime.parse(item['startDate']),
              formData: Map<String, String>.from(item['formData']),
              premium: item['premium'].toDouble(),
              billingFrequency: item['billingFrequency'],
              coverageType: item['coverageType'],
              insuredItemId: item['insuredItemId'],
              pdfTemplateKey: item['pdfTemplateKey'],
              expirationDate: item['endDate'] != null
                  ? DateTime.parse(item['endDate'])
                  : null,
              paymentStatus: '',
            );
          })
          .toList();
    });
  } catch (e) {
    print('Error loading covers: $e');
    // Handle error appropriately
  }
}
  Future<void> _exportAllPolicies() async {
    final pdf = pw.Document();
    for (var cover in covers) {
      pdf.addPage(
        pw.Page(
          build:
              (pw.Context context) => pw.Column(
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
                  pw.Text('Policy ID: ${cover.id}'),
                  pw.Text('Type: ${cover.type}'),
                  pw.Text('Subtype: ${cover.subtype}'),
                  pw.Text('Company: ${cover.companyId}'),
                  pw.Text('Status: ${cover.status}'),
                  pw.Text('Start Date: ${cover.startDate}'),
                  if (cover.endDate != null)
                    pw.Text('End Date: ${cover.expirationDate}'),
                  pw.Text('Premium: KES ${cover.premium!.toStringAsFixed(2)}'),
                  pw.Text('Billing Frequency: ${cover.billingFrequency}'),
                  pw.SizedBox(height: 20),
                  pw.Text('Form Data:', style: pw.TextStyle(fontSize: 16)),
                  ...cover.formData!.entries.map(
                    (e) => pw.Text('${e.key}: ${e.value}'),
                  ),
                ],
              ),
        ),
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/all_policies_report.pdf');
    await file.writeAsBytes(await pdf.save());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All policies exported as PDF')),
    );
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: covers.length,
        itemBuilder: (context, index) {
          final cover = covers[index];
          return Card(
            child: ListTile(
              title: Text('${cover.type} - ${cover.subtype}'),
              subtitle: Text(
                'Status: ${cover.status}\nEnd: ${cover.endDate ?? 'N/A'}\nPremium: KES ${cover.premium!.toStringAsFixed(2)}',
                style: TextStyle(
                  color:
                      cover.status == CoverStatus.nearingExpiration
                          ? Colors.yellow[800]
                          : cover.status == CoverStatus.expired
                          ? Colors.red
                          : null,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () async {
                  final pdf = pw.Document();
                  pdf.addPage(
                    pw.Page(
                      build:
                          (pw.Context context) => pw.Column(
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
                              if (cover.endDate != null)
                                pw.Text('End Date: ${cover.endDate}'),
                              pw.Text(
                                'Premium: KES ${cover.premium!.toStringAsFixed(2)}',
                              ),
                              pw.Text(
                                'Billing Frequency: ${cover.billingFrequency}',
                              ),
                              pw.SizedBox(height: 20),
                              pw.Text(
                                'Form Data:',
                                style: pw.TextStyle(fontSize: 16),
                              ),
                              ...cover.formData!.entries.map(
                                (e) => pw.Text('${e.key}: ${e.value}'),
                              ),
                            ],
                          ),
                    ),
                  );

                  final directory = await getApplicationDocumentsDirectory();
                  final file = File('${directory.path}/policy_${cover.id}.pdf');
                  await file.writeAsBytes(await pdf.save());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cover ${cover.id} exported as PDF'),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

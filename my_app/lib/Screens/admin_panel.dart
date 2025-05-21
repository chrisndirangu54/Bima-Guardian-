import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fl_chart/fl_chart.dart' as charts;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_app/Models/pdf_template.dart';
import 'package:my_app/Models/policy.dart';
import 'package:my_app/insurance_app.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_app/Screens/pdf_editor.dart'; // Import PdfCoordinateEditor

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  List<Policy> policies = [];
  Map<String, PDFTemplate> cachedPdfTemplates = {};
  final secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadPolicies();
    _loadCachedPdfTemplates();
  }

  Future<void> _loadPolicies() async {
    String? data = await secureStorage.read(key: 'policies');
    if (data == null) return;
    final key = encrypt.Key.fromLength(32);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final decrypted = encrypter.decrypt64(data, iv: iv);
    setState(() {
      policies =
          (jsonDecode(decrypted) as List)
              .map((item) => Policy.fromJson(item))
              .toList();
    });
  }

  Future<void> _savePolicies() async {
    final key = encrypt.Key.fromLength(32);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(
      jsonEncode(policies.map((policy) => policy.toJson()).toList()),
      iv: iv,
    );
    await secureStorage.write(key: 'policies', value: encrypted.base64);
  }

  Future<void> _loadCachedPdfTemplates() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/pdf_templates.json');
    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString());
      setState(() {
        cachedPdfTemplates = data.map(
          (key, value) => MapEntry(key, PDFTemplate.fromJson(value)),
        );
      });
    }
  }

  Future<void> _savePdfTemplates() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/pdf_templates.json');
    await file.writeAsString(
      jsonEncode(
        cachedPdfTemplates.map((key, value) => MapEntry(key, value.toJson())),
      ),
    );
  }

  Future<Map<String, String>?> _showPolicySelectionDialog(
    BuildContext context,
  ) async {
    String? policyType;
    String? policySubtype;
    final policyTypes = ['auto', 'health', 'home'];
    final policySubtypes = {
      'auto': ['comprehensive', 'third_party'],
      'health': ['individual', 'family'],
      'home': ['standard', 'premium'],
    };

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Policy Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    hint: const Text('Policy Type'),
                    value: policyType,
                    items:
                        policyTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      setState(() {
                        policyType = value;
                        policySubtype = null; // Reset subtype when type changes
                      });
                    },
                  ),
                  if (policyType != null)
                    DropdownButton<String>(
                      hint: const Text('Policy Subtype'),
                      value: policySubtype,
                      items:
                          policySubtypes[policyType]!
                              .map(
                                (subtype) => DropdownMenuItem(
                                  value: subtype,
                                  child: Text(subtype),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() {
                          policySubtype = value;
                        });
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed:
                      policyType != null && policySubtype != null
                          ? () => Navigator.pop(context, {
                            'policyType': policyType!,
                            'policySubtype': policySubtype!,
                          })
                          : null,
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _uploadPdfTemplate() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      String templateKey = result.files.single.name.split('.').first;

      // Show policy selection dialog
      final policyDetails = await _showPolicySelectionDialog(context);
      if (policyDetails == null) return; // User canceled

      final directory = await getApplicationDocumentsDirectory();
      final templateFile = File(
        '${directory.path}/pdf_templates/$templateKey.pdf',
      );
      await File(filePath).copy(templateFile.path);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => PdfCoordinateEditor(
                pdfPath: templateFile.path,
                onSave: (coordinates, fieldDefinitions) {
                  setState(() {
                    cachedPdfTemplates[templateKey] = PDFTemplate(
                      fields: fieldDefinitions,
                      fieldMappings: fieldDefinitions.map(
                        (key, value) => MapEntry(key, key),
                      ),
                      coordinates: coordinates,
                      policyType: policyDetails['policyType']!,
                      policySubtype: policyDetails['policySubtype']!,
                      templateKey: templateKey,
                    );
                  });
                  _savePdfTemplates();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'PDF template "$templateKey" saved successfully',
                      ),
                    ),
                  );
                },
              ),
        ),
      );
    }
  }

  Future<void> _updatePolicyStatus(Policy policy, CoverStatus newStatus) async {
    setState(() {
      policies =
          policies.map((p) {
            if (p.id == policy.id) {
              return Policy(
                id: p.id,
                insuredItemId: p.insuredItemId,
                type: p.type,
                subtype: p.subtype,
                status: newStatus,
                endDate:
                    newStatus == CoverStatus.extended
                        ? p.endDate?.add(Duration(days: 365)) ??
                            DateTime.now().add(Duration(days: 365))
                        : p.endDate,

                companyId: p.companyId,
                coverageType: p.coverageType,
                pdfTemplateKey: '',
              );
            }
            return p;
          }).toList();
    });
    await _savePolicies();
    await FirebaseMessaging.instance.sendMessage(
      to: '/topics/policy_updates',
      data: {'policy_id': policy.id, 'new_status': newStatus.toString()},
    );
  }

  Future<void> _notifyPolicyExpiration(Policy policy) async {
    await FirebaseMessaging.instance.sendMessage(
      to: '/topics/policy_updates',
      data: {
        'policy_id': policy.id,
        'message':
            'Reminder: Policy ${policy.id} (${policy.type} - ${policy.subtype}) is ${policy.status == CoverStatus.expired ? 'expired' : 'nearing expiration'}',
      },
    );
  }

  List<charts.FlSpot> _createPolicyTrendDataForFlChart() {
    final groupedData =
        groupBy(
          policies,
          (Policy p) => DateTime(p.endDate!.year, p.endDate!.month),
        ).entries.map((e) => MapEntry(e.key, e.value.length)).toList();

    groupedData.sort((a, b) => a.key.compareTo(b.key));

    return groupedData.map((entry) {
      return charts.FlSpot(
        entry.key.millisecondsSinceEpoch.toDouble(),
        entry.value.toDouble(),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _uploadPdfTemplate,
              child: const Text('Upload PDF Template'),
            ),
            const SizedBox(height: 20),
            const Text(
              'PDF Templates',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cachedPdfTemplates.length,
              itemBuilder: (context, index) {
                final templateKey = cachedPdfTemplates.keys.elementAt(index);
                final template = cachedPdfTemplates[templateKey]!;
                return ListTile(
                  title: Text(
                    '$templateKey (${template.policyType} - ${template.policySubtype})',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      final directory =
                          await getApplicationDocumentsDirectory();
                      final file = File(
                        '${directory.path}/pdf_templates/$templateKey.pdf',
                      );
                      if (await file.exists()) {
                        await file.delete();
                        setState(() {
                          cachedPdfTemplates.remove(templateKey);
                        });
                        await _savePdfTemplates();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Template $templateKey deleted'),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Policies',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: policies.length,
              itemBuilder: (context, index) {
                final policy = policies[index];
                return ListTile(
                  title: Text('${policy.type} - ${policy.subtype}'),
                  subtitle: Text(
                    'Status: ${policy.status} | End: ${policy.endDate ?? 'N/A'}',
                    style: TextStyle(
                      color:
                          policy.status == CoverStatus.nearingExpiration
                              ? Colors.yellow[800]
                              : policy.status == CoverStatus.expired
                              ? Colors.red
                              : null,
                    ),
                  ),
                  trailing: DropdownButton<CoverStatus>(
                    value: policy.status,
                    items:
                        CoverStatus.values
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(status.toString().split('.').last),
                              ),
                            )
                            .toList(),
                    onChanged: (newStatus) async {
                      if (newStatus != null) {
                        await _updatePolicyStatus(policy, newStatus);
                        if (newStatus == CoverStatus.nearingExpiration ||
                            newStatus == CoverStatus.expired) {
                          await _notifyPolicyExpiration(policy);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Policy status updated to $newStatus',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Policy Trends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 200,
              child: charts.LineChart(
                charts.LineChartData(
                  gridData: const charts.FlGridData(show: true),
                  titlesData: charts.FlTitlesData(
                    show: true,
                    rightTitles: const charts.AxisTitles(
                      sideTitles: charts.SideTitles(showTitles: false),
                    ),
                    topTitles: const charts.AxisTitles(
                      sideTitles: charts.SideTitles(showTitles: false),
                    ),
                    bottomTitles: charts.AxisTitles(
                      sideTitles: charts.SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final date = DateTime.fromMillisecondsSinceEpoch(
                            value.toInt(),
                          );
                          return charts.SideTitleWidget(
                            space: 8.0,
                            meta: meta,
                            child: Text(
                              '${date.month}/${date.year % 100}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                        interval: 2592000000,
                      ),
                    ),
                    leftTitles: charts.AxisTitles(
                      sideTitles: charts.SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                        interval: 1,
                      ),
                    ),
                  ),
                  borderData: charts.FlBorderData(
                    show: true,
                    border: Border.all(
                      color: const Color(0xff37434d),
                      width: 1,
                    ),
                  ),
                  lineBarsData: [
                    charts.LineChartBarData(
                      spots: _createPolicyTrendDataForFlChart(),
                      isCurved: true,
                      color: Colors.blueAccent,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const charts.FlDotData(show: true),
                      belowBarData: charts.BarAreaData(
                        show: true,
                        color: Colors.blueAccent.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

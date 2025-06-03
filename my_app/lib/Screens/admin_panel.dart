import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fl_chart/fl_chart.dart' as charts;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/Models/field_definition.dart';
import 'package:my_app/Models/pdf_template.dart';
import 'package:my_app/Models/policy.dart';
import 'package:my_app/Screens/pdf_editor.dart';
import 'package:my_app/insurance_app.dart'; // Import PdfCoordinateEditor

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  List<Policy> policies = [];
  Map<String, PDFTemplate> cachedPdfTemplates = {};

  @override
  void initState() {
    super.initState();
    _loadPolicies();
    _loadCachedPdfTemplates();
  }

  Future<void> _loadPolicies() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('policies').get();

      setState(() {
        policies = snapshot.docs.map((doc) {
          final data = doc.data();
          return Policy(
            id: data['id'] as String,
            insuredItemId: data['insuredItemId'] as String? ?? '',
            companyId: data['companyId'] as String,
            type: PolicyType.fromJson(data['type'] as Map<String, dynamic>),
            subtype:
                PolicySubtype.fromJson(data['subtype'] as Map<String, dynamic>),
            coverageType: CoverageType.fromJson(
                data['coverageType'] as Map<String, dynamic>),
            status: CoverStatus.values.firstWhere(
              (e) => e.toString() == data['status'],
              orElse: () => CoverStatus.active,
            ),
            endDate: data['expirationDate'] != null
                ? (data['expirationDate'] as Timestamp).toDate()
                : null,
            pdfTemplateKey: data['pdfTemplateKey'] as String?, name: '',
          );
        }).toList();
      });

      if (policies.isEmpty && kDebugMode) {
        print('No policies found in Firestore.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading policies: $e');
      }
      setState(() {
        policies = [];
      });
    }
  }

  Future<void> _savePolicies() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var policy in policies) {
        final docRef =
            FirebaseFirestore.instance.collection('policies').doc(policy.id);
        batch.set(docRef, {
          'id': policy.id,
          'type': policy.type,
          'subtype': policy.subtype,
          'companyId': policy.companyId,
          'status': policy.status.toString(),
          'insuredItemId': policy.insuredItemId,
          'coverageType': policy.coverageType,
          'pdfTemplateKey': policy.pdfTemplateKey,
          'endDate': policy.endDate != null
              ? Timestamp.fromDate(policy.endDate!)
              : null,
        });
      }
      await batch.commit();
      if (kDebugMode) {
        print('Policies saved to Firestore.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving policies: $e');
      }
    }
  }

  Future<void> _loadCachedPdfTemplates() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('pdf_templates').get();

      setState(() {
        cachedPdfTemplates = Map.fromEntries(
          snapshot.docs.map(
            (doc) => MapEntry(
              doc.id,
              PDFTemplate.fromJson(doc.data()),
            ),
          ),
        );
      });

      if (cachedPdfTemplates.isEmpty) {
        // Initialize default template
        final defaultTemplate = PDFTemplate(
          templateKey: 'default',
          policyType: 'motor',
          policySubtype: 'comprehensive',
          coordinates: {
            'name': {'page': 1.0, 'x': 50.0, 'y': 50.0},
            'email': {'page': 1.0, 'x': 50.0, 'y': 70.0},
            'phone': {'page': 1.0, 'x': 50.0, 'y': 90.0},
          },
          fields: {
            'name': FieldDefinition(
                expectedType: ExpectedType.name,
                validator: (String) {
                  return null;
                }),
            'email': FieldDefinition(
                expectedType: ExpectedType.email,
                validator: (String) {
                  return null;
                }),
            'phone': FieldDefinition(
                expectedType: ExpectedType.phone,
                validator: (String) {
                  return null;
                }),
          },
          fieldMappings: {},
        );
        await FirebaseFirestore.instance
            .collection('pdf_templates')
            .doc('default')
            .set(defaultTemplate.toJson());
        setState(() {
          cachedPdfTemplates['default'] = defaultTemplate;
        });
        if (kDebugMode) {
          print('Initialized default PDF template in Firestore.');
        }
      } else {
        if (kDebugMode) {
          print('PDF templates loaded from Firestore.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading cached PDF templates: $e');
      }
      setState(() {
        cachedPdfTemplates = {};
      });
    }
  }

  Future<void> _savePdfTemplates() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      cachedPdfTemplates.forEach((key, template) {
        final docRef =
            FirebaseFirestore.instance.collection('pdf_templates').doc(key);
        batch.set(docRef, template.toJson());
      });
      await batch.commit();
      if (kDebugMode) {
        print('PDF templates saved to Firestore.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving PDF templates: $e');
      }
    }
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

      // Upload PDF to Firebase Storage
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('pdf_templates/$templateKey.pdf');
        await storageRef.putFile(File(filePath));
        final downloadUrl = await storageRef.getDownloadURL();

        // Launch PdfCoordinateEditor
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfCoordinateEditor(
              pdfPath: filePath, // Local path for editing
              onSave: (coordinates, fieldDefinitions) async {
                final template = PDFTemplate(
                  fields: fieldDefinitions,
                  fieldMappings: fieldDefinitions.map(
                    (key, value) => MapEntry(key, key),
                  ),
                  coordinates: coordinates,
                  policyType: policyDetails['policyType']!,
                  policySubtype: policyDetails['policySubtype']!,
                  templateKey: templateKey,
                );

                // Save template metadata to Firestore
                await FirebaseFirestore.instance
                    .collection('pdf_templates')
                    .doc(templateKey)
                    .set(template.toJson());

                setState(() {
                  cachedPdfTemplates[templateKey] = template;
                });

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
      } catch (e) {
        if (kDebugMode) {
          print('Error uploading PDF template: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload PDF template: $e'),
          ),
        );
      }
    }
  }

  Future<void> _updatePolicyStatus(Policy policy, CoverStatus newStatus) async {
    try {
      final updatedPolicy = Policy(
        id: policy.id,
        insuredItemId: policy.insuredItemId,
        type: policy.type,
        subtype: policy.subtype,
        status: newStatus,
        endDate: newStatus == CoverStatus.extended
            ? policy.endDate?.add(Duration(days: 365)) ??
                DateTime.now().add(Duration(days: 365))
            : policy.endDate,
        companyId: policy.companyId,
        coverageType: policy.coverageType,
        pdfTemplateKey: policy.pdfTemplateKey, name: '',
      );

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('policies')
          .doc(policy.id)
          .set({
        'id': updatedPolicy.id,
        'type': updatedPolicy.type,
        'subtype': updatedPolicy.subtype,
        'companyId': updatedPolicy.companyId,
        'status': updatedPolicy.status.toString(),
        'insuredItemId': updatedPolicy.insuredItemId,
        'coverageType': updatedPolicy.coverageType,
        'pdfTemplateKey': updatedPolicy.pdfTemplateKey,
        'endDate': updatedPolicy.endDate != null
            ? Timestamp.fromDate(updatedPolicy.endDate!)
            : null,
      });

      setState(() {
        policies =
            policies.map((p) => p.id == policy.id ? updatedPolicy : p).toList();
      });

      // Send notification
      await FirebaseMessaging.instance.sendMessage(
        to: '/topics/policy_updates',
        data: {'policy_id': policy.id, 'new_status': newStatus.toString()},
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Policy status updated to $newStatus'),
        ),
      );

      // Notify expiration if applicable
      if (newStatus == CoverStatus.nearingExpiration ||
          newStatus == CoverStatus.expired) {
        await _notifyPolicyExpiration(updatedPolicy);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating policy status: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update policy status: $e'),
        ),
      );
    }
  }

  Future<void> _notifyPolicyExpiration(Policy policy) async {
    try {
      await FirebaseMessaging.instance.sendMessage(
        to: '/topics/policy_updates',
        data: {
          'policy_id': policy.id,
          'message':
              'Reminder: Policy ${policy.id} (${policy.type} - ${policy.subtype}) is ${policy.status == CoverStatus.expired ? 'expired' : 'nearing expiration'}',
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error sending policy expiration notification: $e');
      }
    }
  }

  Future<Map<String, String>?> _showPolicySelectionDialog(
    BuildContext context,
  ) async {
    PolicyType? policyType;
    PolicySubtype? policySubtype;
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
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: Text(
                'Select Policy Details',
                style: GoogleFonts.lora(
                  color: Color(0xFF1B263B),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Policy Type',
                      labelStyle: GoogleFonts.roboto(color: Color(0xFFD3D3D3)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Color(0xFFD3D3D3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Color(0xFFD3D3D3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Color(0xFF8B0000)),
                      ),
                    ),
                    value: policyType as String?,
                    items: policyTypes
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(
                              type,
                              style:
                                  GoogleFonts.roboto(color: Color(0xFF1B263B)),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        policyType = value != null ? PolicyType.fromJson({'name': value}) : null;
                        policySubtype = null;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select a policy type' : null,
                  ),
                  if (policyType != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Policy Subtype',
                          labelStyle:
                              GoogleFonts.roboto(color: Color(0xFFD3D3D3)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Color(0xFFD3D3D3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Color(0xFFD3D3D3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Color(0xFF8B0000)),
                          ),
                        ),
                        value: policySubtype?.name,
                        items: policySubtypes[policyType]!
                            .map(
                              (subtype) => DropdownMenuItem(
                                value: subtype,
                                child: Text(
                                  subtype,
                                  style: GoogleFonts.roboto(
                                      color: Color(0xFF1B263B)),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            policySubtype = value != null ? PolicySubtype.fromJson({'name': value}) : null;
                          });
                        },
                        validator: (value) => value == null
                            ? 'Please select a policy subtype'
                            : null,
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.roboto(color: Color(0xFFD3D3D3)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (policyType != null && policySubtype != null) {
                      Navigator.pop(context, {
                        'policyType': policyType!,
                        'policySubtype': policySubtype!,
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please select both policy type and subtype',
                            style: GoogleFonts.roboto(color: Colors.white),
                          ),
                          backgroundColor: Color(0xFF8B0000),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF8B0000),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Confirm',
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<charts.FlSpot> _createPolicyTrendDataForFlChart() {
    final groupedData = groupBy(
      policies.where((p) => p.endDate != null),
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
      appBar: AppBar(
        title: Text(
          'Admin Panel',
          style: GoogleFonts.lora(
            color: Color(0xFF1B263B),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _uploadPdfTemplate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF8B0000),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Upload PDF Template',
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'PDF Templates',
              style: GoogleFonts.lora(
                color: Color(0xFF1B263B),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
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
                    style: GoogleFonts.roboto(color: Color(0xFF1B263B)),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Color(0xFF8B0000),
                    ),
                    onPressed: () async {
                      try {
                        // Delete from Firestore
                        await FirebaseFirestore.instance
                            .collection('pdf_templates')
                            .doc(templateKey)
                            .delete();
                        // Delete from Firebase Storage
                        await FirebaseStorage.instance
                            .ref('pdf_templates/$templateKey.pdf')
                            .delete();
                        setState(() {
                          cachedPdfTemplates.remove(templateKey);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Template $templateKey deleted'),
                          ),
                        );
                      } catch (e) {
                        if (kDebugMode) {
                          print('Error deleting template $templateKey: $e');
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to delete template: $e'),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Policies',
              style: GoogleFonts.lora(
                color: Color(0xFF1B263B),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: policies.length,
              itemBuilder: (context, index) {
                final policy = policies[index];
                return ListTile(
                  title: Text(
                    '${policy.type} - ${policy.subtype}',
                    style: GoogleFonts.roboto(color: Color(0xFF1B263B)),
                  ),
                  subtitle: Text(
                    'Status: ${policy.status} | End: ${policy.endDate?.toString() ?? 'N/A'}',
                    style: GoogleFonts.roboto(
                      color: policy.status == CoverStatus.nearingExpiration
                          ? Colors.yellow[800]
                          : policy.status == CoverStatus.expired
                              ? Color(0xFF8B0000)
                              : Color(0xFFD3D3D3),
                    ),
                  ),
                  trailing: DropdownButton<CoverStatus>(
                    value: policy.status,
                    items: CoverStatus.values
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(
                              status.toString().split('.').last,
                              style:
                                  GoogleFonts.roboto(color: Color(0xFF1B263B)),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (newStatus) async {
                      if (newStatus != null) {
                        await _updatePolicyStatus(policy, newStatus);
                      }
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Policy Trends',
              style: GoogleFonts.lora(
                color: Color(0xFF1B263B),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
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
                              style: GoogleFonts.roboto(
                                color: Color(0xFF1B263B),
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                        interval: 2592000000, // Approx 30 days
                      ),
                    ),
                    leftTitles: charts.AxisTitles(
                      sideTitles: charts.SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: GoogleFonts.roboto(
                              color: Color(0xFF1B263B),
                              fontSize: 10,
                            ),
                          );
                        },
                        interval: 1,
                      ),
                    ),
                  ),
                  borderData: charts.FlBorderData(
                    show: true,
                    border: Border.all(
                      color: Color(0xFF1B263B),
                      width: 1,
                    ),
                  ),
                  lineBarsData: [
                    charts.LineChartBarData(
                      spots: _createPolicyTrendDataForFlChart(),
                      isCurved: true,
                      color: Color(0xFF8B0000),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const charts.FlDotData(show: true),
                      belowBarData: charts.BarAreaData(
                        show: true,
                        color: Color(0xFF8B0000).withOpacity(0.3),
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

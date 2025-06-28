import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/Models/cover.dart';
import 'dart:convert';

// Assuming Cover class and ClaimStatus enum are defined as provided

class EmailAnalyzer {
  final String userId = 'me'; // Gmail API userId (authenticated user)
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Gmail API client setup
  Future<gmail.GmailApi> _getGmailClient() async {
    final credentials = await obtainAccessCredentialsViaUserConsent(
      ClientId('YOUR_CLIENT_ID', 'YOUR_CLIENT_SECRET'),
      ['https://www.googleapis.com/auth/gmail.readonly'],
      http.Client(),
      (url) => print('Please go to $url to authorize this app'),
    );
    final authClient = authenticatedClient(http.Client(), credentials);
    return gmail.GmailApi(authClient);
  }

  // Fetch emails from inbox or specific thread
  Future<List<gmail.Message>> _fetchEmails(String query) async {
    final gmailApi = await _getGmailClient();
    final messages = await gmailApi.users.messages.list(userId, q: query);
    final List<gmail.Message> emailDetails = [];

    for (var message in messages.messages ?? []) {
      final email = await gmailApi.users.messages.get(userId, message.id!);
      emailDetails.add(email);
    }
    return emailDetails;
  }

  // Analyze email content using ChatGPT (or similar AI model)
  Future<ClaimStatus> _analyzeEmailContent(String emailContent) async {
    final openAiApiKey = 'YOUR_OPENAI_API_KEY';
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $openAiApiKey',
    };

    final body = jsonEncode({
      'model': 'gpt-4', // or 'gpt-3.5-turbo'
      'messages': [
        {
          'role': 'system',
          'content':
              'You are an assistant that analyzes emails to determine insurance claim statuses. Read the email content and return one of the following statuses: "pending", "approved", "rejected", or "none". If the email does not mention a claim status, return "none".',
        },
        {
          'role': 'user',
          'content': emailContent,
        },
      ],
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final statusText = data['choices'][0]['message']['content'].trim();
        switch (statusText.toLowerCase()) {
          case 'pending':
            return ClaimStatus.pending;
          case 'approved':
            return ClaimStatus.approved;
          case 'rejected':
            return ClaimStatus.rejected;
          default:
            return ClaimStatus.none;
        }
      } else {
        throw Exception('Failed to analyze email: ${response.statusCode}');
      }
    } catch (e) {
      print('Error analyzing email: $e');
      return ClaimStatus.none;
    }
  }

  // Update Firestore with the claim status
  Future<void> _updateCoverStatus(String coverId, ClaimStatus status) async {
    try {
      await _firestore.collection('covers').doc(coverId).update({
        'claimStatus': status.name,
      });
      print('Updated cover $coverId with claimStatus: ${status.name}');
    } catch (e) {
      print('Error updating Firestore: $e');
    }
  }

  // Main function to analyze emails and update Firestore
  Future<void> analyzeAndUpdateClaimStatus({
    required String coverId,
    String query = 'from:insurance@example.com', // Adjust query as needed
  }) async {
    try {
      // Fetch emails based on query (e.g., from insurance company)
      final emails = await _fetchEmails(query);

      for (var email in emails) {
        // Decode email content (assuming base64 encoded)
        String emailContent = '';
        if (email.payload?.parts != null) {
          for (var part in email.payload!.parts!) {
            if (part.mimeType == 'text/plain' && part.body?.data != null) {
              emailContent = utf8.decode(base64Url.decode(part.body!.data!));
              break;
            }
          }
        } else if (email.payload?.body?.data != null) {
          emailContent =
              utf8.decode(base64Url.decode(email.payload!.body!.data!));
        }

        // Analyze email content
        final claimStatus = await _analyzeEmailContent(emailContent);

        // Update Firestore if a valid status is found
        if (claimStatus != ClaimStatus.none) {
          await _updateCoverStatus(coverId, claimStatus);
          break; // Stop after finding the first relevant email
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error processing emails: $e');
      }
    }
  }
}

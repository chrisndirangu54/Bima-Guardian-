import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;

  const NotificationsScreen({super.key, required this.notifications});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.lora(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: notifications.isEmpty
          ? Center(
              child: Text(
                'No notifications available',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                // Placeholder for refreshing notifications
                await Future.delayed(const Duration(seconds: 1));
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  // Safely access notification fields with fallbacks
                  final message = notification['message'] ??
                      notification['title'] ??
                      'Notification';
                  final body = notification['body'] ?? '';
                  final status =
                      notification['status']?.toString().toLowerCase() ??
                          'info';
                  final timestamp = notification['timestamp'] != null
                      ? _formatTimestamp(notification['timestamp'])
                      : '';

                  // Determine icon based on status
                  IconData icon;
                  switch (status) {
                    case 'expired':
                      icon = Icons.error;
                      break;
                    case 'warning':
                      icon = Icons.warning;
                      break;
                    default:
                      icon = Icons.info;
                  }

                  return Card(
                    elevation: 2.0, // Fixed: Use double instead of EdgeInsets
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      // Fixed: Removed const to allow dynamic icon
                      leading: Icon(icon), // Fixed: Use Icon widget directly
                      title: Text(
                        message,
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: body.isNotEmpty
                          ? Text(
                              body,
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                              ),
                            )
                          : null,
                      trailing: timestamp.isNotEmpty
                          ? Text(
                              timestamp,
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      // Updated to include time for clarity
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}

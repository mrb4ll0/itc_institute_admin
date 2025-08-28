import 'package:flutter/material.dart';

class NotificationPage extends StatelessWidget {
  final List<Map<String, String>> notifications = [
    {
      "title": "New Message",
      "body": "You received a new message from Admin.",
      "time": "2m ago"
    },
    {
      "title": "System Update",
      "body": "Your app was updated to the latest version.",
      "time": "1h ago"
    },
    {
      "title": "Reminder",
      "body": "Don’t forget your training tomorrow at 10 AM.",
      "time": "Yesterday"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: notifications.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return GestureDetector(
            onTap: ()
            {
              NotificationDetailsDialog.show(context, title: notification['title']!, message: notification['body']!, time: notification['time']!);
            },
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.notifications, color: Colors.blue),
                ),
                title: Text(
                  notification["title"] ?? "",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(notification["body"] ?? ""),
                trailing: Text(
                  notification["time"] ?? "",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


class NotificationDetailsDialog {
  static void show(BuildContext context, {
    required String title,
    required String message,
    required String time,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // dialog fits content
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with title + close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
              const SizedBox(height: 8),

              // Notification message
              Text(
                message,
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 16),

              // Timestamp
              Row(
                children: [
                  Icon(Icons.access_time, size: 18, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    time,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action button
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    // handle action e.g. mark as read, navigate
                    Navigator.of(context).pop();
                  },
                  child: Text("OK"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


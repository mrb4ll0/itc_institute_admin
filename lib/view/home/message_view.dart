import 'package:flutter/material.dart';

class MessagesPage extends StatelessWidget {
  final Color backgroundColor = Color(0xFF122118);
  final Color primaryGreen = Color(0xFF38E07B);
  final Color secondaryGreen = Color(0xFF264532);
  final Color borderColor = Color(0xFF366348);
  final Color textMuted = Color(0xFF96C5A9);

  final List<Map<String, String>> messages = [
    {
      "title": "Announcements",
      "subtitle": "Logbooks due by Friday",
      "icon": "megaphone",
    },
    {
      "title": "Computer Science",
      "subtitle": "Discussing project timelines",
      "icon": "hash",
    },
    {
      "title": "Business Administration",
      "subtitle": "Internship opportunities",
      "icon": "hash",
    },
    {
      "title": "General",
      "subtitle": "Upcoming events",
      "icon": "hash",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Tabs
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTab('All', true),
                _buildTab('Announcements', false),
                _buildTab('Departments', false),
              ],
            ),
          ),
          // Messages List
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final item = messages[index];
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: backgroundColor,
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: secondaryGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildIcon(item['icon']!),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title']!,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              item['subtitle']!,
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Floating Add Button
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: backgroundColor,
                shape: StadiumBorder(),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              icon: Icon(Icons.add, size: 24),
              label: Text(
                'Add Message',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),);
  }

  Widget _buildTab(String label, bool selected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : textMuted,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 4),
        Container(
          height: 3,
          width: 40,
          color: selected ? primaryGreen : Colors.transparent,
        ),
      ],
    );
  }

  Widget _buildIcon(String iconName) {
    switch (iconName) {
      case 'megaphone':
        return Icon(Icons.campaign, color: Colors.white);
      case 'hash':
        return Icon(Icons.tag, color: Colors.white);
      default:
        return Icon(Icons.circle, color: Colors.white);
    }
  }
}


import 'package:flutter/material.dart';

import 'details/approved_placements_details.dart';

class ApprovedPlacementsPage extends StatelessWidget {
  const ApprovedPlacementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final placements = [
      {
        "company": "TechCorp Ltd",
        "role": "Software Developer Intern",
        "duration": "3 Months",
        "stipend": "₦50,000 / month",
        "location": "Lagos, Nigeria",
        "startDate": "01-Sep-2025",
      },
      {
        "company": "DataSoft Inc",
        "role": "Data Analyst Trainee",
        "duration": "6 Months",
        "stipend": "₦30,000 / month",
        "location": "Abuja, Nigeria",
        "startDate": "15-Sep-2025",
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Approved Placements"),
      ),
      body: Column(
        children: [
          // 🔍 Search Box
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search placements...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),

          // 📋 List of Placements
          Expanded(
            child: ListView.builder(
              itemCount: placements.length,
              itemBuilder: (context, index) {
                final p = placements[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 3,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.business, color: Colors.white),
                    ),
                    title: Text(
                      p["role"]!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Company: ${p["company"]}"),
                        Text("Duration: ${p["duration"]}"),
                        Text("Stipend: ${p["stipend"]}"),
                        Text("Location: ${p["location"]}"),
                        Text("Start: ${p["startDate"]}"),
                      ],
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue.shade600),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlacementDetailsPage(placement: p),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';

class PendingPlacementsPage extends StatelessWidget {
  const PendingPlacementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pendingPlacements = List.generate(10, (index) => {
      "company": "Company ${index + 1}",
      "role": "Internship Role ${index + 1}",
      "duration": "${2 + index % 3} Months",
      "stipend": "₦${20_000 + (index * 5_000)} / month",
      "location": index % 2 == 0 ? "Lagos" : "Abuja",
      "submittedBy": "HR ${index + 1}",
      "submissionDate": "2025-08-${10 + index}",
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pending Placements "),
      ),
      body: Column(
        children: [
          // 🔍 Search Box
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search placements...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),

          // 📋 List of Pending Placements
          Expanded(
            child: ListView.builder(
              itemCount: pendingPlacements.length,
              itemBuilder: (context, index) {
                final p = pendingPlacements[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p["role"]!,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text("Company: ${p["company"]}",style: TextStyle(color: Colors.white),),
                        Text("Duration: ${p["duration"]}",style: TextStyle(color: Colors.white)),
                        Text("Stipend: ${p["stipend"]}",style: TextStyle(color: Colors.white)),
                        Text("Location: ${p["location"]}",style: TextStyle(color: Colors.white)),
                        Text("Submitted by: ${p["submittedBy"]}",style: TextStyle(color: Colors.white)),
                        Text("Submission Date: ${p["submissionDate"]}",style: TextStyle(color: Colors.white)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                // TODO: Approve placement logic
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Approved ${p["role"]}")),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              child: const Text("Approve"),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                // TODO: Reject placement logic
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Rejected ${p["role"]}")),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text("Reject"),
                            ),
                          ],
                        ),
                      ],
                    ),
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

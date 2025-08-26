import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PlacementDetailsPage extends StatelessWidget {
  final Map<String, String> placement;

  const PlacementDetailsPage({super.key, required this.placement});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(placement["role"]!),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Company: ${placement["company"]}", style: const TextStyle(
                color: Colors.white,
                fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Duration: ${placement["duration"]}", style: TextStyle(color: Colors.white),),
            Text("Stipend: ${placement["stipend"]}",style: TextStyle(color: Colors.white)),
            Text("Location: ${placement["location"]}",style: TextStyle(color: Colors.white)),
            Text("Start Date: ${placement["startDate"]}",style: TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Apply or Save Placement
              },
              icon: const Icon(Icons.check_circle),
              label: const Text("Apply Now"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

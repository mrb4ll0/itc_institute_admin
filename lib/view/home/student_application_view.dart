import 'package:flutter/material.dart';

class InstitutionApplicationsPage extends StatelessWidget {
  final List<Map<String, String>> applications = [
    {
      "studentName": "John Doe",
      "company": "TechSoft Ltd",
      "status": "Pending",
    },
    {
      "studentName": "Jane Smith",
      "company": "CodeWorks Inc",
      "status": "Accepted",
    },
    {
      "studentName": "Ahmed Musa",
      "company": "InnovateHub",
      "status": "Rejected",
    },
  ];

  InstitutionApplicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Student Applications",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: DataTable(
            columnSpacing: 20,
            headingRowColor: WidgetStateColor.resolveWith(
                  (states) => Colors.blue.shade50,
            ),
            border: TableBorder.all(color: Colors.grey.shade300),
            columns: const [
              DataColumn(
                label: Text("Student",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              DataColumn(
                label: Text("Company",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              DataColumn(
                label: Text("Status",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
            rows: applications.map((app) {
              Color statusColor;
              switch (app["status"]) {
                case "Accepted":
                  statusColor = Colors.green;
                  break;
                case "Rejected":
                  statusColor = Colors.red;
                  break;
                default:
                  statusColor = Colors.orange;
              }

              return DataRow(
                cells: [
                  DataCell(Text(app["studentName"] ?? "")),
                  DataCell(Text(app["company"] ?? "")),
                  DataCell(
                    Text(
                      app["status"] ?? "",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

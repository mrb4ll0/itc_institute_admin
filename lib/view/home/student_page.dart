import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StudentsPage extends StatelessWidget {
  const StudentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bgDark = const Color(0xFF122118);
    final bgMid = const Color(0xFF264532);
    final bgLight = const Color(0xFF1B3124);
    final textMuted = const Color(0xFF96C5A9);

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search by name or matric number",
                  hintStyle: TextStyle(color: textMuted),
                  prefixIcon: Icon(Icons.search, color: textMuted),
                  filled: true,
                  fillColor: bgMid,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Student list
            Expanded(
              child: ListView(
                children: const [
                  StudentCard(
                    name: "Aisha Bello",
                    matric: "2021/CS/001",
                    department: "Computer Science",
                    year: "3",
                    company: "Tech Solutions Inc.",
                    supervisor: "Dr. Adebayo",
                    imageUrl:
                    "https://lh3.googleusercontent.com/aida-public/AB6AXuBCreQLtYtdoVGtUg3rK0MqQy9c_2ZOObCajg2Q1JorYVtzR097H0LpNpqib6rP2nXFj3euTbI3O6HaPqdgl0xKJ952HKtxdkCrV1BJadKx2dZq8kITernzJ8ksamUsrW_pXY-ODuJ_kVbV_kIiwn5H9iXJOMO9a8d7wAeEOTaTZvR02B-P2uA6XsxghwloB9VMNqFV3jBlFpcUMVUCaCc_ACR0ZbGTfqAIYZ-mOsy1daHPvPVyknYjeOHwXCT8_2ndutUK1O2UQXw",
                  ),
                  StudentCard(
                    name: "Chukwudi Okoro",
                    matric: "2020/EE/002",
                    department: "Electrical Engineering",
                    year: "4",
                    company: "Power Systems Ltd.",
                    supervisor: "Prof. Eze",
                    imageUrl:
                    "https://lh3.googleusercontent.com/aida-public/AB6AXuCaMUcvOx-rxECh32H9W8gAIclM5FwVFHBp-xm4MR64d3S_tGfkmLPGvgnrYfnH7J6xF0mAy-agOY99XpR1ovwzXEOt36B1A5eqeS65YWOU7F3Uyegq9QCWcLdwoeyvKZIK52-IZ24UN0jfRBe4QZMpT0pgfY-v7p529fG5L8ClWimH-STQoLksf48Ewk6qTIZ1LVlr_bPiTGXjLMyGmggArptjRDHBmF4RVInmo6Ahkaw6a9n7osSaUdI5nf-WGLqZzY5LGkrBZcg",
                  ),
                  StudentCard(
                    name: "Fatima Hassan",
                    matric: "2022/ME/003",
                    department: "Mechanical Engineering",
                    year: "2",
                    company: "Auto Manufacturing Co.",
                    supervisor: "Engr. Musa",
                    imageUrl:
                    "https://lh3.googleusercontent.com/aida-public/AB6AXuBBdOsOwDji1oufFlOp9H-mlaSjtNRLrV3MF75OCBwpHNMrv2CRbgM_GHUYzfjh2aZJQ-WyPT-SLydNoMr8jGcIYmczhDo7PZWnwuedzLW70z242e2YJn1yjTWsOJVxhbxsWCDiO6WPjitFYDXYSFIYtJ-rPvLcCF-ABSAzqPgyHSl4LrR_bFJcoXKZKLtgVnISAA4SC_517MQNG11HJogOtW8mqzJYj3qh1zKjiY3TtPWFDDhslY3oZ-6Jw21F8dr2Z5eq40WCtLI",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentCard extends StatelessWidget {
  final String name, matric, department, year, company, supervisor, imageUrl;

  const StudentCard({
    super.key,
    required this.name,
    required this.matric,
    required this.department,
    required this.year,
    required this.company,
    required this.supervisor,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = const Color(0xFF96C5A9);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with avatar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFF122118),
          child: Row(
            children: [
              CircleAvatar(radius: 28, backgroundImage: NetworkImage(imageUrl)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                  Text("Matric: $matric", style: TextStyle(color: textMuted, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),

        // Details
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF366348))),
          ),
          child: Column(
            children: [
              _infoRow("Department", department, textMuted),
              _infoRow("Year", year, textMuted),
              _infoRow("Placement Company", company, textMuted),
              _infoRow("Supervisor", supervisor, textMuted),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, Color muted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: muted, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }
}

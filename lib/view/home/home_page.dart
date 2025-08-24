import 'package:flutter/material.dart';

import '../../logic/model/institution_model.dart';

class InstitutionHomePage extends StatefulWidget
{
  final Institution institution;
  const InstitutionHomePage({super.key, required this.institution});

  @override
  State<InstitutionHomePage> createState() => _InstitutionHomePageState();
}

class _InstitutionHomePageState extends State<InstitutionHomePage> {

  TextEditingController _textEditingController = TextEditingController();
  String query = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.school, color: Colors.red,),
            SizedBox(width: 10,),
             Text(widget.institution.name),
          ],
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            SearchBox(controller: _textEditingController,
                onChanged: (value)
            {
              setState(() {
                query = value;
              });
            }),            // Section 1: Registered Students
            _buildSectionHeader(
              context,
              title: "Registered Students",
              onViewMore: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AllStudentsPage(title: "Registered Students")),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildStudentList(context, isApplied: false),

            const SizedBox(height: 24),

            // Section 2: Students Applied for IT
            _buildSectionHeader(
              context,
              title: "IT Applications",
              onViewMore: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AllStudentsPage(title: "IT Applications")),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildStudentList(context, isApplied: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context,
      {required String title, required VoidCallback onViewMore}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(
          onPressed: onViewMore,
          child: const Text("View More"),
        )
      ],
    );
  }

  // Dummy data preview list (4 only)
  Widget _buildStudentList(BuildContext context, {required bool isApplied}) {
    final dummyStudents = List.generate(
      4,
          (i) => {
        "name": isApplied ? "Applicant $i" : "Student $i",
        "matric": "MAT${1000 + i}",
      },
    );

    return Column(
      children: dummyStudents
          .map((student) => Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(student["name"]!),
          subtitle: Text("Matric: ${student["matric"]}"),
        ),
      ))
          .toList(),
    );
  }
}

// Separate page for full student list
class AllStudentsPage extends StatefulWidget {
  final String title;
  const AllStudentsPage({super.key, required this.title});

  @override
  State<AllStudentsPage> createState() => _AllStudentsPageState();
}

class _AllStudentsPageState extends State<AllStudentsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> students = [];

  @override
  void initState() {
    super.initState();
    students = List.generate(
      20,
          (i) => {
        "name": "${widget.title} User $i",
        "matric": "MAT${2000 + i}",
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Search by name or matric number...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),

          // List
          Expanded(
            child: ListView(
              children: students
                  .where((student) =>
              student["name"]!
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase()) ||
                  student["matric"]!
                      .toLowerCase()
                      .contains(_searchController.text.toLowerCase()))
                  .map((student) => Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(student["name"]!),
                  subtitle: Text("Matric: ${student["matric"]}"),
                ),
              ))
                  .toList(),
            ),
          )
        ],
      ),
    );
  }
}


class SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final String hintText;

  const SearchBox({
    Key? key,
    required this.controller,
    required this.onChanged,
    this.hintText = "Search...",
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,
          icon: const Icon(Icons.search, color: Colors.green),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Colors.red),
            onPressed: () {
              controller.clear();
              onChanged('');
            },
          )
              : null,
        ),
      ),
    );
  }
}

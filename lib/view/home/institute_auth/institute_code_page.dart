import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:itc_institute_admin/logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/view/home/home_page.dart';

import '../../../logic/model/institution_model.dart';
import 'institute_registration.dart';

class InstitutionCodePage extends StatefulWidget {
  @override
  _InstitutionCodePageState createState() => _InstitutionCodePageState();
}

class _InstitutionCodePageState extends State<InstitutionCodePage> {
  final TextEditingController _codeController = TextEditingController();

  void _verifyCode() async {
    String code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter your ITC code")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Verifying ITC code: $code")),
      );
      Institution? institution =
      await InstitutionService().verifyInstitutionCode(code);
      if (institution != null) {
        Navigator.push(context, MaterialPageRoute(builder: (context) {
          return InstitutionDashboardPage();
        }));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Incorrect Code: $code")),
        );
      }
    }
  }

  void _registerInstitution() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegisterInstitutionPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D3B2E), // Dark green background
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D3B2E),
        elevation: 0,
        title: Text(
          "Institution Access",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome Institution",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Enter your unique ITC-generated code to continue. "
                  "If you don’t have one, please register your institution first.",
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 20),

            // Code input inside card
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: TextField(
                  cursorColor: Colors.black,
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: "ITC Code",
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Verify button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _verifyCode,
                icon: const Icon(Icons.verified_outlined, color: Colors.white),
                label: Text(
                  "Verify Code",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            Center(
              child: TextButton(
                onPressed: _registerInstitution,
                child: Text(
                  "Register Institution",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

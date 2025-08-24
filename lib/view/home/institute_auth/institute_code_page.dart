import 'package:flutter/material.dart';
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
      Institution? institution = await InstitutionService().verifyInstitutionCode(code);
      if (institution != null)
        {
          Navigator.push(context, MaterialPageRoute(builder: (context)
          {
            return InstitutionHomePage(institution: institution);
          }));
        }
      else
        {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Incorrect Code: $code")),
          );
        }
    }
  }

  void _registerInstitution() {
    // TODO: Navigate to institution registration page
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegisterInstitutionPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Institution Access"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome Institution",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Enter your unique ITC-generated code to continue. "
                  "If you don’t have one, please register your institution first.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),

            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: "ITC Code",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),

            ElevatedButton(
              onPressed: _verifyCode,
              child: Text("Verify Code"),
            ),
            SizedBox(height: 10),

            TextButton(
              onPressed: _registerInstitution,
              child: Text("Register Institution"),
            ),
          ],
        ),
      ),
    );
  }
}


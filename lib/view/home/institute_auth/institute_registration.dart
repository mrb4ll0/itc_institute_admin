import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../logic/firebase/general_cloud.dart';
import '../../../logic/model/institution_model.dart';

class RegisterInstitutionPage extends StatefulWidget {
  const RegisterInstitutionPage({super.key});

  @override
  _RegisterInstitutionPageState createState() {
    return _RegisterInstitutionPageState();
  }
}

class _RegisterInstitutionPageState extends State<RegisterInstitutionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _shortNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedType;

  final List<String> _institutionTypes = [
    "University",
    "Polytechnic",
    "College"
  ];

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {

      String universityCode = generateInstitutionCode(_shortNameController.text.trim());
      final newInstitution = Institution(
        institutionCode: universityCode,
        id: "",
        name: _nameController.text.trim(),
        shortName: _shortNameController.text.trim(),
        type: _selectedType!,
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        country: _countryController.text.trim(),
        localGovernment: "",
        contactEmail: _emailController.text.trim(),
        contactPhone: _phoneController.text.trim(),
        website: "",
        logoUrl: "",
        accreditationStatus: "Provisional",
        establishedYear: DateTime.now().year,
        faculties: [],
        departments: [],
        programsOffered: [],
        admissionRequirements: "",
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final service = InstitutionService();
      final id = await service.addInstitution(newInstitution);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Institution registered successfully with id $id")),
      );
      showUniversityCodeDialog(context, universityCode);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
      keyboardType: keyboardType,
    );
  }

  Widget _verticalSpace([double height = 16]) => SizedBox(height: height);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Register Institution"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Card(
          elevation: 3,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Register Your Institution",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  _verticalSpace(20),

                  _buildTextField(
                    controller: _nameController,
                    label: "Institution Name",
                    validator: (v) =>
                    v!.isEmpty ? "Please enter institution name" : null,
                  ),
                  _verticalSpace(),

                  _buildTextField(
                    controller: _shortNameController,
                    label: "Short Name (Acronym)",
                    validator: (v) =>
                    v!.isEmpty ? "Please enter acronym" : null,
                  ),
                  _verticalSpace(),

                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: "Institution Type",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    value: _selectedType,
                    items: _institutionTypes
                        .map((type) =>
                        DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedType = val),
                    validator: (v) =>
                    v == null ? "Please select institution type" : null,
                  ),
                  _verticalSpace(),

                  _buildTextField(
                    controller: _addressController,
                    label: "Address",
                    validator: (v) =>
                    v!.isEmpty ? "Please enter address" : null,
                  ),
                  _verticalSpace(),

                  _buildTextField(
                    controller: _cityController,
                    label: "City",
                  ),
                  _verticalSpace(),

                  _buildTextField(
                    controller: _stateController,
                    label: "State",
                    validator: (v) => v!.isEmpty ? "Please enter state" : null,
                  ),
                  _verticalSpace(),

                  _buildTextField(
                    controller: _countryController,
                    label: "Country",
                    validator: (v) =>
                    v!.isEmpty ? "Please enter country" : null,
                  ),
                  _verticalSpace(),

                  _buildTextField(
                    controller: _emailController,
                    label: "Contact Email",
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                    v!.isEmpty ? "Please enter email" : null,
                  ),
                  _verticalSpace(),

                  _buildTextField(
                    controller: _phoneController,
                    label: "Contact Phone",
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                    v!.isEmpty ? "Please enter phone number" : null,
                  ),
                  _verticalSpace(24),

                  ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      padding:
                      EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      "Register Institution",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  void showUniversityCodeDialog(BuildContext context, String universityCode) {
    showDialog(
      context: context,
      barrierDismissible: false, // prevent closing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.school, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(child: Text("University Registered")),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Your university has been successfully registered!",
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                "Your Login Code:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              SelectableText(
                universityCode,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Please save this code. You'll need it to log in.",
                style: TextStyle(color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text("Copy"),
              onPressed: () {
                // copy to clipboard
                Clipboard.setData(ClipboardData(text: universityCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Code copied to clipboard")),
                );
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

}

String generateInstitutionCode(String shortName) {
  final random = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
  return "${shortName.toUpperCase()}-$random";
}
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/model/internship_model.dart';
import 'package:path_provider/path_provider.dart';

import '../../../firebase_cloud_storage/firebase_cloud.dart';
import '../../../model/company.dart';

class CreateIndustrialTrainingPage extends StatefulWidget {
  const CreateIndustrialTrainingPage({super.key});

  @override
  State<CreateIndustrialTrainingPage> createState() =>
      _CreateIndustrialTrainingPageState();
}

class _CreateIndustrialTrainingPageState
    extends State<CreateIndustrialTrainingPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _intakeController = TextEditingController();
  final TextEditingController _stipendController = TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();

  final Company_Cloud company_cloud = Company_Cloud();
  final ITCFirebaseLogic _itcFirebaseLogic = ITCFirebaseLogic();

  final FirebaseUploader firebaseUploader = FirebaseUploader();

  String? _aptitudeTest;
  String? _status;
  String? _formUsage;
  List<PlatformFile> _selectedFiles = [];
  bool _isLoading = false;
  String? _companyLogoUrl;
  String? _companyName;
  String? _companyId;

  final List<String> _statusOptions = ['Open', 'Closed'];
  final List<String> _aptitudeTestOptions = ['Yes', 'No'];
  final List<String> _formUsageOptions = ['universal', 'single'];

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
    _formUsage = _formUsageOptions[0]; // Default to universal
    _status = _statusOptions[0]; // Default to Open
  }

  Future<void> _loadCompanyData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(user.uid)
          .get();

      if (companyDoc.exists) {
        final data = companyDoc.data()!;
        setState(() {
          _companyId = user.uid;
          _companyName = data['companyName'] ?? 'Company';
          _companyLogoUrl = data['logoUrl'] ?? data['profileImage'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading company data: $e');
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      _showError('Error picking files: $e');
    }
  }

  Future<List<String>> _uploadFiles() async {
    List<String> downloadUrls = [];

    if (_selectedFiles.isEmpty) {
      return downloadUrls;
    }

    try {
      // Convert PlatformFiles to Files
      List<File> filesToUpload = await _convertPlatformFilesToFiles(
        _selectedFiles,
      );

      if (filesToUpload.isEmpty) {
        throw Exception('No valid files to upload');
      }

      // Call uploadMultipleFiles with converted Files
      downloadUrls = await firebaseUploader.uploadMultipleFiles(
        filesToUpload,
        _companyId ?? FirebaseAuth.instance.currentUser!.uid,
        'training_opportunities',
      );

      // Clear files after successful upload
      setState(() {
        _selectedFiles.clear();
      });

      print('Successfully uploaded ${downloadUrls.length} files');
    } catch (e) {
      print('Error in _uploadFiles: $e');
      _showError('Failed to upload files: $e');
    }

    return downloadUrls;
  }

  Future<List<File>> _convertPlatformFilesToFiles(
    List<PlatformFile> platformFiles,
  ) async {
    List<File> files = [];

    for (final platformFile in platformFiles) {
      try {
        File? file = await _convertSinglePlatformFile(platformFile);
        if (file != null && await file.exists()) {
          files.add(file);
        }
      } catch (e) {
        print('Failed to convert ${platformFile.name}: $e');
      }
    }

    return files;
  }

  Future<File?> _convertSinglePlatformFile(PlatformFile platformFile) async {
    try {
      // Method 1: If path exists
      if (platformFile.path != null) {
        final file = File(platformFile.path!);
        if (await file.exists()) {
          return file;
        }
      }

      // Method 2: If bytes exist, create temp file
      if (platformFile.bytes != null) {
        final tempDir = await getTemporaryDirectory();
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${platformFile.name}';
        final tempFile = File('${tempDir.path}/$fileName');

        await tempFile.writeAsBytes(platformFile.bytes!);
        return tempFile;
      }

      return null;
    } catch (e) {
      print('Error converting ${platformFile.name}: $e');
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_aptitudeTest == null) {
      _showError('Please select if aptitude test is required');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload files if any
      List<String> attachmentUrls = [];
      if (_selectedFiles.isNotEmpty) {
        attachmentUrls = await _uploadFiles();
      }
      Company? company = await _itcFirebaseLogic.getCompany(
        FirebaseAuth.instance.currentUser!.uid,
      );

      if (company == null) {
        Fluttertoast.showToast(
          msg: "Company account not found, kidly re-login",
        );
      }
      debugPrint("form usage: $_formUsage");
      if (_formUsage == 'universal') {
        await company_cloud.updateCompanyForm(
          FirebaseAuth.instance.currentUser!.uid,
          attachmentUrls,
        );
      }

      IndustrialTraining it = IndustrialTraining(
        company: company!,
        title: _titleController.text.trim(),
        industry: company?.industry ?? "",
        duration: null,
        startDate: null,
        endDate: null,
        department: _departmentController.text.trim(),
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
        applicationsCount: 0,
        intake: int.tryParse(_intakeController.text.trim()) ?? 0,
        status: _status!.toLowerCase(),
        stipendAvailable:
            _stipendController.text.trim() != null &&
            _stipendController.text.trim().isNotEmpty,
        stipend: _stipendController.text.trim(),
        eligibilityCriteria: _skillsController.text.trim(),
        files: _formUsage != 'universal' ? attachmentUrls : [],
        aptitudeTestRequired: _aptitudeTest == 'Yes',
        isTemplate: _formUsage == 'universal',
        isUniversalForm: _formUsage == 'universal',
        contactPerson: _contactPersonController.text.trim(),
      );

      // If it's a universal template, also save to templates collection
      if (_formUsage == 'universal') {
        await FirebaseFirestore.instance
            .collection('training_templates')
            .doc(_companyId)
            .set({
              'template': it.toMap(),
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
      await company_cloud.postInternship(it);
      // Show success message
      _showSuccess('Training opportunity posted successfully!');

      // Clear form after successful submission
      _clearForm();
    } catch (e) {
      _showError('Failed to post training opportunity: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _departmentController.clear();
    _locationController.clear();
    _descriptionController.clear();
    _skillsController.clear();
    _intakeController.clear();
    _stipendController.clear();
    _contactPersonController.clear();
    setState(() {
      _selectedFiles.clear();
      _aptitudeTest = null;
      _status = _statusOptions[0];
      _formUsage = _formUsageOptions[0];
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Widget _buildFilePreview() {
    if (_selectedFiles.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Selected Files:',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ..._selectedFiles.asMap().entries.map((entry) {
          final index = entry.key;
          final file = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Icon(
                  _getFileIcon(file.extension),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${(file.size / 1024).toStringAsFixed(2)} KB',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Theme.of(context).colorScheme.error,
                  onPressed: () => _removeFile(index),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0f1323)
          : const Color(0xFFf8f9fa),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Post Industrial Training Opportunity',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF343a40),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Fill in the details below to publish a new industrial training opportunity.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF6c757d),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Form Container
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1a2036)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF343a40)
                                : const Color(0xFFdee2e6),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Opportunity Details',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF343a40),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Grid Layout
                            Column(
                              children: [
                                // Training Title
                                _buildTextField(
                                  label: 'Training Title',
                                  controller: _titleController,
                                  hintText:
                                      'e.g., Software Development Trainee',
                                  isRequired: true,
                                  icon: Icons.title,
                                ),
                                const SizedBox(height: 16),

                                // Department
                                _buildTextField(
                                  label: 'Specify Department',
                                  controller: _departmentController,
                                  hintText: 'Enter department name',
                                  isRequired: true,
                                  icon: Icons.business,
                                ),
                                const SizedBox(height: 16),

                                // Location
                                _buildTextField(
                                  label: 'Location',
                                  controller: _locationController,
                                  hintText: 'e.g., Kwara State, Ilorin',
                                  isRequired: true,
                                  icon: Icons.location_on,
                                ),
                                const SizedBox(height: 16),

                                // Description
                                _buildTextArea(
                                  label: 'Description',
                                  controller: _descriptionController,
                                  hintText:
                                      'Provide a detailed description of the training...',
                                  isRequired: true,
                                  maxLines: 5,
                                ),
                                const SizedBox(height: 16),

                                // Required Skills
                                _buildTextArea(
                                  label: 'Required Skills/Qualifications',
                                  controller: _skillsController,
                                  hintText:
                                      'List required skills, e.g., Java, Python, Project Management',
                                  maxLines: 4,
                                ),
                                const SizedBox(height: 16),

                                // Row for Aptitude Test and Intake
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdown(
                                        label: 'Aptitude Test',
                                        value: _aptitudeTest,
                                        items: _aptitudeTestOptions,
                                        onChanged: (value) {
                                          setState(() {
                                            _aptitudeTest = value;
                                          });
                                        },
                                        isRequired: true,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildTextField(
                                        label: 'Intake',
                                        controller: _intakeController,
                                        hintText: 'e.g., 5',
                                        isRequired: true,
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Row for Stipend and Status
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        label: 'Stipend Offered',
                                        controller: _stipendController,
                                        hintText:
                                            "e.g., \$1000/month or 'Unpaid'",
                                        isRequired: true,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildDropdown(
                                        label: 'Status',
                                        value: _status,
                                        items: _statusOptions,
                                        onChanged: (value) {
                                          setState(() {
                                            _status = value;
                                          });
                                        },
                                        isRequired: true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Contact Person
                                _buildTextField(
                                  label: 'Contact Person',
                                  controller: _contactPersonController,
                                  hintText: 'e.g., John Doe - hr@company.com',
                                  isRequired: true,
                                  icon: Icons.person,
                                ),
                                const SizedBox(height: 24),

                                // File Upload Section
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Attach Files',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    const SizedBox(height: 8),

                                    GestureDetector(
                                      onTap: _pickFiles,
                                      child: DottedBorder(
                                        options: CustomPathDottedBorderOptions(
                                          color: const Color(0xFFcbd5e0),
                                          strokeWidth: 2,
                                          dashPattern: const [5, 3],
                                          customPath: (size) => Path()
                                            ..moveTo(0, size.height)
                                            ..relativeLineTo(size.width, 0),
                                        ),

                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(32),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF2d3448)
                                                : const Color(0xFFf8f9fa),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.cloud_upload,
                                                size: 48,
                                                color: const Color(0xFF6c757d),
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'Click to upload or drag and drop',
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: const Color(
                                                        0xFF6c757d,
                                                      ),
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'PDF, DOC, DOCX, JPG, PNG (Max. 10MB each)',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: const Color(
                                                        0xFF6c757d,
                                                      ),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    _buildFilePreview(),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Form Usage Options
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Form Usage',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    ..._formUsageOptions.map((option) {
                                      final isSelected = _formUsage == option;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Radio<String>(
                                              value: option,
                                              groupValue: _formUsage,
                                              onChanged: (value) {
                                                setState(() {
                                                  _formUsage = value;
                                                });
                                              },
                                              activeColor: const Color(
                                                0xFF005f73,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    option == 'universal'
                                                        ? 'Use as Universal Form Template'
                                                        : 'Use for Single Posting Only',
                                                    style: theme
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    option == 'universal'
                                                        ? 'Save this form as a template for future postings. You can reuse it across multiple departments.'
                                                        : 'Post this opportunity only to the specified department above.',
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: const Color(
                                                            0xFF6c757d,
                                                          ),
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                                const SizedBox(height: 32),

                                // Submit Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _submitForm,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF005f73),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 32,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Submit',
                                                style: theme.textTheme.bodyLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.send,
                                                size: 20,
                                                color: Colors.white,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isRequired)
              const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: isDark ? const Color(0xFF2d3448) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF343a40)
                    : const Color(0xFFdee2e6),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF343a40)
                    : const Color(0xFFdee2e6),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF005f73), width: 2),
            ),
            prefixIcon: icon != null
                ? Icon(icon, color: const Color(0xFF6c757d))
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.white : const Color(0xFF343a40),
          ),
          validator: (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return 'This field is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTextArea({
    required String label,
    required TextEditingController controller,
    required String hintText,
    bool isRequired = false,
    int maxLines = 3,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isRequired)
              const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: isDark ? const Color(0xFF2d3448) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF343a40)
                    : const Color(0xFFdee2e6),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF343a40)
                    : const Color(0xFFdee2e6),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF005f73), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.white : const Color(0xFF343a40),
          ),
          validator: (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return 'This field is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    bool isRequired = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isRequired) const Text(' *', style: TextStyle(color: Colors.red)),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2d3448) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF343a40) : const Color(0xFFdee2e6),
            ),
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: value,
            items: items.map((item) {
              return DropdownMenuItem<String>(value: item, child: Text(item));
            }).toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              hintText: 'Select an option',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white : const Color(0xFF343a40),
            ),
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6c757d)),
            validator: (value) {
              if (isRequired && value == null) {
                return 'Please select an option';
              }
              return null;
            },
            dropdownColor: isDark ? const Color(0xFF2d3448) : Colors.white,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _departmentController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _skillsController.dispose();
    _intakeController.dispose();
    _stipendController.dispose();
    _contactPersonController.dispose();
    super.dispose();
  }
}

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/model/internship_model.dart';
import 'package:itc_institute_admin/view/home/industrailTraining/fileDetails.dart';
import 'package:path_provider/path_provider.dart';

import '../../../firebase_cloud_storage/firebase_cloud.dart';
import '../../../model/company.dart';
import '../../../model/companyForm.dart';


class CreateIndustrialTrainingPage extends StatefulWidget {
  final bool isAuthority;
  const CreateIndustrialTrainingPage({super.key, required this.isAuthority});

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
  List<String> _existingFormFiles = [];
  bool _isLoading = false;
  bool _loadingExistingForms = false;
  String? _companyLogoUrl;
  String? _companyName;
  String? _companyId;
  List<CompanyForm> _existingForms = [];
  List<CompanyForm>? _selectedForm;
  bool _showExistingForms = false;

  final List<String> _statusOptions = ['Open', 'Closed'];
  final List<String> _aptitudeTestOptions = ['Yes', 'No'];
  final List<String> _formUsageOptions = [
    'Use existing categorized form',
    'Upload new form',
  ];

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
    _formUsage = _formUsageOptions[1]; // Default to Universal template
    _status = _statusOptions[0]; // Default to Open
  }

  Future<void> _loadCompanyData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final companyDoc = await FirebaseFirestore.instance.collection("users").doc("companies")
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

        // Load existing forms after company data is loaded
        _loadExistingForms();
      }
    } catch (e) {
      print('Error loading company data: $e');
    }
  }

  Future<void> _loadExistingForms() async {
    if (_companyId == null) return;

    setState(() {
      _loadingExistingForms = true;
    });

    try {
      final forms = await company_cloud.getCompanyForms(_companyId!);
      debugPrint("existing form ${forms.length}");
      setState(() {
        _existingForms = forms;
        _loadingExistingForms = false;
      });
    } catch (e) {
      print('Error loading existing forms: $e');
      setState(() {
        _loadingExistingForms = false;
      });
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

    if (_selectedFiles.isEmpty && _existingFormFiles.isEmpty) {
      return downloadUrls;
    }

    try {
      // Upload new files if any
      if (_selectedFiles.isNotEmpty) {
        List<File> filesToUpload = await _convertPlatformFilesToFiles(
          _selectedFiles,
        );

        if (filesToUpload.isNotEmpty) {
          List<String> newUrls = await firebaseUploader.uploadMultipleFiles(
            filesToUpload,
            _companyId ?? FirebaseAuth.instance.currentUser!.uid,
            'training_opportunities',
          );
          downloadUrls.addAll(newUrls);
        }
      }

      // Add existing form files if selected
      if (_selectedForm != null ) {
        for(CompanyForm form in _selectedForm!)
          {
            downloadUrls.add(form.downloadUrl!);
          }

      } else if (_existingFormFiles.isNotEmpty) {
        downloadUrls.addAll(_existingFormFiles);
      }

      // Clear files after successful upload
      setState(() {
        _selectedFiles.clear();
      });

      print('Successfully prepared ${downloadUrls.length} files');
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
      // Prepare files based on form usage selection
      List<String> attachmentUrls = [];

      if (_formUsage == _formUsageOptions[0]) {
        // Use existing categorized form
        if (_selectedForm == null && _existingFormFiles.isEmpty) {
          _showError('Please select an existing form or upload files');
          setState(() { _isLoading = false; });
          return;
        }
        debugPrint("_selectedForm size is ${_selectedForm?.length}");
        for(CompanyForm  form in _selectedForm!)

          {
            if(form.downloadUrl == null)continue;
            attachmentUrls.add(form.downloadUrl!);
          }


      } else if (_formUsage == _formUsageOptions[1]) {
        // Upload new form
        if (_selectedFiles.isEmpty) {
          _showError('Please upload at least one file for the new form');
          setState(() { _isLoading = false; });
          return;
        }
        attachmentUrls = await _uploadFiles();

        // Save the new form as a categorized form for future use
        if (attachmentUrls.isNotEmpty) {
          final newForm = CompanyForm(
            formId: 'form_${DateTime.now().millisecondsSinceEpoch}',
            companyId: _companyId!,
            fileName: '${_departmentController.text.trim()} - ${DateTime.now().toLocal()}',
            departmentName: _departmentController.text.trim(),
            downloadUrl: attachmentUrls.first, // Use first file as main form
            uploadedAt: DateTime.now(),
          );

          await company_cloud.addCompanyForm(_companyId!, newForm);
        }
      } else {
        // Universal template - upload files if any
        if (_selectedFiles.isNotEmpty) {
          attachmentUrls = await _uploadFiles();
        }
      }

      Company? company = await _itcFirebaseLogic.getCompany(
        FirebaseAuth.instance.currentUser!.uid,
      );

      if (company == null) {
        Fluttertoast.showToast(
          msg: "Company account not found, kindly re-login",
        );
        setState(() { _isLoading = false; });
        return;
      }

      debugPrint("form usage: $_formUsage");


      IndustrialTraining it = IndustrialTraining(
        company: company,
        title: _titleController.text.trim(),
        industry: company.industry ?? "",
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
        files: attachmentUrls,
        aptitudeTestRequired: _aptitudeTest == 'Yes',
        contactPerson: _contactPersonController.text.trim(),
      );
         debugPrint("internship details ${it.files?.length}");
      await company_cloud.postInternship(it,isAuthority:widget.isAuthority);

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
      _existingFormFiles.clear();
      _selectedForm = null;
      _aptitudeTest = null;
      _status = _statusOptions[0];
      _formUsage = _formUsageOptions[0];
      _showExistingForms = false;
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

  void _removeExistingFile(int index) {
    setState(() {
      _existingFormFiles.removeAt(index);
    });
  }

  void _selectForm(List<CompanyForm> form) {
    setState(() {
      _selectedForm = form;
      _existingFormFiles.clear();

        for(CompanyForm form in form)
          {
            _existingFormFiles.add(form.downloadUrl!);
          }

      _showExistingForms = false;
    });
  }

  void _clearFormSelection() {
    setState(() {
      _selectedForm = null;
      _existingFormFiles.clear();
    });
  }
   String? _selectedDepartment;
  Widget _buildExistingFormsSelector() {
    if (_loadingExistingForms) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_existingForms.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'No existing forms available. Upload a new form first.',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Group forms by department
    final Map<String, List<CompanyForm>> formsByDepartment = {};
    for (final form in _existingForms) {
      final department = form.departmentName ?? 'Uncategorized';
      if (!formsByDepartment.containsKey(department)) {
        formsByDepartment[department] = [];
      }
      formsByDepartment[department]!.add(form);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select a categorized form:',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        const SizedBox(height: 12),

        if (_selectedForm != null)
          InkWell(
            onTap: () {
              if (_selectedForm == null ) return;
              // Show dialog with all files in this department
              _showDepartmentFilesDialog(
                _selectedForm?.first.departmentName ?? 'Uncategorized',
                formsByDepartment[_selectedForm?.first.departmentName ?? 'Uncategorized'] ?? [],
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedForm?.first.departmentName ?? "Not specified",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green[800],
                          ),
                        ),
                        if (_selectedForm != null)
                          Text(
                            'Department: ${_selectedForm?.first.departmentName}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        Text(
                          'Files in department: ${formsByDepartment[_selectedForm?.first.departmentName ?? 'Uncategorized']?.length ?? 1}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red),
                    onPressed: _clearFormSelection,
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            constraints: BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              physics: AlwaysScrollableScrollPhysics(),
              itemCount: formsByDepartment.length,
              itemBuilder: (context, index) {
                final department = formsByDepartment.keys.toList()[index];
                final departmentForms = formsByDepartment[department]!;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Radio<String>(
                        value: department,
                        groupValue: _selectedDepartment, // ← THIS IS REQUIRED!
                        onChanged: (value) {
                          setState(() {
                            _selectedDepartment = value; // Update the selected department
                            _selectedForm = formsByDepartment[value];
                          });
                        },
                      ),
                      Expanded(
                        child: ExpansionTile(
                          leading: Icon(Icons.folder, color: Colors.blue),
                          title: Text(
                            department,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${departmentForms.length} form${departmentForms.length > 1 ? 's' : ''} available',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                          children: departmentForms.map((form) {
                            return ListTile(
                              leading: Icon(Icons.description, color: Colors.grey[700]),
                              title: Text(form.fileName ?? "Unnamed Form"),
                              subtitle: Text(
                                'Uploaded: ${form.uploadedAt != null ? _formatDate(form.uploadedAt!) : 'Unknown date'}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                              ),
                              trailing: Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => _showDepartmentFilesDialog(department, departmentForms),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showDepartmentFilesDialog(String department, List<CompanyForm> departmentForms) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dialog Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              department,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.blue[900],
                              ),
                            ),
                            Text(
                              '${departmentForms.length} form${departmentForms.length > 1 ? 's' : ''}',
                              style: TextStyle(color: Colors.blue[700]),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Files List
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: departmentForms.length,
                    itemBuilder: (context, index) {
                      final form = departmentForms[index];
                      final allFileUrls = [
                        if (form.downloadUrl != null) form.downloadUrl!
                      ];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getFileIconFromUrl(form.downloadUrl ?? ''),
                              color: Colors.blue,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            form.fileName ?? 'Unnamed Form',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${allFileUrls.length} file${allFileUrls.length > 1 ? 's' : ''}',
                                style: TextStyle(fontSize: 12),
                              ),
                              if (form.uploadedAt != null)
                                Text(
                                  'Uploaded: ${_formatDate(form.uploadedAt!)}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                            ],
                          ),
                          trailing: allFileUrls.length > 1
                              ? PopupMenuButton(
                            icon: Icon(Icons.more_vert),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                child: Row(
                                  children: [
                                    Icon(Icons.visibility, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Preview Files'),
                                  ],
                                ),
                                onTap: () => _previewForm(form, index, departmentForms),
                              ),
                              PopupMenuItem(
                                child: Row(
                                  children: [
                                    Icon(Icons.select_all, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Select This Form'),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.pop(context); // Close popup menu
                                  Navigator.pop(context); // Close dialog
                                  _selectForm(departmentForms);
                                },
                              ),
                            ],
                          )
                              : IconButton(
                            icon: Icon(Icons.visibility),
                            onPressed: () => _previewForm(form, index, departmentForms),
                          ),
                          onTap: () => _previewForm(form, index, departmentForms),
                        ),
                      );
                    },
                  ),
                ),

                // Select Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.check),
                      label: Text('SELECT FORM'),
                      onPressed: () {
                        if (_selectedForm == null && departmentForms.isNotEmpty) {
                          _selectForm(departmentForms);
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue[700],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _previewForm(CompanyForm form, int index, List<CompanyForm> departmentForms) async {
    Navigator.pop(context); // Close dialog first

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenViewer(
          firebasePath: form.downloadUrl,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  IconData _getFileIconFromUrl(String url) {
    if (url.toLowerCase().contains('.pdf')) return Icons.picture_as_pdf;
    if (url.toLowerCase().contains('.doc')) return Icons.description;
    if (url.toLowerCase().contains('.jpg') ||
        url.toLowerCase().contains('.jpeg') ||
        url.toLowerCase().contains('.png')) return Icons.image;
    return Icons.insert_drive_file;
  }


  Widget _buildFilePreview() {
    List<Widget> fileWidgets = [];

    // Show selected existing form files
    if (_existingFormFiles.isNotEmpty) {
      fileWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected Form Files:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ..._existingFormFiles.asMap().entries.map((entry) {
              final index = entry.key;
              final url = entry.value;
              final fileName = url.split('/').last;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.description, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'From existing form',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _removeExistingFile(index),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      );
    }

    // Show newly uploaded files
    if (_selectedFiles.isNotEmpty) {
      fileWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_existingFormFiles.isNotEmpty) const SizedBox(height: 16),
            Text(
              'Newly Uploaded Files:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ..._selectedFiles.asMap().entries.map((entry) {
              final index = entry.key;
              final file = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
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
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fileWidgets,
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
                                                  _selectedForm = null;
                                                  _existingFormFiles.clear();
                                                  if (value == _formUsageOptions[0]) {
                                                    _loadExistingForms();
                                                  }
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
                                                    option == _formUsageOptions[0]
                                                        ? 'Use Existing Categorized Form'
                                                        : option == _formUsageOptions[1]
                                                        ? 'Upload New Form (Will be saved for future use)'
                                                        : 'Universal Template',
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
                                                    option == _formUsageOptions[0]
                                                        ? 'Select from your previously uploaded forms categorized by department'
                                                        : option == _formUsageOptions[1]
                                                        ? 'Upload new files. These will be saved as a categorized form for future use'
                                                        : 'Save this form as a universal template for future postings',
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
                                const SizedBox(height: 16),

                                // Show existing forms selector if that option is selected
                                if (_formUsage == _formUsageOptions[0])
                                  Column(
                                    children: [
                                      _buildExistingFormsSelector(),
                                      const SizedBox(height: 16),
                                    ],
                                  ),

                                // File Upload Section (only for new form upload or universal template)
                                if (_formUsage == _formUsageOptions[1])
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formUsage == _formUsageOptions[1]
                                            ? 'Upload Form Files (Will be saved for future use)'
                                            : 'Attach Files (Optional)',
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
                                                if (_formUsage == _formUsageOptions[1])
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 8),
                                                    child: Text(
                                                      'This form will be categorized under: ${_departmentController.text.isNotEmpty ? _departmentController.text : "Current Department"}',
                                                      style: TextStyle(
                                                        color: Colors.blue[700],
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                      textAlign: TextAlign.center,
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

                                // Show file preview for existing forms
                                if (_formUsage == _formUsageOptions[0] && (_existingFormFiles.isNotEmpty || _selectedFiles.isNotEmpty))
                                  Column(
                                    children: [
                                      const SizedBox(height: 16),
                                      _buildFilePreview(),
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
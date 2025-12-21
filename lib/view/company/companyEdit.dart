import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:itc_institute_admin/firebase_cloud_storage/firebase_cloud.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart';
import 'package:itc_institute_admin/model/company.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';

class CompanyEditPage extends StatefulWidget {
  final Company company;
  final Function(Company) onSave;
  final Function() onCancel;

  const CompanyEditPage({
    Key? key,
    required this.company,
    required this.onSave,
    required this.onCancel,
  }) : super(key: key);

  @override
  _CompanyEditPageState createState() => _CompanyEditPageState();
}

class _CompanyEditPageState extends State<CompanyEditPage> {
  late Company _editedCompany;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  File? _logoFile;
  final ImagePicker _picker = ImagePicker();
  final ITCFirebaseLogic _firebaseLogic = ITCFirebaseLogic();
  final Company_Cloud company_cloud = Company_Cloud();
  final FirebaseUploader firebaseUploader = FirebaseUploader();

  // Nigerian states for dropdown
  final List<String> nigerianStates = [
    'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue',
    'Borno', 'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu', 'FCT',
    'Gombe', 'Imo', 'Jigawa', 'Kaduna', 'Kano', 'Katsina', 'Kebbi', 'Kogi',
    'Kwara', 'Lagos', 'Nasarawa', 'Niger', 'Ogun', 'Ondo', 'Osun', 'Oyo',
    'Plateau', 'Rivers', 'Sokoto', 'Taraba', 'Yobe', 'Zamfara'
  ];

  // Industry categories
  final List<String> industries = [
    'Technology', 'Education', 'Healthcare', 'Finance', 'Manufacturing',
    'Retail', 'Agriculture', 'Construction', 'Transportation', 'Energy',
    'Telecommunications', 'Media', 'Hospitality', 'Consulting', 'Real Estate',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _editedCompany = widget.company.copyWith();
  }

  Future<void> _pickLogo() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _logoFile = File(image.path);
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _takeLogoPhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _logoFile = File(photo.path);
        });
      }
    } catch (e) {
      _showError('Failed to take photo: $e');
    }
  }

  void _showLogoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickLogo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _takeLogoPhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadLogo() async {
    if (_logoFile == null) return null;

    try {
      setState(() => _isLoading = true);
      final downloadUrl = await firebaseUploader.uploadFile(
         _logoFile!,
         FirebaseAuth.instance.currentUser!.uid,
         'company_logos/${_editedCompany.id}'
      );
      return downloadUrl;
    } catch (e) {
      _showError('Failed to upload logo: $e');
      return null;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCompany() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Upload new logo if selected
      if (_logoFile != null) {
        final logoUrl = await _uploadLogo();
        if (logoUrl != null) {
          _editedCompany = _editedCompany.copyWith(logoURL: logoUrl);
        }
      }

      // Update company in Firebase
      await company_cloud.updateCompany(_editedCompany);

      // Return updated company
      widget.onSave(_editedCompany);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Failed to update company: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Company Profile'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveCompany,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Logo Section
            _buildLogoSection(theme),
            const SizedBox(height: 24),

            // Basic Information
            _buildSectionHeader('Basic Information', theme),
            _buildTextField(
              label: 'Company Name',
              initialValue: _editedCompany.name,
              onChanged: (value) => _editedCompany = _editedCompany.copyWith(name: value),
              validator: (value) => value!.isEmpty ? 'Company name is required' : null,
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              label: 'Industry',
              value: _editedCompany.industry,
              items: industries,
              onChanged: (value) => _editedCompany = _editedCompany.copyWith(industry: value!),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Registration Number',
              initialValue: _editedCompany.registrationNumber,
              onChanged: (value) => _editedCompany = _editedCompany.copyWith(registrationNumber: value),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Description',
              initialValue: _editedCompany.description,
              onChanged: (value) => _editedCompany = _editedCompany.copyWith(description: value),
              maxLines: 4,
            ),
            const SizedBox(height: 24),

            // Contact Information
            _buildSectionHeader('Contact Information', theme),
            _buildTextField(
              label: 'Email',
              initialValue: _editedCompany.email,
              onChanged: (value) => _editedCompany = _editedCompany.copyWith(email: value),
              validator: (value) => value!.isEmpty ? 'Email is required' : null,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Phone Number',
              initialValue: _editedCompany.phoneNumber,
              onChanged: (value) => _editedCompany = _editedCompany.copyWith(phoneNumber: value),
              validator: (value) => value!.isEmpty ? 'Phone number is required' : null,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Address',
              initialValue: _editedCompany.address,
              onChanged: (value) => _editedCompany = _editedCompany.copyWith(address: value),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Location Information
            _buildSectionHeader('Location Information', theme),
            _buildDropdown(
              label: 'State',
              value: _editedCompany.state,
              items: nigerianStates,
              onChanged: (value) => _editedCompany = _editedCompany.copyWith(state: value!),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Local Government',
              initialValue: _editedCompany.localGovernment,
              onChanged: (value) => _editedCompany = _editedCompany.copyWith(localGovernment: value),
            ),
            const SizedBox(height: 24),

            // Status Information (Read-only)
            _buildSectionHeader('Account Status', theme),
            _buildStatusChips(theme),
            const SizedBox(height: 24),

            // Action Buttons
            _buildActionButtons(theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection(ThemeData theme) {
    return Column(
      children: [
        GestureDetector(
          onTap: _showLogoOptions,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Logo image
                if (_logoFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: Image.file(
                      _logoFile!,
                      width: 116,
                      height: 116,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (_editedCompany.logoURL.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: Image.network(
                      _editedCompany.logoURL,
                      width: 116,
                      height: 116,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: theme.colorScheme.surfaceVariant,
                          child: const Icon(Icons.business, size: 48),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.business, size: 48),
                  ),

                // Edit overlay
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap to change logo',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String initialValue,
    required ValueChanged<String> onChanged,
    FormFieldValidator<String>? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
      ),
      onChanged: onChanged,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {

    String? exactMatch;
    if (value.isNotEmpty) {
      final lowerValue = value.toLowerCase();
      for (final item in items) {
        if (item.toLowerCase() == lowerValue) {
          exactMatch = item; // Use the exact case from the list
          break;
        }
      }
    }

    return DropdownButtonFormField<String>(
      initialValue: exactMatch,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
      ),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('Select...'),
        ),
        ...items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item),
          );
        }).toList(),
      ],
      onChanged: onChanged,
      validator: (value) => value == null ? 'Please select $label' : null,
    );
  }

  Widget _buildStatusChips(ThemeData theme) {
    final statuses = [
      if (_editedCompany.isVerified) _buildStatusChip('Verified', Colors.green, theme),
      if (_editedCompany.isActive) _buildStatusChip('Active', Colors.green, theme),
      if (_editedCompany.isPending) _buildStatusChip('Pending', Colors.orange, theme),
      if (_editedCompany.isApproved) _buildStatusChip('Approved', Colors.blue, theme),
      if (_editedCompany.isRejected) _buildStatusChip('Rejected', Colors.red, theme),
      if (_editedCompany.isBlocked) _buildStatusChip('Blocked', Colors.red, theme),
      if (_editedCompany.isSuspended) _buildStatusChip('Suspended', Colors.orange, theme),
      if (_editedCompany.isBanned) _buildStatusChip('Banned', Colors.red, theme),
      if (_editedCompany.isMuted) _buildStatusChip('Muted', Colors.orange, theme),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses,
    );
  }

  Widget _buildStatusChip(String label, Color color, ThemeData theme) {
    return Chip(
      label: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
        ),
      ),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: widget.onCancel,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveCompany,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Save Changes'),
          ),
        ),
      ],
    );
  }
}
import 'dart:io';
import 'dart:math' as math;
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart';
import 'package:itc_institute_admin/notification/view/localFilePreview.dart';
import 'package:open_file/open_file.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart'; // For file preview/download
import 'package:path_provider/path_provider.dart';

import '../../firebase_cloud_storage/firebase_cloud.dart';
import '../../model/companyForm.dart';
import '../../style/BorderStyle.dart';

class CompanyFormUploadPage extends StatefulWidget {
  final String companyId;
  final String companyName;

  const CompanyFormUploadPage({
    Key? key,
    required this.companyId,
    this.companyName = 'Our Company',
  }) : super(key: key);

  @override
  _CompanyFormUploadPageState createState() => _CompanyFormUploadPageState();
}

class _CompanyFormUploadPageState extends State<CompanyFormUploadPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _departmentController = TextEditingController();
  List<File> _selectedFiles = [];
  bool _isLoading = false;
  final Uuid _uuid = const Uuid();
  String? _fileError;
  List<Map<String, String>> _fileDetails = []; // Store file details
  final companyService = Company_Cloud(FirebaseAuth.instance.currentUser!.uid);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _pickMultipleFiles() async {
    // Clear any previous errors
    setState(() => _fileError = null);

    try {
      // Show file picker with multiple selection
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: CompanyForm.allowedFileExtensions,
        allowMultiple: true,
        withData: false,
        withReadStream: false,
      );

      if (result != null && result.files.isNotEmpty) {
        // Check total size
        const maxTotalSize = 50 * 1024 * 1024; // 50MB total for all files
        int totalSize = 0;

        for (final platformFile in result.files) {
          totalSize += platformFile.size;
        }

        if (totalSize > maxTotalSize) {
          setState(() => _fileError = 'Total file size must be less than 50MB');
          return;
        }

        final List<File> validFiles = [];
        final List<Map<String, String>> newFileDetails = [];

        for (final platformFile in result.files) {
          // Check individual file size (max 20MB)
          const maxSize = 20 * 1024 * 1024;
          if (platformFile.size > maxSize) {
            setState(() => _fileError = 'Each file must be less than 20MB');
            continue;
          }

          // Check file extension
          final extension = platformFile.extension?.toLowerCase() ?? '';
          if (!CompanyForm.allowedFileExtensions.contains(extension)) {
            setState(() => _fileError = 'File type $extension not allowed');
            continue;
          }

          // Create File object from path
          if (platformFile.path != null) {
            final file = File(platformFile.path!);

            // Check if file exists and is readable
            if (await file.exists()) {
              validFiles.add(file);

              // Get file details
              final fileSize = _formatFileSize(platformFile.size);
              final fileType = _getFileTypeFromExtension(extension);

              newFileDetails.add({
                'name': platformFile.name,
                'size': fileSize,
                'type': fileType,
                'path': platformFile.path!,
                'extension': extension,
              });
            }
          }
        }

        if (validFiles.isNotEmpty) {
          await _processSelectedFiles(validFiles, newFileDetails);
        }
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
      setState(() => _fileError = 'Error selecting files: $e');
    }
  }

  Future<void> _processSelectedFiles(List<File> files, List<Map<String, String>> fileDetails) async {
    setState(() => _isLoading = true);

    try {
      setState(() {
        _selectedFiles.addAll(files);
        _fileDetails.addAll(fileDetails);
        _isLoading = false;
      });

      // Show success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${files.length} file(s) selected',
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );

    } catch (e) {
      debugPrint('Error processing files: $e');
      setState(() {
        _fileError = 'Error processing files: $e';
        _isLoading = false;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  String _getFileTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'PDF Document';
      case 'doc':
      case 'docx':
        return 'Word Document';
      case 'xls':
      case 'xlsx':
        return 'Excel Spreadsheet';
      case 'txt':
      case 'rtf':
      case 'odt':
        return 'Text Document';
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'bmp':
      case 'heic':
      case 'heif':
        return 'Image';
      default:
        return 'Document';
    }
  }

  String _getMimeTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      case 'rtf':
        return 'application/rtf';
      case 'odt':
        return 'application/vnd.oasis.opendocument.text';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'application/octet-stream';
    }
  }

  void _removeFile(int index) {
    setState(() {
      if (index < _selectedFiles.length) {
        _selectedFiles.removeAt(index);
      }
      if (index < _fileDetails.length) {
        _fileDetails.removeAt(index);
      }
    });
  }

  void _clearAllFiles() {
    setState(() {
      _selectedFiles.clear();
      _fileDetails.clear();
      _fileError = null;
    });
  }

  // Preview file functionality
  // Simplified preview method using open_file
  Future<void> _previewFile(int index) async {
     GeneralMethods.navigateTo(context, InAppFilePreviewPage(files: _selectedFiles, fileDetails: _fileDetails,initialIndex: index,));
  }

  void _showFileCannotOpenDialog(BuildContext context, Map<String, String> fileDetail, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cannot Open File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No app found to open this file type.'),
            SizedBox(height: 16),
            Text('File: ${fileDetail['name']}'),
            Text('Type: ${fileDetail['type']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _fallbackPreviewMethods(File file, Map<String, String> fileDetail, int index) async {
    final extension = fileDetail['extension']?.toLowerCase() ?? '';

    // For images, show custom preview
    if (['png', 'jpg', 'jpeg', 'gif', 'bmp'].contains(extension)) {
      _showImagePreview(context, file);
      return;
    }

    // For text files, show text preview
    if (extension == 'txt') {
      _showTextPreview(context, file);
      return;
    }

    // For PDFs, try alternative PDF viewer
    if (extension == 'pdf') {
      await _openPdfAlternative(file, fileDetail, index);
      return;
    }

    // Show file info dialog
    _showEnhancedFileInfoDialog(context, fileDetail, index);
  }


  void _showEnhancedFileInfoDialog(
      BuildContext context,
      Map<String, String> fileDetail,
      int index
      ) {
    final fileName = fileDetail['name'] ?? 'Unknown file';
    final fileSize = fileDetail['size'] ?? 'Unknown size';
    final fileType = fileDetail['type'] ?? 'Unknown type';
    final filePath = fileDetail['path'] ?? 'Unknown path';
    final extension = fileDetail['extension'] ?? '';
    final mimeType = fileDetail['mimeType'] ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _getFileTypeIcon(fileType),
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'File Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // File Name Section
                _buildInfoRow(
                  context,
                  icon: Icons.description,
                  label: 'File Name',
                  value: fileName,
                  isImportant: true,
                ),
                const SizedBox(height: 12),

                // File Type & Size Row
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoRow(
                        context,
                        icon: Icons.category,
                        label: 'Type',
                        value: fileType,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoRow(
                        context,
                        icon: Icons.storage,
                        label: 'Size',
                        value: fileSize,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Technical Details Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Technical Details',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (extension.isNotEmpty) ...[
                        _buildDetailItem(context, 'Extension', '.$extension'),
                        const SizedBox(height: 4),
                      ],

                      if (mimeType.isNotEmpty) ...[
                        _buildDetailItem(context, 'MIME Type', mimeType),
                        const SizedBox(height: 4),
                      ],

                      _buildDetailItem(
                        context,
                        'Path',
                        filePath,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // File Status
                if (fileDetail.containsKey('status'))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(context, fileDetail['status']),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(fileDetail['status']),
                          size: 14,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Status: ${fileDetail['status']?.toUpperCase() ?? 'UNKNOWN'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            // Close Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              child: Text('Close'),
            ),

            // Spacer
            const Spacer(),

            // Copy Path Button
            OutlinedButton.icon(
              onPressed: () => _copyToClipboard(context, filePath, 'File path copied'),
              icon: const Icon(Icons.copy, size: 18),
              label: Text('Copy Path'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),

            const SizedBox(width: 8),

            // Open Button (for supported file types)
            if (_isOpenableFile(extension)) ...[
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openFileWithSystemApp(index);
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text('Open'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                ),
              ),
            ],
          ],
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        );
      },
    );
  }

  Widget _buildInfoRow(
      BuildContext context, {
        required IconData icon,
        required String label,
        required String value,
        bool isImportant = false,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: isImportant ? FontWeight.bold : FontWeight.normal,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildDetailItem(
      BuildContext context,
      String label,
      String value, {
        int maxLines = 1,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
            maxLines: maxLines,
          ),
        ),
      ],
    );
  }

  bool _isOpenableFile(String extension) {
    final openableExtensions = [
      'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'rtf', 'odt',
      'png', 'jpg', 'jpeg', 'gif', 'bmp', 'heic', 'heif',
    ];
    return openableExtensions.contains(extension.toLowerCase());
  }

  Color _getStatusColor(BuildContext context, String? status) {
    switch (status?.toLowerCase()) {
      case 'uploaded':
      case 'completed':
      case 'success':
        return Colors.green;
      case 'pending':
      case 'processing':
        return Colors.orange;
      case 'failed':
      case 'error':
        return Colors.red;
      case 'draft':
        return Colors.blue;
      default:
        return Theme.of(context).colorScheme.surfaceVariant;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'uploaded':
      case 'completed':
      case 'success':
        return Icons.check_circle;
      case 'pending':
      case 'processing':
        return Icons.access_time;
      case 'failed':
      case 'error':
        return Icons.error;
      case 'draft':
        return Icons.edit;
      default:
        return Icons.info;
    }
  }

  Future<void> _copyToClipboard(BuildContext context, String text, String successMessage) async {
    await Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successMessage),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openFileWithSystemApp(int index) async {
    if (index >= _selectedFiles.length) return;

    final file = _selectedFiles[index];
    final fileDetail = _fileDetails[index];

    try {
      // Use open_file package
      final result = await OpenFile.open(file.path);

      if (result.type != ResultType.done) {
        // Fallback to url_launcher
        if (await canLaunchUrl(Uri.file(file.path))) {
          await launchUrl(Uri.file(file.path));
        } else {
          throw Exception('Cannot open file');
        }
      }
    } catch (e) {
      debugPrint('Error opening file: $e');
      // You might want to show an error to the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: ${fileDetail['name']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// Helper method to get external storage directory
  Future<Directory?> getExternalStorageDirectory() async {
    try {
      if (Platform.isAndroid) {
        return await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        return await getApplicationDocumentsDirectory();
      } else {
        return await getDownloadsDirectory();
      }
    } catch (e) {
      debugPrint('Error getting external storage: $e');
      return null;
    }
  }

  Future<void> _openPdfAlternative(File file, Map<String, String> fileDetail, int index) async {
    // Option 1: Try with url_launcher (may not work on all Android versions)
    try {
      if (await canLaunchUrl(Uri.file(file.path))) {
        await launchUrl(Uri.file(file.path));
        return;
      }
    } catch (e) {
      debugPrint('url_launcher failed: $e');
    }

    // Option 2: Copy to external storage and open
    try {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final externalFile = File('${externalDir.path}/${fileDetail['name']}');
        await file.copy(externalFile.path);

        final result = await OpenFile.open(externalFile.path);
        if (result.type == ResultType.done) {
          return;
        }
      }
    } catch (e) {
      debugPrint('External storage copy failed: $e');
    }

    // Option 3: Show error dialog
    _showFileCannotOpenDialog(context, fileDetail, index);
  }
  void _showImagePreview(BuildContext context, File file) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 3,
              child: Image.file(file),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTextPreview(BuildContext context, File file) async {
    try {
      final content = await file.readAsString();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Text Preview'),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: SelectableText(
                content,
                style: TextStyle(fontFamily: 'Monospace'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot read file content'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showFileInfoDialog(BuildContext context, Map<String, String> fileDetail) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('File Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${fileDetail['name']}'),
            SizedBox(height: 8),
            Text('Size: ${fileDetail['size']}'),
            SizedBox(height: 8),
            Text('Type: ${fileDetail['type']}'),
            SizedBox(height: 8),
            Text('Path: ${fileDetail['path']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPreviewDialog(BuildContext context, File file, String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Preview Not Available'),
        content: Text('Cannot preview this file type directly. Would you like to open it with another app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (await canLaunchUrl(Uri.file(file.path))) {
                await launchUrl(Uri.file(file.path));
              }
            },
            child: Text('Open'),
          ),
        ],
      ),
    );
  }

  // Validate form before saving
  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (_selectedFiles.isEmpty) {
      setState(() => _fileError = 'Please select at least one file to upload');
      return false;
    }

    // Check if all files exist
    for (final file in _selectedFiles) {
      if (!file.existsSync()) {
        setState(() => _fileError = 'One or more selected files no longer exist');
        return false;
      }
    }

    return true;
  }

  Future<void> _saveForm({bool isDraft = false}) async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      final List<CompanyForm> companyForms = [];
      final firebaseUploader = FirebaseUploader();

      // Upload all files in parallel
      final uploadTasks = _selectedFiles.asMap().entries.map((entry) async {
        final index = entry.key;
        final file = entry.value;
        final fileDetail = _fileDetails[index];

        // Upload file to Firebase Storage
        final downloadUrl = await firebaseUploader.uploadFile(
          file,
          widget.companyId,
          'company_forms/${_departmentController.text.trim().toLowerCase().replaceAll(' ', '_')}',
        );

        if (downloadUrl == null) {
          throw Exception('Failed to upload file: ${fileDetail['name']}');
        }

        // Create form object for each file
        final companyForm = CompanyForm(
          formId: _uuid.v4(),
          departmentName: _departmentController.text.trim(),
          companyId: widget.companyId,
          uploadedAt: DateTime.now(),
          filePath: file.path,
          fileName: fileDetail['name'],
          fileSize: fileDetail['size'],
          fileType: fileDetail['type'],
          downloadUrl: downloadUrl,
        );

        return companyForm;
      }).toList();

      // Wait for all uploads to complete
      final forms = await Future.wait(uploadTasks);
      companyForms.addAll(forms);

      // Add all forms to company in Firestore
      for (final form in companyForms) {
        await companyService.addCompanyForm(widget.companyId, form);
      }

      debugPrint('${forms.length} form(s) saved to Firestore');

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDraft
                ? '${forms.length} form(s) saved as draft!'
                : '${forms.length} form(s) uploaded successfully!',
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'View',
            textColor: Theme.of(context).colorScheme.onPrimary,
            onPressed: () {
              Navigator.pop(context, companyForms);
            },
          ),
        ),
      );

      // If not draft, clear form
      if (!isDraft) {
        _resetForm();

        // Navigate back after successful submission
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pop(context, companyForms);
        }
      }

    } catch (error, stackTrace) {
      // Handle errors
      debugPrint('Error saving form: $error');
      debugPrint('Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${error.toString()}',
            style: TextStyle(color: Theme.of(context).colorScheme.onError),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Theme.of(context).colorScheme.onError,
            onPressed: () => _saveForm(isDraft: isDraft),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _clearAllFiles();
    _departmentController.clear();
  }

  Future<bool> _confirmExit() async {
    if (_departmentController.text.isNotEmpty || _selectedFiles.isNotEmpty) {
      return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Unsaved Changes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Text(
            'You have ${_selectedFiles.length} file(s) selected. Are you sure you want to leave?',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Leave',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ) ?? false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final shouldPop = await _confirmExit();
          if (shouldPop) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload Forms',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.companyName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            if (_selectedFiles.isNotEmpty || _departmentController.text.isNotEmpty)
              IconButton(
                icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                tooltip: 'Clear all',
                onPressed: _resetForm,
              ),
          ],
        ),
        body: _isLoading && _selectedFiles.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress indicator
                  _buildProgressIndicator(context),
                  const SizedBox(height: 24),

                  // Department form
                  _buildDepartmentForm(context),
                  const SizedBox(height: 24),

                  // File upload section
                  _buildFileUploadSection(context),
                  if (_fileError != null) ...[
                    const SizedBox(height: 8),
                    _buildErrorText(context),
                  ],

                  // Selected files list
                  if (_selectedFiles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSelectedFilesList(context),
                  ],

                  const SizedBox(height: 32),

                  // Action buttons
                  _buildActionButtons(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    final steps = ['Details', 'Upload', 'Review'];
    final currentStep = _selectedFiles.isEmpty ? 0 : _departmentController.text.isEmpty ? 1 : 2;

    return Column(
      children: [
        Row(
          children: steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isActive = index <= currentStep;

            return Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceVariant,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isActive
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (index < steps.length - 1) Expanded(
                        child: Container(
                          height: 2,
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDepartmentForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Department Information',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter department details and upload multiple forms',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _departmentController,
          decoration: InputDecoration(
            labelText: 'Department Name *',
            hintText: 'e.g., Computer Science, Mechanical Engineering',
            prefixIcon: Icon(Icons.business, color: Theme.of(context).colorScheme.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          ),
          style: Theme.of(context).textTheme.bodyLarge,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter department name';
            }
            if (value.trim().length < 2) {
              return 'Department name must be at least 2 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: InputDecoration(
            labelText: 'Description (Optional)',
            hintText: 'Brief description about these department forms',
            prefixIcon: Icon(Icons.description, color: Theme.of(context).colorScheme.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          ),
          maxLines: 3,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _buildFileUploadSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Form Documents',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Upload multiple forms (PDF, Word, Excel, Images, or Text files)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _isLoading ? null : _pickMultipleFiles,
          child: DashedBorder(
            color: Theme.of(context).colorScheme.outline,
            strokeWidth: 2,
            dashWidth: 8,
            dashSpace: 4,
            borderRadius: 16,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              child: _buildUploadPlaceholder(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadPlaceholder(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _selectedFiles.isEmpty ? Icons.cloud_upload : Icons.add_circle_outline,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          _selectedFiles.isEmpty ? 'Tap to select files' : 'Tap to add more files',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Supports: PDF, DOC, XLS, Images, TXT\nMax 20MB per file, 50MB total',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        if (_selectedFiles.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Selected: ${_selectedFiles.length} file(s)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedFilesList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected Files (${_selectedFiles.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _selectedFiles.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final fileDetail = _fileDetails[index];
            final icon = _getFileTypeIcon(fileDetail['type']);

            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
                title: Text(
                  fileDetail['name'] ?? 'Unknown file',
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${fileDetail['size']} • ${fileDetail['type']}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove_red_eye, size: 20),
                      onPressed: () => _previewFile(index),
                      tooltip: 'Preview',
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _removeFile(index),
                      tooltip: 'Remove',
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ],
                ),
                onTap: () => _previewFile(index),
              ),
            );
          },
        ),
      ],
    );
  }

  IconData _getFileTypeIcon(String? fileType) {
    final type = fileType?.toLowerCase() ?? '';
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('image')) return Icons.image;
    if (type.contains('word')) return Icons.description;
    if (type.contains('excel')) return Icons.table_chart;
    if (type.contains('text')) return Icons.text_fields;
    return Icons.insert_drive_file;
  }

  Widget _buildErrorText(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _fileError!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        if (_selectedFiles.isNotEmpty && _departmentController.text.isNotEmpty) ...[
          _buildFormPreview(context),
          const SizedBox(height: 20),
        ],
        Row(
          children: [
            // Expanded(
            //   child: OutlinedButton(
            //     onPressed: _isLoading ? null : () => _saveForm(isDraft: true),
            //     style: OutlinedButton.styleFrom(
            //       padding: const EdgeInsets.symmetric(vertical: 16),
            //       shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(12),
            //       ),
            //       side: BorderSide(color: Theme.of(context).colorScheme.outline),
            //     ),
            //     child: Text(
            //       'Save as Draft',
            //       style: Theme.of(context).textTheme.titleMedium,
            //     ),
            //   ),
            // ),
            // const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _saveForm(isDraft: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
                    : Text(
                  'Upload ${_selectedFiles.length} Form(s)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormPreview(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.preview, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Upload Summary',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.business, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Department:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                _departmentController.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.description, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Files to Upload:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Chip(
                label: Text('${_selectedFiles.length} file(s)'),
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_fileDetails.isNotEmpty) ...[
            Text(
              'File List:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            ..._fileDetails.take(3).map((fileDetail) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '• ${fileDetail['name']} (${fileDetail['size']})',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            if (_fileDetails.length > 3) ...[
              Text(
                '+ ${_fileDetails.length - 3} more file(s)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
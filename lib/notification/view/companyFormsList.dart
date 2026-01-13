import 'dart:io';
import 'package:flutter/material.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart'; // Add this import
import 'package:itc_institute_admin/model/company.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../model/companyForm.dart';
import '../../view/home/industrailTraining/fileDetails.dart';
import 'companyFormUploadPage.dart';


class CompanyFormsListPage extends StatefulWidget {
  final Company company;

  const CompanyFormsListPage({
    Key? key,
    required this.company,
  }) : super(key: key);

  @override
  _CompanyFormsListPageState createState() => _CompanyFormsListPageState();
}

class _CompanyFormsListPageState extends State<CompanyFormsListPage> {
  Map<String, List<CompanyForm>> _formsByDepartment = {};
  Map<String, List<CompanyForm>> _filteredFormsByDepartment = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Dio _dio = Dio();
  final Map<String, File> _cachedFiles = {};
  bool _sortByDateAscending = false;
  final Company_Cloud _companyService = Company_Cloud(); // Add service instance

  @override
  void initState() {
    super.initState();
    _loadCompanyForms();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyForms() async {
    setState(() => _isLoading = true);

    try {
      // Use getCompanyForms method to fetch forms from Firestore
      final List<CompanyForm> forms = await _companyService.getCompanyForms(widget.company.id);

      // Sort forms by date
      forms.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

      // Group forms by department name
      final Map<String, List<CompanyForm>> groupedForms = {};

      for (final form in forms) {
        final department = form.departmentName;
        if (!groupedForms.containsKey(department)) {
          groupedForms[department] = [];
        }
        groupedForms[department]!.add(form);
      }

      setState(() {
        _formsByDepartment = groupedForms;
        _filteredFormsByDepartment = Map.from(groupedForms);
        _isLoading = false;
      });

      debugPrint("Loaded ${forms.length} forms for company ${widget.company.id}");

    } catch (e) {
      debugPrint("Error loading company forms: $e");
      setState(() => _isLoading = false);

      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load forms: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();

      if (_searchQuery.isEmpty) {
        _filteredFormsByDepartment = Map.from(_formsByDepartment);
      } else {
        _filteredFormsByDepartment = {};

        for (final department in _formsByDepartment.keys) {
          final forms = _formsByDepartment[department]!;
          final filteredForms = forms.where((form) {
            return form.departmentName.toLowerCase().contains(_searchQuery) ||
                (form.fileName?.toLowerCase().contains(_searchQuery) ?? false) ||
                (form.fileType?.toLowerCase().contains(_searchQuery) ?? false);
          }).toList();

          if (filteredForms.isNotEmpty) {
            _filteredFormsByDepartment[department] = filteredForms;
          }
        }
      }
    });
  }

  void _toggleSortOrder() {
    setState(() {
      _sortByDateAscending = !_sortByDateAscending;

      for (final department in _filteredFormsByDepartment.keys) {
        final forms = _filteredFormsByDepartment[department]!;
        forms.sort((a, b) => _sortByDateAscending
            ? a.uploadedAt.compareTo(b.uploadedAt)
            : b.uploadedAt.compareTo(a.uploadedAt)
        );
      }
    });
  }

  void _viewDepartmentForms(String department, List<CompanyForm> forms) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      department,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: forms.length,
                  itemBuilder: (context, index) {
                    final form = forms[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Icon(
                              _getFormIcon(form.fileType),
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          form.fileName ?? 'Unknown file',
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${form.fileSize ?? 'Unknown size'}'),
                            Text(
                              _formatDate(form.uploadedAt),
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(context);
                          _previewForm(form, index, forms);
                        },
                      ),
                    );
                  },
                ),
              ),
              // Add download all button at the bottom
              Container(
                padding: EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _downloadAllDepartmentFiles(department, forms);
                  },
                  icon: Icon(Icons.download),
                  label: Text('Download All ${forms.length} Files'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadAllDepartmentFiles(String department, List<CompanyForm> forms) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Preparing ${forms.length} files for download...'),
          ],
        ),
        backgroundColor: Colors.blue,
      ),
    );

    int downloadedCount = 0;
    for (final form in forms) {
      try {
        await _downloadFormFile(form);
        downloadedCount++;
      } catch (e) {
        debugPrint('Error downloading ${form.fileName}: $e');
      }
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (downloadedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded $downloadedCount/${forms.length} files'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download files'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<File?> _downloadFormFile(CompanyForm form) async {
    if (form.downloadUrl == null) return null;

    // Check cache first
    if (_cachedFiles.containsKey(form.formId)) {
      final cachedFile = _cachedFiles[form.formId]!;
      if (await cachedFile.exists()) {
        return cachedFile;
      } else {
        _cachedFiles.remove(form.formId);
      }
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = form.fileName ?? 'form_${form.formId}';
      final cleanFileName = _cleanFileName(fileName);
      final savePath = '${tempDir.path}/$cleanFileName';

      await _dio.download(form.downloadUrl!, savePath);

      final file = File(savePath);
      if (await file.exists()) {
        _cachedFiles[form.formId] = file;
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('Error downloading file: $e');
      return null;
    }
  }

  String _cleanFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  Future<void> _previewForm(CompanyForm form, int index, List<CompanyForm> departmentForms) async {
    // Create lists of Firebase download URLs
    final List<String> firebasePaths = [];

    for (final deptForm in departmentForms) {
      if (deptForm.downloadUrl != null && deptForm.downloadUrl!.isNotEmpty) {
        firebasePaths.add(deptForm.downloadUrl!);
      }
    }

    if (firebasePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No downloadable files available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Find the index of the current form in the list
    final currentFormIndex = departmentForms.indexWhere((f) => f.formId == form.formId);
    final previewIndex = currentFormIndex >= 0 ? currentFormIndex : 0;

    for(String file in firebasePaths)
      {
       debugPrint("file $file and index is $previewIndex");
      }

    debugPrint("length ${firebasePaths.length}");

    // Navigate to preview page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenViewer(
          firebasePath: firebasePaths[previewIndex],
        ),
      ),
    );
  }

  IconData _getFormIcon(String? fileType) {
    final type = fileType?.toLowerCase() ?? '';
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('image')) return Icons.image;
    if (type.contains('word')) return Icons.description;
    if (type.contains('excel')) return Icons.table_chart;
    if (type.contains('text')) return Icons.text_fields;
    return Icons.insert_drive_file;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes < 1) return 'Just now';
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays ~/ 7}w ago';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  String _getExtension(String? fileName) {
    if (fileName == null) return '';
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  Widget _buildDepartmentCard(String department, List<CompanyForm> forms) {
    final fileCount = forms.length;
    final latestForm = forms.isNotEmpty ? forms.first : null;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () => _viewDepartmentForms(department, forms),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    fileCount.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      department,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '$fileCount form(s)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (latestForm != null) ...[
                      SizedBox(height: 4),
                      Text(
                        'Latest: ${latestForm.fileName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormList() {
    if (_filteredFormsByDepartment.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              _searchQuery.isNotEmpty ? 'No matching forms found' : 'No Forms Uploaded',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Upload forms to see them here',
              style: TextStyle(color: Colors.grey),
            ),
            if (!_isLoading && _searchQuery.isEmpty)
              ElevatedButton.icon(
                onPressed: _loadCompanyForms,
                icon: Icon(Icons.refresh),
                label: Text('Refresh'),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _cachedFiles.clear();
        await _loadCompanyForms();
      },
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 16),
        itemCount: _filteredFormsByDepartment.length,
        itemBuilder: (context, index) {
          final department = _filteredFormsByDepartment.keys.elementAt(index);
          final forms = _filteredFormsByDepartment[department]!;
          return _buildDepartmentCard(department, forms);
        },
      ),
    );
  }

  Widget _buildStatsHeader() {
    final totalForms = _filteredFormsByDepartment.values
        .fold(0, (sum, forms) => sum + forms.length);
    final departmentCount = _filteredFormsByDepartment.length;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.business,
            label: 'Departments',
            value: departmentCount.toString(),
          ),
          _buildStatItem(
            icon: Icons.description,
            label: 'Total Forms',
            value: totalForms.toString(),
          ),
          _buildStatItem(
            icon: Icons.calendar_today,
            label: _sortByDateAscending ? 'Oldest' : 'Latest',
            value: _getLatestFormDate(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({required IconData icon, required String label, required String value}) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _getLatestFormDate() {
    if (_filteredFormsByDepartment.isEmpty) return 'None';

    DateTime? latestDate;
    for (final forms in _filteredFormsByDepartment.values) {
      for (final form in forms) {
        if (latestDate == null || form.uploadedAt.isAfter(latestDate)) {
          latestDate = form.uploadedAt;
        }
      }
    }

    if (latestDate == null) return 'None';
    return _formatDate(latestDate);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by department, filename, or type...',
          prefixIcon: Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Company Forms',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              widget.company.name,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadCompanyForms,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(_sortByDateAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: _toggleSortOrder,
            tooltip: _sortByDateAscending ? 'Oldest first' : 'Newest first',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'refresh') {
                _cachedFiles.clear();
                _loadCompanyForms();
              } else if (value == 'clear_cache') {
                setState(() {
                  _cachedFiles.clear();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Cache cleared')),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_cache',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, size: 20),
                    SizedBox(width: 8),
                    Text('Clear Cache'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildSearchBar(),
          _buildStatsHeader(),
          Expanded(child: _buildFormList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CompanyFormUploadPage(
                companyId: widget.company.id,
                companyName: widget.company.name,
              ),
            ),
          ).then((value) {
            if (value != null) {
              _cachedFiles.clear();
              _loadCompanyForms(); // Reload forms after upload
            }
          });
        },
        icon: Icon(Icons.upload),
        label: Text('Upload New'),
      ),
    );
  }
}
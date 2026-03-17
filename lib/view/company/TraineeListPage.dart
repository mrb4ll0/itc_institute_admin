import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart' as csv;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:itc_institute_admin/extensions/extensions.dart';
import '../../model/student.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class TraineesListPage extends StatefulWidget {
  final String companyId;
  final String companyName;
  final List<Student> trainees;

  const TraineesListPage({
    Key? key,
    required this.companyId,
    required this.companyName,
    required this.trainees,
  }) : super(key: key);

  @override
  State<TraineesListPage> createState() => _TraineesListPageState();
}

class _TraineesListPageState extends State<TraineesListPage> {
  late List<Student> _filteredTrainees;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  String _selectedSort = 'Newest';
  bool _isGridView = false;

  final List<String> _filterOptions = [
    'All',
    'Active',
    'Graduated',
    'Withdrawn',
    'Suspended'
  ];

  final List<String> _sortOptions = [
    'Newest',
    'Oldest',
    'Name A-Z',
    'Name Z-A',
    'School',
    'Level',
    'CGPA',
  ];

  @override
  void initState() {
    super.initState();
    _filteredTrainees = List.from(widget.trainees);
    _searchController.addListener(_filterTrainees);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterTrainees() {
    setState(() {
      String searchTerm = _searchController.text.toLowerCase();
      _filteredTrainees = widget.trainees.where((trainee) {
        if (_selectedFilter != 'All') {
          if (trainee.academicStatus.toLowerCase() !=
              _selectedFilter.toLowerCase()) {
            return false;
          }
        }

        if (searchTerm.isNotEmpty) {
          return (trainee.fullName.toLowerCase().contains(searchTerm)) ||
              (trainee.institution.toLowerCase().contains(searchTerm)) ||
              (trainee.courseOfStudy.toLowerCase().contains(searchTerm)) ||
              (trainee.email.toLowerCase().contains(searchTerm)) ||
              (trainee.matricNumber.toLowerCase().contains(searchTerm)) ||
              (trainee.registrationNumber.toLowerCase().contains(searchTerm)) ||
              (trainee.currentAddress?.toLowerCase().contains(searchTerm) ??
                  false);
        }

        return true;
      }).toList();

      _applySorting();
    });
  }

  void _applySorting() {
    switch (_selectedSort) {
      case 'Newest':
        _filteredTrainees.sort((a, b) {
          final dateA = a.admissionDate ?? DateTime(2000);
          final dateB = b.admissionDate ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });
        break;
      case 'Oldest':
        _filteredTrainees.sort((a, b) {
          final dateA = a.admissionDate ?? DateTime(2000);
          final dateB = b.admissionDate ?? DateTime(2000);
          return dateA.compareTo(dateB);
        });
        break;
      case 'Name A-Z':
        _filteredTrainees.sort((a, b) =>
            a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
        break;
      case 'Name Z-A':
        _filteredTrainees.sort((a, b) =>
            b.fullName.toLowerCase().compareTo(a.fullName.toLowerCase()));
        break;
      case 'School':
        _filteredTrainees.sort((a, b) =>
            a.institution.toLowerCase().compareTo(b.institution.toLowerCase()));
        break;
      case 'Level':
        _filteredTrainees.sort((a, b) {
          final levelA = int.tryParse(a.level) ?? 0;
          final levelB = int.tryParse(b.level) ?? 0;
          return levelB.compareTo(levelA);
        });
        break;
      case 'CGPA':
        _filteredTrainees.sort((a, b) => b.cgpa.compareTo(a.cgpa));
        break;
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.3,
              maxChildSize: 0.7,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView( // Add SingleChildScrollView
                    controller: scrollController, // Use the provided controller
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Filter Trainees',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        const Text('Academic Status',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _filterOptions.map((filter) {
                            return FilterChip(
                              label: Text(filter),
                              selected: _selectedFilter == filter,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedFilter = filter;
                                });
                                this.setState(() {
                                  _selectedFilter = filter;
                                  _filterTrainees();
                                });
                                Navigator.pop(context);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        const Text('Sort By',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _sortOptions.map((sort) {
                            return FilterChip(
                              label: Text(sort),
                              selected: _selectedSort == sort,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedSort = sort;
                                });
                                this.setState(() {
                                  _selectedSort = sort;
                                  _filterTrainees();
                                });
                                Navigator.pop(context);
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }


  Widget _buildExportOption({
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// ==================== CSV EXPORT ====================

  Future<void> _exportAsCSV() async {
    try {
      final trainees = _filteredTrainees;
      if (trainees.isEmpty) {
        Fluttertoast.showToast(msg: "No trainees to export");
        return;
      }

      Fluttertoast.showToast(msg: "Generating CSV...");

      // Generate CSV content
      String csvContent = _generateCSV(trainees);

      // Request permission and save file
      if (await _requestStoragePermission()) {
        final String filePath = await _saveCSVToFile(csvContent);

        if (filePath.isNotEmpty && filePath != 'not-found') {
          _showExportSuccessDialog('CSV', filePath, trainees.length);
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to export CSV: $e");
    }
  }

  String _generateCSV(List<Student> trainees) {
    List<List<dynamic>> rows = [
      [
        'Full Name',
        'Email',
        'Phone',
        'Status',
        'Institution',
        'Course',
        'Department',
        'Level',
        'Matric Number',
        'Registration Number',
        'CGPA',
        'Skills',
        'Certificates Count',
        'ID Cards Count',
        'IT Letters Count',
        'Has Resume',
        'Has Transcript',
        'IT Eligible',
        'Address',
        'State of Origin',
        'LGA',
        'Nationality',
        'LinkedIn',
        'GitHub',
        'Portfolio',
        'Emergency Contact',
        'Emergency Phone',
      ]
    ];

    for (var trainee in trainees) {
      rows.add([
        trainee.fullName,
        trainee.email,
        trainee.phoneNumber,
        trainee.academicStatus,
        trainee.institution,
        trainee.courseOfStudy,
        trainee.department,
        trainee.level,
        trainee.matricNumber,
        trainee.registrationNumber,
        trainee.cgpa > 0 ? trainee.cgpa.toStringAsFixed(2) : 'N/A',
        trainee.skills.join('; '),
        trainee.academicCertificates.length.toString(),
        trainee.idCards.length.toString(),
        trainee.itLetters.length.toString(),
        trainee.resumeUrl.isNotEmpty ? 'Yes' : 'No',
        trainee.transcriptUrl.isNotEmpty ? 'Yes' : 'No',
        trainee.isEligibleForIndustrialTraining ? 'Yes' : 'No',
        trainee.currentAddress ?? 'N/A',
        trainee.stateOfOrigin ?? 'N/A',
        trainee.localGovernmentArea ?? 'N/A',
        trainee.nationality ?? 'N/A',
        trainee.linkedinUrl ?? 'N/A',
        trainee.githubUrl ?? 'N/A',
        trainee.portfolioUrl ?? 'N/A',
        trainee.emergencyContactName ?? 'N/A',
        trainee.emergencyContactPhone ?? 'N/A',
      ]);
    }

    // Remove the 'const' keyword
    return _convertToCSV(rows);
  }

  String _convertToCSV(List<List<dynamic>> rows) {
    String csv = '';
    for (var row in rows) {
      csv += row.map((cell) {
        String cellStr = cell.toString();
        // Escape quotes and wrap in quotes if contains comma or newline
        if (cellStr.contains(',') || cellStr.contains('\n') ||
            cellStr.contains('"')) {
          cellStr = '"${cellStr.replaceAll('"', '""')}"';
        }
        return cellStr;
      }).join(',') + '\n';
    }
    return csv;
  }

  Future<String> _saveCSVToFile(String csvContent) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        Fluttertoast.showToast(msg: "Storage directory not found");
        return "not-found";
      }

      final fileName = 'trainees_${DateFormat('yyyyMMdd_HHmmss').format(
          DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvContent);

      return file.path;
    } catch (e) {
      debugPrint('Error saving CSV: $e');
      return '';
    }
  }

// ==================== PDF EXPORT ====================

  Future<void> _exportAsPDF() async {
    try {
      final trainees = _filteredTrainees;
      if (trainees.isEmpty) {
        Fluttertoast.showToast(msg: "No trainees to export");
        return;
      }

      Fluttertoast.showToast(msg: "Generating PDF...");

      // Generate PDF
      final pdfFile = await _generatePDF(trainees);

      if (pdfFile != null) {
        _showExportSuccessDialog('PDF', pdfFile.path, trainees.length);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to export PDF: $e");
    }
  }

  Future<File?> _generatePDF(List<Student> trainees) async {
    try {
      final pdf = pw.Document();

      // Add cover page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'Trainee Report',
                    style: pw.TextStyle(
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Company: ${widget.companyName}',
                    style: const pw.TextStyle(fontSize: 18),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(
                        DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Total Trainees: ${trainees.length}',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Add summary page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildPDFSummary(context, trainees);
          },
        ),
      );

      // Add individual trainee pages
      for (int i = 0; i < trainees.length; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return _buildPDFTraineePage(context, trainees[i], i + 1);
            },
          ),
        );
      }

      // Save PDF file
      if (await _requestStoragePermission()) {
        final directory = await getExternalStorageDirectory();
        if (directory == null) return null;

        final fileName = 'trainees_${DateFormat('yyyyMMdd_HHmmss').format(
            DateTime.now())}.pdf';
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(await pdf.save());

        return file;
      }

      return null;
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      return null;
    }
  }

  pw.Widget _buildPDFSummary(pw.Context context, List<Student> trainees) {
    // Calculate statistics
    final statusCount = <String, int>{};
    final institutionCount = <String, int>{};
    final levelCount = <String, int>{};

    for (var trainee in trainees) {
      statusCount[trainee.academicStatus] =
          (statusCount[trainee.academicStatus] ?? 0) + 1;
      institutionCount[trainee.institution] =
          (institutionCount[trainee.institution] ?? 0) + 1;
      levelCount[trainee.level] = (levelCount[trainee.level] ?? 0) + 1;
    }

    // Create status distribution widgets
    List<pw.Widget> statusWidgets = [];
    statusCount.forEach((status, count) {
      statusWidgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 20, bottom: 4),
          child: pw.Row(
            children: [
              pw.Container(
                width: 12,
                height: 12,
                decoration: pw.BoxDecoration(
                  color: _getPDFStatusColor(status),
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text('$status: $count'),
            ],
          ),
        ),
      );
    });

    // Create top institutions widgets
    List<pw.Widget> institutionWidgets = [];
    var sortedInstitutions = institutionCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var i = 0; i <
        (sortedInstitutions.length > 5 ? 5 : sortedInstitutions.length); i++) {
      final entry = sortedInstitutions[i];
      institutionWidgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 20, bottom: 2),
          child: pw.Text('${entry.key}: ${entry.value}'),
        ),
      );
    }

    // Create level distribution widgets
    List<pw.Widget> levelWidgets = [];
    levelCount.forEach((level, count) {
      levelWidgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 20, bottom: 2),
          child: pw.Text('Level $level: $count'),
        ),
      );
    });

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Summary Statistics',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 20),

        // Status distribution
        pw.Text('Status Distribution:',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        ...statusWidgets,

        pw.SizedBox(height: 20),

        // Top institutions
        pw.Text('Top Institutions:',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        ...institutionWidgets,

        pw.SizedBox(height: 20),

        // Level distribution
        pw.Text('Level Distribution:',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        ...levelWidgets,

        pw.SizedBox(height: 20),

        // CGPA statistics
        pw.Text('CGPA Statistics:',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Average CGPA: ${_calculateAverageCGPA(trainees)}'),
              pw.Text('Students with CGPA > 3.5: ${_countHighCGPA(trainees)}'),
              pw.Text('Students with CGPA < 2.0: ${_countLowCGPA(trainees)}'),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPDFTraineePage(pw.Context context, Student trainee,
      int index) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Trainee #$index',
              style: pw.TextStyle(fontSize: 14, color: PdfColors.grey),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: _getPDFStatusColor(trainee.academicStatus),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Text(
                trainee.academicStatus,
                style: pw.TextStyle(color: PdfColors.white, fontSize: 10),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),

        pw.Text(
          trainee.fullName,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),

        pw.Divider(),
        pw.SizedBox(height: 10),

        // Personal Information
        _buildPDFSection('Personal Information', [
          'Email: ${trainee.email}',
          'Phone: ${trainee.phoneNumber}',
        ]),

        pw.SizedBox(height: 10),

        // Education Information
        _buildPDFSection('Education', [
          'Institution: ${trainee.institution}',
          'Course: ${trainee.courseOfStudy}',
          'Department: ${trainee.department}',
          'Level: ${trainee.level}',
          'Matric: ${trainee.matricNumber}',
          'CGPA: ${trainee.cgpa > 0 ? trainee.cgpa.toStringAsFixed(2) : 'N/A'}',
        ]),

        pw.SizedBox(height: 10),

        // Skills
        if (trainee.skills.isNotEmpty)
          _buildPDFSection('Skills', [trainee.skills.join(', ')]),

        pw.SizedBox(height: 10),

        // Documents Summary
        _buildPDFSection('Documents', [
          'Certificates: ${trainee.academicCertificates.length}',
          'ID Cards: ${trainee.idCards.length}',
          'IT Letters: ${trainee.itLetters.length}',
          'Resume: ${trainee.resumeUrl.isNotEmpty ? 'Yes' : 'No'}',
        ]),

        pw.SizedBox(height: 10),

        // Address
        if (trainee.currentAddress != null)
          _buildPDFSection('Address', [trainee.currentAddress!]),
      ],
    );
  }

  pw.Widget _buildPDFSection(String title, List<String> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        ...items.map((item) =>
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 10, bottom: 2),
              child: pw.Text(item, style: const pw.TextStyle(fontSize: 11)),
            )).toList(),
      ],
    );
  }

  PdfColor _getPDFStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return PdfColors.green;
      case 'graduated':
        return PdfColors.blue;
      case 'withdrawn':
        return PdfColors.orange;
      case 'suspended':
        return PdfColors.red;
      default:
        return PdfColors.grey;
    }
  }

// ==================== HELPER METHODS ====================

  Future<bool> _requestStoragePermission() async {
    if (await Permission.storage
        .request()
        .isGranted) {
      return true;
    }

    if (await Permission.storage.isPermanentlyDenied) {
      openAppSettings();
      return false;
    }

    return false;
  }

  void _showExportSuccessDialog(String format, String filePath, int count) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 48,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$format Export Successful',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Exported $count trainees'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    filePath
                        .split('/')
                        .last,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openFile(filePath);
                },
                child: const Text('Open File'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _shareFile(filePath);
                },
                child: const Text('Share'),
              ),
            ],
          ),
    );
  }

  Future<void> _openFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        Fluttertoast.showToast(msg: "File not found");
        return;
      }

      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showFileLocationDialog(filePath);
      }
    } catch (e) {
      debugPrint('Error opening file: $e');
      _showFileLocationDialog(filePath);
    }
  }

  Future<void> _shareFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        Fluttertoast.showToast(msg: "File not found");
        return;
      }

      final xFile = XFile(filePath);
      await Share.shareXFiles(
        [xFile],
        text: 'Trainee Export',
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to share file: $e");
    }
  }

  String _calculateAverageCGPA(List<Student> trainees) {
    double total = 0;
    int count = 0;

    for (var trainee in trainees) {
      if (trainee.cgpa > 0) {
        total += trainee.cgpa;
        count++;
      }
    }

    if (count == 0) return 'N/A';
    return (total / count).toStringAsFixed(2);
  }

  int _countHighCGPA(List<Student> trainees) {
    return trainees
        .where((t) => t.cgpa > 3.5)
        .length;
  }

  int _countLowCGPA(List<Student> trainees) {
    return trainees
        .where((t) => t.cgpa < 2.0 && t.cgpa > 0)
        .length;
  }

// Keep your existing _exportData() method for text export

  Future<void> _exportData() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Show loading
      Fluttertoast.showToast(msg: "Generating report...");

      // Get all trainees from current filtered list
      final trainees = _filteredTrainees;

      if (trainees.isEmpty) {
        Fluttertoast.showToast(msg: "No trainees to export");
        return;
      }

      // Generate the report
      String report = _generateTraineeReport(trainees);

      // Save to file
      final String filePath = await _saveReportToFile(report);

      if (filePath == 'not-found' || filePath.isEmpty) {
        Fluttertoast.showToast(msg: "Failed to save file");
        return;
      }

      // Show success message with options
      messenger.showSnackBar(
        SnackBar(
          content: Text('Report saved: ${trainees.length} trainees'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () async {
              // Close the snackbar first
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              // Open the file in file explorer
              await _openFileInExplorer(filePath);
            },
          ),
        ),
      );
    } catch (e, s) {
      debugPrintStack(stackTrace: s);
      Fluttertoast.showToast(msg: "Failed to export data: $e");
    }
  }

  String _generateTraineeReport(List<Student> trainees) {
    final StringBuffer report = StringBuffer();

    // Header
    report.writeln("TRAINEE MANAGEMENT REPORT");
    report.writeln("=" * 50);
    report.writeln("Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(
        DateTime.now())}");
    report.writeln("Company: ${widget.companyName}");
    report.writeln("Total Trainees: ${trainees.length}");
    report.writeln("=" * 50);
    report.writeln();

    // Statistics by status
    final statusCount = <String, int>{};
    for (var trainee in trainees) {
      final status = trainee.academicStatus;
      statusCount[status] = (statusCount[status] ?? 0) + 1;
    }

    report.writeln("STATUS SUMMARY:");
    statusCount.forEach((status, count) {
      report.writeln("  ${status.padRight(12)}: $count");
    });
    report.writeln();

    // Institution distribution
    final institutionCount = <String, int>{};
    for (var trainee in trainees) {
      final institution = trainee.institution.isNotEmpty
          ? trainee.institution
          : 'Not Specified';
      institutionCount[institution] = (institutionCount[institution] ?? 0) + 1;
    }

    report.writeln("INSTITUTION DISTRIBUTION:");
    institutionCount.forEach((institution, count) {
      report.writeln("  ${institution.substring(
          0, institution.length > 20 ? 20 : institution.length)}: $count");
    });
    report.writeln();

    // Level distribution
    final levelCount = <String, int>{};
    for (var trainee in trainees) {
      final level = trainee.level.isNotEmpty ? trainee.level : 'Not Specified';
      levelCount[level] = (levelCount[level] ?? 0) + 1;
    }

    report.writeln("LEVEL DISTRIBUTION:");
    levelCount.forEach((level, count) {
      report.writeln("  Level $level: $count");
    });
    report.writeln();

    // CGPA statistics
    double totalCgpa = 0;
    int cgpaCount = 0;
    for (var trainee in trainees) {
      if (trainee.cgpa > 0) {
        totalCgpa += trainee.cgpa;
        cgpaCount++;
      }
    }

    if (cgpaCount > 0) {
      report.writeln("CGPA STATISTICS:");
      report.writeln(
          "  Average CGPA: ${(totalCgpa / cgpaCount).toStringAsFixed(2)}");
      report.writeln("  Students with CGPA: $cgpaCount");
      report.writeln();
    }

    // Skills summary
    final allSkills = <String>[];
    for (var trainee in trainees) {
      allSkills.addAll(trainee.skills);
    }
    final skillCount = <String, int>{};
    for (var skill in allSkills) {
      skillCount[skill] = (skillCount[skill] ?? 0) + 1;
    }

    if (skillCount.isNotEmpty) {
      report.writeln("TOP SKILLS:");
      var sortedSkills = skillCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (int i = 0; i <
          (sortedSkills.length > 5 ? 5 : sortedSkills.length); i++) {
        final skill = sortedSkills[i];
        report.writeln("  ${skill.key}: ${skill.value} student${skill.value > 1
            ? 's'
            : ''}");
      }
      report.writeln();
    }

    // Document summary
    int totalCertificates = 0;
    int totalIdCards = 0;
    int totalItLetters = 0;
    int studentsWithResume = 0;

    for (var trainee in trainees) {
      totalCertificates += trainee.academicCertificates.length;
      totalIdCards += trainee.idCards.length;
      totalItLetters += trainee.itLetters.length;
      if (trainee.resumeUrl.isNotEmpty) studentsWithResume++;
    }

    report.writeln("DOCUMENT SUMMARY:");
    report.writeln("  Total Certificates: $totalCertificates");
    report.writeln("  Total ID Cards: $totalIdCards");
    report.writeln("  Total IT Letters: $totalItLetters");
    report.writeln("  Students with Resume: $studentsWithResume");
    report.writeln();

    // Detailed trainee list
    report.writeln("DETAILED TRAINEE LIST:");
    report.writeln("-" * 50);

    for (int i = 0; i < trainees.length; i++) {
      final t = trainees[i];
      report.writeln("${i + 1}. ${t.fullName}");
      report.writeln("   ID: ${t.uid}");
      report.writeln("   Status: ${t.academicStatus}");
      report.writeln("   Email: ${t.email}");
      report.writeln("   Phone: ${t.phoneNumber}");
      report.writeln("   Institution: ${t.institution}");
      report.writeln("   Course: ${t.courseOfStudy}");
      report.writeln("   Level: ${t.level}");
      if (t.cgpa > 0) report.writeln("   CGPA: ${t.cgpa.toStringAsFixed(2)}");
      if (t.skills.isNotEmpty) report.writeln(
          "   Skills: ${t.skills.join(', ')}");
      report.writeln(
          "   Documents: ${t.academicCertificates.length} certificates, "
              "${t.idCards.length} ID cards, ${t.itLetters.length} IT letters");
      report.writeln();
    }

    // Footer
    report.writeln("=" * 50);
    report.writeln("End of Report");

    return report.toString();
  }

  Future<String> _saveReportToFile(String report) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        Fluttertoast.showToast(msg: "Storage directory not found");
        return "not-found";
      }

      debugPrint("Directory path: ${directory.path}");

      final fileName = 'trainee_report_${DateFormat('yyyyMMdd_HHmmss').format(
          DateTime.now())}.txt';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(report);

      return file.path;
    } catch (e) {
      debugPrint('Error saving report: $e');
      return '';
    }
  }

  Future<void> _openFileInExplorer(String filePath) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        Fluttertoast.showToast(msg: "File not found");
        return;
      }

      // For Android
      if (Platform.isAndroid) {
        final uri = Uri.file(filePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          _showFileLocationDialog(filePath);
        }
      } else if (Platform.isIOS) {
        final uri = Uri.file(filePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          _showFileLocationDialog(filePath);
        }
      } else {
        // For other platforms
        final uri = Uri.file(filePath);
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Error opening file: $e');
      _showFileLocationDialog(filePath);
    }
  }

  void _showFileLocationDialog(String filePath) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('File Location'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('File saved at:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    filePath,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  _copyToClipboard(filePath);
                  Navigator.pop(context);
                },
                child: const Text('Copy Path'),
              ),
            ],
          ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Path copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery
        .of(context)
        .size;
    final isSmallScreen = screenSize.width < 360;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trainees',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${widget.companyName} • ${_filteredTrainees.length}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          // Toggle view mode
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view,
                size: isSmallScreen ? 20 : 24),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            tooltip: _isGridView ? 'List view' : 'Grid view',
          ),
          // Filter button
          IconButton(
            icon: Icon(Icons.filter_list, size: isSmallScreen ? 20 : 24),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: isSmallScreen
                      ? 'Search trainees...'
                      : 'Search by name, school, course...',
                  prefixIcon: Icon(Icons.search, size: isSmallScreen ? 18 : 24,
                      color: theme.colorScheme.primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, size: isSmallScreen ? 16 : 20),
                    onPressed: () {
                      _searchController.clear();
                      _filterTrainees();
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 8 : 12),
                ),
              ),
            ),
          ),

          // Active filters
          if (_selectedFilter != 'All' || _selectedSort != 'Newest')
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_selectedFilter != 'All')
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 8 : 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isSmallScreen
                                  ? 'S: $_selectedFilter'
                                  : 'Status: $_selectedFilter',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedFilter = 'All';
                                  _filterTrainees();
                                });
                              },
                              child: Icon(
                                  Icons.close, size: isSmallScreen ? 12 : 14,
                                  color: theme.colorScheme.primary),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (_selectedSort != 'Newest')
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 8 : 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isSmallScreen ? 'Sort: ${_selectedSort.substring(
                                  0, 3)}' : 'Sort: $_selectedSort',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedSort = 'Newest';
                                  _filterTrainees();
                                });
                              },
                              child: Icon(
                                  Icons.close, size: isSmallScreen ? 12 : 14,
                                  color: theme.colorScheme.primary),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Trainees list/grid
          Expanded(
            child: _filteredTrainees.isEmpty
                ? _buildEmptyState(theme, isSmallScreen)
                : _isGridView
                ? _buildGridView(theme, isSmallScreen)
                : _buildListView(theme, isSmallScreen),
          ),
        ],
      ),
      floatingActionButton: isSmallScreen
          ? FloatingActionButton(
        onPressed: _exportTrainees,
        child: const Icon(Icons.download),
      )
          : FloatingActionButton.extended(
        onPressed: _exportTrainees,
        icon: const Icon(Icons.download),
        label: const Text('Export List'),
      ),
    );
  }

  Widget _buildListView(ThemeData theme, bool isSmallScreen) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
      itemCount: _filteredTrainees.length,
      itemBuilder: (context, index) {
        final trainee = _filteredTrainees[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () => _showTraineeDetails(trainee),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: isSmallScreen ? 24 : 30,
                      backgroundColor: theme.colorScheme.primary.withOpacity(
                          0.1),
                      backgroundImage: trainee.imageUrl.isNotEmpty
                          ? NetworkImage(trainee.imageUrl)
                          : null,
                      child: trainee.imageUrl.isEmpty
                          ? Text(
                        _getInitials(trainee.fullName),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 16 : 18,
                        ),
                      )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Trainee info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name and status row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trainee.fullName,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: isSmallScreen ? 14 : 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (trainee.matricNumber.isNotEmpty &&
                                      !isSmallScreen)
                                    Text(
                                      trainee.matricNumber,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color: theme.colorScheme
                                            .onSurfaceVariant.withOpacity(0.7),
                                        fontSize: 10,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            _buildStatusChip(trainee.academicStatus, theme,
                                isCompact: isSmallScreen),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Institution
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance,
                              size: isSmallScreen ? 12 : 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                trainee.institution.isNotEmpty
                                    ? trainee.institution
                                    : 'Institution not specified',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: isSmallScreen ? 11 : 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        // Course (hide on very small screens to save space)
                        if (!isSmallScreen) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.menu_book,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  trainee.courseOfStudy.isNotEmpty
                                      ? trainee.courseOfStudy
                                      : 'Course not specified',
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 8),

                        // Level and CGPA badges
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(
                                      0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.grade,
                                      size: 12,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      isSmallScreen
                                          ? 'L${trainee.level}'
                                          : 'Level ${trainee.level}',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getCGPAColor(trainee.cgpa)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 12,
                                      color: _getCGPAColor(trainee.cgpa),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      trainee.cgpa.toStringAsFixed(1),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        color: _getCGPAColor(trainee.cgpa),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (trainee.isEligibleForIndustrialTraining) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.work,
                                        size: 12,
                                        color: Colors.green,
                                      ),
                                      if (!isSmallScreen) ...[
                                        const SizedBox(width: 2),
                                        Text(
                                          'IT Eligible',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: Colors.green,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Arrow indicator
                  Icon(
                    Icons.arrow_forward_ios,
                    size: isSmallScreen ? 12 : 14,
                    color: theme.colorScheme.primary.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridView(ThemeData theme, bool isSmallScreen) {
    return GridView.builder(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isSmallScreen ? 1 : 2,
        childAspectRatio: isSmallScreen ? 1.3 : 0.9,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredTrainees.length,
      itemBuilder: (context, index) {
        final trainee = _filteredTrainees[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showTraineeDetails(trainee),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar and status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        radius: isSmallScreen ? 28 : 24,
                        backgroundColor: theme.colorScheme.primary.withOpacity(
                            0.1),
                        backgroundImage: trainee.imageUrl.isNotEmpty
                            ? NetworkImage(trainee.imageUrl)
                            : null,
                        child: trainee.imageUrl.isEmpty
                            ? Text(
                          _getInitials(trainee.fullName),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                            : null,
                      ),
                      _buildStatusChip(
                          trainee.academicStatus, theme, isCompact: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Name
                  Text(
                    trainee.fullName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 15 : 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Institution
                  Row(
                    children: [
                      Icon(Icons.school, size: 12,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          trainee.institution.isNotEmpty
                              ? trainee.institution
                              : 'No institution',
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Course (only show on larger grid items)
                  if (!isSmallScreen) ...[
                    Row(
                      children: [
                        Icon(Icons.book, size: 12, color: theme.colorScheme
                            .primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            trainee.courseOfStudy.isNotEmpty
                                ? trainee.courseOfStudy
                                : 'No course',
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  // Level and CGPA
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'L${trainee.level}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getCGPAColor(trainee.cgpa).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              trainee.cgpa.toStringAsFixed(1),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _getCGPAColor(trainee.cgpa),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getCGPAColor(double cgpa) {
    if (cgpa >= 4.5) return Colors.green;
    if (cgpa >= 3.5) return Colors.blue;
    if (cgpa >= 2.5) return Colors.orange;
    if (cgpa >= 2.0) return Colors.amber;
    return Colors.red;
  }

  Widget _buildAvatar(Student trainee, ThemeData theme, {double radius = 30}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
      backgroundImage: trainee.imageUrl.isNotEmpty
          ? NetworkImage(trainee.imageUrl)
          : null,
      child: trainee.imageUrl.isEmpty
          ? Text(
        _getInitials(trainee.fullName),
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      )
          : null,
    );
  }

  Widget _buildStatusChip(String status, ThemeData theme,
      {bool isCompact = false}) {
    final Color statusColor = _getStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toTitleCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w600,
          fontSize: isCompact ? 10 : 11,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isSmallScreen) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: isSmallScreen ? 60 : 80,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'No Trainees Found',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: isSmallScreen ? 20 : 24,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 20 : 40),
                child: Text(
                  _searchController.text.isNotEmpty
                      ? 'No trainees match your search criteria'
                      : 'No potential trainees have shown interest yet',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: isSmallScreen ? 13 : 14,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    _searchController.clear();
                    _filterTrainees();
                  },
                  child: const Text('Clear Search'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods
  String _getInitials(String name) {
    if (name.isEmpty) return 'T';
    final names = name.trim().split(' ');
    if (names.length > 1) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'graduated':
        return Colors.blue;
      case 'withdrawn':
        return Colors.orange;
      case 'suspended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Action methods
  void _showTraineeDetails(Student trainee) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TraineeDetailsPage(trainee: trainee),
      ),
    );
  }

  void _messageTrainee(Student trainee) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Messaging ${trainee.fullName}')),
    );
  }

  void _viewTraineeDocuments(Student trainee) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TraineeDocumentsPage(trainee: trainee),
      ),
    );
  }

  void _scheduleMeeting(Student trainee) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Schedule meeting with ${trainee.fullName}')),
    );
  }

  void _exportTrainees() {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Export Trainees'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Choose export format:'),
                const SizedBox(height: 16),
                _buildExportOption(
                  icon: Icons.table_chart,
                  color: Colors.green,
                  label: 'CSV Format',
                  subtitle: 'For spreadsheets and data analysis',
                  onTap: () {
                    Navigator.pop(context);
                    _exportAsCSV(); // Call CSV export
                  },
                ),
                const SizedBox(height: 8),
                _buildExportOption(
                  icon: Icons.picture_as_pdf,
                  color: Colors.red,
                  label: 'PDF Format',
                  subtitle: 'Professional document with formatting',
                  onTap: () {
                    Navigator.pop(context);
                    _exportAsPDF(); // Call PDF export
                  },
                ),
                const SizedBox(height: 8),
                _buildExportOption(
                  icon: Icons.description,
                  color: Colors.blue,
                  label: 'Text Report',
                  subtitle: 'Simple text format',
                  onTap: () {
                    Navigator.pop(context);
                    _exportData(); // Keep text export for this option
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }
}


// Trainee Details Page (keep as is)
class TraineeDetailsPage extends StatelessWidget {
  final Student trainee;
  const TraineeDetailsPage({Key? key, required this.trainee}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          trainee.fullName,
          style: TextStyle(fontSize: isSmallScreen ? 18 : 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Info Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: isSmallScreen ? 30 : 40,
                      backgroundColor: theme.primaryColor.withOpacity(0.1),
                      backgroundImage: trainee.imageUrl.isNotEmpty
                          ? NetworkImage(trainee.imageUrl)
                          : null,
                      child: trainee.imageUrl.isEmpty
                          ? Text(
                        trainee.fullName[0].toUpperCase(),
                        style: TextStyle(fontSize: isSmallScreen ? 24 : 30),
                      )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trainee.fullName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 16 : 20,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trainee.email,
                            style: TextStyle(fontSize: isSmallScreen ? 11 : 13),
                          ),
                          Text(
                            trainee.phoneNumber,
                            style: TextStyle(fontSize: isSmallScreen ? 11 : 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Education Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Education',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 18 : 20,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Institution', trainee.institution, isSmallScreen),
                    _buildDetailRow('Course', trainee.courseOfStudy, isSmallScreen),
                    _buildDetailRow('Department', trainee.department, isSmallScreen),
                    _buildDetailRow('Level', trainee.level, isSmallScreen),
                    _buildDetailRow('Matric No', trainee.matricNumber, isSmallScreen),
                    _buildDetailRow('Reg No', trainee.registrationNumber, isSmallScreen),
                    _buildDetailRow('CGPA', trainee.cgpa.toStringAsFixed(2), isSmallScreen),
                    _buildDetailRow('Status', trainee.academicStatus, isSmallScreen),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Skills Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skills & Portfolio',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 18 : 20,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: trainee.skills.map((skill) {
                        return Chip(
                          label: Text(
                            skill,
                            style: TextStyle(fontSize: isSmallScreen ? 11 : 13),
                          ),
                          backgroundColor: theme.primaryColor.withOpacity(0.1),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isSmallScreen ? 80 : 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Not specified',
              style: TextStyle(
                color: Colors.grey,
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Trainee Documents Page (keep as is)
class TraineeDocumentsPage extends StatelessWidget {
  final Student trainee;
  const TraineeDocumentsPage({Key? key, required this.trainee}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${trainee.fullName}\'s Documents',
          style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        children: [
          // Academic Documents
          _buildDocumentSection(
            context,
            title: 'Academic Documents',
            documents: [
              if (trainee.transcriptUrl.isNotEmpty)
                DocumentItem('Transcript', trainee.transcriptUrl),
              ...trainee.academicCertificates.map((url) =>
                  DocumentItem('Certificate', url)),
              if (trainee.studentIdCardUrl.isNotEmpty)
                DocumentItem('Student ID Card', trainee.studentIdCardUrl),
            ],
            isSmallScreen: isSmallScreen,
          ),

          const SizedBox(height: 12),

          // Portfolio Documents
          _buildDocumentSection(
            context,
            title: 'Portfolio',
            documents: [
              if (trainee.resumeUrl.isNotEmpty)
                DocumentItem('Resume/CV', trainee.resumeUrl),
              ...trainee.certifications.map((url) =>
                  DocumentItem('Certification', url)),
            ],
            isSmallScreen: isSmallScreen,
          ),

          const SizedBox(height: 12),

          // ID Cards
          if (trainee.idCards.isNotEmpty)
            _buildDocumentSection(
              context,
              title: 'ID Cards (${trainee.idCards.length})',
              documents: trainee.idCards.asMap().entries.map((entry) =>
                  DocumentItem('ID Card ${entry.key + 1}', entry.value)).toList(),
              isSmallScreen: isSmallScreen,
            ),

          const SizedBox(height: 12),

          // IT Letters
          if (trainee.itLetters.isNotEmpty)
            _buildDocumentSection(
              context,
              title: 'IT Letters (${trainee.itLetters.length})',
              documents: trainee.itLetters.asMap().entries.map((entry) =>
                  DocumentItem('IT Letter ${entry.key + 1}', entry.value)).toList(),
              isSmallScreen: isSmallScreen,
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentSection(
      BuildContext context, {
        required String title,
        required List<DocumentItem> documents,
        required bool isSmallScreen,
      }) {
    if (documents.isEmpty) return const SizedBox();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 16 : 18,
              ),
            ),
            const SizedBox(height: 8),
            ...documents.map((doc) => _buildDocumentTile(doc, isSmallScreen)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentTile(DocumentItem doc, bool isSmallScreen) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.description, size: isSmallScreen ? 18 : 20),
      title: Text(
        doc.name,
        style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
      ),
      subtitle: Text(
        doc.url.length > 30
            ? '...${doc.url.substring(doc.url.length - 30)}'
            : doc.url,
        style: TextStyle(fontSize: isSmallScreen ? 11 : 12),
      ),
      trailing: IconButton(
        icon: Icon(Icons.open_in_new, size: isSmallScreen ? 16 : 18),
        onPressed: () {
          // Open document URL
        },
      ),
    );
  }
}

class DocumentItem {
  final String name;
  final String url;

  DocumentItem(this.name, this.url);
}
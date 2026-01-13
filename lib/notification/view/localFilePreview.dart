import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:photo_view/photo_view.dart';

class InAppFilePreviewPage extends StatefulWidget {
  final List<File> files;
  final List<Map<String, String>> fileDetails;
  final int initialIndex;

  const InAppFilePreviewPage({
    Key? key,
    required this.files,
    required this.fileDetails,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  _InAppFilePreviewPageState createState() => _InAppFilePreviewPageState();
}

class _InAppFilePreviewPageState extends State<InAppFilePreviewPage> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isLoadingPdf = false;
  List<String?> _pdfPaths = [];
  List<int?> _totalPagesList = [];
  List<int?> _currentPagesList = [];
  List<bool> _pdfReadyList = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    // Initialize lists for all files
    _pdfPaths = List.filled(widget.files.length, null);
    _totalPagesList = List.filled(widget.files.length, null);
    _currentPagesList = List.filled(widget.files.length, 0);
    _pdfReadyList = List.filled(widget.files.length, false);

    // Load the initial file
    _loadCurrentFile();
  }

  Future<void> _loadCurrentFile() async {
    if (_currentIndex >= widget.files.length) return;

    final file = widget.files[_currentIndex];
    final fileType = _getFileType(file.path);

    if (fileType == 'pdf') {
      setState(() {
        _isLoadingPdf = true;
        _pdfReadyList[_currentIndex] = false;
      });

      try {
        // Check if file exists and is readable
        if (await file.exists()) {
          setState(() {
            _pdfPaths[_currentIndex] = file.path;
            _pdfReadyList[_currentIndex] = true;
          });
        }
      } catch (e) {
        debugPrint('Error loading PDF: $e');
      } finally {
        setState(() => _isLoadingPdf = false);
      }
    } else {
      // For non-PDF files, mark as ready
      setState(() {
        _pdfReadyList[_currentIndex] = true;
      });
    }
  }

  String _getFileType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    if (extension == '.pdf') return 'pdf';
    if (['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'].contains(extension)) {
      return 'image';
    }
    return 'unknown';
  }

  Widget _buildPdfPreview(int index) {
    final filePath = _pdfPaths[index];
    final isReady = _pdfReadyList[index];

    if (_isLoadingPdf && index == _currentIndex) {
      return Center(child: CircularProgressIndicator());
    }

    if (filePath == null || !isReady) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 60),
            SizedBox(height: 16),
            Text(
              'Failed to load PDF',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
      );
    }

    return PDFView(
      key: Key('pdf_$index'), // Important: unique key for each PDF
      filePath: filePath,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      defaultPage: _currentPagesList[index] ?? 0,
      fitPolicy: FitPolicy.BOTH,
      preventLinkNavigation: false,
      onRender: (_pages) {
        setState(() {
          _totalPagesList[index] = _pages;
        });
      },
      onError: (error) {
        debugPrint('PDF Error for index $index: $error');
        setState(() {
          _pdfReadyList[index] = false;
        });
      },
      onPageError: (page, error) {
        debugPrint('Page $page error for index $index: $error');
      },
      onPageChanged: (int? page, int? total) {
        setState(() {
          _currentPagesList[index] = page;
        });
      },
    );
  }

  Widget _buildImagePreview(int index) {
    final file = widget.files[index];
    return PhotoView(
      key: Key('image_$index'), // Important: unique key for each image
      imageProvider: FileImage(file),
      backgroundDecoration: BoxDecoration(color: Colors.black),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 2.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileDetails[_currentIndex]['name'] ?? 'Preview',
              style: TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.fileDetails.length > 1)
              Text(
                '${_currentIndex + 1} of ${widget.files.length}',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          if (_getFileType(widget.files[_currentIndex].path) == 'pdf' &&
              _totalPagesList[_currentIndex] != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: Text(
                '${(_currentPagesList[_currentIndex] ?? 0) + 1}/${_totalPagesList[_currentIndex]}',
                style: TextStyle(color: Colors.white),
              ),
            ),
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () => _saveCurrentFile(),
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () => _shareCurrentFile(),
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (widget.files.isEmpty) {
      return Center(child: Text('No files', style: TextStyle(color: Colors.white)));
    }

    return Column(
      children: [
        // Page indicator for multiple files
        if (widget.files.length > 1)
          Container(
            padding: EdgeInsets.all(8),
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: _currentIndex > 0 ? _goToPrevious : null,
                ),
                Text(
                  '${_currentIndex + 1} / ${widget.files.length}',
                  style: TextStyle(color: Colors.white),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: _currentIndex < widget.files.length - 1 ? _goToNext : null,
                ),
              ],
            ),
          ),

        // File preview with PageView
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.files.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              // Load the new file if it's a PDF
              _loadCurrentFile();
            },
            itemBuilder: (context, index) {
              final file = widget.files[index];
              final fileType = _getFileType(file.path);

              switch (fileType) {
                case 'pdf':
                  return _buildPdfPreview(index);
                case 'image':
                  return _buildImagePreview(index);
                default:
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.insert_drive_file, size: 100, color: Colors.grey),
                        SizedBox(height: 20),
                        Text(
                          'Preview not available in app',
                          style: TextStyle(color: Colors.white),
                        ),
                        SizedBox(height: 10),
                        Text(
                          path.basename(file.path),
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
              }
            },
          ),
        ),
      ],
    );
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.files.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveCurrentFile() async {
    final file = widget.files[_currentIndex];
    try {
      final savedPath = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          sourceFilePath: file.path,
          fileName: path.basename(file.path),
        ),
      );
      if (savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareCurrentFile() async {
    final file = widget.files[_currentIndex];
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Sharing file: ${path.basename(file.path)}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Share failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
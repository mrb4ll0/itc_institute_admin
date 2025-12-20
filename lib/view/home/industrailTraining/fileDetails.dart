import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FullScreenViewer extends StatefulWidget {
  final List<String>? firebasePaths; // Changed to support multiple paths
  final String? firebasePath; // Keep for backward compatibility
  final String? fileName;
  final String? fileType;
  final int initialIndex; // For gallery mode

  FullScreenViewer({
    Key? key,
    this.firebasePaths, // List of paths for gallery mode
    this.firebasePath, // Single path for backward compatibility
    this.fileName,
    this.fileType,
    this.initialIndex = 0,
  }) : super(key: key) {
    // Validate that at least one path is provided
    assert(firebasePaths != null || firebasePath != null,
    'Either firebasePaths or firebasePath must be provided');
  }

  @override
  _FullScreenViewerState createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<FullScreenViewer> {
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _localPath;
  String? _errorMessage;
  Uint8List? _fileBytes;
  List<String> _downloadUrls = []; // Changed to list
  PDFViewController? _pdfViewController;
  int _totalPages = 0;
  int _currentPage = 0;
  bool _pdfReady = false;
  int _currentIndex = 0; // For gallery mode
  PageController? _pageController;
  bool _isGalleryMode = false;
  List<bool> _loadedImages = []; // Track which images are loaded

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Determine if we're in gallery mode
      _isGalleryMode = widget.firebasePaths != null && widget.firebasePaths!.length > 1;

      // Get all download URLs
      final List<String> paths = _isGalleryMode
          ? widget.firebasePaths!
          : [widget.firebasePath!];

      debugPrint("Initializing with ${paths.length} file(s)");

      for (String path in paths) {
        final url = await _getFirebaseDownloadUrl(path);
        if (url != null) {
          _downloadUrls.add(url);
        }
      }

      if (_downloadUrls.isEmpty) {
        throw Exception('Could not get download URLs from Firebase');
      }

      // Initialize loaded images tracker
      _loadedImages = List.filled(_downloadUrls.length, false);

      // Initialize page controller for gallery mode
      if (_isGalleryMode) {
        _pageController = PageController(initialPage: _currentIndex);
      }

      final firstFileType = _getFileTypeFromUrl(_downloadUrls.first);
      debugPrint("First file type: $firstFileType");

      if (firstFileType == 'image') {
        // For images, we can preview directly
        setState(() => _isLoading = false);
      } else if (firstFileType == 'pdf') {
        // For PDFs, download first for preview
        debugPrint("File is PDF");
        await _loadFileForPreview();
      } else {
        // For other files, just show download option
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Initialization error: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading file: ${e.toString()}';
      });
    }
  }

  Future<String?> _getFirebaseDownloadUrl(String filePath) async {
    // If the string already starts with https://firebasestorage.googleapis.com, it's a ready URL.
    if (filePath.startsWith("http://") || filePath.startsWith("https://")) {
      debugPrint("Input is already a download URL");
      return filePath;
    }

    try {
      // Otherwise treat it as storage path
      Reference storageRef = FirebaseStorage.instance.ref().child(filePath);
      String downloadUrl = await storageRef.getDownloadURL();
      debugPrint("Generated Firebase download URL: $downloadUrl");
      return downloadUrl;
    } catch (e, s) {
      debugPrint("Error getting download URL: $e");
      debugPrintStack(stackTrace: s);
      return null;
    }
  }

  String _getFileTypeFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();

      if (path.contains('.pdf')) return 'pdf';
      if (path.contains('.jpg') || path.contains('.jpeg')) return 'image';
      if (path.contains('.png')) return 'image';
      if (path.contains('.gif')) return 'image';
      if (path.contains('.bmp')) return 'image';
      if (path.contains('.webp')) return 'image';
      if (path.contains('.svg')) return 'image';
      if (path.contains('.tiff') || path.contains('.tif')) return 'image';
      if (path.contains('.ico')) return 'image';
      if (path.contains('.heic') || path.contains('.heif')) return 'image';
      if (path.contains('.avif')) return 'image';
      if (path.contains('.apng')) return 'image';
      if (path.contains('.jxl')) return 'image';
      return 'document';
    } catch (e) {
      return 'unknown';
    }
  }

  Future<void> _loadFileForPreview() async {
    if (_downloadUrls.isEmpty) return;

    try {
      debugPrint("Downloading file for preview...");

      final response = await Dio().get(
        _downloadUrls.first,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            debugPrint(
              "Download progress: ${(received / total * 100).toStringAsFixed(1)}%",
            );
          }
        },
      );

      if (response.statusCode == 200 && response.data is List<int>) {
        _fileBytes = Uint8List.fromList(response.data as List<int>);
        debugPrint("File downloaded, size: ${_fileBytes!.length} bytes");

        // Save to temporary file
        final tempDir = await getTemporaryDirectory();
        final fileType = _getFileTypeFromUrl(_downloadUrls.first);
        final extension = fileType == 'pdf' ? '.pdf' : '.file';
        final tempFile = File('${tempDir.path}/temp_preview$extension');
        await tempFile.writeAsBytes(_fileBytes!);
        _localPath = tempFile.path;

        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("File loading error: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = 'Preview not available. You can download the file.';
      });
    }
  }

  Widget _buildImagePreview() {
    if (_downloadUrls.isEmpty) {
      return Center(
        child: Text(
          'No preview available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    if (!_isGalleryMode) {
      // Single image view
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: InteractiveViewer(
          minScale: 0.1,
          maxScale: 5.0,
          child: Image.network(
            _downloadUrls.first,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 60),
                    SizedBox(height: 16),
                    Text(
                      'Failed to load image',
                      style: TextStyle(fontSize: 16, color: Colors.red),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _downloadCurrentFile,
                      child: Text('Download Instead'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    } else {
      // Gallery mode - multiple images
      return Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _downloadUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black,
                child: InteractiveViewer(
                  minScale: 0.1,
                  maxScale: 5.0,
                  child: Image.network(
                    _downloadUrls[index],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        _loadedImages[index] = true;
                        return child;
                      }
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 60),
                            SizedBox(height: 16),
                            Text(
                              'Failed to load image ${index + 1}',
                              style: TextStyle(fontSize: 16, color: Colors.red),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),

          // Gallery controls overlay
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Container(
              alignment: Alignment.center,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${_downloadUrls.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          // Navigation arrows for gallery
          if (_downloadUrls.length > 1)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 40,
                  ),
                  onPressed: _currentIndex > 0
                      ? () {
                    _pageController?.previousPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                      : null,
                ),
              ),
            ),

          if (_downloadUrls.length > 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 40,
                  ),
                  onPressed: _currentIndex < _downloadUrls.length - 1
                      ? () {
                    _pageController?.nextPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                      : null,
                ),
              ),
            ),

          // Download current image button
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.black.withOpacity(0.6),
              foregroundColor: Colors.white,
              onPressed: _downloadCurrentFile,
              child: Icon(Icons.download),
              mini: true,
            ),
          ),
        ],
      );
    }
  }

  Future<void> _downloadPdfForPreview() async {
    if (_downloadUrls.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      debugPrint("Downloading PDF for preview...");

      final tempDir = await getTemporaryDirectory();
      final fileName = _extractFileNameFromPath(widget.firebasePath ?? _downloadUrls.first);
      final cleanFileName = _cleanFileName(fileName);
      final tempFile = File('${tempDir.path}/preview_$cleanFileName');

      // Download the file
      await Dio().download(
        _downloadUrls.first,
        tempFile.path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100);
            debugPrint("Download progress: ${progress.toStringAsFixed(1)}%");

            // Update UI if needed
            if (mounted) {
              setState(() {
                _downloadProgress = received / total;
              });
            }
          }
        },
      );

      // Verify the file was downloaded
      if (await tempFile.exists()) {
        final fileSize = await tempFile.length();
        debugPrint(
          "PDF downloaded successfully: ${tempFile.path}, size: $fileSize bytes",
        );

        _localPath = tempFile.path;

        setState(() {
          _isLoading = false;
        });
      } else {
        throw Exception('File download failed - file not found');
      }
    } catch (e, stackTrace) {
      debugPrint("PDF download error: $e");
      debugPrint("Stack trace: $stackTrace");

      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load PDF for preview: ${e.toString()}';
      });
    }
  }

  Widget _buildPdfPreview() {
    // ... (keep existing PDF preview code, but update to use _downloadUrls.first)
    // (The PDF preview logic remains the same for single PDF files)

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
            ),
            SizedBox(height: 20),
            Text(
              _downloadProgress > 0
                  ? 'Downloading PDF... ${(_downloadProgress * 100).toStringAsFixed(0)}%'
                  : 'Loading PDF...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_localPath == null || _errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 100, color: Colors.blue),
            SizedBox(height: 20),
            Text(
              'PDF Document',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            Text(
              widget.fileName ?? _extractFileNameFromPath(widget.firebasePath ?? _downloadUrls.first),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 20),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _downloadPdfForPreview,
              icon: Icon(Icons.refresh),
              label: Text('Retry PDF Preview'),
            ),
            SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _downloadCurrentFile,
              icon: Icon(Icons.download),
              label: Text('Download to Device'),
            ),
          ],
        ),
      );
    }

    // Actual PDF Preview
    return Stack(
      children: [
        PDFView(
          filePath: _localPath,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          pageSnap: true,
          defaultPage: _currentPage,
          fitPolicy: FitPolicy.BOTH,
          preventLinkNavigation: false,
          onRender: (pages) {
            if (mounted) {
              setState(() {
                _totalPages = pages!;
                _pdfReady = true;
              });
            }
          },
          onError: (error) {
            debugPrint("PDF Error: $error");
            if (mounted) {
              setState(() {
                _errorMessage = 'Failed to load PDF: $error';
              });
            }
          },
          onPageError: (page, error) {
            debugPrint("PDF Page Error: $error on page $page");
          },
          onViewCreated: (PDFViewController pdfViewController) {
            _pdfViewController = pdfViewController;
          },
          onPageChanged: (int? page, int? total) {
            if (page != null && total != null && mounted) {
              setState(() {
                _currentPage = page;
              });
            }
          },
        ),

        // Page indicator overlay
        if (_pdfReady)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Container(
              alignment: Alignment.center,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: Colors.white),
                      onPressed: _currentPage > 0
                          ? () {
                        _pdfViewController?.setPage(_currentPage - 1);
                      }
                          : null,
                    ),
                    Text(
                      '${_currentPage + 1} / $_totalPages',
                      style: TextStyle(color: Colors.white),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: Colors.white),
                      onPressed: _currentPage < _totalPages - 1
                          ? () {
                        _pdfViewController?.setPage(_currentPage + 1);
                      }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDocumentPreview() {
    final fileType = _getFileTypeFromUrl(_downloadUrls.first);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getFileIcon(fileType), size: 100, color: Colors.blue),
          SizedBox(height: 20),
          Text(
            _getFileTypeName(fileType),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 10),
          Text(
            widget.fileName ?? _extractFileNameFromPath(widget.firebasePath ?? _downloadUrls.first),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _downloadCurrentFile,
            icon: Icon(Icons.download),
            label: Text('Download to View'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadCurrentFile() async {
    if (_downloadUrls.isEmpty) return;

    final url = _isGalleryMode ? _downloadUrls[_currentIndex] : _downloadUrls.first;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      Directory directory;
      if (Platform.isAndroid) {
        // Use Downloads directory
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory =
              await getExternalStorageDirectory() ??
                  await getTemporaryDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      // Extract filename from URL
      String fileName = _extractFileNameFromPath(url);
      fileName = _cleanFileName(fileName);

      // Add index for gallery mode
      if (_isGalleryMode) {
        fileName = '${_currentIndex + 1}_$fileName';
      }

      final savePath = '${directory.path}/$fileName';
      debugPrint("Saving to: $savePath");

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Download the file
      await Dio().download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      final file = File(savePath);
      final fileSize = await file.length();

      setState(() {
        _isDownloading = false;
        _localPath = savePath;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded: $fileName'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'OPEN',
            onPressed: () => _openFile(savePath),
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint("Download error: $e");
      debugPrint("Stack trace: $stackTrace");

      setState(() => _isDownloading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadAllFiles() async {
    if (!_isGalleryMode || _downloadUrls.length <= 1) {
      await _downloadCurrentFile();
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      Directory directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download/Images_${DateTime.now().millisecondsSinceEpoch}');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      int downloadedCount = 0;
      for (int i = 0; i < _downloadUrls.length; i++) {
        final url = _downloadUrls[i];
        String fileName = _extractFileNameFromPath(url);
        fileName = _cleanFileName(fileName);
        fileName = '${i + 1}_$fileName';

        final savePath = '${directory.path}/$fileName';

        await Dio().download(
          url,
          savePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              final progress = (downloadedCount + (received / total)) / _downloadUrls.length;
              setState(() {
                _downloadProgress = progress;
              });
            }
          },
        );

        downloadedCount++;
      }

      setState(() {
        _isDownloading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded ${_downloadUrls.length} images to ${directory.path}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _extractFileNameFromPath(String path) {
    // ... (keep existing filename extraction logic)
    try {
      // If it's a URL, parse it
      if (path.startsWith("http://") || path.startsWith("https://")) {
        final uri = Uri.parse(path);
        String fileName = uri.path.split('/').last;

        // Decode URL encoding
        fileName = Uri.decodeComponent(fileName);

        // Remove query parameters if present
        fileName = fileName.split('?').first;

        // Clean up Firebase storage paths
        fileName = fileName.replaceAll('%2F', '/').replaceAll('uploads/', '');

        // Get the actual filename after all cleaning
        final segments = fileName
            .split('/')
            .where((s) => s.isNotEmpty)
            .toList();
        if (segments.isNotEmpty) {
          fileName = segments.last;
        }

        return fileName.isNotEmpty ? fileName : 'document';
      } else {
        // Handle non-URL paths (Firebase storage paths)
        String cleanPath = path
            .replaceAll('uploads/', '')
            .replaceAll('%2F', '/');
        final segments = cleanPath
            .split('/')
            .where((s) => s.isNotEmpty)
            .toList();
        if (segments.isNotEmpty) {
          String fileName = segments.last;
          fileName = Uri.decodeComponent(fileName);
          return fileName.isNotEmpty ? fileName : 'document';
        }
      }
    } catch (e) {
      debugPrint("Error extracting filename: $e");
    }

    return 'document_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _cleanFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _openFile(String path) async {
    try {
      await OpenFilex.open(path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot open file: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareCurrentFile() async {
    if (_downloadUrls.isEmpty) return;

    try {
      // For immediate sharing, share the URL
      await SharePlus.instance.share(
        ShareParams(
          text: _downloadUrls[_isGalleryMode ? _currentIndex : 0],
          subject: 'Image from ITC Institute',
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot share file: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'image':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getFileTypeName(String fileType) {
    switch (fileType) {
      case 'pdf':
        return 'PDF Document';
      case 'image':
        return 'Image';
      default:
        return 'File';
    }
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
            if (_isGalleryMode)
              Text(
                'Gallery',
                style: TextStyle(fontSize: 16),
              ),
            Text(
              widget.fileName ?? _extractFileNameFromPath(
                  widget.firebasePath ?? _downloadUrls.first),
              style: TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            if (_isGalleryMode)
              Text(
                '${_currentIndex + 1} of ${_downloadUrls.length}',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          if (_isDownloading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    value: _downloadProgress,
                    strokeWidth: 3,
                    backgroundColor: Colors.grey,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else if (!_isLoading && _errorMessage == null)
            if (_isGalleryMode)
              PopupMenuButton(
                icon: Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 20),
                        SizedBox(width: 8),
                        Text('Download Current'),
                      ],
                    ),
                    onTap: _downloadCurrentFile,
                  ),
                  PopupMenuItem(
                    child: Row(
                      children: [
                        Icon(Icons.download_for_offline, size: 20),
                        SizedBox(width: 8),
                        Text('Download All'),
                      ],
                    ),
                    onTap: _downloadAllFiles,
                  ),
                  PopupMenuItem(
                    child: Row(
                      children: [
                        Icon(Icons.share, size: 20),
                        SizedBox(width: 8),
                        Text('Share Current'),
                      ],
                    ),
                    onTap: _shareCurrentFile,
                  ),
                ],
              )
            else
              IconButton(
                icon: Icon(Icons.download),
                onPressed: _downloadCurrentFile,
                tooltip: 'Download File',
              ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              _isGalleryMode ? 'Loading gallery...' : 'Loading file...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      )
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 60),
              SizedBox(height: 20),
              Text(
                'Error Loading File',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _downloadCurrentFile,
                child: Text('Try Download Instead'),
              ),
            ],
          ),
        ),
      )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_downloadUrls.isEmpty) {
      return Center(
        child: Text('No file available', style: TextStyle(color: Colors.white)),
      );
    }

    final fileType = _getFileTypeFromUrl(_downloadUrls.first);

    if (fileType == 'image') {
      return _buildImagePreview();
    } else if (fileType == 'pdf') {
      return _buildPdfPreview();
    } else {
      return _buildDocumentPreview();
    }
  }
}
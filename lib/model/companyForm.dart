import 'dart:convert';
import 'dart:math' as math;

class CompanyForm {
  final String formId;
  final String departmentName;
  final String? filePath;
  final String companyId;
  final DateTime uploadedAt;
  final String? fileName;
  final String? fileSize;
  final String? fileType;
  final String? downloadUrl;

  CompanyForm({
    required this.formId,
    required this.departmentName,
    this.filePath,
    required this.companyId,
    required this.uploadedAt,
    this.fileName,
    this.fileSize,
    this.fileType,
    this.downloadUrl,
  });

  factory CompanyForm.newForm({
    required String departmentName,
    required String companyId,
    String? filePath,
    String? fileName,
    String? fileSize,
    String? fileType,
  }) {
    return CompanyForm(
      formId: 'form_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}',
      departmentName: departmentName,
      companyId: companyId,
      uploadedAt: DateTime.now(),
      filePath: filePath,
      fileName: fileName,
      fileSize: fileSize,
      fileType: fileType,
    );
  }

  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(Iterable.generate(
      length,
          (_) => chars.codeUnitAt((math.Random().nextDouble() * chars.length).floor()),
    ));
  }

  Map<String, dynamic> toMap() {
    return {
      'formId': formId,
      'departmentName': departmentName,
      'filePath': filePath,
      'companyId': companyId,
      'uploadedAt': uploadedAt.toIso8601String(),
      'fileName': fileName,
      'fileSize': fileSize,
      'fileType': fileType,
      'downloadUrl': downloadUrl,
    };
  }

  factory CompanyForm.fromMap(Map<String, dynamic> map) {
    return CompanyForm(
      formId: map['formId']?.toString() ?? '',
      departmentName: map['departmentName']?.toString() ?? '',
      filePath: map['filePath']?.toString(),
      companyId: map['companyId']?.toString() ?? '',
      uploadedAt: map['uploadedAt'] != null
          ? DateTime.tryParse(map['uploadedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      fileName: map['fileName']?.toString(),
      fileSize: map['fileSize']?.toString(),
      fileType: map['fileType']?.toString(),
      downloadUrl: map['downloadUrl']?.toString(),
    );
  }

  String toJson() => json.encode(toMap());

  factory CompanyForm.fromJson(String source) =>
      CompanyForm.fromMap(json.decode(source));

  @override
  String toString() {
    return 'CompanyForm(formId: $formId, departmentName: $departmentName, filePath: $filePath, companyId: $companyId, uploadedAt: $uploadedAt, fileName: $fileName, fileSize: $fileSize, fileType: $fileType, downloadUrl: $downloadUrl)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CompanyForm &&
        other.formId == formId &&
        other.departmentName == departmentName &&
        other.filePath == filePath &&
        other.companyId == companyId &&
        other.uploadedAt == uploadedAt &&
        other.fileName == fileName &&
        other.fileSize == fileSize &&
        other.fileType == fileType &&
        other.downloadUrl == downloadUrl;
  }

  @override
  int get hashCode {
    return Object.hash(
      formId,
      departmentName,
      filePath,
      companyId,
      uploadedAt,
      fileName,
      fileSize,
      fileType,
      downloadUrl,
    );
  }

  CompanyForm copyWith({
    String? formId,
    String? departmentName,
    String? filePath,
    String? companyId,
    DateTime? uploadedAt,
    String? fileName,
    String? fileSize,
    String? fileType,
    String? downloadUrl,
  }) {
    return CompanyForm(
      formId: formId ?? this.formId,
      departmentName: departmentName ?? this.departmentName,
      filePath: filePath ?? this.filePath,
      companyId: companyId ?? this.companyId,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileType: fileType ?? this.fileType,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }

  static List<String> get allowedFileExtensions => [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'txt',
    'rtf',
    'odt',
    'png',
    'jpg',
    'jpeg',
    'gif',
    'bmp',
    'heic',
    'heif',
  ];

  static List<String> get allowedMimeTypes => [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain',
    'application/rtf',
    'application/vnd.oasis.opendocument.text',
    'image/png',
    'image/jpeg',
    'image/gif',
    'image/bmp',
    'image/heic',
    'image/heif',
  ];
}
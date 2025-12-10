class CompanyReview {
  final String id;
  final String companyId;
  final String studentId;
  final String studentName;
  final String comment;
  final int rating; // 1-5
  final DateTime createdAt;

  CompanyReview({
    required this.id,
    required this.companyId,
    required this.studentId,
    required this.studentName,
    required this.comment,
    required this.rating,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'companyId': companyId,
    'studentId': studentId,
    'studentName': studentName,
    'comment': comment,
    'rating': rating,
    'createdAt': createdAt.toIso8601String(),
  };

  static CompanyReview fromMap(Map<String, dynamic> map) => CompanyReview(
    id: map['id'],
    companyId: map['companyId'],
    studentId: map['studentId'],
    studentName: map['studentName'],
    comment: map['comment'],
    rating: map['rating'],
    createdAt: DateTime.parse(map['createdAt']),
  );
} 
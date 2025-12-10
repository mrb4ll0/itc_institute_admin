class Application {
  final String id;
  final String studentId;
  final String internshipId;
  final String status; // Example: 'pending', 'accepted', 'rejected'
  final String message;
  final String IT_letter;
  final String studenIDCard;

  Application({
    required this.IT_letter,
    required this.studenIDCard,
    required this.id,
    required this.studentId,
    required this.internshipId,
    required this.status,
    required this.message,
  });

  factory Application.fromMap(Map<String, dynamic> map, String id) {
    return Application(
      IT_letter: map['IT_letter'],
      studenIDCard: map['studentIDCard'],
      id: id,
      studentId: map['student_id'],
      internshipId: map['internship_id'],
      status: map['status'],
      message: map['message'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'internship_id': internshipId,
      'status': status,
      'message': message,
      'IT_letter': IT_letter,
      'studentIDCard': studenIDCard
    };
  }
}

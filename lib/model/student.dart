import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Student {
  // Basic Information
  String fullName;
  String email;
  String bio;
  String role;
  String imageUrl;
  String uid;
  String phoneNumber;

  // Educational Information
  String institution; // University/College name
  String courseOfStudy; // Major/Program
  String department;
  String level; // e.g., 100, 200, 300, 400, 500
  String registrationNumber;
  String matricNumber;
  DateTime? admissionDate;
  DateTime? expectedGraduationDate;
  double cgpa; // Cumulative GPA
  List<String> courses; // Current courses
  String academicStatus; // 'active', 'graduated', 'withdrawn', 'suspended'

  // Educational Documents
  String transcriptUrl;
  List<String> academicCertificates;
  List<String> recommendationLetters;
  List<String> testimonials;
  String studentIdCardUrl;

  // Portfolio fields
  List<String> skills;
  String resumeUrl;
  List<String> certifications;
  String portfolioDescription;
  List<Map<String, dynamic>> pastInternships;

  // ID Cards (list of URLs)
  List<String> idCards;

  // IT Letters (list of URLs)
  List<String> itLetters;

  // Social/Contact Information
  String? linkedinUrl;
  String? githubUrl;
  String? portfolioUrl;
  String? twitterUrl;

  // Address Information
  String? permanentAddress;
  String? currentAddress;
  String? stateOfOrigin;
  String? localGovernmentArea;
  String? nationality;

  // Emergency Contact
  String? emergencyContactName;
  String? emergencyContactPhone;
  String? emergencyContactRelationship;
  String? emergencyContactEmail;
  String? fcmToken;

  // Constructor
  Student({
    // Basic Information
    required this.phoneNumber,
    required this.uid,
    required this.fullName,
    required this.email,
    required this.bio,
    required this.role,
    required this.imageUrl,

    // Educational Information
    this.institution = '',
    this.courseOfStudy = '',
    this.department = '',
    this.level = '',
    this.registrationNumber = '',
    this.matricNumber = '',
    this.admissionDate,
    this.expectedGraduationDate,
    this.cgpa = 0.0,
    this.courses = const [],
    this.academicStatus = 'active',

    // Educational Documents
    this.transcriptUrl = '',
    this.academicCertificates = const [],
    this.recommendationLetters = const [],
    this.testimonials = const [],
    this.studentIdCardUrl = '',

    // Portfolio fields
    this.skills = const [],
    this.resumeUrl = '',
    this.certifications = const [],
    this.portfolioDescription = '',
    this.pastInternships = const [],

    // ID Cards
    this.idCards = const [],

    // IT Letters
    this.itLetters = const [],

    // Social/Contact Information
    this.linkedinUrl,
    this.githubUrl,
    this.portfolioUrl,
    this.twitterUrl,

    // Address Information
    this.permanentAddress,
    this.currentAddress,
    this.stateOfOrigin,
    this.localGovernmentArea,
    this.nationality,

    // Emergency Contact
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelationship,
    this.emergencyContactEmail,
    this.fcmToken,
  });

  // Helper method to safely convert dynamic to List<String>
  static List<String> _safeConvertToStringList(dynamic data) {
    if (data == null) return [];

    try {
      if (data is List) {
        return data
            .map((item) {
              if (item is String) {
                return item;
              } else if (item is Map) {
                final map = Map<String, dynamic>.from(
                  item as Map<dynamic, dynamic>,
                );
                return map['name']?.toString() ??
                    map['title']?.toString() ??
                    map['id']?.toString() ??
                    item.toString();
              } else {
                return item.toString();
              }
            })
            .toList()
            .cast<String>();
      } else if (data is String) {
        return [data];
      }
      return [data.toString()];
    } catch (e) {
      print('Error converting to string list: $e, data: $data');
      return [];
    }
  }

  // Helper method for List<Map<String, dynamic>>
  static List<Map<String, dynamic>> _safeConvertToMapList(dynamic data) {
    if (data == null) return [];

    try {
      if (data is List) {
        return data.map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          } else if (item is Map) {
            return Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
          } else {
            return <String, dynamic>{'value': item.toString()};
          }
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error converting to map list: $e');
      return [];
    }
  }

  // Safe method to convert dynamic to DateTime
  static DateTime? _safeConvertToDateTime(dynamic data) {
    if (data == null) return null;

    try {
      if (data is Timestamp) {
        return data.toDate();
      } else if (data is DateTime) {
        return data;
      } else if (data is String) {
        return DateTime.tryParse(data);
      } else if (data is int) {
        return DateTime.fromMillisecondsSinceEpoch(data);
      }
      return null;
    } catch (e) {
      print('Error converting to DateTime: $e, data: $data');
      return null;
    }
  }

  // Safe method to convert dynamic to double
  static double _safeConvertToDouble(
    dynamic data, [
    double defaultValue = 0.0,
  ]) {
    if (data == null) return defaultValue;

    try {
      if (data is double) {
        return data;
      } else if (data is int) {
        return data.toDouble();
      } else if (data is String) {
        return double.tryParse(data) ?? defaultValue;
      }
      return defaultValue;
    } catch (e) {
      print('Error converting to double: $e, data: $data');
      return defaultValue;
    }
  }

  // Method to create a Student object from a Firestore document snapshot
  factory Student.fromFirestore(Map<String, dynamic> data, String? uid) {
    return Student(
      // Basic Information
      phoneNumber: data['phoneNumber']?.toString() ?? '',
      fullName: data['fullName']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      bio: data['bio']?.toString() ?? '',
      role: data['role']?.toString() ?? 'student',
      imageUrl: data['imageUrl']?.toString() ?? '',
      uid: data['uid']?.toString() ?? uid ?? "",

      // Educational Information
      institution: data['institution']?.toString() ?? '',
      courseOfStudy: data['courseOfStudy']?.toString() ?? '',
      department: data['department']?.toString() ?? '',
      level: data['level']?.toString() ?? '',
      registrationNumber: data['registrationNumber']?.toString() ?? '',
      matricNumber: data['matricNumber']?.toString() ?? '',
      admissionDate: _safeConvertToDateTime(data['admissionDate']),
      expectedGraduationDate: _safeConvertToDateTime(
        data['expectedGraduationDate'],
      ),
      cgpa: _safeConvertToDouble(data['cgpa'], 0.0),
      courses: _safeConvertToStringList(data['courses']),
      academicStatus: data['academicStatus']?.toString() ?? 'active',

      // Educational Documents
      transcriptUrl: data['transcriptUrl']?.toString() ?? '',
      academicCertificates: _safeConvertToStringList(
        data['academicCertificates'],
      ),
      recommendationLetters: _safeConvertToStringList(
        data['recommendationLetters'],
      ),
      testimonials: _safeConvertToStringList(data['testimonials']),
      studentIdCardUrl: data['studentIdCardUrl']?.toString() ?? '',

      // Portfolio fields
      skills: _safeConvertToStringList(data['skills']),
      resumeUrl: data['resumeUrl']?.toString() ?? '',
      certifications: _safeConvertToStringList(data['certifications']),
      portfolioDescription: data['portfolioDescription']?.toString() ?? '',
      pastInternships: _safeConvertToMapList(data['pastInternships']),

      // ID Cards
      idCards: _safeConvertToStringList(data['idCards']),

      // IT Letters
      itLetters: _safeConvertToStringList(data['itLetters']),

      // Social/Contact Information
      linkedinUrl: data['linkedinUrl']?.toString(),
      githubUrl: data['githubUrl']?.toString(),
      portfolioUrl: data['portfolioUrl']?.toString(),
      twitterUrl: data['twitterUrl']?.toString(),

      // Address Information
      permanentAddress: data['permanentAddress']?.toString(),
      currentAddress: data['currentAddress']?.toString(),
      stateOfOrigin: data['stateOfOrigin']?.toString(),
      localGovernmentArea: data['localGovernmentArea']?.toString(),
      nationality: data['nationality']?.toString(),

      // Emergency Contact
      emergencyContactName: data['emergencyContactName']?.toString(),
      emergencyContactPhone: data['emergencyContactPhone']?.toString(),
      emergencyContactRelationship: data['emergencyContactRelationship']
          ?.toString(),
      emergencyContactEmail: data['emergencyContactEmail']?.toString(),
      fcmToken: data['fcmToken']?.toString(),
    );
  }

  // Method to convert the Student object to a Map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      // Basic Information
      'phoneNumber': phoneNumber,
      'fullName': fullName,
      'email': email,
      'bio': bio,
      'role': role,
      'imageUrl': imageUrl,
      'uid': uid,

      // Educational Information
      'institution': institution,
      'courseOfStudy': courseOfStudy,
      'department': department,
      'level': level,
      'registrationNumber': registrationNumber,
      'matricNumber': matricNumber,
      'admissionDate': admissionDate != null
          ? Timestamp.fromDate(admissionDate!)
          : null,
      'expectedGraduationDate': expectedGraduationDate != null
          ? Timestamp.fromDate(expectedGraduationDate!)
          : null,
      'cgpa': cgpa,
      'courses': courses,
      'academicStatus': academicStatus,

      // Educational Documents
      'transcriptUrl': transcriptUrl,
      'academicCertificates': academicCertificates,
      'recommendationLetters': recommendationLetters,
      'testimonials': testimonials,
      'studentIdCardUrl': studentIdCardUrl,

      // Portfolio fields
      'skills': skills,
      'resumeUrl': resumeUrl,
      'certifications': certifications,
      'portfolioDescription': portfolioDescription,
      'pastInternships': pastInternships,

      // ID Cards
      'idCards': idCards,

      // IT Letters
      'itLetters': itLetters,

      // Social/Contact Information
      'linkedinUrl': linkedinUrl,
      'githubUrl': githubUrl,
      'portfolioUrl': portfolioUrl,
      'twitterUrl': twitterUrl,

      // Address Information
      'permanentAddress': permanentAddress,
      'currentAddress': currentAddress,
      'stateOfOrigin': stateOfOrigin,
      'localGovernmentArea': localGovernmentArea,
      'nationality': nationality,

      // Emergency Contact
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'emergencyContactRelationship': emergencyContactRelationship,
      'emergencyContactEmail': emergencyContactEmail,

      // Timestamps
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'fcmToken': fcmToken,
    };
  }

  factory Student.fromUserCredential(UserCredential credential) {
    final user = credential.user!;
    return Student(
      phoneNumber: user.phoneNumber ?? "Add your phone number",
      uid: user.uid,
      fullName: user.displayName ?? '',
      email: user.email ?? '',
      bio: '',
      role: 'student',
      imageUrl: user.photoURL ?? '',
    );
  }

  factory Student.fromMap(Map<String, dynamic> data) {
    return Student(
      // Basic Information
      phoneNumber: data['phoneNumber']?.toString() ?? '',
      fullName: data['fullName']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      bio: data['bio']?.toString() ?? '',
      role: data['role']?.toString() ?? 'student',
      imageUrl: data['imageUrl']?.toString() ?? '',
      uid: data['uid']?.toString() ?? '',

      // Educational Information
      institution: data['institution']?.toString() ?? '',
      courseOfStudy: data['courseOfStudy']?.toString() ?? '',
      department: data['department']?.toString() ?? '',
      level: data['level']?.toString() ?? '',
      registrationNumber: data['registrationNumber']?.toString() ?? '',
      matricNumber: data['matricNumber']?.toString() ?? '',
      admissionDate: _safeConvertToDateTime(data['admissionDate']),
      expectedGraduationDate: _safeConvertToDateTime(
        data['expectedGraduationDate'],
      ),
      cgpa: _safeConvertToDouble(data['cgpa'], 0.0),
      courses: _safeConvertToStringList(data['courses']),
      academicStatus: data['academicStatus']?.toString() ?? 'active',

      // Educational Documents
      transcriptUrl: data['transcriptUrl']?.toString() ?? '',
      academicCertificates: _safeConvertToStringList(
        data['academicCertificates'],
      ),
      recommendationLetters: _safeConvertToStringList(
        data['recommendationLetters'],
      ),
      testimonials: _safeConvertToStringList(data['testimonials']),
      studentIdCardUrl: data['studentIdCardUrl']?.toString() ?? '',

      // Portfolio fields
      skills: _safeConvertToStringList(data['skills']),
      resumeUrl: data['resumeUrl']?.toString() ?? '',
      certifications: _safeConvertToStringList(data['certifications']),
      portfolioDescription: data['portfolioDescription']?.toString() ?? '',
      pastInternships: _safeConvertToMapList(data['pastInternships']),

      // ID Cards
      idCards: _safeConvertToStringList(data['idCards']),

      // IT Letters
      itLetters: _safeConvertToStringList(data['itLetters']),

      // Social/Contact Information
      linkedinUrl: data['linkedinUrl']?.toString(),
      githubUrl: data['githubUrl']?.toString(),
      portfolioUrl: data['portfolioUrl']?.toString(),
      twitterUrl: data['twitterUrl']?.toString(),

      // Address Information
      permanentAddress: data['permanentAddress']?.toString(),
      currentAddress: data['currentAddress']?.toString(),
      stateOfOrigin: data['stateOfOrigin']?.toString(),
      localGovernmentArea: data['localGovernmentArea']?.toString(),
      nationality: data['nationality']?.toString(),

      // Emergency Contact
      emergencyContactName: data['emergencyContactName']?.toString(),
      emergencyContactPhone: data['emergencyContactPhone']?.toString(),
      emergencyContactRelationship: data['emergencyContactRelationship']
          ?.toString(),
      emergencyContactEmail: data['emergencyContactEmail']?.toString(),
      fcmToken: data['fcmToken']?.toString(),
    );
  }

  Student copyWith({
    // Basic Information
    String? phoneNumber,
    String? uid,
    String? fullName,
    String? email,
    String? bio,
    String? role,
    String? imageUrl,

    // Educational Information
    String? institution,
    String? courseOfStudy,
    String? department,
    String? level,
    String? registrationNumber,
    String? matricNumber,
    DateTime? admissionDate,
    DateTime? expectedGraduationDate,
    double? cgpa,
    List<String>? courses,
    String? academicStatus,

    // Educational Documents
    String? transcriptUrl,
    List<String>? academicCertificates,
    List<String>? recommendationLetters,
    List<String>? testimonials,
    String? studentIdCardUrl,

    // Portfolio fields
    List<String>? skills,
    String? resumeUrl,
    List<String>? certifications,
    String? portfolioDescription,
    List<Map<String, dynamic>>? pastInternships,

    // ID Cards
    List<String>? idCards,

    // IT Letters
    List<String>? itLetters,

    // Social/Contact Information
    String? linkedinUrl,
    String? githubUrl,
    String? portfolioUrl,
    String? twitterUrl,

    // Address Information
    String? permanentAddress,
    String? currentAddress,
    String? stateOfOrigin,
    String? localGovernmentArea,
    String? nationality,

    // Emergency Contact
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelationship,
    String? emergencyContactEmail,
    String? fcmToken,
  }) {
    return Student(
      // Basic Information
      phoneNumber: phoneNumber ?? this.phoneNumber,
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      imageUrl: imageUrl ?? this.imageUrl,

      // Educational Information
      institution: institution ?? this.institution,
      courseOfStudy: courseOfStudy ?? this.courseOfStudy,
      department: department ?? this.department,
      level: level ?? this.level,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      matricNumber: matricNumber ?? this.matricNumber,
      admissionDate: admissionDate ?? this.admissionDate,
      expectedGraduationDate:
          expectedGraduationDate ?? this.expectedGraduationDate,
      cgpa: cgpa ?? this.cgpa,
      courses: courses ?? this.courses,
      academicStatus: academicStatus ?? this.academicStatus,

      // Educational Documents
      transcriptUrl: transcriptUrl ?? this.transcriptUrl,
      academicCertificates: academicCertificates ?? this.academicCertificates,
      recommendationLetters:
          recommendationLetters ?? this.recommendationLetters,
      testimonials: testimonials ?? this.testimonials,
      studentIdCardUrl: studentIdCardUrl ?? this.studentIdCardUrl,

      // Portfolio fields
      skills: skills ?? this.skills,
      resumeUrl: resumeUrl ?? this.resumeUrl,
      certifications: certifications ?? this.certifications,
      portfolioDescription: portfolioDescription ?? this.portfolioDescription,
      pastInternships: pastInternships ?? this.pastInternships,

      // ID Cards
      idCards: idCards ?? this.idCards,

      // IT Letters
      itLetters: itLetters ?? this.itLetters,

      // Social/Contact Information
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      githubUrl: githubUrl ?? this.githubUrl,
      portfolioUrl: portfolioUrl ?? this.portfolioUrl,
      twitterUrl: twitterUrl ?? this.twitterUrl,

      // Address Information
      permanentAddress: permanentAddress ?? this.permanentAddress,
      currentAddress: currentAddress ?? this.currentAddress,
      stateOfOrigin: stateOfOrigin ?? this.stateOfOrigin,
      localGovernmentArea: localGovernmentArea ?? this.localGovernmentArea,
      nationality: nationality ?? this.nationality,

      // Emergency Contact
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      emergencyContactRelationship:
          emergencyContactRelationship ?? this.emergencyContactRelationship,
      emergencyContactEmail:
          emergencyContactEmail ?? this.emergencyContactEmail,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  // Helper methods for managing ID cards
  Student addIdCard(String idCardUrl) {
    return copyWith(idCards: [...idCards, idCardUrl]);
  }

  Student removeIdCard(String idCardUrl) {
    return copyWith(
      idCards: idCards.where((card) => card != idCardUrl).toList(),
    );
  }

  Student updateIdCards(List<String> newIdCards) {
    return copyWith(idCards: newIdCards);
  }

  // Helper methods for managing IT letters
  Student addItLetter(String itLetterUrl) {
    return copyWith(itLetters: [...itLetters, itLetterUrl]);
  }

  Student removeItLetter(String itLetterUrl) {
    return copyWith(
      itLetters: itLetters.where((letter) => letter != itLetterUrl).toList(),
    );
  }

  Student updateItLetters(List<String> newItLetters) {
    return copyWith(itLetters: newItLetters);
  }

  // Get the latest ID card (most recently added)
  String? get latestIdCard => idCards.isNotEmpty ? idCards.last : null;

  // Get the latest IT letter (most recently added)
  String? get latestItLetter => itLetters.isNotEmpty ? itLetters.last : null;

  // Check if student has any ID cards
  bool get hasIdCards => idCards.isNotEmpty;

  // Check if student has any IT letters
  bool get hasItLetters => itLetters.isNotEmpty;

  // Get number of ID cards
  int get idCardCount => idCards.length;

  // Get number of IT letters
  int get itLetterCount => itLetters.length;

  // Check if student is currently in school
  bool get isCurrentlyEnrolled => academicStatus == 'active';

  // Get years of study
  int? get yearsOfStudy {
    if (admissionDate == null) return null;
    final now = DateTime.now();
    final difference = now.difference(admissionDate!);
    return (difference.inDays / 365).floor() + 1;
  }

  // Get remaining years to graduation
  int? get yearsRemaining {
    if (expectedGraduationDate == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expectedGraduationDate!)) return 0;
    final difference = expectedGraduationDate!.difference(now);
    return (difference.inDays / 365).ceil();
  }

  // Get academic year (e.g., "2023/2024")
  String? get academicYear {
    if (admissionDate == null) return null;
    final startYear = admissionDate!.year;
    final endYear = startYear + yearsOfStudy! - 1;
    return '$startYear/$endYear';
  }

  // Get full educational info
  String get educationalInfo {
    return '$courseOfStudy, $level Level, $institution';
  }

  // Check if student has required documents for IT
  bool get hasRequiredDocumentsForIT {
    return studentIdCardUrl.isNotEmpty &&
        transcriptUrl.isNotEmpty &&
        hasItLetters;
  }

  // Add a course
  Student addCourse(String course) {
    return copyWith(courses: [...courses, course]);
  }

  // Remove a course
  Student removeCourse(String course) {
    return copyWith(courses: courses.where((c) => c != course).toList());
  }

  // Add academic certificate
  Student addAcademicCertificate(String certificateUrl) {
    return copyWith(
      academicCertificates: [...academicCertificates, certificateUrl],
    );
  }

  // Add recommendation letter
  Student addRecommendationLetter(String letterUrl) {
    return copyWith(
      recommendationLetters: [...recommendationLetters, letterUrl],
    );
  }

  // Add testimonial
  Student addTestimonial(String testimonialUrl) {
    return copyWith(testimonials: [...testimonials, testimonialUrl]);
  }

  // Get GPA classification
  String get gpaClassification {
    if (cgpa >= 4.5) return 'First Class';
    if (cgpa >= 3.5) return 'Second Class Upper';
    if (cgpa >= 2.5) return 'Second Class Lower';
    if (cgpa >= 2.0) return 'Third Class';
    return 'Pass';
  }

  // Check if student is eligible for IT (based on level and GPA)
  bool get isEligibleForIndustrialTraining {
    // Usually students from 300 level upward are eligible
    final levelNum = int.tryParse(level);
    return levelNum != null &&
        levelNum >= 300 &&
        cgpa >= 2.0 && // Minimum GPA requirement
        isCurrentlyEnrolled;
  }

  // Get student's progress percentage towards graduation
  double get graduationProgress {
    if (admissionDate == null || expectedGraduationDate == null) return 0.0;

    final totalDuration = expectedGraduationDate!.difference(admissionDate!);
    final elapsedDuration = DateTime.now().difference(admissionDate!);

    if (totalDuration.inDays <= 0) return 100.0;

    final progress = (elapsedDuration.inDays / totalDuration.inDays) * 100;
    return progress.clamp(0.0, 100.0);
  }
}

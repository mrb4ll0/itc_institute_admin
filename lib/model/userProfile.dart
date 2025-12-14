import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:itc_institute_admin/model/student.dart';

import 'admin.dart';
import 'company.dart';

abstract class UserProfile {
  String get displayName;
  String get email;
  String get role;
  String get imageUrl;
  String get uid;
  String get phoneNumber;
}

class UserConverter implements UserProfile {
  final dynamic _user;
  late final String type;

  UserConverter(this._user) {
    if (_user is Student) {
      type = 'student';
    } else if (_user is Company) {
      type = 'company';
    } else if (_user is Admin) {
      type = 'admin';
    } else {
      throw ArgumentError('Unknown user type: ${_user.runtimeType}');
    }
  }

  // Get the original object if needed
  T? getAs<T>() {
    return _user is T ? _user as T : null;
  }

  // Check type
  bool get isStudent => _user is Student;
  bool get isCompany => _user is Company;
  bool get isAdmin => _user is Admin;

  // Common properties with safe access
  @override
  String get displayName {
    if (_user is Student) {
      return (_user as Student).fullName;
    } else if (_user is Company) {
      return (_user as Company).name;
    } else if (_user is Admin) {
      return (_user as Admin).fullName;
    }
    return '';
  }

  @override
  String get email {
    if (_user is Student) {
      return (_user as Student).email;
    } else if (_user is Company) {
      return (_user as Company).email;
    } else if (_user is Admin) {
      return (_user as Admin).email;
    }
    return '';
  }

  @override
  String get imageUrl {
    if (_user is Student) {
      return (_user as Student).imageUrl;
    } else if (_user is Company) {
      return (_user as Company).logoURL;
    } else if (_user is Admin) {
      return (_user as Admin).photoUrl ?? '';
    }
    return '';
  }

  @override
  String get uid {
    if (_user is Student) {
      return (_user as Student).uid;
    } else if (_user is Company) {
      return (_user as Company).id;
    } else if (_user is Admin) {
      return (_user as Admin).uid;
    }
    return '';
  }

  @override
  String get phoneNumber {
    if (_user is Student) {
      return (_user as Student).phoneNumber;
    } else if (_user is Company) {
      return (_user as Company).phoneNumber;
    } else if (_user is Admin) {
      return 'N/A'; // Admin doesn't have phone number
    }
    return '';
  }

  @override
  String get role {
    if (_user is Student) {
      return (_user as Student).role;
    } else if (_user is Company) {
      return (_user as Company).role;
    } else if (_user is Admin) {
      return (_user as Admin).role;
    }
    return '';
  }

  // Additional common methods
  Map<String, dynamic> toMap() {
    if (_user is Student) {
      return (_user as Student).toMap();
    } else if (_user is Company) {
      return (_user as Company).toMap();
    } else if (_user is Admin) {
      return (_user as Admin).toMap();
    }
    return {};
  }

  // Dynamic property access
  dynamic operator [](String key) {
    if (_user is Student) {
      final student = _user as Student;
      final map = student.toMap();
      return map[key];
    } else if (_user is Company) {
      final company = _user as Company;
      final map = company.toMap();
      return map[key];
    } else if (_user is Admin) {
      final admin = _user as Admin;
      final map = admin.toMap();
      return map[key];
    }
    return null;
  }

  // Convenience methods
  DateTime? get createdAt {
    if (_user is Admin) {
      return (_user as Admin).createdAt;
    }
    return null;
  }

  String get bio {
    if (_user is Student) {
      return (_user as Student).bio;
    } else if (_user is Company) {
      return (_user as Company).description;
    }
    return '';
  }

  bool get isActive {
    if (_user is Company) {
      return (_user as Company).isActive;
    }
    return true; // Students and Admins are always considered active
  }

  @override
  String toString() {
    return 'UserConverter(type: $type, name: $displayName, email: $email)';
  }
}

class UserConverterFactory {
  static UserConverter fromDynamic(dynamic data, {String? role}) {
    if (data is Student || data is Company || data is Admin) {
      return UserConverter(data);
    } else if (data is Map<String, dynamic>) {
      // Determine type from data
      final userRole = role ?? data['role']?.toString().toLowerCase();

      switch (userRole) {
        case 'student':
          return UserConverter(Student.fromFirestore(data, ""));
        case 'company':
          return UserConverter(Company.fromMap(data));
        case 'admin':
          return UserConverter(
            Admin.fromMap(data, data['uid']?.toString() ?? ''),
          );
        default:
          // Try to infer from structure
          if (data.containsKey('fullName') && data.containsKey('bio')) {
            return UserConverter(Student.fromFirestore(data, ""));
          } else if (data.containsKey('name') && data.containsKey('industry')) {
            return UserConverter(Company.fromMap(data));
          } else if (data.containsKey('fullName') &&
              data.containsKey('createdAt')) {
            return UserConverter(
              Admin.fromMap(data, data['uid']?.toString() ?? ''),
            );
          }
          throw ArgumentError('Cannot determine user type from data');
      }
    }
    throw ArgumentError('Unsupported data type: ${data.runtimeType}');
  }

  static Future<UserConverter> fromFirestoreDocument(
    DocumentSnapshot doc, {
    String? role,
  }) async {
    final data = doc.data() as Map<String, dynamic>;
    return fromDynamic({...data, 'uid': doc.id}, role: role);
  }
}

extension UserConversionExtensions on dynamic {
  UserConverter get asUser {
    return UserConverter(this);
  }
}

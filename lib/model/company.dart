import 'dart:convert';

class Company {
  final String id;
  final String name;
  final String industry;
  final String email;
  final String phoneNumber;
  final String logoURL;
  final String localGovernment;
  final String state;
  final String address;
  final String role;
  final String fcmToken;
  final String registrationNumber;
  final String description; // Added description field
  final bool isfeatured;
  final bool isActive;
  final bool isVerified;
  final bool isDeleted;
  final bool isApproved;
  final bool isRejected;
  final bool isPending;
  final bool isBlocked;
  final bool isSuspended;
  final bool isBanned;
  final bool isMuted;
  final DateTime? isMutedUntil;
  final String? isMutedBy;
  final String? isMutedFor;
  final DateTime? isMutedOn;
  final List<String>? formUrl;
  final DateTime? updatedAt;
  final List<dynamic> potentialtrainee;
  // Add these new fields
  List<String> pendingApplications = [];
  List<String> acceptedTrainees = []; // Accepted but not started
  List<String> currentTrainees = [];  // Currently active
  List<String> completedTrainees = []; // Completed training
  List<String> rejectedApplications = [];
  List<String> supervisors = []; // Supervisor IDs

  Company({
    required this.id,
    required this.name,
    required this.industry,
    required this.email,
    required this.phoneNumber,
    required this.logoURL,
    required this.localGovernment,
    required this.state,
    required this.address,
    required this.role,
    required this.fcmToken,
    required this.registrationNumber,
    required this.description, // Added to constructor
    required this.isfeatured,
    this.isActive = true,
    this.isVerified = false,
    this.isDeleted = false,
    this.isApproved = false,
    this.isRejected = false,
    this.isPending = true,
    this.isBlocked = false,
    this.isSuspended = false,
    this.isBanned = false,
    this.isMuted = false,
    this.isMutedUntil,
    this.isMutedBy,
    this.isMutedFor,
    this.isMutedOn,
    this.formUrl,
    this.updatedAt,
    this.potentialtrainee = const [],
    this.acceptedTrainees = const [],
    this.rejectedApplications = const [],
    this.completedTrainees = const [],
    this.currentTrainees = const [],
    this.pendingApplications = const [],
    this.supervisors = const [],

  });

  Company copyWith({
    String? id,
    String? name,
    String? industry,
    String? email,
    String? phoneNumber,
    String? logoURL,
    String? localGovernment,
    String? state,
    String? address,
    String? role,
    String? fcmToken,
    String? registrationNumber,
    String? description, // Added to copyWith
    bool? isfeatured,
    bool? isActive,
    bool? isVerified,
    bool? isDeleted,
    bool? isApproved,
    bool? isRejected,
    bool? isPending,
    bool? isBlocked,
    bool? isSuspended,
    bool? isBanned,
    bool? isMuted,
    DateTime? isMutedUntil,
    String? isMutedBy,
    String? isMutedFor,
    DateTime? isMutedOn,
    List<String>? formUrl,
    DateTime? updatedAt,
    List<dynamic>? potentialtrainee,
    List<String>? acceptedTrainees,
    List<String>? rejectedApplications,
    List<String>? completedTrainees,
    List<String>? currentTrainees,
    List<String>? pendingApplications,
    List<String>? supervisors,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      industry: industry ?? this.industry,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      logoURL: logoURL ?? this.logoURL,
      localGovernment: localGovernment ?? this.localGovernment,
      state: state ?? this.state,
      address: address ?? this.address,
      role: role ?? this.role,
      fcmToken: fcmToken ?? this.fcmToken,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      description: description ?? this.description, // Added here
      isfeatured: isfeatured ?? this.isfeatured,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      isDeleted: isDeleted ?? this.isDeleted,
      isApproved: isApproved ?? this.isApproved,
      isRejected: isRejected ?? this.isRejected,
      isPending: isPending ?? this.isPending,
      isBlocked: isBlocked ?? this.isBlocked,
      isSuspended: isSuspended ?? this.isSuspended,
      isBanned: isBanned ?? this.isBanned,
      isMuted: isMuted ?? this.isMuted,
      isMutedUntil: isMutedUntil ?? this.isMutedUntil,
      isMutedBy: isMutedBy ?? this.isMutedBy,
      isMutedFor: isMutedFor ?? this.isMutedFor,
      isMutedOn: isMutedOn ?? this.isMutedOn,
      formUrl: formUrl ?? this.formUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      potentialtrainee: potentialtrainee ?? this.potentialtrainee,
      acceptedTrainees: acceptedTrainees ?? this.acceptedTrainees,
      rejectedApplications: rejectedApplications ?? this.rejectedApplications,
      completedTrainees: completedTrainees ?? this.completedTrainees,
      currentTrainees: currentTrainees ?? this.currentTrainees,
      pendingApplications: pendingApplications ?? this.pendingApplications,
      supervisors: supervisors ?? this.supervisors,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'industry': industry,
      'email': email,
      'phoneNumber': phoneNumber,
      'logoURL': logoURL,
      'localGovernment': localGovernment,
      'state': state,
      'address': address,
      'role': role,
      'fcmToken': fcmToken,
      'registrationNumber': registrationNumber,
      'description': description, // Added to toMap
      'isfeatured': isfeatured,
      'isActive': isActive,
      'isVerified': isVerified,
      'isDeleted': isDeleted,
      'isApproved': isApproved,
      'isRejected': isRejected,
      'isPending': isPending,
      'isBlocked': isBlocked,
      'isSuspended': isSuspended,
      'isBanned': isBanned,
      'isMuted': isMuted,
      'isMutedUntil': isMutedUntil?.toIso8601String(),
      'isMutedBy': isMutedBy,
      'isMutedFor': isMutedFor,
      'isMutedOn': isMutedOn?.toIso8601String(),
      'formUrl': formUrl,
      'updatedAt': updatedAt,
      'potentialtrainee': potentialtrainee,
      'acceptedTrainees': acceptedTrainees,
      'rejectedApplications': rejectedApplications,
      'completedTrainees': completedTrainees,
      'currentTrainees': currentTrainees,
      'pendingApplications': pendingApplications,
      'supervisors': supervisors,
    };
  }

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      industry: map['industry']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phoneNumber: map['phoneNumber']?.toString() ?? '',
      logoURL: map['logoURL']?.toString() ?? '',
      localGovernment: map['localGovernment']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      role: map['role']?.toString() ?? 'company',
      fcmToken: map['fcmToken']?.toString() ?? '',
      registrationNumber: map['registrationNumber']?.toString() ?? '',
      description: map['description']?.toString() ?? '', // Added to fromMap
      isfeatured: map['isfeatured'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? true,
      isVerified: map['isVerified'] as bool? ?? false,
      isDeleted: map['isDeleted'] as bool? ?? false,
      isApproved: map['isApproved'] as bool? ?? false,
      isRejected: map['isRejected'] as bool? ?? false,
      isPending: map['isPending'] as bool? ?? true,
      isBlocked: map['isBlocked'] as bool? ?? false,
      isSuspended: map['isSuspended'] as bool? ?? false,
      isBanned: map['isBanned'] as bool? ?? false,
      isMuted: map['isMuted'] as bool? ?? false,
      isMutedUntil: map['isMutedUntil'] != null
          ? DateTime.tryParse(map['isMutedUntil'].toString())
          : null,
      isMutedBy: map['isMutedBy']?.toString(),
      isMutedFor: map['isMutedFor']?.toString(),
      isMutedOn: map['isMutedOn'] != null
          ? DateTime.tryParse(map['isMutedOn'].toString())
          : null,
      formUrl:
          (map['formUrl'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
      potentialtrainee:
          (map['potentialtrainee'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      pendingApplications: List<String>.from(map['pendingApplications'] ?? []),
      acceptedTrainees: List<String>.from(map['acceptedTrainees'] ?? []),
      currentTrainees: List<String>.from(map['currentTrainees'] ?? []),
      completedTrainees: List<String>.from(map['completedTrainees'] ?? []),
      rejectedApplications: List<String>.from(map['rejectedApplications'] ?? []),
      supervisors: List<String>.from(map['supervisors'] ?? []),
    );
  }

  String toJson() => json.encode(toMap());

  factory Company.fromJson(String source) =>
      Company.fromMap(json.decode(source));

  @override
  String toString() {
    return 'Company(id: $id, name: $name, industry: $industry, email: $email, phoneNumber: $phoneNumber, logoURL: $logoURL, localGovernment: $localGovernment, state: $state, address: $address, role: $role, fcmToken: $fcmToken, registrationNumber: $registrationNumber, description: $description, isfeatured: $isfeatured, isActive: $isActive, isVerified: $isVerified, isDeleted: $isDeleted, isApproved: $isApproved, isRejected: $isRejected, isPending: $isPending, isBlocked: $isBlocked, isSuspended: $isSuspended, isBanned: $isBanned, isMuted: $isMuted, isMutedUntil: $isMutedUntil, isMutedBy: $isMutedBy, isMutedFor: $isMutedFor, isMutedOn: $isMutedOn)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Company &&
        other.id == id &&
        other.name == name &&
        other.industry == industry &&
        other.email == email &&
        other.phoneNumber == phoneNumber &&
        other.logoURL == logoURL &&
        other.localGovernment == localGovernment &&
        other.state == state &&
        other.address == address &&
        other.role == role &&
        other.fcmToken == fcmToken &&
        other.registrationNumber == registrationNumber &&
        other.description == description && // Added to equality check
        other.isfeatured == isfeatured &&
        other.isActive == isActive &&
        other.isVerified == isVerified &&
        other.isDeleted == isDeleted &&
        other.isApproved == isApproved &&
        other.isRejected == isRejected &&
        other.isPending == isPending &&
        other.isBlocked == isBlocked &&
        other.isSuspended == isSuspended &&
        other.isBanned == isBanned &&
        other.isMuted == isMuted &&
        other.isMutedUntil == isMutedUntil &&
        other.isMutedBy == isMutedBy &&
        other.isMutedFor == isMutedFor &&
        other.isMutedOn == isMutedOn &&
        other.formUrl == formUrl &&
        other.updatedAt == updatedAt &&
        other.acceptedTrainees == acceptedTrainees &&
        other.rejectedApplications == rejectedApplications &&
        other.completedTrainees == completedTrainees &&
        other.currentTrainees == currentTrainees &&
        other.pendingApplications == pendingApplications &&
        other.supervisors == supervisors &&
        other.potentialtrainee == potentialtrainee;

  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      name,
      industry,
      email,
      phoneNumber,
      logoURL,
      localGovernment,
      state,
      address,
      role,
      fcmToken,
      registrationNumber,
      description, // Added to hashCode
      isfeatured,
      isActive,
      isVerified,
      isDeleted,
      isApproved,
      isRejected,
      isPending,
      isBlocked,
      isSuspended,
      isBanned,
      isMuted,
      isMutedUntil,
      isMutedBy,
      isMutedFor,
      isMutedOn,
      formUrl,
      updatedAt,
      potentialtrainee,
      acceptedTrainees,
      rejectedApplications,
      completedTrainees,
      currentTrainees,
      pendingApplications,
      supervisors,
    ]);
  }
}

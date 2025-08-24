class Institution {
  final String id; // unique identifier (could be Firebase docId or UUID)
  final String name; // institution name e.g. "University of Lagos"
  final String shortName; // acronym e.g. "UNILAG"
  final String type; // e.g. "University", "Polytechnic", "College"
  final String address;
  final String city;
  final String state;
  final String country;
  final String localGovernment;
  final String contactEmail;
  final String contactPhone;
  final String website;
  final String logoUrl; // institution logo
  final String accreditationStatus; // e.g. "Accredited", "Provisional", "Not Accredited"
  final int establishedYear;
  final List<String> faculties; // list of faculties/schools
  final List<String> departments; // list of departments
  final List<String> programsOffered; // list of programs/courses
  final String admissionRequirements; // plain text or rich info
  final bool isActive; // institution enabled/disabled in your system
  final DateTime createdAt;
  final DateTime updatedAt;
  final String institutionCode;

  Institution({
    required this.institutionCode,
    required this.id,
    required this.name,
    required this.shortName,
    required this.type,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.localGovernment,
    required this.contactEmail,
    required this.contactPhone,
    required this.website,
    required this.logoUrl,
    required this.accreditationStatus,
    required this.establishedYear,
    required this.faculties,
    required this.departments,
    required this.programsOffered,
    required this.admissionRequirements,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert Institution -> Map (for Firebase/JSON)
  Map<String, dynamic> toMap() {
    return {
      'institutionCode':institutionCode,
      'id': id,
      'name': name,
      'shortName': shortName,
      'type': type,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'localGovernment': localGovernment,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'website': website,
      'logoUrl': logoUrl,
      'accreditationStatus': accreditationStatus,
      'establishedYear': establishedYear,
      'faculties': faculties,
      'departments': departments,
      'programsOffered': programsOffered,
      'admissionRequirements': admissionRequirements,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Convert Map -> Institution (from Firebase/JSON)
  factory Institution.fromMap(Map<String, dynamic> map) {
    return Institution(
      institutionCode: map['institutionCode']??'',
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      shortName: map['shortName'] ?? '',
      type: map['type'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      country: map['country'] ?? '',
      localGovernment: map['localGovernment'] ?? '',
      contactEmail: map['contactEmail'] ?? '',
      contactPhone: map['contactPhone'] ?? '',
      website: map['website'] ?? '',
      logoUrl: map['logoUrl'] ?? '',
      accreditationStatus: map['accreditationStatus'] ?? '',
      establishedYear: map['establishedYear'] ?? 0,
      faculties: List<String>.from(map['faculties'] ?? []),
      departments: List<String>.from(map['departments'] ?? []),
      programsOffered: List<String>.from(map['programsOffered'] ?? []),
      admissionRequirements: map['admissionRequirements'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

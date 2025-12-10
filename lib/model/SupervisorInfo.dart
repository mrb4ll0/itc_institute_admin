class SupervisorInfo {
  String id;
  String name;
  String email;
  String phone;
  String department;
  String position;
  String? imageUrl;
  List<String> areasOfExpertise;

  SupervisorInfo({
    this.id = '',
    this.name = '',
    this.email = '',
    this.phone = '',
    this.department = '',
    this.position = '',
    this.imageUrl,
    this.areasOfExpertise = const [],
  });

  factory SupervisorInfo.fromMap(Map<String, dynamic> map) {
    return SupervisorInfo(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      department: map['department'] ?? '',
      position: map['position'] ?? '',
      imageUrl: map['imageUrl'],
      areasOfExpertise: List<String>.from(map['areasOfExpertise'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'department': department,
      'position': position,
      'imageUrl': imageUrl,
      'areasOfExpertise': areasOfExpertise,
    };
  }
}

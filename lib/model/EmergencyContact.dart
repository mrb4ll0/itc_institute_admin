class EmergencyContact {
  String name;
  String relationship;
  String phone;
  String? email;
  String? address;

  EmergencyContact({
    required this.name,
    required this.relationship,
    required this.phone,
    this.email,
    this.address,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      name: map['name'] ?? '',
      relationship: map['relationship'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'],
      address: map['address'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'relationship': relationship,
      'phone': phone,
      'email': email,
      'address': address,
    };
  }
}

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final String age;
  final String address;
  final String? gender; 
  final String? fotoUrl;

  const UserModel({
    required this.id,
    required this.email,
    this.fullName = '',
    this.phone = '',
    this.age = '',
    this.address = '',
    this.gender, 
    this.fotoUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      age: json['age']?.toString() ?? '',
      address: json['address'] as String? ?? '',
      gender: json['gender'] as String?, 
      fotoUrl: json['foto_url'] as String?,
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'age': age,
      'address': address,
      'gender': gender,
    };
  }

  UserModel copyWith({
    String? fullName,
    String? phone,
    String? age,
    String? address,
    String? gender,
    String? fotoUrl,
  }) {
    return UserModel(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      address: address ?? this.address,
      gender: gender ?? this.gender,
      fotoUrl: fotoUrl ?? this.fotoUrl,
    );
  }
}
class User {
  final int userId;
  final int companyId;
  final String name;
  final String email;
  final bool isAdmin;
  final bool isInstructor;
  final String? instructorCertificateNumber;
  final String? phone;
  final String status;
  final String createdAt;
  final String? lastLogin;

  User({
    required this.userId,
    required this.companyId,
    required this.name,
    required this.email,
    required this.isAdmin,
    required this.isInstructor,
    this.instructorCertificateNumber,
    this.phone,
    required this.status,
    required this.createdAt,
    this.lastLogin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      companyId: json['company_id'],
      name: json['name'],
      email: json['email'],
      isAdmin: json['is_admin'] == 1 || json['is_admin'] == true,
      isInstructor: json['is_instructor'] == 1 || json['is_instructor'] == true,
      instructorCertificateNumber: json['instructor_certificate_number'],
      phone: json['phone'],
      status: json['status'],
      createdAt: json['created_at'],
      lastLogin: json['last_login'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'company_id': companyId,
      'name': name,
      'email': email,
      'is_admin': isAdmin,
      'is_instructor': isInstructor,
      'instructor_certificate_number': instructorCertificateNumber,
      'phone': phone,
      'status': status,
      'created_at': createdAt,
      'last_login': lastLogin,
    };
  }
}
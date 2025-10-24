/// Model for student enrollment data with verification and OCR information
///
/// This replaces the magic Map<String, dynamic> parsedData with explicit typing
class StudentEnrollmentData {
  // === CORE IDENTIFICATION (OCR Extracted) ===
  final String driverNumber;
  final String surname;
  final String forename;
  final String dateOfBirth; // Format: DD.MM.YYYY
  final String address;
  final String postcode;

  // === VERIFICATION DATA ===
  final double matchScore; // 0-100
  final String verificationDecision; // "PASS", "MANUAL_REVIEW", or "FAIL"
  final DateTime verificationTimestamp;

  // === PHOTOS ===
  final String studentPhotoPath;
  final String licensePhotoPath;

  // === OVERRIDE/SUSPICION (Optional) ===
  final String? overrideReason;
  final bool? suspicionRaised;
  final String? suspicionReason;

  // === VALIDATION FLAGS ===
  final bool? isLicenceExpired;
  final bool? ageRestrictionWarning;

  // === OCR METADATA ===
  final double? ocrConfidence;
  final List<String>? manualCorrections;

  // === SESSION CONTEXT ===
  final int enrolledByInstructorId;

  StudentEnrollmentData({
    required this.driverNumber,
    required this.surname,
    required this.forename,
    required this.dateOfBirth,
    required this.address,
    required this.postcode,
    required this.matchScore,
    required this.verificationDecision,
    required this.verificationTimestamp,
    required this.studentPhotoPath,
    required this.licensePhotoPath,
    required this.enrolledByInstructorId,
    this.overrideReason,
    this.suspicionRaised,
    this.suspicionReason,
    this.isLicenceExpired,
    this.ageRestrictionWarning,
    this.ocrConfidence,
    this.manualCorrections,
  });

  /// Convert to JSON for API transmission
  Map<String, dynamic> toJson() {
    return {
      'driver_number': driverNumber,
      'surname': surname,
      'forename': forename,
      'date_of_birth': dateOfBirth,
      'address': address,
      'postcode': postcode,
      'match_score': matchScore,
      'verification_decision': verificationDecision,
      'verification_timestamp': verificationTimestamp.toIso8601String(),
      'student_photo': studentPhotoPath,
      'license_photo': licensePhotoPath,
      'enrolled_by_instructor_id': enrolledByInstructorId,
      if (overrideReason != null) 'override_reason': overrideReason,
      if (suspicionRaised != null) 'suspicion_raised': suspicionRaised,
      if (suspicionReason != null) 'suspicion_reason': suspicionReason,
      if (isLicenceExpired != null) 'is_licence_expired': isLicenceExpired,
      if (ageRestrictionWarning != null)
        'age_restriction_warning': ageRestrictionWarning,
      if (ocrConfidence != null) 'ocr_confidence': ocrConfidence,
      if (manualCorrections != null) 'manual_corrections': manualCorrections,
    };
  }

  /// Create from JSON (for testing or if API returns student data)
  factory StudentEnrollmentData.fromJson(Map<String, dynamic> json) {
    return StudentEnrollmentData(
      driverNumber: json['driver_number'],
      surname: json['surname'],
      forename: json['forename'],
      dateOfBirth: json['date_of_birth'],
      address: json['address'],
      postcode: json['postcode'],
      matchScore: (json['match_score'] as num).toDouble(),
      verificationDecision: json['verification_decision'],
      verificationTimestamp: DateTime.parse(json['verification_timestamp']),
      studentPhotoPath: json['student_photo'],
      licensePhotoPath: json['license_photo'],
      enrolledByInstructorId: json['enrolled_by_instructor_id'],
      overrideReason: json['override_reason'],
      suspicionRaised: json['suspicion_raised'],
      suspicionReason: json['suspicion_reason'],
      isLicenceExpired: json['is_licence_expired'],
      ageRestrictionWarning: json['age_restriction_warning'],
      ocrConfidence: json['ocr_confidence'] != null
          ? (json['ocr_confidence'] as num).toDouble()
          : null,
      manualCorrections: json['manual_corrections'] != null
          ? List<String>.from(json['manual_corrections'])
          : null,
    );
  }

  /// Create a copy with some fields changed (useful for edits)
  StudentEnrollmentData copyWith({
    String? driverNumber,
    String? surname,
    String? forename,
    String? dateOfBirth,
    String? address,
    String? postcode,
    double? matchScore,
    String? verificationDecision,
    DateTime? verificationTimestamp,
    String? studentPhotoPath,
    String? licensePhotoPath,
    int? enrolledByInstructorId,
    String? overrideReason,
    bool? suspicionRaised,
    String? suspicionReason,
    bool? isLicenceExpired,
    bool? ageRestrictionWarning,
    double? ocrConfidence,
    List<String>? manualCorrections,
  }) {
    return StudentEnrollmentData(
      driverNumber: driverNumber ?? this.driverNumber,
      surname: surname ?? this.surname,
      forename: forename ?? this.forename,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      address: address ?? this.address,
      postcode: postcode ?? this.postcode,
      matchScore: matchScore ?? this.matchScore,
      verificationDecision: verificationDecision ?? this.verificationDecision,
      verificationTimestamp:
          verificationTimestamp ?? this.verificationTimestamp,
      studentPhotoPath: studentPhotoPath ?? this.studentPhotoPath,
      licensePhotoPath: licensePhotoPath ?? this.licensePhotoPath,
      enrolledByInstructorId:
          enrolledByInstructorId ?? this.enrolledByInstructorId,
      overrideReason: overrideReason ?? this.overrideReason,
      suspicionRaised: suspicionRaised ?? this.suspicionRaised,
      suspicionReason: suspicionReason ?? this.suspicionReason,
      isLicenceExpired: isLicenceExpired ?? this.isLicenceExpired,
      ageRestrictionWarning:
          ageRestrictionWarning ?? this.ageRestrictionWarning,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
      manualCorrections: manualCorrections ?? this.manualCorrections,
    );
  }

  @override
  String toString() {
    return 'StudentEnrollmentData(driverNumber: $driverNumber, name: $forename $surname, decision: $verificationDecision)';
  }
}

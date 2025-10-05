class Teacher {
  // Existing fields
  final String objectId;
  final String fullName;
  final String subject; // Keep for backward compatibility
  final String gender;
  final String? photoUrl;
  final int yearsOfExperience;
  final double rating;
  final int ratingCount;
  final double hourlyRate;
  final String? schoolId;
  final String? schoolName;

  // User Account Management
  final String? userId;
  final String? username;
  final String? plainPassword; // Store plain password for admin access
  final bool hasUserAccount;
  final DateTime? accountCreatedAt;
  final DateTime? lastPasswordReset;
  final bool isAccountActive;

  // Contact Information
  final String? email;
  final String? phone;
  final String? address;
  final String? emergencyContact;

  // Professional Details
  final String? employeeId;
  final String? department;
  final List<String> subjects;
  final String? qualification;
  final DateTime? joinDate;
  final String? employmentStatus;

  // Teaching Assignments
  final List<String> assignedClasses;
  final int maxClassesPerDay;
  final List<String> availableDays;

  // Audit & Security
  final String? createdBy;
  final DateTime? lastModified;
  final String? modifiedBy;

  Teacher({
    required this.objectId,
    required this.fullName,
    required this.subject,
    required this.gender,
    this.photoUrl,
    this.yearsOfExperience = 0,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.hourlyRate = 0.0,
    this.schoolId,
    this.schoolName,

    // User Account
    this.userId,
    this.username,
    this.plainPassword,
    this.hasUserAccount = false,
    this.accountCreatedAt,
    this.lastPasswordReset,
    this.isAccountActive = true,

    // Contact Information
    this.email,
    this.phone,
    this.address,
    this.emergencyContact,

    // Professional Information
    this.employeeId,
    this.department,
    this.subjects = const [],
    this.qualification,
    this.joinDate,
    this.employmentStatus,

    // Teaching Assignments
    this.assignedClasses = const [],
    this.maxClassesPerDay = 6,
    this.availableDays = const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday'
    ],

    // Security & Audit
    this.createdBy,
    this.lastModified,
    this.modifiedBy,
  });

  factory Teacher.fromParseObject(Map<String, dynamic> data) {
    // Extract school information if available
    String? schoolId;
    String? schoolName;
    final schoolData = data['school'];
    if (schoolData != null && schoolData is Map<String, dynamic>) {
      schoolId = schoolData['objectId'];
      schoolName = schoolData['schoolName'];
    }

    // Extract user information if available
    String? userId;
    final userData = data['userId'];
    if (userData != null && userData is Map<String, dynamic>) {
      userId = userData['objectId'];
    }

    // Parse arrays safely
    List<String> subjects = [];
    if (data['subjects'] != null) {
      subjects = List<String>.from(data['subjects'] ?? []);
    }

    List<String> assignedClasses = [];
    if (data['assignedClasses'] != null) {
      assignedClasses = List<String>.from(data['assignedClasses'] ?? []);
    }

    List<String> availableDays = [];
    if (data['availableDays'] != null) {
      availableDays = List<String>.from(data['availableDays'] ?? []);
    } else {
      availableDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    }

    // Parse dates safely
    DateTime? parseDate(dynamic dateData) {
      if (dateData == null) return null;
      if (dateData is DateTime) return dateData;
      if (dateData is String) return DateTime.tryParse(dateData);
      if (dateData is Map && dateData['iso'] != null) {
        return DateTime.tryParse(dateData['iso']);
      }
      return null;
    }

    return Teacher(
      objectId: data['objectId'] ?? '',
      fullName: data['fullName'] ?? '',
      subject: data['subject'] ?? '',
      gender: data['gender'] ?? '',
      photoUrl: data['photo'],
      yearsOfExperience: data['yearsOfExperience'] ?? 0,
      rating: (data['rating'] ?? 0.0).toDouble(),
      ratingCount: data['ratingCount'] ?? 0,
      hourlyRate: (data['hourlyRate'] ?? 0.0).toDouble(),
      schoolId: schoolId,
      schoolName: schoolName,

      // User Account
      userId: userId ?? data['userId']?.toString(),
      username: data['username'],
      plainPassword: data['plainPassword'],
      hasUserAccount: data['hasUserAccount'] ?? false,
      accountCreatedAt: parseDate(data['accountCreatedAt']),
      lastPasswordReset: parseDate(data['lastPasswordReset']),
      isAccountActive: data['isAccountActive'] ?? true,

      // Contact Information
      email: data['email'],
      phone: data['phone'],
      address: data['address'],
      emergencyContact: data['emergencyContact'],

      // Professional Information
      employeeId: data['employeeId'],
      department: data['department'],
      subjects: subjects,
      qualification: data['qualification'],
      joinDate: parseDate(data['joinDate']),
      employmentStatus: data['employmentStatus'],

      // Teaching Assignments
      assignedClasses: assignedClasses,
      maxClassesPerDay: data['maxClassesPerDay'] ?? 6,
      availableDays: availableDays,

      // Security & Audit
      createdBy: data['createdBy'],
      lastModified:
          parseDate(data['updatedAt']) ?? parseDate(data['lastModified']),
      modifiedBy: data['modifiedBy'],
    );
  }
}

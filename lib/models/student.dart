class Student {
  final String objectId;
  final String name;
  final String grade;
  final String address;
  final String phoneNumber;
  final String studyStatus;
  final DateTime? dateOfBirth;
  final String? photoUrl;
  final String gender;
  final String? schoolId;
  final String? schoolName;

  Student({
    required this.objectId,
    required this.name,
    required this.grade,
    required this.address,
    required this.phoneNumber,
    required this.studyStatus,
    this.dateOfBirth,
    this.photoUrl,
    required this.gender,
    this.schoolId,
    this.schoolName,
  });

  factory Student.fromParseObject(Map<String, dynamic> data) {
    // Extract school information if available
    String? schoolId;
    String? schoolName;
    final schoolData = data['school'];
    if (schoolData != null && schoolData is Map<String, dynamic>) {
      schoolId = schoolData['objectId'];
      schoolName = schoolData['schoolName'];
    }

    return Student(
      objectId: data['objectId'] ?? '',
      name: data['name'] ?? '',
      grade: data['grade'] ?? '',
      address: data['address'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      studyStatus: data['studyStatus'] ?? '',
      dateOfBirth: data['dateOfBirth'] != null
          ? DateTime.tryParse(data['dateOfBirth'])
          : null,
      photoUrl: data['photo'],
      gender: data['gender'] ?? '',
      schoolId: schoolId,
      schoolName: schoolName,
    );
  }
}

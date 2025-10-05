class SchoolClass {
  final String objectId;
  final String name;
  final String? description;
  final String? schoolId;
  final String? schoolName;

  SchoolClass({
    required this.objectId,
    required this.name,
    this.description,
    this.schoolId,
    this.schoolName,
  });

  factory SchoolClass.fromParseObject(Map<String, dynamic> data) {
    // Extract school information if available
    String? schoolId;
    String? schoolName;
    final schoolData = data['school'];
    if (schoolData != null && schoolData is Map<String, dynamic>) {
      schoolId = schoolData['objectId'];
      schoolName = schoolData['schoolName'];
    }

    return SchoolClass(
      objectId: data['objectId'] ?? '',
      name: data['classname'] ?? '',
      description: data['description'],
      schoolId: schoolId,
      schoolName: schoolName,
    );
  }
}

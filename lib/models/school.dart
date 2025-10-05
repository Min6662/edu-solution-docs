class School {
  final String objectId;
  final String schoolName;
  final String schoolCode;
  final String? logo;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final String subscriptionPlan;
  final int maxUsers;
  final int currentUserCount;
  final bool isActive;
  final DateTime? createdAt;
  final String? ownerId;

  School({
    required this.objectId,
    required this.schoolName,
    required this.schoolCode,
    this.logo,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.subscriptionPlan = 'basic',
    this.maxUsers = 50,
    this.currentUserCount = 0,
    this.isActive = true,
    this.createdAt,
    this.ownerId,
  });

  factory School.fromParseObject(Map<String, dynamic> data) {
    return School(
      objectId: data['objectId'] ?? '',
      schoolName: data['schoolName'] ?? '',
      schoolCode: data['schoolCode'] ?? '',
      logo: data['logo'],
      address: data['address'],
      phone: data['phone'],
      email: data['email'],
      website: data['website'],
      subscriptionPlan: data['subscriptionPlan'] ?? 'basic',
      maxUsers: data['maxUsers'] ?? 50,
      currentUserCount: data['currentUserCount'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'])
          : null,
      ownerId: data['ownerId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'objectId': objectId,
      'schoolName': schoolName,
      'schoolCode': schoolCode,
      'logo': logo,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'subscriptionPlan': subscriptionPlan,
      'maxUsers': maxUsers,
      'currentUserCount': currentUserCount,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'ownerId': ownerId,
    };
  }
}

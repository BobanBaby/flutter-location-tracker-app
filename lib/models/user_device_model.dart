import 'dart:convert';

class UserDeviceProfile {
  final String userId;
  final String userName;
  final String userEmail;
  final String deviceId;
  final String deviceModel;
  final String osVersion;

  UserDeviceProfile({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.deviceId,
    required this.deviceModel,
    required this.osVersion,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'device_id': deviceId,
      'device_model': deviceModel,
      'os_version': osVersion,
    };
  }

  factory UserDeviceProfile.fromMap(Map<String, dynamic> map) {
    return UserDeviceProfile(
      userId: (map['user_id'] as String?) ?? 'USR_DEFAULT',
      userName: (map['user_name'] as String?) ?? 'Sales Representative',
      userEmail: (map['user_email'] as String?) ?? 'sales@locationpoc.com',
      deviceId: (map['device_id'] as String?) ?? 'DEV_UNKNOWN',
      deviceModel: (map['device_model'] as String?) ?? 'Unknown Device',
      osVersion: (map['os_version'] as String?) ?? 'Unknown OS',
    );
  }

  UserDeviceProfile copyWith({
    String? userId,
    String? userName,
    String? userEmail,
    String? deviceId,
    String? deviceModel,
    String? osVersion,
  }) {
    return UserDeviceProfile(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      deviceId: deviceId ?? this.deviceId,
      deviceModel: deviceModel ?? this.deviceModel,
      osVersion: osVersion ?? this.osVersion,
    );
  }

  String toJson() => json.encode(toMap());
  factory UserDeviceProfile.fromJson(String source) =>
      UserDeviceProfile.fromMap(json.decode(source) as Map<String, dynamic>);
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_device_model.dart';

class UserDeviceService {
  static final UserDeviceService instance = UserDeviceService._init();
  UserDeviceService._init();

  UserDeviceProfile? _cachedProfile;

  UserDeviceProfile get currentProfile =>
      _cachedProfile ??
      UserDeviceProfile(
        userId: '',
        userName: '',
        userEmail: '',
        deviceId: 'DEV_001',
        deviceModel: 'Android Device',
        osVersion: 'Android OS',
      );

  /// Check if user details have been configured and saved in persistent storage
  bool get hasValidUserProfile {
    final profile = currentProfile;
    return profile.userId.trim().isNotEmpty && profile.userName.trim().isNotEmpty;
  }

  /// Initialize user and auto-detect device hardware specs
  Future<UserDeviceProfile> initProfile() async {
    String deviceId = 'DEV_UNKNOWN';
    String deviceModel = 'Unknown Device';
    String osVersion = 'Unknown OS';

    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    try {
      if (kIsWeb) {
        deviceModel = 'Web Browser';
        osVersion = 'Web';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
        osVersion = 'Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'IOS_DEVICE';
        deviceModel = iosInfo.name;
        osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      }
    } catch (e) {
      print('Error fetching device info: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final savedUserId = prefs.getString('user_id') ?? '';
    final savedUserName = prefs.getString('user_name') ?? '';
    final savedUserEmail = prefs.getString('user_email') ?? '';

    _cachedProfile = UserDeviceProfile(
      userId: savedUserId,
      userName: savedUserName,
      userEmail: savedUserEmail,
      deviceId: deviceId,
      deviceModel: deviceModel,
      osVersion: osVersion,
    );

    return _cachedProfile!;
  }

  /// Update user profile details in persistent storage
  Future<void> updateProfile({
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('user_name', userName);
    await prefs.setString('user_email', userEmail);

    _cachedProfile = currentProfile.copyWith(
      userId: userId,
      userName: userName,
      userEmail: userEmail,
    );
  }
}

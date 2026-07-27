import 'dart:convert';

class GpsLog {
  final int? id;
  final String journeyId;
  final String userId;
  final String userName;
  final String deviceId;
  final String deviceModel;
  final String timestamp;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final double bearing;
  final double altitude;
  final String activity; // 'Driving', 'Walking', 'Still', 'Unknown'
  final int batteryLevel;
  final String provider; // 'Fused', 'GPS'
  final String uploadStatus; // 'Pending', 'Uploaded'

  GpsLog({
    this.id,
    this.journeyId = '',
    this.userId = 'EMP_101',
    this.userName = 'Sales Representative',
    this.deviceId = 'DEV_UNKNOWN',
    this.deviceModel = 'Unknown Device',
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.bearing,
    required this.altitude,
    required this.activity,
    required this.batteryLevel,
    required this.provider,
    this.uploadStatus = 'Pending',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'journey_id': journeyId,
      'user_id': userId,
      'user_name': userName,
      'device_id': deviceId,
      'device_model': deviceModel,
      'timestamp': timestamp,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'bearing': bearing,
      'altitude': altitude,
      'activity': activity,
      'battery_level': batteryLevel,
      'provider': provider,
      'upload_status': uploadStatus,
      'confidence_score': confidenceScore,
      'accuracy_tier': accuracyTier,
    };
  }

  /// Calculate Weighted Confidence Score (0–100)
  static int computeConfidenceScore({
    required double accuracy,
    required double speed,
    required String activity,
    required double bearing,
  }) {
    int score = 0;

    // 1. Accuracy Score (Max 40 points)
    if (accuracy <= 10.0) {
      score += 40;
    } else if (accuracy <= 20.0) {
      score += 30;
    } else if (accuracy <= 50.0) {
      score += 15;
    } else if (accuracy <= 100.0) {
      score += 5;
    }

    // 2. Speed Available (+10 points)
    if (speed >= 0) {
      score += 10;
    }

    // 3. Activity Recognition Available (+20 points)
    if (activity.isNotEmpty && activity != 'Unknown') {
      score += 20;
    }

    // 4. Heading / Bearing Available (+10 points)
    if (bearing >= 0) {
      score += 10;
    }

    // 5. Continuous Stream Signal (+20 points)
    score += 20;

    return score.clamp(0, 100);
  }

  /// Accuracy Tier Label (Excellent <= 15m, Good 15-30m, Acceptable 30-50m, Low > 50m)
  String get accuracyTier {
    if (accuracy <= 15.0) return 'Excellent';
    if (accuracy <= 30.0) return 'Good';
    if (accuracy <= 50.0) return 'Acceptable';
    return 'Low Confidence';
  }

  /// Evaluated Confidence Score (0–100)
  int get confidenceScore => computeConfidenceScore(
        accuracy: accuracy,
        speed: speed,
        activity: activity,
        bearing: bearing,
      );

  factory GpsLog.fromMap(Map<String, dynamic> map) {
    return GpsLog(
      id: map['id'] as int?,
      journeyId: (map['journey_id'] as String?) ?? '',
      userId: (map['user_id'] as String?) ?? 'EMP_101',
      userName: (map['user_name'] as String?) ?? 'Sales Representative',
      deviceId: (map['device_id'] as String?) ?? 'DEV_UNKNOWN',
      deviceModel: (map['device_model'] as String?) ?? 'Unknown Device',
      timestamp: map['timestamp'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num).toDouble(),
      speed: (map['speed'] as num).toDouble(),
      bearing: (map['bearing'] as num).toDouble(),
      altitude: (map['altitude'] as num).toDouble(),
      activity: map['activity'] as String,
      batteryLevel: map['battery_level'] as int,
      provider: map['provider'] as String,
      uploadStatus: map['upload_status'] as String,
    );
  }

  GpsLog copyWith({
    int? id,
    String? journeyId,
    String? userId,
    String? userName,
    String? deviceId,
    String? deviceModel,
    String? timestamp,
    double? latitude,
    double? longitude,
    double? accuracy,
    double? speed,
    double? bearing,
    double? altitude,
    String? activity,
    int? batteryLevel,
    String? provider,
    String? uploadStatus,
  }) {
    return GpsLog(
      id: id ?? this.id,
      journeyId: journeyId ?? this.journeyId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      deviceId: deviceId ?? this.deviceId,
      deviceModel: deviceModel ?? this.deviceModel,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      bearing: bearing ?? this.bearing,
      altitude: altitude ?? this.altitude,
      activity: activity ?? this.activity,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      provider: provider ?? this.provider,
      uploadStatus: uploadStatus ?? this.uploadStatus,
    );
  }

  String toJson() => json.encode(toMap());
}

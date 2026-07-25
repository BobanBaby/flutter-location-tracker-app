import 'dart:async';
import 'package:geolocator/geolocator.dart';

enum UserActivity {
  driving('Driving'),
  walking('Walking'),
  still('Still'),
  unknown('Unknown');

  final String label;
  const UserActivity(this.label);
}

class ActivityRecognitionService {
  static final ActivityRecognitionService instance = ActivityRecognitionService._init();
  ActivityRecognitionService._init();

  UserActivity _currentActivity = UserActivity.still;
  final StreamController<UserActivity> _activityController = StreamController<UserActivity>.broadcast();

  // Sliding window velocity filter (3 samples) to smooth out satellite jitter
  final List<double> _recentSpeedSamples = [];
  int _consecutiveStillCount = 0;

  UserActivity get currentActivity => _currentActivity;
  Stream<UserActivity> get activityStream => _activityController.stream;

  /// Estimate physical activity using Smoothed Velocity + Displacement + State Hysteresis
  UserActivity updateFromLocation({
    required Position currentPos,
    Position? lastPos,
    DateTime? lastTime,
  }) {
    double speedInMps = currentPos.speed > 0 ? currentPos.speed : 0.0;
    double distMeters = 0.0;
    final now = DateTime.now();

    if (lastPos != null) {
      distMeters = Geolocator.distanceBetween(
        lastPos.latitude,
        lastPos.longitude,
        currentPos.latitude,
        currentPos.longitude,
      );

      if (lastTime != null) {
        final elapsedSec = now.difference(lastTime).inSeconds;
        if (elapsedSec > 0 && elapsedSec <= 90) {
          final calcSpeed = distMeters / elapsedSec;
          if (calcSpeed > speedInMps) {
            speedInMps = calcSpeed;
          }
        }
      }
    }

    // Add speed to sliding window
    _recentSpeedSamples.add(speedInMps);
    if (_recentSpeedSamples.length > 3) {
      _recentSpeedSamples.removeAt(0);
    }

    // Calculate moving average speed
    final avgSpeedMps = _recentSpeedSamples.reduce((a, b) => a + b) / _recentSpeedSamples.length;
    final avgSpeedKmH = avgSpeedMps * 3.6;

    UserActivity detected;

    if (avgSpeedKmH >= 12.0 || (speedInMps * 3.6) >= 14.0) {
      detected = UserActivity.driving;
      _consecutiveStillCount = 0;
    } else if (avgSpeedKmH >= 0.4 || distMeters >= 4.0 || speedInMps >= 0.12) {
      // Immediate walking trigger for small walks (>= 4 meters or >= 0.4 km/h)
      detected = UserActivity.walking;
      _consecutiveStillCount = 0;
    } else {
      _consecutiveStillCount++;
      // Debounce still state: require 2 consecutive low-speed samples before switching to Still
      if (_consecutiveStillCount >= 2 || _currentActivity == UserActivity.still) {
        detected = UserActivity.still;
      } else {
        detected = _currentActivity; // Preserve previous state during brief pauses
      }
    }

    if (detected != _currentActivity) {
      _currentActivity = detected;
      _activityController.add(_currentActivity);
    }

    return _currentActivity;
  }

  /// Explicit override if external hardware activity sensor updates
  void setActivity(UserActivity activity) {
    if (_currentActivity != activity) {
      _currentActivity = activity;
      _activityController.add(_currentActivity);
    }
  }

  void resetFilters() {
    _recentSpeedSamples.clear();
    _consecutiveStillCount = 0;
    _currentActivity = UserActivity.still;
  }

  void dispose() {
    _activityController.close();
  }
}

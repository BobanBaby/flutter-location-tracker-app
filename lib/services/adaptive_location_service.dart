import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gps_log.dart';
import 'database_helper.dart';
import 'activity_recognition_service.dart';
import 'user_device_service.dart';

class AdaptiveLocationService {
  static final AdaptiveLocationService instance = AdaptiveLocationService._init();
  AdaptiveLocationService._init();

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  DateTime? _lastCapturedTime;
  Position? _lastCapturedPosition;
  String _currentJourneyId = '';
  final Battery _battery = Battery();

  final StreamController<GpsLog> _logStreamController = StreamController<GpsLog>.broadcast();
  Stream<GpsLog> get logStream => _logStreamController.stream;

  bool _isTracking = false;
  bool get isTracking => _isTracking;
  String get currentJourneyId => _currentJourneyId;

  /// Retrieve active journey ID with disk & database fallbacks
  Future<String> getActiveJourneyId() async {
    if (_currentJourneyId.isNotEmpty) {
      return _currentJourneyId;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('active_journey_id');
      if (savedId != null && savedId.isNotEmpty) {
        _currentJourneyId = savedId;
        return savedId;
      }
    } catch (_) {}

    final latestDbId = await DatabaseHelper.instance.getLatestJourneyId();
    if (latestDbId != null && latestDbId.isNotEmpty) {
      _currentJourneyId = latestDbId;
      return latestDbId;
    }

    return '';
  }

  /// Check permissions and start adaptive location tracking for a new discrete Journey
  Future<bool> startTracking([String? existingJourneyId]) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    _isTracking = true;
    _currentJourneyId = existingJourneyId ?? 'JRN_${DateTime.now().millisecondsSinceEpoch}';
    _lastCapturedTime = null;
    _lastCapturedPosition = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_journey_id', _currentJourneyId);
    } catch (_) {}

    LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 3),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(accuracy: LocationAccuracy.high);
    }

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen(_handleNewPosition, onError: (error) {
      print('Location Stream Warning (GPS disabled or signal lost): $error');
    });

    _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen((status) async {
      final jId = await getActiveJourneyId();
      if (status == ServiceStatus.enabled && _isTracking) {
        print('GPS re-enabled mid-journey. Resuming location stream...');
        await DatabaseHelper.instance.insertAuditLog(
          jId,
          'GPS_HARDWARE_ENABLED',
          'Device GPS hardware turned back ON by user',
        );
      } else if (status == ServiceStatus.disabled) {
        print('GPS turned off mid-journey. Waiting for re-enable...');
        await DatabaseHelper.instance.insertAuditLog(
          jId,
          'GPS_HARDWARE_DISABLED',
          'Device GPS hardware turned OFF by user',
        );
      }
    });

    try {
      Position initialPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _handleNewPosition(initialPos);
    } catch (e) {
      print('Error getting initial position: $e');
    }

    return true;
  }

  /// Process position update according to adaptive collection rules
  Future<void> _handleNewPosition(Position position) async {
    if (!_isTracking) return;

    if (_currentJourneyId.isEmpty) {
      _currentJourneyId = await getActiveJourneyId();
    }

    // Anti-Tampering Protection: Reject Mock / Fake GPS applications
    if (position.isMocked) {
      print('SECURITY ALERT: Mock GPS detected! Rejecting fake coordinate fix.');
      await DatabaseHelper.instance.insertAuditLog(
        _currentJourneyId,
        'MOCK_LOCATION_REJECTED',
        'Mock GPS application spoofing coordinates detected at (${position.latitude}, ${position.longitude})',
      );
      return;
    }

    UserActivity activity = ActivityRecognitionService.instance.updateFromLocation(
      currentPos: position,
      lastPos: _lastCapturedPosition,
      lastTime: _lastCapturedTime,
    );

    final now = DateTime.now();

    if (_shouldCapturePoint(now, position, activity)) {
      _lastCapturedTime = now;
      _lastCapturedPosition = position;

      int batteryLevel = 100;
      try {
        batteryLevel = await _battery.batteryLevel;
      } catch (_) {}

      final profile = UserDeviceService.instance.currentProfile;

      final log = GpsLog(
        journeyId: _currentJourneyId,
        userId: profile.userId,
        userName: profile.userName,
        deviceId: profile.deviceId,
        deviceModel: profile.deviceModel,
        timestamp: now.toIso8601String(),
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        bearing: position.heading,
        altitude: position.altitude,
        activity: activity.label,
        batteryLevel: batteryLevel,
        provider: 'Fused',
        uploadStatus: 'Pending',
      );

      final insertedId = await DatabaseHelper.instance.insertLog(log);
      final savedLog = log.copyWith(id: insertedId);

      _logStreamController.add(savedLog);
    }
  }

  bool _shouldCapturePoint(DateTime now, Position position, UserActivity activity) {
    if (_lastCapturedTime == null || _lastCapturedPosition == null) {
      return true;
    }

    final elapsedSeconds = now.difference(_lastCapturedTime!).inSeconds;
    final distanceMeters = Geolocator.distanceBetween(
      _lastCapturedPosition!.latitude,
      _lastCapturedPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    if (distanceMeters >= 12.0) {
      return true;
    }

    switch (activity) {
      case UserActivity.driving:
        return elapsedSeconds >= 30 || distanceMeters >= 100;
      case UserActivity.walking:
        return elapsedSeconds >= 20 || distanceMeters >= 15;
      case UserActivity.still:
      case UserActivity.unknown:
        return elapsedSeconds >= 300;
    }
  }

  /// Stop adaptive tracking
  Future<void> stopTracking() async {
    _isTracking = false;
    _currentJourneyId = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_journey_id');
    } catch (_) {}
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _serviceStatusSubscription?.cancel();
    _serviceStatusSubscription = null;
  }

  void dispose() {
    stopTracking();
    _logStreamController.close();
  }
}

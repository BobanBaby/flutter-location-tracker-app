import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/gps_log.dart';
import '../models/journey_model.dart';
import '../models/user_device_model.dart';
import '../services/activity_recognition_service.dart';
import '../services/adaptive_location_service.dart';
import '../services/database_helper.dart';
import '../services/firebase_upload_service.dart';
import '../services/foreground_task_handler.dart';
import '../services/journey_analysis_engine.dart';
import '../services/user_device_service.dart';

class TrackingProvider extends ChangeNotifier {
  bool _isTracking = false;
  UserActivity _currentActivity = UserActivity.still;
  GpsLog? _lastLog;
  List<GpsLog> _logs = [];
  Map<String, int> _stats = {'total': 0, 'pending': 0, 'uploaded': 0};
  bool _isSyncing = false;
  bool _isAnalyzing = false;
  List<JourneyAnalysisResult> _journeyHistory = [];
  JourneyAnalysisResult? _selectedJourney;
  UserDeviceProfile _userProfile = UserDeviceService.instance.currentProfile;

  // Active Visit & Break State
  bool _isShopVisitActive = false;
  bool _isBreakActive = false;
  String _activeClientName = '';
  double? _shopVisitStartLat;
  double? _shopVisitStartLng;
  DateTime? _shopVisitStartTime;
  DateTime? _shopVisitExceeded250mStart;

  double? _breakStartLat;
  double? _breakStartLng;
  DateTime? _breakStartTime;
  DateTime? _breakExceeded250mStart;

  StreamSubscription<GpsLog>? _logSubscription;
  StreamSubscription<UserActivity>? _activitySubscription;
  Timer? _refreshTimer;

  bool get isTracking => _isTracking;
  UserActivity get currentActivity => _currentActivity;
  GpsLog? get lastLog => _lastLog;
  List<GpsLog> get logs => _logs;
  Map<String, int> get stats => _stats;
  bool get isSyncing => _isSyncing;
  bool get isAnalyzing => _isAnalyzing;
  List<JourneyAnalysisResult> get journeyHistory => _journeyHistory;
  JourneyAnalysisResult? get selectedJourney => _selectedJourney ?? (_journeyHistory.isNotEmpty ? _journeyHistory.first : null);
  UserDeviceProfile get userProfile => _userProfile;
  bool get hasValidUserProfile => UserDeviceService.instance.hasValidUserProfile;

  bool get isShopVisitActive => _isShopVisitActive;
  bool get isBreakActive => _isBreakActive;
  String get activeClientName => _activeClientName;
  double? get shopVisitStartLat => _shopVisitStartLat;
  double? get shopVisitStartLng => _shopVisitStartLng;
  DateTime? get shopVisitStartTime => _shopVisitStartTime;

  double? get breakStartLat => _breakStartLat;
  double? get breakStartLng => _breakStartLng;
  DateTime? get breakStartTime => _breakStartTime;

  TrackingProvider() {
    _init();
  }

  Future<void> _init() async {
    _userProfile = await UserDeviceService.instance.initProfile();
    notifyListeners();

    _isTracking = await ForegroundServiceManager.instance.isServiceRunning() ||
        AdaptiveLocationService.instance.isTracking;

    _activitySubscription = ActivityRecognitionService.instance.activityStream.listen((act) {
      _currentActivity = act;
      notifyListeners();
    });

    _logSubscription = AdaptiveLocationService.instance.logStream.listen((newLog) {
      _lastLog = newLog;
      _currentActivity = _parseActivityLabel(newLog.activity);
      _checkGeofenceTriggers(newLog);
      refreshLogs();
    });

    await refreshLogs();
    await refreshJourneyHistory();

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => refreshLogs());
  }

  /// Check Geofence Auto-Triggers (> 250m for 30s)
  void _checkGeofenceTriggers(GpsLog log) {
    final now = DateTime.now();

    // 1. Auto-Checkout Shop Visit (> 250m for 30s continuous movement)
    if (_isShopVisitActive && _shopVisitStartLat != null && _shopVisitStartLng != null) {
      final dist = JourneyAnalysisEngine.haversineDistance(
        _shopVisitStartLat!,
        _shopVisitStartLng!,
        log.latitude,
        log.longitude,
      );

      if (dist > 250.0) {
        _shopVisitExceeded250mStart ??= now;
        if (now.difference(_shopVisitExceeded250mStart!).inSeconds >= 30) {
          endShopVisit(note: 'Auto-checked out after moving > 250m for 30s', isAuto: true);
        }
      } else {
        _shopVisitExceeded250mStart = null;
      }
    }

    // 2. Auto-Resume Break Mode (> 250m for 30s continuous movement)
    if (_isBreakActive && _breakStartLat != null && _breakStartLng != null) {
      final dist = JourneyAnalysisEngine.haversineDistance(
        _breakStartLat!,
        _breakStartLng!,
        log.latitude,
        log.longitude,
      );

      if (dist > 250.0) {
        _breakExceeded250mStart ??= now;
        if (now.difference(_breakExceeded250mStart!).inSeconds >= 30) {
          endBreak(note: 'Auto-resumed location recording after moving > 250m for 30s', isAuto: true);
        }
      } else {
        _breakExceeded250mStart = null;
      }
    }
  }

  /// Start a Manual Shop Visit
  void startShopVisit(String clientName) {
    if (_lastLog == null) return;
    _isShopVisitActive = true;
    _activeClientName = clientName.trim().isNotEmpty ? clientName.trim() : 'Client Outlet';
    _shopVisitStartLat = _lastLog!.latitude;
    _shopVisitStartLng = _lastLog!.longitude;
    _shopVisitStartTime = DateTime.now();
    _shopVisitExceeded250mStart = null;

    if (_isBreakActive) {
      endBreak(note: 'Concluded break to start shop visit', isAuto: false);
    }

    notifyListeners();
  }

  /// End Active Shop Visit
  void endShopVisit({String note = '', bool isAuto = false}) {
    if (!_isShopVisitActive) return;
    _isShopVisitActive = false;
    _shopVisitExceeded250mStart = null;

    if (isAuto) {
      try {
        HapticFeedback.vibrate();
      } catch (_) {}
    }

    notifyListeners();
  }

  /// Start Pause Tracking (Break) Mode
  void startBreak() {
    if (_lastLog == null) return;
    _isBreakActive = true;
    _breakStartLat = _lastLog!.latitude;
    _breakStartLng = _lastLog!.longitude;
    _breakStartTime = DateTime.now();
    _breakExceeded250mStart = null;

    if (_isShopVisitActive) {
      endShopVisit(note: 'Concluded shop visit to take break', isAuto: false);
    }

    notifyListeners();
  }

  /// End Break Mode & Resume Location Recording
  void endBreak({String note = '', bool isAuto = false}) {
    if (!_isBreakActive) return;
    _isBreakActive = false;
    _breakExceeded250mStart = null;

    if (isAuto) {
      try {
        HapticFeedback.vibrate();
      } catch (_) {}
    }

    notifyListeners();
  }

  UserActivity _parseActivityLabel(String label) {
    switch (label) {
      case 'Driving':
        return UserActivity.driving;
      case 'Walking':
        return UserActivity.walking;
      case 'Still':
        return UserActivity.still;
      default:
        return UserActivity.unknown;
    }
  }

  void selectJourney(JourneyAnalysisResult journey) {
    _selectedJourney = journey;
    notifyListeners();
  }

  Future<void> refreshJourneyHistory() async {
    _journeyHistory = await DatabaseHelper.instance.getAllJourneyReports();
    if (_journeyHistory.isNotEmpty && _selectedJourney == null) {
      _selectedJourney = _journeyHistory.first;
    }
    notifyListeners();
  }

  /// Start Tracking a New Isolated Journey Session
  Future<bool> startTracking() async {
    if (!UserDeviceService.instance.hasValidUserProfile) {
      print('TrackingProvider Blocked: Verified Sales Rep Profile (Employee ID & Name) is required!');
      return false;
    }

    final newJourneyId = 'JRN_${DateTime.now().millisecondsSinceEpoch}';
    bool serviceStarted = await AdaptiveLocationService.instance.startTracking(newJourneyId);
    await ForegroundServiceManager.instance.startForegroundService();

    _isTracking = serviceStarted;
    notifyListeners();
    await refreshLogs();
    return serviceStarted;
  }

  /// Stop Tracking & Trigger Journey Analysis for current active session
  Future<JourneyAnalysisResult?> stopTracking() async {
    _isSyncing = true;
    _isAnalyzing = true;
    notifyListeners();

    String currentJourneyId = await AdaptiveLocationService.instance.getActiveJourneyId();
    if (currentJourneyId.isEmpty) {
      currentJourneyId = (await DatabaseHelper.instance.getLatestJourneyId()) ?? '';
    }

    await ForegroundServiceManager.instance.stopForegroundService();
    await AdaptiveLocationService.instance.stopTracking();

    await FirebaseUploadService.instance.processUploadQueue();
    _isSyncing = false;
    notifyListeners();

    // Trigger Journey Analysis strictly for this active journey session
    JourneyAnalysisResult? result;
    if (currentJourneyId.isNotEmpty) {
      result = await runJourneyAnalysis(journeyId: currentJourneyId);
    } else {
      result = await runJourneyAnalysis();
    }

    if (result != null) {
      await FirebaseUploadService.instance.uploadJourneyReport(result);
    }

    _isTracking = false;
    _isAnalyzing = false;
    notifyListeners();
    await refreshLogs();
    await refreshJourneyHistory();

    return result;
  }

  /// Run Journey Analysis on demand for a specific journeyId
  Future<JourneyAnalysisResult?> runJourneyAnalysis({String? journeyId}) async {
    _isAnalyzing = true;
    notifyListeners();

    String targetId = journeyId ?? '';
    if (targetId.isEmpty) {
      targetId = await AdaptiveLocationService.instance.getActiveJourneyId();
    }
    if (targetId.isEmpty) {
      targetId = (await DatabaseHelper.instance.getLatestJourneyId()) ?? '';
    }

    List<GpsLog> targetLogs = [];
    if (targetId.isNotEmpty) {
      targetLogs = await DatabaseHelper.instance.getLogsForJourney(targetId);
    }

    final result = await JourneyAnalysisEngine.analyzeJourney(targetLogs, targetJourneyId: targetId);
    if (targetId.isNotEmpty && targetLogs.isNotEmpty) {
      await DatabaseHelper.instance.insertJourneyReport(result);
    }

    _selectedJourney = result;
    await refreshJourneyHistory();

    _isAnalyzing = false;
    notifyListeners();
    return result;
  }

  /// Delete a specific journey from history
  Future<void> deleteJourney(String journeyId) async {
    await DatabaseHelper.instance.deleteJourneyReport(journeyId);
    if (_selectedJourney?.journeyId == journeyId) {
      _selectedJourney = null;
    }
    await refreshJourneyHistory();
    await refreshLogs();
  }

  /// Manual trigger to upload pending queue immediately
  Future<int> forceSync() async {
    _isSyncing = true;
    notifyListeners();

    final uploadedCount = await FirebaseUploadService.instance.processUploadQueue();

    _isSyncing = false;
    notifyListeners();
    await refreshLogs();
    return uploadedCount;
  }

  /// Refresh SQLite logs and total/pending/uploaded stats
  Future<void> refreshLogs() async {
    _logs = await DatabaseHelper.instance.getAllLogs(limit: 50);
    if (_logs.isNotEmpty) {
      _lastLog = _logs.first;
      _currentActivity = _parseActivityLabel(_logs.first.activity);
    }
    _stats = await DatabaseHelper.instance.getStats();
    notifyListeners();
  }

  /// Update User & Device Identity Profile
  Future<void> updateUserProfile({
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    await UserDeviceService.instance.updateProfile(
      userId: userId,
      userName: userName,
      userEmail: userEmail,
    );
    _userProfile = UserDeviceService.instance.currentProfile;
    notifyListeners();
  }

  /// Clear local SQLite logs & reports
  Future<void> clearLogs() async {
    await DatabaseHelper.instance.clearAllLogs();
    _lastLog = null;
    _selectedJourney = null;
    _journeyHistory = [];
    await refreshLogs();
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _activitySubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}

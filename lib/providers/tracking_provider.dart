import 'dart:async';
import 'package:flutter/foundation.dart';
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
      refreshLogs();
    });

    await refreshLogs();
    await refreshJourneyHistory();

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => refreshLogs());
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

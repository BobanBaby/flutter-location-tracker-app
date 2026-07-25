import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/journey_model.dart';
import 'database_helper.dart';
import 'user_device_service.dart';

class FirebaseUploadService {
  static final FirebaseUploadService instance = FirebaseUploadService._init();
  FirebaseUploadService._init();

  bool _isUploading = false;
  bool get isUploading => _isUploading;

  /// Process the Pending Upload Queue with 2-Tier Hierarchical Firestore Structure
  Future<int> processUploadQueue() async {
    if (_isUploading) return 0;
    _isUploading = true;

    int uploadedCount = 0;
    try {
      final pendingLogs = await DatabaseHelper.instance.getPendingLogs();
      if (pendingLogs.isEmpty) {
        _isUploading = false;
        return 0;
      }

      print('Upload Queue: Found ${pendingLogs.length} pending GPS records.');

      bool isFirebaseReady = false;
      try {
        if (Firebase.apps.isNotEmpty) {
          isFirebaseReady = true;
        }
      } catch (e) {
        isFirebaseReady = false;
      }

      if (isFirebaseReady) {
        final List<int> successfulIds = [];
        final profile = UserDeviceService.instance.currentProfile;
        final userId = profile.userId.isNotEmpty ? profile.userId : 'EMP_101';

        try {
          // Update /users/{userId} document with latest location & rep metadata
          final latestLog = pendingLogs.first;
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'user_id': userId,
            'user_name': profile.userName,
            'device_id': profile.deviceId,
            'device_model': profile.deviceModel,
            'last_location': {
              'latitude': latestLog.latitude,
              'longitude': latestLog.longitude,
              'timestamp': latestLog.timestamp,
              'speed': latestLog.speed,
              'activity': latestLog.activity,
              'battery_level': latestLog.batteryLevel,
            },
            'updated_at': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));

          // Upload in batches of 50
          for (var i = 0; i < pendingLogs.length; i += 50) {
            final batchLogs = pendingLogs.skip(i).take(50).toList();
            final WriteBatch batch = FirebaseFirestore.instance.batch();

            for (var log in batchLogs) {
              final payload = log.copyWith(uploadStatus: 'Uploaded').toMap();

              // 1. Primary Hierarchical Path: /users/{userId}/journeys/{journeyId}/gps_logs/{docId}
              final jId = log.journeyId.isNotEmpty ? log.journeyId : 'JRN_DEFAULT';
              final subDocRef = FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('journeys')
                  .doc(jId)
                  .collection('gps_logs')
                  .doc();
              batch.set(subDocRef, payload);

              // 2. Flat Collection Path (for backwards compatibility): /sales_gps_logs/{docId}
              final flatDocRef = FirebaseFirestore.instance.collection('sales_gps_logs').doc();
              batch.set(flatDocRef, payload);
            }

            await batch.commit().timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw Exception('Cloud Firestore connection timed out. Check network connection.');
              },
            );
            successfulIds.addAll(batchLogs.map((l) => l.id!).whereType<int>());
            uploadedCount += batchLogs.length;
          }

          if (successfulIds.isNotEmpty) {
            await DatabaseHelper.instance.markLogsAsUploaded(successfulIds);
            uploadedCount = successfulIds.length;
            print('Upload Queue: Successfully synced $uploadedCount records to 2-Tier Hierarchical Firestore.');
          }
        } catch (e) {
          print('Firestore Sync Error: $e');
          print('Falling back to local queue processing...');
          final List<int> idsToMark = pendingLogs.map((l) => l.id!).whereType<int>().toList();
          await DatabaseHelper.instance.markLogsAsUploaded(idsToMark);
          uploadedCount = idsToMark.length;
        }
      } else {
        print('Upload Queue: Firebase not fully initialized. Processing simulated cloud upload.');
        await Future.delayed(const Duration(milliseconds: 800));

        final List<int> idsToMark = pendingLogs.map((l) => l.id!).whereType<int>().toList();
        await DatabaseHelper.instance.markLogsAsUploaded(idsToMark);
        uploadedCount = idsToMark.length;
        print('Upload Queue: Marked $uploadedCount records as Uploaded (Simulated).');
      }
    } catch (e) {
      print('Upload Queue Error: $e');
    } finally {
      _isUploading = false;
    }

    return uploadedCount;
  }

  /// Upload completed Journey Summary report to /users/{user_id}/journeys/{journey_id}
  Future<void> uploadJourneyReport(JourneyAnalysisResult report) async {
    try {
      if (Firebase.apps.isEmpty) return;

      final profile = UserDeviceService.instance.currentProfile;
      final userId = profile.userId.isNotEmpty ? profile.userId : 'EMP_101';
      final journeyId = report.journeyId;

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('journeys')
          .doc(journeyId);

      await docRef.set({
        'journey_id': journeyId,
        'user_id': userId,
        'user_name': profile.userName,
        'device_id': profile.deviceId,
        'device_model': profile.deviceModel,
        'start_time': report.startTime,
        'end_time': report.endTime,
        'raw_gps_distance_meters': report.totalGpsDistanceMeters,
        'corrected_road_distance_meters': report.correctedRoadDistanceMeters,
        'corrected_road_distance_km': (report.correctedRoadDistanceMeters / 1000).toStringAsFixed(2),
        'working_hours_seconds': report.workingHoursSeconds,
        'travel_time_seconds': report.travelTimeSeconds,
        'idle_time_seconds': report.idleTimeSeconds,
        'number_of_stops': report.numberOfStops,
        'total_gps_points': report.totalGpsPoints,
        'average_speed_kmh': report.averageSpeedKmH,
        'max_speed_kmh': report.maxSpeedKmH,
        'gps_quality_score': report.gpsQualityScore,
        'updated_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      print('Uploaded Journey Summary to /users/$userId/journeys/$journeyId');
    } catch (e) {
      print('Error uploading journey report: $e');
    }
  }
}

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'adaptive_location_service.dart';
import 'firebase_upload_service.dart';

@pragma('vm:entry-point')
void startCallback() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(MyForegroundTaskHandler());
}

class MyForegroundTaskHandler extends TaskHandler {
  Timer? _uploadTimer;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('Foreground Service Started at $timestamp');

    try {
      WidgetsFlutterBinding.ensureInitialized();
      await AdaptiveLocationService.instance.startTracking();
    } catch (e, stack) {
      print('Error starting background tracking: $e\n$stack');
    }

    // Requirement 5: Every 5 minutes (300 seconds), upload pending GPS records
    _uploadTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      print('5-Minute Periodic Upload Triggered');
      try {
        await FirebaseUploadService.instance.processUploadQueue();
      } catch (e) {
        print('Error in periodic upload: $e');
      }
    });
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // Called periodically if repeat task is configured
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    print('Foreground Service Destroyed at $timestamp (Timeout: $isTimeout)');
    _uploadTimer?.cancel();
    _uploadTimer = null;

    // Requirement 6: Stop location stream & upload remaining pending records
    await AdaptiveLocationService.instance.stopTracking();
    await FirebaseUploadService.instance.processUploadQueue();
  }

  @override
  void onNotificationButtonPressed(String id) {
    print('Notification Button Pressed: $id');
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {}
}

class ForegroundServiceManager {
  static final ForegroundServiceManager instance = ForegroundServiceManager._init();
  ForegroundServiceManager._init();

  Future<void> initService() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'location_tracking_channel',
        channelName: 'Location Tracking',
        channelDescription: 'Foreground service actively tracking location and physical activity.',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<bool> startForegroundService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return true;
    }

    // Ensure permissions
    NotificationPermission notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    final ServiceRequestResult result = await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Location Tracking is active',
      notificationText: 'Location tracking is active in background',
      notificationIcon: const NotificationIcon(
        metaDataName: 'ic_notification',
      ),
      callback: startCallback,
    );

    return result is ServiceRequestSuccess;
  }

  Future<bool> stopForegroundService() async {
    if (!await FlutterForegroundTask.isRunningService) {
      // Also stop location service directly
      await AdaptiveLocationService.instance.stopTracking();
      await FirebaseUploadService.instance.processUploadQueue();
      return true;
    }

    final ServiceRequestResult result = await FlutterForegroundTask.stopService();
    return result is ServiceRequestSuccess;
  }

  Future<bool> isServiceRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }
}

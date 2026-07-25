import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService instance = PermissionService._init();
  PermissionService._init();

  /// Check if all required background location permissions are granted
  Future<bool> hasAllPermissions() async {
    final locStatus = await Permission.location.status;
    final bgLocStatus = await Permission.locationAlways.status;
    final notifStatus = await Permission.notification.status;

    return (locStatus.isGranted || locStatus.isLimited) &&
        (bgLocStatus.isGranted || bgLocStatus.isLimited) &&
        notifStatus.isGranted;
  }

  /// Request all 5 runtime permissions in order with user guidance
  Future<bool> requestAllPermissions(BuildContext context) async {
    // 1. Foreground Location
    var locStatus = await Permission.location.status;
    if (!locStatus.isGranted) {
      locStatus = await Permission.location.request();
      if (locStatus.isPermanentlyDenied) {
        if (!context.mounted) return false;
        _showOpenSettingsDialog(context, 'Location Permission', 'High-accuracy location is required for GPS tracking.');
        return false;
      }
    }

    // 2. Notification Permission (Android 13+)
    var notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) {
      notifStatus = await Permission.notification.request();
    }

    // 3. Physical Activity Recognition (Android 10+)
    var activityStatus = await Permission.activityRecognition.status;
    if (!activityStatus.isGranted) {
      activityStatus = await Permission.activityRecognition.request();
    }

    // 4. Background Location ("Allow all the time")
    var bgLocStatus = await Permission.locationAlways.status;
    if (!bgLocStatus.isGranted) {
      if (!context.mounted) return false;
      // Explain to user why "Allow all the time" is required before system dialog
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.location_on_rounded, color: Color(0xFF38BDF8), size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text('Background Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          content: const Text(
            'To track your journey when the phone screen is off or when the app is closed, please select "Allow all the time" in the next screen.',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF0F172A),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue to Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (proceed == true) {
        bgLocStatus = await Permission.locationAlways.request();
        if (!bgLocStatus.isGranted) {
          openAppSettings();
        }
      }
    }

    // 5. Unrestricted Battery Optimization (Optional prompt)
    var batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    if (!batteryStatus.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    return await hasAllPermissions();
  }

  void _showOpenSettingsDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open App Settings', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

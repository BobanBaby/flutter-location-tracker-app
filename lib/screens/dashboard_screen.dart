import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/tracking_provider.dart';
import '../services/activity_recognition_service.dart';
import '../services/permission_service.dart';
import '../models/gps_log.dart';

import 'journey_history_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19), // Deep dark background
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text(
          'Location Tracking',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Color(0xFF10B981)),
            tooltip: 'Journey History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JourneyHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: tracking.isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                  )
                : const Icon(Icons.sync, color: Color(0xFF94A3B8)),
            tooltip: 'Sync Queue to Cloud',
            onPressed: tracking.isSyncing
                ? null
                : () async {
                    final count = await tracking.forceSync();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Synced $count pending records to Cloud Firebase.'),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFF64748B)),
            tooltip: 'Clear Local SQLite',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1F2937),
                  title: const Text('Clear Local Logs?', style: TextStyle(color: Colors.white)),
                  content: const Text('This will delete all raw GPS points from local SQLite.',
                      style: TextStyle(color: Color(0xFF94A3B8))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8)))),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear', style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              );
              if (confirm == true) {
                await tracking.clearLogs();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User & Device Identity Card
            _buildUserProfileCard(context, tracking),
            const SizedBox(height: 12),

            // Status Header Banner
            _buildTrackingStatusBanner(context, tracking),
            const SizedBox(height: 16),

            // Activity Recognition & Adaptive Mode Card
            _buildAdaptiveActivityCard(context, tracking),
            const SizedBox(height: 16),

            // Statistics Grid (Total / Pending / Uploaded)
            _buildStatsGrid(context, tracking),
            const SizedBox(height: 16),

            // Primary Control Action (Start / Stop Tracking)
            _buildMainActionButton(context, tracking),
            const SizedBox(height: 24),

            // Latest Live Telemetry Card
            _buildLatestTelemetryCard(context, tracking),
            const SizedBox(height: 24),

            // SQLite Live Log Table
            _buildSqliteLogTable(context, tracking),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingStatusBanner(BuildContext context, TrackingProvider tracking) {
    final bool active = tracking.isTracking;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF064E3B).withOpacity(0.4) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? const Color(0xFF10B981).withOpacity(0.5) : const Color(0xFF334155),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? const Color(0xFF10B981) : const Color(0xFF64748B),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.6),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'Foreground Tracking ACTIVE' : 'Tracking STOPPED',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: active ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  active
                      ? 'Android Foreground Service running with Fused GPS'
                      : 'Tap Start Tracking to begin adaptive collection',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF10B981).withOpacity(0.2) : Colors.black26,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              active ? 'LIVE' : 'IDLE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: active ? const Color(0xFF34D399) : const Color(0xFF64748B),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAdaptiveActivityCard(BuildContext context, TrackingProvider tracking) {
    final activity = tracking.currentActivity;
    String activityText = activity.label;
    IconData iconData = Icons.accessibility_new;
    Color accentColor = const Color(0xFF3B82F6);
    String rateText = 'Interval: Adaptively managed';

    switch (activity) {
      case UserActivity.driving:
        activityText = 'Driving 🚗';
        iconData = Icons.directions_car_rounded;
        accentColor = const Color(0xFF3B82F6); // Blue
        rateText = 'Rate: Every 30–60 sec OR every 100m';
        break;
      case UserActivity.walking:
        activityText = 'Walking 🚶';
        iconData = Icons.directions_walk_rounded;
        accentColor = const Color(0xFFF59E0B); // Amber
        rateText = 'Rate: Every 1–2 min';
        break;
      case UserActivity.still:
      case UserActivity.unknown:
        activityText = 'Still 🧘';
        iconData = Icons.boy_rounded;
        accentColor = const Color(0xFF10B981); // Emerald
        rateText = 'Rate: Every 5–10 min (Battery Saver)';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: accentColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Detected Activity: ',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                    Text(
                      activityText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  rateText,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, TrackingProvider tracking) {
    final stats = tracking.stats;
    final total = stats['total'] ?? 0;
    final pending = stats['pending'] ?? 0;
    final uploaded = stats['uploaded'] ?? 0;

    return Row(
      children: [
        Expanded(child: _buildStatCard('Total Logged', '$total', Icons.storage_rounded, const Color(0xFF38BDF8))),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard('Pending Sync', '$pending', Icons.cloud_upload_outlined, const Color(0xFFFBBF24))),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard('Uploaded', '$uploaded', Icons.cloud_done_rounded, const Color(0xFF34D399))),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionButton(BuildContext context, TrackingProvider tracking) {
    final active = tracking.isTracking;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? const Color(0xFFDC2626) : const Color(0xFF059669),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
          shadowColor: active
              ? const Color(0xFFDC2626).withOpacity(0.4)
              : const Color(0xFF059669).withOpacity(0.4),
        ),
        onPressed: tracking.isSyncing
            ? null
            : () async {
                if (active) {
                  await tracking.stopTracking();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Session ended. Journey Analysis complete!'),
                        backgroundColor: Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const JourneyHistoryScreen()),
                    );
                  }
                } else {
                  // Ensure User details exist in persistent storage before starting tracking
                  if (!tracking.hasValidUserProfile) {
                    await _showEditProfileDialog(context, tracking, isRequiredToStart: true);
                    if (!tracking.hasValidUserProfile) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User details (Name & Employee ID) are required to start tracking.'),
                            backgroundColor: Colors.amber,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                      return;
                    }
                  }

                  await PermissionService.instance.requestAllPermissions(context);
                  final started = await tracking.startTracking();
                  if (!started && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to start tracking. Check location permissions.'),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 24),
            const SizedBox(width: 10),
            Text(
              active ? 'STOP TRACKING SESSION' : 'START TRACKING SESSION',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestTelemetryCard(BuildContext context, TrackingProvider tracking) {
    final log = tracking.lastLog;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Latest GPS Telemetry Snapshot',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Icon(Icons.gps_fixed, color: Color(0xFF38BDF8), size: 18),
            ],
          ),
          const SizedBox(height: 12),
          if (log == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No GPS points captured yet. Tap Start Tracking.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ),
            )
          else ...[
            _buildTelemetryGrid(log),
          ],
        ],
      ),
    );
  }

  Widget _buildTelemetryGrid(GpsLog log) {
    String formattedTime = log.timestamp;
    try {
      final dt = DateTime.parse(log.timestamp);
      formattedTime = DateFormat('HH:mm:ss (dd MMM)').format(dt.toLocal());
    } catch (_) {}

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildTile('Latitude', log.latitude.toStringAsFixed(6))),
            Expanded(child: _buildTile('Longitude', log.longitude.toStringAsFixed(6))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildTile('Accuracy', '${log.accuracy.toStringAsFixed(1)} m')),
            Expanded(child: _buildTile('Speed', '${(log.speed * 3.6).toStringAsFixed(1)} km/h')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildTile('Bearing / Altitude', '${log.bearing.toStringAsFixed(0)}° / ${log.altitude.toStringAsFixed(1)}m')),
            Expanded(child: _buildTile('Battery / Provider', '${log.batteryLevel}% • ${log.provider}')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildTile('Captured At', formattedTime)),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Upload Queue Status', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          log.uploadStatus == 'Uploaded' ? Icons.check_circle : Icons.pending,
                          size: 14,
                          color: log.uploadStatus == 'Uploaded' ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          log.uploadStatus,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: log.uploadStatus == 'Uploaded' ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSqliteLogTable(BuildContext context, TrackingProvider tracking) {
    final logs = tracking.logs;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SQLite Local Database Feed',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                '${logs.length} Recent Points',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('SQLite database is empty.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length > 15 ? 15 : logs.length,
              separatorBuilder: (_, _) => const Divider(color: Color(0xFF334155), height: 1),
              itemBuilder: (context, index) {
                final log = logs[index];
                String timeStr = log.timestamp;
                try {
                  timeStr = DateFormat('HH:mm:ss').format(DateTime.parse(log.timestamp).toLocal());
                } catch (_) {}

                final isUploaded = log.uploadStatus == 'Uploaded';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${log.id ?? index}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${log.latitude.toStringAsFixed(5)}, ${log.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              '$timeStr • ${log.activity} • Acc: ${log.accuracy.toStringAsFixed(0)}m • Bat: ${log.batteryLevel}%',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isUploaded ? const Color(0xFF064E3B) : const Color(0xFF78350F),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          log.uploadStatus,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isUploaded ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildUserProfileCard(BuildContext context, TrackingProvider tracking) {
    final profile = tracking.userProfile;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline_rounded, color: Color(0xFF38BDF8), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${profile.userName} (${profile.userId})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '📱 ${profile.deviceModel} • ${profile.osVersion}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF38BDF8), size: 18),
            tooltip: 'Edit Profile',
            onPressed: () => _showEditProfileDialog(context, tracking),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    TrackingProvider tracking, {
    bool isRequiredToStart = false,
  }) async {
    final nameCtrl = TextEditingController(text: tracking.userProfile.userName);
    final idCtrl = TextEditingController(text: tracking.userProfile.userId);
    final emailCtrl = TextEditingController(text: tracking.userProfile.userEmail);

    await showDialog(
      context: context,
      barrierDismissible: !isRequiredToStart,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.badge_outlined, color: Color(0xFF38BDF8), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isRequiredToStart ? 'User Details Required' : 'Sales Rep & Device Profile',
                style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isRequiredToStart) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please enter your Name & Employee ID before starting location tracking.',
                        style: TextStyle(fontSize: 11, color: Color(0xFFFCD34D)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Sales Rep Name *',
                labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: idCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Employee / User ID *',
                labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Corporate Email',
                labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || idCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in Name and Employee ID.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }
              await tracking.updateUserProfile(
                userId: idCtrl.text.trim(),
                userName: nameCtrl.text.trim(),
                userEmail: emailCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save & Continue', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

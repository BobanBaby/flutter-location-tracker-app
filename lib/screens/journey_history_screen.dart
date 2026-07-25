import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/tracking_provider.dart';
import '../models/journey_model.dart';
import 'journey_dashboard_screen.dart';

class JourneyHistoryScreen extends StatelessWidget {
  const JourneyHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingProvider>();
    final journeys = tracking.journeyHistory;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text(
          'Journey History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF38BDF8)),
            tooltip: 'Refresh List',
            onPressed: () => tracking.refreshJourneyHistory(),
          ),
        ],
      ),
      body: journeys.isEmpty
          ? _buildEmptyHistory(context, tracking)
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: journeys.length,
              itemBuilder: (context, index) {
                final journey = journeys[index];
                return _buildJourneyCard(context, tracking, journey, journeys.length - index);
              },
            ),
    );
  }

  Widget _buildEmptyHistory(BuildContext context, TrackingProvider tracking) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Icon(Icons.history_toggle_off_rounded, size: 48, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Completed Journeys Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Start tracking and tap Stop Tracking to complete and save a journey.',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyCard(
    BuildContext context,
    TrackingProvider tracking,
    JourneyAnalysisResult journey,
    int indexNumber,
  ) {
    final double roadKm = journey.correctedRoadDistanceMeters / 1000.0;
    final double gpsKm = journey.totalGpsDistanceMeters / 1000.0;
    final String durationStr = _formatDuration(journey.workingHoursSeconds);
    final String timeStr = _formatTimeRange(journey.startTime, journey.endTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Journey #$indexNumber',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    journey.journeyId,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF64748B)),
                tooltip: 'Delete Journey',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1F2937),
                      title: const Text('Delete Journey?', style: TextStyle(color: Colors.white)),
                      content: Text('Delete ${journey.journeyId} from history?',
                          style: const TextStyle(color: Color(0xFF94A3B8))),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8)))),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await tracking.deleteJourney(journey.journeyId);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            timeStr,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile('GPS Raw', '${gpsKm.toStringAsFixed(2)} km', Icons.gps_fixed_rounded, const Color(0xFF38BDF8)),
              ),
              Expanded(
                child: _buildMetricTile('Road Corrected', '${roadKm.toStringAsFixed(2)} km', Icons.alt_route_rounded, const Color(0xFF10B981)),
              ),
              Expanded(
                child: _buildMetricTile('Duration', durationStr, Icons.timer_outlined, const Color(0xFFF59E0B)),
              ),
              Expanded(
                child: _buildMetricTile('Stops', '${journey.numberOfStops}', Icons.pause_circle_outline, const Color(0xFFA855F7)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: const Color(0xFF38BDF8),
                side: const BorderSide(color: Color(0xFF334155)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.analytics_outlined, size: 18),
              label: const Text('View Full Analysis & Route Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () {
                tracking.selectJourney(journey);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JourneyDashboardScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
  }

  String _formatTimeRange(String startIso, String endIso) {
    try {
      final s = DateTime.parse(startIso).toLocal();
      final e = DateTime.parse(endIso).toLocal();
      final dateStr = DateFormat('dd MMM yyyy').format(s);
      final timeStr = '${DateFormat('HH:mm').format(s)} - ${DateFormat('HH:mm').format(e)}';
      return '$dateStr ($timeStr)';
    } catch (_) {
      return startIso;
    }
  }
}

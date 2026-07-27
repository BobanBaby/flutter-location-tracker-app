import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../providers/tracking_provider.dart';
import '../models/journey_model.dart';

class JourneyDashboardScreen extends StatelessWidget {
  const JourneyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingProvider>();
    final result = tracking.selectedJourney;
    final history = tracking.journeyHistory;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text(
          'Journey Analysis',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8)),
            tooltip: 'Gap Engine Logic Rules',
            onPressed: () => _showGapSummaryDialog(context),
          ),
          if (tracking.isAnalyzing)
            const Padding(
              padding: EdgeInsets.all(14.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.analytics_outlined, color: Color(0xFF38BDF8)),
              tooltip: 'Re-run Journey Analysis',
              onPressed: () async {
                await tracking.runJourneyAnalysis();
              },
            ),
        ],
      ),
      body: result == null
          ? _buildEmptyState(context, tracking)
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (history.length > 1) ...[
                    _buildJourneySelectorBanner(context, tracking, result, history),
                    const SizedBox(height: 16),
                  ],

                  // KPI Summary Cards Grid
                  _buildKpiGrid(context, result),
                  const SizedBox(height: 20),

                  // Route Visualizer Canvas Card
                  _buildRouteVisualizerCard(context, result),
                  const SizedBox(height: 20),

                  // Daily Travel Timeline Breakdown (Immediately below Route Visualization)
                  _buildTimelineBreakdown(context, result),
                  const SizedBox(height: 20),

                  // Gap Breakdown Table (Fixed height & scrollable)
                  _buildGapBreakdownTable(context, result),
                  const SizedBox(height: 20),

                  // Download / Export Options
                  _buildExportOptionsCard(context, result),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, TrackingProvider tracking) {
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
              child: const Icon(Icons.route_rounded, size: 48, color: Color(0xFF38BDF8)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Journey Analysis Report Available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Start tracking and tap Stop Tracking to automatically generate journey metrics and gap analysis.',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Analyze Current SQLite Data', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                await tracking.runJourneyAnalysis();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiGrid(BuildContext context, JourneyAnalysisResult result) {
    final double gpsKm = result.totalGpsDistanceMeters / 1000.0;
    final double roadKm = result.correctedRoadDistanceMeters / 1000.0;
    final String workHours = _formatDuration(result.workingHoursSeconds);
    final String travelTime = _formatDuration(result.travelTimeSeconds);
    final String idleTime = _formatDuration(result.idleTimeSeconds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Journey Metrics & KPIs',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                'Calculated GPS Distance',
                '${gpsKm.toStringAsFixed(2)} km',
                'Raw sum of GPS fixes',
                Icons.gps_fixed_rounded,
                const Color(0xFF38BDF8),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                'Corrected Road Distance',
                '${roadKm.toStringAsFixed(2)} km',
                'After gap & drift correction',
                Icons.alt_route_rounded,
                const Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                'Working Hours',
                workHours,
                'Travel: $travelTime • Idle: $idleTime',
                Icons.timer_outlined,
                const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                'GPS Quality Score',
                '${result.gpsQualityScore.toStringAsFixed(0)}%',
                'Points: ${result.totalGpsPoints}',
                Icons.verified_outlined,
                result.gpsQualityScore >= 80 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                'Travel Confidence',
                '${result.travelConfidencePercentage.toStringAsFixed(0)}%',
                'Quality: ${result.gpsQualityLabel} (${result.driftPointsRemovedCount} Drifts Filtered)',
                Icons.verified_user_rounded,
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                'Stops & Visits',
                '${result.numberOfStops} Stops',
                'Gaps: ${result.numberOfMissingGaps} (${result.numberOfCorrectedGaps} Corrected)',
                Icons.pause_circle_outline_rounded,
                const Color(0xFFA855F7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String mainValue, String subText, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mainValue,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subText,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRouteVisualizerCard(BuildContext context, JourneyAnalysisResult result) {
    // Extract points for FlutterMap
    final List<ll.LatLng> allFixes = [];
    final List<Polyline> polylines = [];
    final List<Marker> markers = [];

    for (var seg in result.segments) {
      final p1 = ll.LatLng(seg.startPoint.latitude, seg.startPoint.longitude);
      final p2 = ll.LatLng(seg.endPoint.latitude, seg.endPoint.longitude);
      allFixes.add(p1);
      allFixes.add(p2);

      final segPoints = seg.polylinePoints.map((p) => ll.LatLng(p.latitude, p.longitude)).toList();
      if (segPoints.isNotEmpty && seg.caseType != GapCaseType.stationary && seg.caseType != GapCaseType.gpsDrift) {
        if (seg.caseType == GapCaseType.gapCorrected) {
          polylines.add(
            Polyline(
              points: segPoints,
              color: const Color(0xFFF97316), // Orange for API corrected
              strokeWidth: 4.5,
            ),
          );
        } else {
          polylines.add(
            Polyline(
              points: segPoints,
              color: const Color(0xFF38BDF8), // Blue for raw GPS
              strokeWidth: 3.5,
            ),
          );
        }
      }
    }

    final ll.LatLng center = allFixes.isNotEmpty
        ? allFixes.first
        : const ll.LatLng(12.9716, 77.5946);

    if (polylines.isNotEmpty) {
      // Start Marker (Green)
      markers.add(
        Marker(
          point: allFixes.first,
          width: 32,
          height: 32,
          child: Container(
            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
          ),
        ),
      );

      // End Marker (Red)
      markers.add(
        Marker(
          point: allFixes.last,
          width: 32,
          height: 32,
          child: Container(
            decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
            child: const Icon(Icons.stop_rounded, color: Colors.white, size: 18),
          ),
        ),
      );
    } else if (allFixes.isNotEmpty) {
      // Stationary Marker (Orange Pause/Location Pin)
      markers.add(
        Marker(
          point: center,
          width: 42,
          height: 42,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF59E0B), width: 2),
            ),
            child: const Icon(Icons.pause_circle_filled_rounded, color: Color(0xFFF59E0B), size: 24),
          ),
        ),
      );
    }

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
                'Journey Route Visualization',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Icon(Icons.map_rounded, color: Color(0xFF38BDF8), size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: allFixes.isEmpty
                  ? const Center(
                      child: Text('No GPS route points to visualize on map.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    )
                  : FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 15.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.locationpoc.app',
                        ),
                        PolylineLayer(polylines: polylines),
                        MarkerLayer(markers: markers),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Map Color Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem('Actual GPS Route', const Color(0xFF38BDF8)),
              _buildLegendItem('Routes API Corrected', const Color(0xFFF97316)),
              _buildLegendItem('Start 🟢', const Color(0xFF10B981)),
              _buildLegendItem('End 🔴', const Color(0xFFEF4444)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFFCBD5E1))),
      ],
    );
  }

  void _showGapSummaryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text('Gap Engine Logic Rules', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCaseLogicRow('Case 1: Normal Tracking', 'Time Gap ≤ 2m', const Color(0xFF38BDF8)),
            _buildCaseLogicRow('Case 2: Stationary (Shop/Lunch)', 'Gap > 2m & Dist < 150m (No API call)', const Color(0xFFF1F5F9)),
            _buildCaseLogicRow('Case 3: Missing Travel (API Corrected)', 'Gap > 2m & Dist > 300m (Routes API)', const Color(0xFFF97316)),
            _buildCaseLogicRow('Case 4: GPS Drift', 'Road Dist < Straight Dist (Ignored movement)', const Color(0xFFA855F7)),
            _buildCaseLogicRow('Case 5: No Route Found', 'Routes API fallback to raw GPS', const Color(0xFF64748B)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseLogicRow(String title, String condition, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 8),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              condition,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGapBreakdownTable(BuildContext context, JourneyAnalysisResult result) {
    final segments = result.segments;

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
                'Gap Detection Table',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                '${segments.length} Segments Analyzed',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (segments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No segment gaps detected.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ),
            )
          else
            SizedBox(
              height: 260,
              child: RawScrollbar(
                thumbColor: const Color(0xFF38BDF8),
                radius: const Radius.circular(4),
                thickness: 4,
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: segments.length,
                  separatorBuilder: (context, index) => const Divider(color: Color(0xFF334155), height: 1),
                  itemBuilder: (context, index) {
                    final seg = segments[index];
                    Color caseColor = const Color(0xFF38BDF8);

                    switch (seg.caseType) {
                      case GapCaseType.normal:
                        caseColor = const Color(0xFF38BDF8);
                        break;
                      case GapCaseType.stationary:
                        caseColor = const Color(0xFFE2E8F0);
                        break;
                      case GapCaseType.gapCorrected:
                        caseColor = const Color(0xFFF97316);
                        break;
                      case GapCaseType.gpsDrift:
                        caseColor = const Color(0xFFA855F7);
                        break;
                      case GapCaseType.noRouteFound:
                        caseColor = const Color(0xFF64748B);
                        break;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'P${seg.startIndex + 1}',
                              style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  seg.caseType.title,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: caseColor),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Gap: ${seg.timeGapSeconds}s • GPS: ${seg.straightDistanceMeters.toStringAsFixed(0)}m • Road: ${seg.roadDistanceMeters.toStringAsFixed(0)}m',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                ),
                                Text(
                                  seg.statusNotes,
                                  style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineBreakdown(BuildContext context, JourneyAnalysisResult result) {
    final segments = result.segments;

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
          const Text(
            'Daily Travel Timeline Summary',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.circle, color: Color(0xFF10B981), size: 12),
              const SizedBox(width: 8),
              Text(
                'Journey Started at ${_formatTime(result.startTime)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (segments.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(left: 5),
              padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0xFF334155), width: 2)),
              ),
              child: Text(
                '• Active Travel Duration: ${_formatDuration(result.travelTimeSeconds)}\n'
                '• Total Stationary / Idle Time: ${_formatDuration(result.idleTimeSeconds)}\n'
                '• Total Route Corrected Distance: ${(result.correctedRoadDistanceMeters / 1000).toStringAsFixed(2)} km',
                style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1), height: 1.5),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              const Icon(Icons.circle, color: Color(0xFFEF4444), size: 12),
              const SizedBox(width: 8),
              Text(
                'Journey Ended at ${_formatTime(result.endTime)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportOptionsCard(BuildContext context, JourneyAnalysisResult result) {
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
          const Text(
            'Export & Download Analysis Report',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.copy_all_rounded, size: 18),
                  label: const Text('Copy JSON Report', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: result.toJsonString()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Journey Analysis JSON copied to clipboard!'),
                        backgroundColor: Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Copy CSV Summary', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final csv = _generateCsv(result);
                    Clipboard.setData(ClipboardData(text: csv));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Journey CSV summary copied to clipboard!'),
                        backgroundColor: Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _generateCsv(JourneyAnalysisResult r) {
    final sb = StringBuffer();
    sb.writeln('Segment,Start_Time,End_Time,Case_Type,Time_Gap_Sec,Straight_Dist_Meters,Road_Dist_Meters,Notes');
    for (var s in r.segments) {
      sb.writeln(
        '${s.startIndex + 1},${s.startPoint.timestamp},${s.endPoint.timestamp},${s.caseType.name},${s.timeGapSeconds},${s.straightDistanceMeters.toStringAsFixed(1)},${s.roadDistanceMeters.toStringAsFixed(1)},"${s.statusNotes}"',
      );
    }
    return sb.toString();
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60);
    final secs = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${mins}m ${secs}s';
    }
    return '${mins}m ${secs}s';
  }

  Widget _buildJourneySelectorBanner(
    BuildContext context,
    TrackingProvider tracking,
    JourneyAnalysisResult current,
    List<JourneyAnalysisResult> history,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: Color(0xFF10B981), size: 18),
          const SizedBox(width: 10),
          const Text('Select Journey: ', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: current.journeyId,
                dropdownColor: const Color(0xFF1F2937),
                isExpanded: true,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                items: history.map((j) {
                  final distKm = (j.correctedRoadDistanceMeters / 1000).toStringAsFixed(1);
                  return DropdownMenuItem<String>(
                    value: j.journeyId,
                    child: Text(
                      '${j.journeyId} (${distKm}km)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (selectedId) {
                  if (selectedId != null) {
                    final found = history.firstWhere((element) => element.journeyId == selectedId);
                    tracking.selectJourney(found);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      return DateFormat('HH:mm:ss (dd MMM yyyy)').format(dt);
    } catch (_) {
      return isoTime;
    }
  }
}

/// Custom Canvas Painter to render the interactive Journey Route (Blue: actual GPS, Orange: API corrected)
class RouteCanvasPainter extends CustomPainter {
  final List<JourneySegment> segments;

  RouteCanvasPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'No GPS route points to visualize.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));
      return;
    }

    // Collect all points to compute bounding box
    final List<LatLngPoint> allPoints = [];
    for (var seg in segments) {
      allPoints.addAll(seg.polylinePoints);
    }

    if (allPoints.isEmpty) return;

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (var p in allPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final double latSpan = (maxLat - minLat).abs() == 0 ? 0.001 : (maxLat - minLat).abs();
    final double lngSpan = (maxLng - minLng).abs() == 0 ? 0.001 : (maxLng - minLng).abs();

    const double padding = 24.0;
    final double widthFactor = (size.width - 2 * padding) / lngSpan;
    final double heightFactor = (size.height - 2 * padding) / latSpan;

    Offset toOffset(LatLngPoint pt) {
      final x = padding + (pt.longitude - minLng) * widthFactor;
      final y = size.height - (padding + (pt.latitude - minLat) * heightFactor); // Invert Y
      return Offset(x, y);
    }

    final gpsPaint = Paint()
      ..color = const Color(0xFF38BDF8) // Blue for raw GPS
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final correctedPaint = Paint()
      ..color = const Color(0xFFF97316) // Orange for Routes API corrected
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final driftPaint = Paint()
      ..color = const Color(0xFFA855F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (var seg in segments) {
      if (seg.polylinePoints.length < 2) continue;

      final path = Path();
      final startOffset = toOffset(seg.polylinePoints.first);
      path.moveTo(startOffset.dx, startOffset.dy);

      for (int i = 1; i < seg.polylinePoints.length; i++) {
        final pt = toOffset(seg.polylinePoints[i]);
        path.lineTo(pt.dx, pt.dy);
      }

      if (seg.caseType == GapCaseType.gapCorrected) {
        canvas.drawPath(path, correctedPaint);
      } else if (seg.caseType == GapCaseType.gpsDrift) {
        canvas.drawPath(path, driftPaint);
      } else {
        canvas.drawPath(path, gpsPaint);
      }
    }

    // Draw Start (Green) & End (Red) Markers
    final startPt = toOffset(segments.first.polylinePoints.first);
    final endPt = toOffset(segments.last.polylinePoints.last);

    canvas.drawCircle(startPt, 6, Paint()..color = const Color(0xFF10B981));
    canvas.drawCircle(startPt, 3, Paint()..color = Colors.white);

    canvas.drawCircle(endPt, 6, Paint()..color = const Color(0xFFEF4444));
    canvas.drawCircle(endPt, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

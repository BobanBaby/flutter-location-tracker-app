import 'dart:math';
import '../models/gps_log.dart';
import '../models/journey_model.dart';
import '../models/user_device_model.dart';
import 'google_routes_service.dart';
import 'user_device_service.dart';

class JourneyAnalysisEngine {
  /// Calculate Haversine distance between two coordinates in meters
  static double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  static double _toRadians(double degree) => degree * (pi / 180.0);

  /// Analyze raw GPS points and return a comprehensive JourneyAnalysisResult
  static Future<JourneyAnalysisResult> analyzeJourney(
    List<GpsLog> rawLogs, {
    String? targetJourneyId,
    bool ignoreLowConfidence = true,
  }) async {
    final String effectiveJourneyId = targetJourneyId ??
        (rawLogs.isNotEmpty && rawLogs.first.journeyId.isNotEmpty
            ? rawLogs.first.journeyId
            : 'JRN_${DateTime.now().millisecondsSinceEpoch}');

    if (rawLogs.isEmpty) {
      return JourneyAnalysisResult(
        journeyId: effectiveJourneyId,
        startTime: DateTime.now().toIso8601String(),
        endTime: DateTime.now().toIso8601String(),
        totalGpsDistanceMeters: 0,
        correctedRoadDistanceMeters: 0,
        workingHoursSeconds: 0,
        travelTimeSeconds: 0,
        idleTimeSeconds: 0,
        numberOfStops: 0,
        totalGpsPoints: 0,
        numberOfMissingGaps: 0,
        numberOfCorrectedGaps: 0,
        averageSpeedKmH: 0,
        maxSpeedKmH: 0,
        gpsQualityScore: 100.0,
        segments: [],
      );
    }

    // Step 1: Sort by timestamp ascending
    final List<GpsLog> sorted = List.from(rawLogs);
    sorted.sort((a, b) {
      final tA = DateTime.tryParse(a.timestamp) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tB = DateTime.tryParse(b.timestamp) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tA.compareTo(tB);
    });

    final String startTime = sorted.first.timestamp;
    final String endTime = sorted.last.timestamp;

    final startDt = DateTime.tryParse(startTime) ?? DateTime.now();
    final endDt = DateTime.tryParse(endTime) ?? DateTime.now();
    final int workingHoursSeconds = endDt.difference(startDt).inSeconds.clamp(0, 864000);

    // PASS 1: Pre-Filtering & GPS Stabilization (Cold Start Warm-Up Lock Filter)
    // ---------------------------------------------------------------------------
    final List<GpsLog> validPoints = [];
    int initialFilteredCount = 0;

    for (int i = 0; i < sorted.length; i++) {
      final p = sorted[i];

      // 1. Drop gross invalid points (Accuracy > 100m)
      if (p.accuracy > 100.0) {
        initialFilteredCount++;
        continue;
      }

      // 2. Rule 1: GPS Stabilization (Warm-Up Lock Filter)
      // If point[i] has Accuracy > 50m AND next point[i+1] within 30s has Accuracy < 20m,
      // treat point[i] as a GPS warm-up fix and discard it.
      if (i < sorted.length - 1) {
        final nextP = sorted[i + 1];
        final tCurr = DateTime.tryParse(p.timestamp) ?? startDt;
        final tNext = DateTime.tryParse(nextP.timestamp) ?? endDt;
        final gapSec = tNext.difference(tCurr).inSeconds.abs();

        if (p.accuracy > 50.0 && nextP.accuracy < 20.0 && gapSec <= 30) {
          initialFilteredCount++;
          continue;
        }
      }

      validPoints.add(p);
    }

    final List<GpsLog> pointsToProcess = validPoints.isNotEmpty ? validPoints : sorted;

    double totalGpsDistanceMeters = 0;
    double correctedRoadDistanceMeters = 0;
    int travelTimeSeconds = 0;
    int idleTimeSeconds = 0;
    int numberOfStops = 0;
    int numberOfMissingGaps = 0;
    int numberOfCorrectedGaps = 0;
    int driftPointsRemovedCount = initialFilteredCount;
    double maxSpeedMps = 0;
    double accumulatedConfidenceSum = 0.0;

    final List<JourneySegment> segments = [];
    final List<JourneyStop> stopsList = [];

    // PASS 2 & 3: Gap Detection, Stationary Radius Clustering & Gated Routes API
    // ---------------------------------------------------------------------------
    for (int i = 0; i < pointsToProcess.length - 1; i++) {
      final p1 = pointsToProcess[i];
      final p2 = pointsToProcess[i + 1];

      if (p1.speed > maxSpeedMps) maxSpeedMps = p1.speed;
      if (p2.speed > maxSpeedMps) maxSpeedMps = p2.speed;

      final dt1 = DateTime.tryParse(p1.timestamp) ?? startDt;
      final dt2 = DateTime.tryParse(p2.timestamp) ?? endDt;
      final int timeGapSeconds = dt2.difference(dt1).inSeconds.clamp(0, 864000);

      final double straightDist = haversineDistance(
        p1.latitude, p1.longitude, p2.latitude, p2.longitude,
      );
      totalGpsDistanceMeters += straightDist;
      accumulatedConfidenceSum += p1.confidenceScore;

      GapCaseType caseType;
      double roadDist = straightDist;
      List<LatLngPoint> polyline = [
        LatLngPoint(p1.latitude, p1.longitude),
        LatLngPoint(p2.latitude, p2.longitude),
      ];
      String statusNotes = '';

      final double calculatedSpeedMps = timeGapSeconds > 0 ? straightDist / timeGapSeconds : 0.0;

      // Accuracy Tier Low-Confidence Filter (Accuracy > 50m ignored when enabled)
      final bool isLowConfidenceReading = ignoreLowConfidence && (p1.accuracy > 50.0 || p2.accuracy > 50.0);

      // Stationary Radius Clustering (< 4.0 meters OR speed < 0.6 m/s / 2.1 km/h)
      final bool isStationaryJitter = straightDist < 4.0 || calculatedSpeedMps < 0.6;

      if (isStationaryJitter || isLowConfidenceReading) {
        driftPointsRemovedCount++;
      }

      // Stop & Visit Detection Engine (Activity == Still AND Speed < 1 km/h AND Stayed > 5 minutes)
      final bool isStillActivity = p1.activity == 'Still' && p2.activity == 'Still';
      final bool isLowSpeedStop = (p1.speed * 3.6) < 1.0 && (p2.speed * 3.6) < 1.0;
      if (timeGapSeconds >= 300 && (isStillActivity || isLowSpeedStop)) {
        numberOfStops++;
        final String stopLabel = timeGapSeconds >= 1800 ? 'Lunch Break / Prolonged Visit' : 'Client Visit / Office Stop';
        stopsList.add(JourneyStop(
          location: LatLngPoint(p1.latitude, p1.longitude),
          startTime: p1.timestamp,
          endTime: p2.timestamp,
          durationSeconds: timeGapSeconds,
          label: stopLabel,
        ));
      }

      if (isLowConfidenceReading) {
        caseType = GapCaseType.gpsDrift;
        roadDist = 0;
        polyline = [];
        idleTimeSeconds += timeGapSeconds;
        statusNotes = 'Low Confidence GPS fix ignored (Accuracy > 50m: ${max(p1.accuracy, p2.accuracy).toStringAsFixed(1)}m)';
      } else if (timeGapSeconds <= 120) {
        // Case 1 – Normal Tracking
        if (isStationaryJitter) {
          caseType = GapCaseType.stationary;
          roadDist = 0;
          polyline = [];
          idleTimeSeconds += timeGapSeconds;
          statusNotes = 'Stationary GPS noise / Desk idle (${straightDist.toStringAsFixed(1)}m jitter)';
        } else {
          caseType = GapCaseType.normal;
          roadDist = straightDist;
          polyline = [
            LatLngPoint(p1.latitude, p1.longitude),
            LatLngPoint(p2.latitude, p2.longitude),
          ];
          travelTimeSeconds += timeGapSeconds;
          correctedRoadDistanceMeters += roadDist;
          statusNotes = 'Normal GPS tracking within threshold (${timeGapSeconds}s gap)';
        }
      } else {
        // Time Gap > 2 minutes
        numberOfMissingGaps++;

        if (straightDist < 150) {
          // Case 2 – Stationary (Time Gap > 2 min & Movement < 150 meters)
          caseType = GapCaseType.stationary;
          roadDist = 0;
          polyline = [];
          idleTimeSeconds += timeGapSeconds;
          statusNotes = 'Stationary gap (${(timeGapSeconds / 60).toStringAsFixed(1)} min stop, shop/lunch/drift)';
        } else if (straightDist > 300 && (p1.activity == 'Driving' || p2.activity == 'Driving')) {
          // Case 3 – Gated Google Routes API Execution (Gap > 2m AND Movement > 300m AND Activity = Driving)
          final p1Point = LatLngPoint(p1.latitude, p1.longitude);
          final p2Point = LatLngPoint(p2.latitude, p2.longitude);

          final routeResult = await GoogleRoutesService.instance.fetchRoute(p1Point, p2Point);

          if (routeResult != null && routeResult.status == 'OK') {
            // Check Case 4 – GPS Drift
            if (routeResult.distanceMeters < 50 && straightDist > 120) {
              caseType = GapCaseType.gpsDrift;
              roadDist = 0;
              polyline = [];
              idleTimeSeconds += timeGapSeconds;
              statusNotes = 'GPS Drift detected! (GPS=${straightDist.toStringAsFixed(0)}m, Route=${routeResult.distanceMeters.toStringAsFixed(0)}m)';
            } else {
              // Valid Gap Corrected via Routes API
              caseType = GapCaseType.gapCorrected;
              roadDist = routeResult.distanceMeters;
              polyline = routeResult.polyline;
              travelTimeSeconds += timeGapSeconds;
              correctedRoadDistanceMeters += roadDist;
              numberOfCorrectedGaps++;
              statusNotes = 'Gap Corrected via Google Routes API (${roadDist.toStringAsFixed(0)}m road dist)';
            }
          } else {
            // Case 5 – No Route Found
            caseType = GapCaseType.noRouteFound;
            roadDist = straightDist;
            polyline = [
              LatLngPoint(p1.latitude, p1.longitude),
              LatLngPoint(p2.latitude, p2.longitude),
            ];
            travelTimeSeconds += timeGapSeconds;
            correctedRoadDistanceMeters += roadDist;
            statusNotes = 'Google Routes API unavailable. Used GPS distance (${straightDist.toStringAsFixed(0)}m)';
          }
        } else {
          // Normal movement gap
          caseType = GapCaseType.normal;
          roadDist = straightDist;
          polyline = [
            LatLngPoint(p1.latitude, p1.longitude),
            LatLngPoint(p2.latitude, p2.longitude),
          ];
          travelTimeSeconds += timeGapSeconds;
          correctedRoadDistanceMeters += roadDist;
          statusNotes = 'Movement gap (${timeGapSeconds}s, ${straightDist.toStringAsFixed(0)}m)';
        }
      }

      segments.add(JourneySegment(
        startIndex: i,
        endIndex: i + 1,
        startPoint: p1,
        endPoint: p2,
        timeGapSeconds: timeGapSeconds,
        straightDistanceMeters: straightDist,
        roadDistanceMeters: roadDist,
        caseType: caseType,
        polylinePoints: polyline,
        statusNotes: statusNotes,
      ));
    }

    final double avgSpeedKmH = travelTimeSeconds > 0
        ? (correctedRoadDistanceMeters / travelTimeSeconds) * 3.6
        : 0.0;
    final double maxSpeedKmH = maxSpeedMps * 3.6;

    // Calculate Travel Confidence % and GPS Quality Label
    final double avgConfidenceScore = sorted.isNotEmpty ? accumulatedConfidenceSum / sorted.length : 100.0;
    final double qualityScore = segments.isEmpty
        ? 100.0
        : ((segments.where((s) => s.caseType == GapCaseType.normal || s.caseType == GapCaseType.gapCorrected).length) /
                segments.length) *
            100.0;

    String qualityLabel = 'Excellent';
    if (avgConfidenceScore < 60) {
      qualityLabel = 'Low Confidence';
    } else if (avgConfidenceScore < 80) {
      qualityLabel = 'Fair';
    } else if (avgConfidenceScore < 90) {
      qualityLabel = 'Good';
    }

    final profile = sorted.isNotEmpty
        ? UserDeviceProfile(
            userId: sorted.first.userId,
            userName: sorted.first.userName,
            userEmail: '',
            deviceId: sorted.first.deviceId,
            deviceModel: sorted.first.deviceModel,
            osVersion: '',
          )
        : UserDeviceService.instance.currentProfile;

    return JourneyAnalysisResult(
      journeyId: effectiveJourneyId,
      userId: profile.userId,
      userName: profile.userName,
      deviceId: profile.deviceId,
      deviceModel: profile.deviceModel,
      startTime: startTime,
      endTime: endTime,
      totalGpsDistanceMeters: totalGpsDistanceMeters,
      correctedRoadDistanceMeters: correctedRoadDistanceMeters,
      workingHoursSeconds: workingHoursSeconds,
      travelTimeSeconds: travelTimeSeconds,
      idleTimeSeconds: idleTimeSeconds,
      numberOfStops: numberOfStops,
      totalGpsPoints: sorted.length,
      numberOfMissingGaps: numberOfMissingGaps,
      numberOfCorrectedGaps: numberOfCorrectedGaps,
      averageSpeedKmH: avgSpeedKmH,
      maxSpeedKmH: maxSpeedKmH,
      gpsQualityScore: qualityScore,
      travelConfidencePercentage: avgConfidenceScore,
      gpsQualityLabel: qualityLabel,
      correctedSegmentsCount: numberOfCorrectedGaps,
      driftPointsRemovedCount: driftPointsRemovedCount,
      stopsList: stopsList,
      segments: segments,
    );
  }
}

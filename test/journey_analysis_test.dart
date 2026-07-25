import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/gps_log.dart';
import 'package:app/models/journey_model.dart';
import 'package:app/services/journey_analysis_engine.dart';

void main() {
  group('Journey Analysis Engine Tests', () {
    test('Case 1: Normal tracking when gap <= 2 minutes', () async {
      final now = DateTime.now();
      final logs = [
        GpsLog(
          timestamp: now.toIso8601String(),
          latitude: 12.9716,
          longitude: 77.5946,
          accuracy: 5.0,
          speed: 10.0,
          bearing: 0.0,
          altitude: 900.0,
          activity: 'Driving',
          batteryLevel: 95,
          provider: 'Fused',
        ),
        GpsLog(
          timestamp: now.add(const Duration(seconds: 60)).toIso8601String(),
          latitude: 12.9720,
          longitude: 77.5950,
          accuracy: 5.0,
          speed: 10.0,
          bearing: 0.0,
          altitude: 900.0,
          activity: 'Driving',
          batteryLevel: 94,
          provider: 'Fused',
        ),
      ];

      final result = await JourneyAnalysisEngine.analyzeJourney(logs);

      expect(result.totalGpsPoints, 2);
      expect(result.segments.length, 1);
      expect(result.segments.first.caseType, GapCaseType.normal);
      expect(result.numberOfMissingGaps, 0);
    });

    test('Case 2: Stationary classification when gap > 2 minutes and movement < 150m', () async {
      final now = DateTime.now();
      final logs = [
        GpsLog(
          timestamp: now.toIso8601String(),
          latitude: 12.9716,
          longitude: 77.5946,
          accuracy: 5.0,
          speed: 0.0,
          bearing: 0.0,
          altitude: 900.0,
          activity: 'Still',
          batteryLevel: 90,
          provider: 'Fused',
        ),
        GpsLog(
          timestamp: now.add(const Duration(minutes: 5)).toIso8601String(),
          latitude: 12.9718, // ~25 meters movement
          longitude: 77.5947,
          accuracy: 5.0,
          speed: 0.0,
          bearing: 0.0,
          altitude: 900.0,
          activity: 'Still',
          batteryLevel: 89,
          provider: 'Fused',
        ),
      ];

      final result = await JourneyAnalysisEngine.analyzeJourney(logs);

      expect(result.segments.length, 1);
      expect(result.segments.first.caseType, GapCaseType.stationary);
      expect(result.numberOfStops, 1);
      expect(result.numberOfMissingGaps, 1);
    });

    test('Haversine formula calculation test', () {
      // Distance between Bangalore MG Road and Indiranagar (~3.5-4.0 km)
      final distMeters = JourneyAnalysisEngine.haversineDistance(
        12.9756, 77.6066,
        12.9784, 77.6408,
      );

      expect(distMeters, greaterThan(3500));
      expect(distMeters, lessThan(4200));
    });
  });
}

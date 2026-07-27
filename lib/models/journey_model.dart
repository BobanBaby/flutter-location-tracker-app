import 'dart:convert';
import 'gps_log.dart';

class LatLngPoint {
  final double latitude;
  final double longitude;

  const LatLngPoint(this.latitude, this.longitude);

  Map<String, dynamic> toMap() => {'lat': latitude, 'lng': longitude};

  factory LatLngPoint.fromMap(Map<String, dynamic> map) {
    return LatLngPoint(
      (map['lat'] as num).toDouble(),
      (map['lng'] as num).toDouble(),
    );
  }
}

enum GapCaseType {
  normal('Case 1: Normal Tracking', 'Normal GPS tracking within threshold'),
  stationary('Case 2: Stationary', 'Time gap > 2m & movement < 150m (Shop/Lunch/Drift)'),
  gapCorrected('Case 3: Gap Corrected', 'Missing travel filled via Google Routes API'),
  gpsDrift('Case 4: GPS Drift', 'Straight distance invalid, marked stationary'),
  noRouteFound('Case 5: No Route Found', 'Google Routes API route unavailable, using GPS');

  final String title;
  final String description;
  const GapCaseType(this.title, this.description);
}

class JourneySegment {
  final int startIndex;
  final int endIndex;
  final GpsLog startPoint;
  final GpsLog endPoint;
  final int timeGapSeconds;
  final double straightDistanceMeters;
  final double roadDistanceMeters;
  final GapCaseType caseType;
  final List<LatLngPoint> polylinePoints;
  final String statusNotes;

  JourneySegment({
    required this.startIndex,
    required this.endIndex,
    required this.startPoint,
    required this.endPoint,
    required this.timeGapSeconds,
    required this.straightDistanceMeters,
    required this.roadDistanceMeters,
    required this.caseType,
    required this.polylinePoints,
    required this.statusNotes,
  });

  Map<String, dynamic> toMap() {
    return {
      'startIndex': startIndex,
      'endIndex': endIndex,
      'startPoint': startPoint.toMap(),
      'endPoint': endPoint.toMap(),
      'timeGapSeconds': timeGapSeconds,
      'straightDistanceMeters': straightDistanceMeters,
      'roadDistanceMeters': roadDistanceMeters,
      'caseType': caseType.name,
      'polylinePoints': polylinePoints.map((p) => p.toMap()).toList(),
      'statusNotes': statusNotes,
    };
  }

  factory JourneySegment.fromMap(Map<String, dynamic> map) {
    return JourneySegment(
      startIndex: map['startIndex'] as int,
      endIndex: map['endIndex'] as int,
      startPoint: GpsLog.fromMap(Map<String, dynamic>.from(map['startPoint'])),
      endPoint: GpsLog.fromMap(Map<String, dynamic>.from(map['endPoint'])),
      timeGapSeconds: map['timeGapSeconds'] as int,
      straightDistanceMeters: (map['straightDistanceMeters'] as num).toDouble(),
      roadDistanceMeters: (map['roadDistanceMeters'] as num).toDouble(),
      caseType: GapCaseType.values.firstWhere((e) => e.name == map['caseType']),
      polylinePoints: (map['polylinePoints'] as List)
          .map((e) => LatLngPoint.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      statusNotes: map['statusNotes'] as String,
    );
  }
}

class JourneyStop {
  final LatLngPoint location;
  final String startTime;
  final String endTime;
  final int durationSeconds;
  final String label;
  final String stopType; // 'ShopVisit', 'Break', 'AutoStop'
  final String clientName;
  final bool isAutoTriggered;
  final String note;

  JourneyStop({
    required this.location,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.label,
    this.stopType = 'AutoStop',
    this.clientName = '',
    this.isAutoTriggered = false,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'location': location.toMap(),
        'startTime': startTime,
        'endTime': endTime,
        'durationSeconds': durationSeconds,
        'label': label,
        'stopType': stopType,
        'clientName': clientName,
        'isAutoTriggered': isAutoTriggered,
        'note': note,
      };

  factory JourneyStop.fromMap(Map<String, dynamic> map) {
    return JourneyStop(
      location: LatLngPoint.fromMap(Map<String, dynamic>.from(map['location'])),
      startTime: map['startTime'] as String,
      endTime: map['endTime'] as String,
      durationSeconds: map['durationSeconds'] as int,
      label: map['label'] as String,
      stopType: (map['stopType'] as String?) ?? 'AutoStop',
      clientName: (map['clientName'] as String?) ?? '',
      isAutoTriggered: (map['isAutoTriggered'] as bool?) ?? false,
      note: (map['note'] as String?) ?? '',
    );
  }
}

class JourneyAnalysisResult {
  final String journeyId;
  final String userId;
  final String userName;
  final String deviceId;
  final String deviceModel;
  final String startTime;
  final String endTime;
  final double totalGpsDistanceMeters;
  final double correctedRoadDistanceMeters;
  final int workingHoursSeconds;
  final int travelTimeSeconds;
  final int idleTimeSeconds;
  final int numberOfStops;
  final int totalGpsPoints;
  final int numberOfMissingGaps;
  final int numberOfCorrectedGaps;
  final double averageSpeedKmH;
  final double maxSpeedKmH;
  final double gpsQualityScore; // 0 - 100%
  final double travelConfidencePercentage; // e.g. 94.5%
  final String gpsQualityLabel; // 'Excellent', 'Good', 'Fair'
  final int correctedSegmentsCount;
  final int driftPointsRemovedCount;
  final List<JourneyStop> stopsList;
  final List<JourneySegment> segments;

  JourneyAnalysisResult({
    required this.journeyId,
    this.userId = 'EMP_101',
    this.userName = 'Sales Representative',
    this.deviceId = 'DEV_UNKNOWN',
    this.deviceModel = 'Unknown Device',
    required this.startTime,
    required this.endTime,
    required this.totalGpsDistanceMeters,
    required this.correctedRoadDistanceMeters,
    required this.workingHoursSeconds,
    required this.travelTimeSeconds,
    required this.idleTimeSeconds,
    required this.numberOfStops,
    required this.totalGpsPoints,
    required this.numberOfMissingGaps,
    required this.numberOfCorrectedGaps,
    required this.averageSpeedKmH,
    required this.maxSpeedKmH,
    required this.gpsQualityScore,
    this.travelConfidencePercentage = 95.0,
    this.gpsQualityLabel = 'Excellent',
    this.correctedSegmentsCount = 0,
    this.driftPointsRemovedCount = 0,
    this.stopsList = const [],
    required this.segments,
  });

  Map<String, dynamic> toMap() {
    return {
      'journeyId': journeyId,
      'userId': userId,
      'userName': userName,
      'deviceId': deviceId,
      'deviceModel': deviceModel,
      'startTime': startTime,
      'endTime': endTime,
      'totalGpsDistanceMeters': totalGpsDistanceMeters,
      'correctedRoadDistanceMeters': correctedRoadDistanceMeters,
      'workingHoursSeconds': workingHoursSeconds,
      'travelTimeSeconds': travelTimeSeconds,
      'idleTimeSeconds': idleTimeSeconds,
      'numberOfStops': numberOfStops,
      'totalGpsPoints': totalGpsPoints,
      'numberOfMissingGaps': numberOfMissingGaps,
      'numberOfCorrectedGaps': numberOfCorrectedGaps,
      'averageSpeedKmH': averageSpeedKmH,
      'maxSpeedKmH': maxSpeedKmH,
      'gpsQualityScore': gpsQualityScore,
      'travelConfidencePercentage': travelConfidencePercentage,
      'gpsQualityLabel': gpsQualityLabel,
      'correctedSegmentsCount': correctedSegmentsCount,
      'driftPointsRemovedCount': driftPointsRemovedCount,
      'stopsList': stopsList.map((s) => s.toMap()).toList(),
      'segments': segments.map((s) => s.toMap()).toList(),
    };
  }

  factory JourneyAnalysisResult.fromMap(Map<String, dynamic> map) {
    return JourneyAnalysisResult(
      journeyId: map['journeyId'] as String,
      userId: (map['userId'] as String?) ?? 'EMP_101',
      userName: (map['userName'] as String?) ?? 'Sales Representative',
      deviceId: (map['deviceId'] as String?) ?? 'DEV_UNKNOWN',
      deviceModel: (map['deviceModel'] as String?) ?? 'Unknown Device',
      startTime: map['startTime'] as String,
      endTime: map['endTime'] as String,
      totalGpsDistanceMeters: (map['totalGpsDistanceMeters'] as num).toDouble(),
      correctedRoadDistanceMeters: (map['correctedRoadDistanceMeters'] as num).toDouble(),
      workingHoursSeconds: map['workingHoursSeconds'] as int,
      travelTimeSeconds: map['travelTimeSeconds'] as int,
      idleTimeSeconds: map['idleTimeSeconds'] as int,
      numberOfStops: map['numberOfStops'] as int,
      totalGpsPoints: map['totalGpsPoints'] as int,
      numberOfMissingGaps: map['numberOfMissingGaps'] as int,
      numberOfCorrectedGaps: map['numberOfCorrectedGaps'] as int,
      averageSpeedKmH: (map['averageSpeedKmH'] as num).toDouble(),
      maxSpeedKmH: (map['maxSpeedKmH'] as num).toDouble(),
      gpsQualityScore: (map['gpsQualityScore'] as num).toDouble(),
      travelConfidencePercentage: ((map['travelConfidencePercentage'] ?? 95.0) as num).toDouble(),
      gpsQualityLabel: (map['gpsQualityLabel'] as String?) ?? 'Excellent',
      correctedSegmentsCount: (map['correctedSegmentsCount'] as int?) ?? 0,
      driftPointsRemovedCount: (map['driftPointsRemovedCount'] as int?) ?? 0,
      stopsList: map['stopsList'] != null
          ? (map['stopsList'] as List)
              .map((e) => JourneyStop.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : [],
      segments: (map['segments'] as List)
          .map((e) => JourneySegment.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  String toJsonString() => json.encode(toMap());

  factory JourneyAnalysisResult.fromJsonString(String source) =>
      JourneyAnalysisResult.fromMap(json.decode(source));
}

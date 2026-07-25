import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/journey_model.dart';

class RouteResult {
  final double distanceMeters;
  final int durationSeconds;
  final List<LatLngPoint> polyline;
  final String status;

  RouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.polyline,
    required this.status,
  });
}

class GoogleRoutesService {
  static final GoogleRoutesService instance = GoogleRoutesService._init();
  GoogleRoutesService._init();

  static String get apiKey => ApiConfig.googleRoutesApiKey;

  /// Call Google Directions / Routes API to fetch road distance, duration & polyline
  Future<RouteResult?> fetchRoute(LatLngPoint origin, LatLngPoint destination) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&key=$apiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'] as String?;

        if (status == 'OK' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          final double distance = (leg['distance']['value'] as num).toDouble();
          final int duration = leg['duration']['value'] as int;
          final String overviewPolyline = route['overview_polyline']['points'] ?? '';

          final points = decodePolyline(overviewPolyline);

          return RouteResult(
            distanceMeters: distance,
            durationSeconds: duration,
            polyline: points.isNotEmpty ? points : [origin, destination],
            status: 'OK',
          );
        } else {
          print('Google Routes API status: $status');
          return RouteResult(
            distanceMeters: 0,
            durationSeconds: 0,
            polyline: [origin, destination],
            status: status ?? 'ZERO_RESULTS',
          );
        }
      }
    } catch (e) {
      print('Google Routes API error: $e');
    }

    return null;
  }

  /// Decode Google Encoded Polyline string into List of LatLngPoint
  static List<LatLngPoint> decodePolyline(String encoded) {
    List<LatLngPoint> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLngPoint(lat / 1E5, lng / 1E5));
    }
    return poly;
  }
}

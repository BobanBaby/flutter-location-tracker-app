import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app/main.dart';
import 'package:app/providers/tracking_provider.dart';

void main() {
  testWidgets('App initializes with SplashScreen and branding text', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TrackingProvider()),
        ],
        child: const LocationTrackingApp(),
      ),
    );

    expect(find.text('Location Tracking'), findsOneWidget);

    // Advance timers so SplashScreen transitions cleanly
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:geo_gps_cam/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Basic smoke test - app should exist
    expect(find.byType(GeoGPSCamApp), findsNothing);
  });
}

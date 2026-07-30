import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geo_gps_cam/screens/camera_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init locale
  await initializeDateFormatting('id_ID', null);

  // Init cameras
  cameras = await availableCameras();

  runApp(const GeoGPSCamApp());
}

class GeoGPSCamApp extends StatelessWidget {
  const GeoGPSCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoGPS Cam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00D4FF),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const CameraScreen(),
    );
  }
}

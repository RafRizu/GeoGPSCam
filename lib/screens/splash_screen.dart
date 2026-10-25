import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geo_gps_cam/services/auth_service.dart';
import 'package:geo_gps_cam/services/ad_service.dart';
import 'package:geo_gps_cam/screens/camera_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnim;
  late Animation<double> _pulseAnim;
  late Animation<Offset> _slideAnim;

  String _statusText = 'Memulai...';

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    _fadeController.forward();
    _slideController.forward();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Step 1: Initialize AdMob
    _setStatus('Menginisialisasi layanan...');
    await Future.delayed(const Duration(milliseconds: 600));
    await AdService().initialize();

    // Step 2: Try to restore session
    _setStatus('Memeriksa sesi login...');
    await Future.delayed(const Duration(milliseconds: 400));
    final user = await AuthService().restoreSession();

    if (user != null) {
      // User already signed in
      _setStatus('Selamat datang, ${user.displayName ?? user.email}!');

      if (!user.isAdFree) {
        // Preload ads for non-ad-free users
        AdService().loadInterstitialAd();
        AdService().loadRewardedAd();
      } else {
        AdService().disableAds();
      }

      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const CameraScreen(),
            transitionsBuilder: (_, anim, __, child) {
              return FadeTransition(opacity: anim, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } else {
      // Not signed in → go to login
      _setStatus('Silakan masuk untuk melanjutkan');
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  void _setStatus(String text) {
    if (mounted) setState(() => _statusText = text);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C1E),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Icon with pulse glow
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, child) => Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF00D4FF), Color(0xFF7B61FF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D4FF)
                              .withValues(alpha: _pulseAnim.value * 0.4),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // App Name
                Text(
                  'GeoGPS Cam',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 8),

                // Tagline
                Text(
                  'Capture with precision',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF00D4FF).withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 48),

                // Loading indicator
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: const Color(0xFF00D4FF).withValues(alpha: 0.8),
                  ),
                ),

                const SizedBox(height: 16),

                // Status text
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _statusText,
                    key: ValueKey(_statusText),
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

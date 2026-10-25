import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geo_gps_cam/models/location_data.dart';
import 'package:geo_gps_cam/screens/preview_screen.dart';
import 'package:geo_gps_cam/services/location_service.dart';
import 'package:geo_gps_cam/services/auth_service.dart';
import 'package:geo_gps_cam/services/ad_service.dart';
import 'package:geo_gps_cam/widgets/banner_ad_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _flashOn = false;
  double _zoomLevel = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 5.0;

  LocationDataModel? _locationData;
  bool _locationLoading = true;
  DateTime? _locationLastUpdated;
  Timer? _locationTimer;

  late AnimationController _captureAnimController;
  late AnimationController _pulseController;
  late Animation<double> _captureAnim;
  late Animation<double> _pulseAnim;

  final LocationService _locationService = LocationService();
  final AuthService _authService = AuthService();
  final AdService _adService = AdService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _captureAnimController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _captureAnim = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _captureAnimController, curve: Curves.easeInOut),
    );
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initPermissionsAndStart();
    if (_adService.shouldShowAds) {
      _adService.loadInterstitialAd();
      _adService.loadRewardedAd();
    }
  }

  /// Minta semua permission sekaligus lalu inisialisasi kamera & lokasi
  Future<void> _initPermissionsAndStart() async {
    await _requestPermissions();
    await _initCamera();
    await _fetchLocation();
    // Jadwalkan auto-update lokasi setiap 15 menit
    _locationTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _fetchLocation(),
    );
  }

  /// Tampilkan dialog permintaan akses permission
  Future<void> _requestPermissions() async {
    // Cek status permission saat ini
    final cameraStatus = await Permission.camera.status;
    final locationStatus = await Permission.location.status;
    final storageStatus = await Permission.photos.status;

    final needsRequest = cameraStatus.isDenied ||
        locationStatus.isDenied ||
        storageStatus.isDenied;

    if (!needsRequest || !mounted) {
      // Langsung request jika belum pernah ditanya
      await [Permission.camera, Permission.location, Permission.photos].request();
      return;
    }

    // Tampilkan dialog penjelasan sebelum meminta permission
    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: Color(0xFF00D4FF), size: 24),
            const SizedBox(width: 10),
            Text(
              'Izin Akses Diperlukan',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GeoGPS Cam memerlukan akses berikut agar bisa berfungsi dengan baik:',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            _buildPermissionItem(
              Icons.camera_alt_rounded,
              const Color(0xFF00D4FF),
              'Kamera',
              'Untuk mengambil foto dengan watermark GPS',
            ),
            const SizedBox(height: 10),
            _buildPermissionItem(
              Icons.location_on_rounded,
              const Color(0xFF34D399),
              'Lokasi',
              'Untuk menampilkan koordinat & alamat GPS pada foto',
            ),
            const SizedBox(height: 10),
            _buildPermissionItem(
              Icons.photo_library_rounded,
              const Color(0xFF7B61FF),
              'Foto & Media',
              'Untuk menyimpan foto hasil ke galeri',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Nanti',
              style: GoogleFonts.inter(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Izinkan',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (shouldRequest == true) {
      await [Permission.camera, Permission.location, Permission.photos].request();

      // Jika ada permission yang permanently denied, arahkan ke settings
      final cameraPermanent = await Permission.camera.isPermanentlyDenied;
      final locationPermanent = await Permission.location.isPermanentlyDenied;
      final storagePermanent = await Permission.photos.isPermanentlyDenied;

      if ((cameraPermanent || locationPermanent || storagePermanent) && mounted) {
        _showOpenSettingsDialog();
      }
    }
  }

  /// Dialog untuk membuka pengaturan aplikasi jika permission permanently denied
  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Akses Ditolak',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Beberapa izin akses ditolak secara permanen. Buka Pengaturan untuk mengaktifkan akses Kamera, Lokasi, dan Foto/Media secara manual.',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.inter(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: Text('Buka Pengaturan',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(
      IconData icon, Color color, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _initCamera() async {
    // Permission sudah diminta di _requestPermissions()
    if (cameras.isEmpty) return;

    final camera = cameras[_selectedCameraIndex];
    await _controller?.dispose();
    final controller = CameraController(
      camera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;

    try {
      await controller.initialize();
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  /// Fetch lokasi. [forceRefresh] true = manual (tombol), false = auto (cek cache 15 menit)
  Future<void> _fetchLocation({bool forceRefresh = false}) async {
    // Jika masih dalam cache dan bukan refresh manual, langsung gunakan cache
    if (!forceRefresh && _locationService.isCacheValid) {
      final cached = await _locationService.getCurrentLocation();
      if (mounted) setState(() => _locationData = cached);
      return;
    }

    setState(() => _locationLoading = true);
    final data = await _locationService.getCurrentLocation(
      forceRefresh: forceRefresh,
    );
    if (mounted) {
      setState(() {
        _locationData = data;
        _locationLoading = false;
        if (data != null) _locationLastUpdated = DateTime.now();
      });
    }
  }

  Future<void> _switchCamera() async {
    if (cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % cameras.length;
    setState(() => _isInitialized = false);
    await _controller?.dispose();
    await _initCamera();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    setState(() => _flashOn = !_flashOn);
    await _controller!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_isInitialized || _isCapturing) return;

    setState(() => _isCapturing = true);
    _captureAnimController.forward().then((_) {
      _captureAnimController.reverse();
    });

    try {
      final XFile file = await _controller!.takePicture();

      // Gunakan lokasi yang sudah di-cache (tidak perlu fetch ulang saat capture)
      _locationData ??= await _locationService.getCurrentLocation();
      final captureTime = DateTime.now();

      if (!mounted) return;

      // Navigate to preview
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => PreviewScreen(
            imagePath: file.path,
            locationData: _locationData,
            captureTime: captureTime,
          ),
          transitionsBuilder: (_, anim, __, child) {
            return FadeTransition(opacity: anim, child: child);
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil gambar: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _onZoomChanged(double value) async {
    if (_controller == null) return;
    final zoom = value.clamp(_minZoom, _maxZoom);
    setState(() => _zoomLevel = zoom);
    await _controller!.setZoomLevel(zoom);
  }

  void _showProfileMenu() {
    final user = _authService.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User avatar
            CircleAvatar(
              radius: 32,
              backgroundColor: const Color(0xFF00D4FF).withValues(alpha: 0.2),
              backgroundImage:
                  user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null
                  ? Text(
                      user.initials,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF00D4FF),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),

            const SizedBox(height: 12),

            Text(
              user.displayName ?? 'User',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              user.email,
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 8),

            // Ad-free badge
            if (user.isAdFree)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF7B61FF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '✨ Premium - Bebas Iklan',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            // Reward ad-free status
            if (!user.isAdFree && _adService.remainingRewardTime != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '🎁 Bebas iklan ${_adService.remainingRewardTime!.inMinutes} menit lagi',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF34D399),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            const SizedBox(height: 20),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),

            // Watch ad for reward (only for non-ad-free users)
            if (!user.isAdFree && _adService.shouldShowAds)
              _buildMenuTile(
                icon: Icons.card_giftcard_rounded,
                iconColor: const Color(0xFFFFD700),
                label: 'Tonton iklan untuk bebas iklan 30 menit',
                onTap: () {
                  Navigator.pop(context);
                  _showRewardedAd();
                },
              ),

            // Logout
            _buildMenuTile(
              icon: Icons.logout_rounded,
              iconColor: const Color(0xFFFF6B6B),
              label: 'Keluar',
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Future<void> _showRewardedAd() async {
    final shown = await _adService.showRewardedAd(
      onRewarded: () {
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Selamat! Bebas iklan selama 30 menit 🎉',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF34D399),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
    );

    if (!shown && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Iklan belum tersedia. Coba lagi nanti.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();
    _adService.dispose();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // Abaikan jika controller belum diinisialisasi
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    // Lepas hardware kamera saat aplikasi di background / terkunci untuk menghemat baterai
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      cameraController.dispose();
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _controller = null;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      // Inisialisasi ulang kamera saat user membuka aplikasi kembali
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    _controller?.dispose();
    _captureAnimController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          if (_isInitialized && _controller != null)
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
            ),

          // Gradient overlays
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.15, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // Top bar (pinned to top of screen)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildGlassButton(
                      icon: _flashOn ? Icons.flash_on : Icons.flash_off,
                      color: _flashOn ? Colors.yellow : Colors.white,
                      onTap: _toggleFlash,
                    ),
                    Text(
                      'GeoGPS Cam',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    // Profile button (replaces camera switch in top bar)
                    _buildProfileButton(),
                  ],
                ),
              ),
            ),
          ),

          // GPS Info card (floating above zoom slider)
          Positioned(
            bottom: _adService.shouldShowAds ? 225 : 175,
            left: 16,
            right: 16,
            child: _buildGPSInfoCard(),
          ),

          // Zoom slider (floating above bottom shutter controls)
          Positioned(
            bottom: _adService.shouldShowAds ? 165 : 115,
            left: 40,
            right: 40,
            child: _buildZoomSlider(),
          ),

          // Bottom control bar (shutter, gallery, switch camera pinned to bottom)
          Positioned(
            bottom: _adService.shouldShowAds ? 50 : 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: _buildBottomControls(),
            ),
          ),

          // Banner Ad at the very bottom
          if (_adService.shouldShowAds)
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: BannerAdWidget(),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileButton() {
    final user = _authService.currentUser;
    return GestureDetector(
      onTap: _showProfileMenu,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
            ),
          ],
          image: user?.photoUrl != null
              ? DecorationImage(
                  image: NetworkImage(user!.photoUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: user?.photoUrl == null
            ? Center(
                child: Text(
                  user?.initials ?? '?',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF00D4FF),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _buildGPSInfoCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00D4FF).withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D4FF).withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: _locationLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00D4FF),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Mengambil lokasi GPS...',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFF00D4FF),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _locationData?.address ?? 'Lokasi tidak tersedia',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Tombol refresh manual (force update)
                    GestureDetector(
                      onTap: () => _fetchLocation(forceRefresh: true),
                      child: Tooltip(
                        message: 'Perbarui lokasi sekarang',
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: Color(0xFF00D4FF),
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.my_location,
                      color: Color(0xFF7B61FF),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _locationData != null
                          ? 'Lat: ${_locationData!.latitude.toStringAsFixed(6)}  Lng: ${_locationData!.longitude.toStringAsFixed(6)}'
                          : 'Koordinat tidak tersedia',
                      style: GoogleFonts.robotoMono(
                        color: const Color(0xFF7B61FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (_locationData?.district != null && _locationData!.district!.isNotEmpty) ...[  
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_rounded,
                        color: Color(0xFF34D399),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _locationData!.district!,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF34D399),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                // Tampilkan waktu terakhir diperbarui
                if (_locationLastUpdated != null) ...[  
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        color: Colors.white38,
                        size: 10,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Diperbarui ${DateFormat('HH:mm').format(_locationLastUpdated!)} · auto tiap 15 mnt',
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildZoomSlider() {
    return Column(
      children: [
        Text(
          '${_zoomLevel.toStringAsFixed(1)}×',
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF00D4FF),
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            trackHeight: 3,
          ),
          child: Slider(
            min: _minZoom,
            max: _maxZoom,
            value: _zoomLevel,
            onChanged: _onZoomChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 4, 30, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Gallery hint
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(
              Icons.photo_library_outlined,
              color: Colors.white70,
              size: 24,
            ),
          ),

          // Capture button
          GestureDetector(
            onTap: _capturePhoto,
            child: ScaleTransition(
              scale: _captureAnim,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Container(
                  width: 80,
                  height: 80,
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
                            .withValues(alpha: _pulseAnim.value * 0.5),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: _isCapturing
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                ),
              ),
            ),
          ),

          // Switch camera
          GestureDetector(
            onTap: _switchCamera,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(
                Icons.flip_camera_ios_outlined,
                color: Colors.white70,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geo_gps_cam/models/location_data.dart';
import 'package:geo_gps_cam/screens/preview_screen.dart';
import 'package:geo_gps_cam/services/location_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin {
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

  late AnimationController _captureAnimController;
  late AnimationController _pulseController;
  late Animation<double> _captureAnim;
  late Animation<double> _pulseAnim;

  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
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

    _initCamera();
    _fetchLocation();
  }

  Future<void> _initCamera() async {
    await Permission.camera.request();
    if (cameras.isEmpty) return;

    final camera = cameras[_selectedCameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.ultraHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _fetchLocation() async {
    setState(() => _locationLoading = true);
    final data = await _locationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _locationData = data;
        _locationLoading = false;
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

      // Refresh location at capture time
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

  @override
  void dispose() {
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
                    _buildGlassButton(
                      icon: Icons.cameraswitch_rounded,
                      color: Colors.white,
                      onTap: _switchCamera,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // GPS Info card (floating above zoom slider)
          Positioned(
            bottom: 175,
            left: 16,
            right: 16,
            child: _buildGPSInfoCard(),
          ),

          // Zoom slider (floating above bottom shutter controls)
          Positioned(
            bottom: 115,
            left: 40,
            right: 40,
            child: _buildZoomSlider(),
          ),

          // Bottom control bar (shutter, gallery, switch camera pinned to bottom)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: _buildBottomControls(),
            ),
          ),
        ],
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
                    GestureDetector(
                      onTap: _fetchLocation,
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFF00D4FF),
                        size: 16,
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

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geo_gps_cam/models/location_data.dart';
import 'package:geo_gps_cam/services/watermark_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class PreviewScreen extends StatefulWidget {
  final String imagePath;
  final LocationDataModel? locationData;
  final DateTime captureTime;

  const PreviewScreen({
    super.key,
    required this.imagePath,
    required this.locationData,
    required this.captureTime,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with SingleTickerProviderStateMixin {
  bool _isSaving = false;
  bool _savedSuccess = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;
  Uint8List? _watermarkedBytes;
  bool _isProcessing = true;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();
    _processWatermark();
  }

  Future<void> _processWatermark() async {
    setState(() => _isProcessing = true);
    try {
      final bytes = await WatermarkService.addWatermark(
        imagePath: widget.imagePath,
        locationData: widget.locationData,
        captureTime: widget.captureTime,
      );
      if (mounted) {
        setState(() {
          _watermarkedBytes = bytes;
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('Watermark error: $e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // Request gallery permission
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        await Gal.requestAccess(toAlbum: true);
      }

      // Ensure watermark processing is complete
      _watermarkedBytes ??= await WatermarkService.addWatermark(
        imagePath: widget.imagePath,
        locationData: widget.locationData,
        captureTime: widget.captureTime,
      );

      final dir = await getTemporaryDirectory();
      final fileName =
          'GeoGPS_${DateFormat('yyyyMMdd_HHmmss').format(widget.captureTime)}.png';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(_watermarkedBytes!);

      // Save to gallery album
      await Gal.putImage(file.path, album: 'GeoGPS Cam');

      if (mounted) {
        setState(() {
          _isSaving = false;
          _savedSuccess = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Foto berhasil disimpan ke Galeri!'),
              ],
            ),
            backgroundColor: const Color(0xFF00C853),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } on GalException catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: ${e.type.name}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image with watermark overlay
          Positioned.fill(
            child: _isProcessing
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFF00D4FF),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Menambahkan watermark...',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : _watermarkedBytes != null
                    ? Image.memory(
                        _watermarkedBytes!,
                        fit: BoxFit.contain,
                      )
                    : Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.contain,
                      ),
          ),

          // Gradient overlay top & bottom
          Positioned.fill(
            child: IgnorePointer(
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
                    stops: const [0.0, 0.15, 0.65, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Top navigation bar (pinned to top)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Preview Foto',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom action bar (pinned to bottom)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnim,
              child: SafeArea(
                top: false,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildInfoRow(),
                      const SizedBox(height: 14),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.arrow_back_rounded,
                              label: 'Kembali',
                              isOutline: true,
                              onTap: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _buildActionButton(
                              icon: _savedSuccess
                                  ? Icons.check_circle_rounded
                                  : Icons.save_alt_rounded,
                              label: _isSaving
                                  ? 'Menyimpan...'
                                  : _savedSuccess
                                      ? 'Tersimpan!'
                                      : 'Simpan ke Galeri',
                              isOutline: false,
                              savedSuccess: _savedSuccess,
                              onTap: _isSaving ? null : _saveToGallery,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow() {
    final dateStr = DateFormat('dd MMM yyyy, HH:mm:ss').format(widget.captureTime);
    final latLngStr = widget.locationData != null
        ? '${widget.locationData!.latitude.toStringAsFixed(5)}, ${widget.locationData!.longitude.toStringAsFixed(5)}'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.access_time_rounded, color: Color(0xFF00D4FF), size: 14),
            const SizedBox(width: 4),
            Expanded(
              flex: 5,
              child: Text(
                dateStr,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (latLngStr != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.my_location, color: Color(0xFF7B61FF), size: 12),
              const SizedBox(width: 4),
              Expanded(
                flex: 6,
                child: Text(
                  latLngStr,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFF7B61FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on_rounded, color: Color(0xFFFF6B6B), size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.locationData?.address ?? 'Alamat tidak tersedia',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isOutline,
    VoidCallback? onTap,
    bool savedSuccess = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          gradient: isOutline
              ? null
              : savedSuccess
                  ? null
                  : const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFF00D4FF), Color(0xFF7B61FF)],
                    ),
          color: isOutline
              ? Colors.white24
              : savedSuccess
                  ? const Color(0xFF00C853)
                  : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isOutline || savedSuccess
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isSaving && label.contains('Menyimpan')
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: isOutline ? Colors.white70 : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

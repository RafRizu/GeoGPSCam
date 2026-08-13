import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geo_gps_cam/models/location_data.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class WatermarkService {
  /// Adds a professional, high-resolution GPS watermark panel directly onto the image.
  /// Returns the processed watermarked image as Uint8List PNG/JPEG bytes.
  static Future<Uint8List> addWatermark({
    required String imagePath,
    required LocationDataModel? locationData,
    required DateTime captureTime,
  }) async {
    // Initialize Indonesian date formatting
    await initializeDateFormatting('id_ID', null);

    // 1. Read source image file bytes
    final File file = File(imagePath);
    final Uint8List bytes = await file.readAsBytes();

    // 2. Decode image to ui.Image
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image originalImage = frameInfo.image;

    final double imgWidth = originalImage.width.toDouble();
    final double imgHeight = originalImage.height.toDouble();

    // 3. Setup canvas at native photo resolution
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    // 4. Draw original photo background
    canvas.drawImage(originalImage, Offset.zero, Paint());

    // 5. Calculate card dimensions scaled to photo resolution
    final double margin = imgWidth * 0.03;
    final double cardWidth = imgWidth - (margin * 2);
    final double cardHeight = (imgHeight * 0.13).clamp(160.0, 420.0);
    final double cardX = margin;
    final double cardY = imgHeight - cardHeight - margin;
    final double cornerRadius = cardHeight * 0.08;

    final RRect cardRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardX, cardY, cardWidth, cardHeight),
      Radius.circular(cornerRadius),
    );

    // 6. Draw semi-transparent dark card background
    final Paint bgPaint = Paint()
      ..color = const Color(0xEA0F172A) // 92% opacity dark slate
      ..style = PaintingStyle.fill;
    canvas.drawRRect(cardRRect, bgPaint);

    // 7. Draw cyan border outline
    final Paint borderPaint = Paint()
      ..color = const Color(0x8800D4FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (cardHeight * 0.015).clamp(2.0, 6.0);
    canvas.drawRRect(cardRRect, borderPaint);

    // 8. Draw left accent bar
    final double accentWidth = cardWidth * 0.012;
    final RRect accentRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardX, cardY, accentWidth, cardHeight),
      Radius.circular(cornerRadius),
    );
    final Paint accentPaint = Paint()
      ..color = const Color(0xFF00D4FF)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(accentRRect, accentPaint);

    // 9. Format watermark text strings
    final String timeStr = DateFormat('HH:mm:ss').format(captureTime);
    final String dateStr = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(captureTime);
    final String latStr = locationData != null
        ? 'LAT: ${locationData.latitude.toStringAsFixed(6)}°'
        : 'LAT: --';
    final String lngStr = locationData != null
        ? 'LNG: ${locationData.longitude.toStringAsFixed(6)}°'
        : 'LNG: --';

    // Format hierarki lokasi (3 item pertama di baris 1 menyamping, item ke-4 dst di baris 2 menyamping):
    final List<String> locHierarchy = [];
    if (locationData != null) {
      if (locationData.country != null && locationData.country!.isNotEmpty) {
        locHierarchy.add('Negara: ${locationData.country}');
      }
      if (locationData.province != null && locationData.province!.isNotEmpty) {
        locHierarchy.add('Prov: ${locationData.province}');
      }
      if (locationData.regency != null && locationData.regency!.isNotEmpty) {
        locHierarchy.add('Kab/Kota: ${locationData.regency}');
      }
      if (locationData.district != null && locationData.district!.isNotEmpty) {
        locHierarchy.add('Kec: ${locationData.district}');
      }
      if (locationData.subDistrict != null && locationData.subDistrict!.isNotEmpty) {
        locHierarchy.add('Desa/Kel: ${locationData.subDistrict}');
      }
      if (locationData.street != null && locationData.street!.isNotEmpty) {
        locHierarchy.add('Jln/Blok: ${locationData.street}');
      }
    }

    String detailedLocationStr = '';
    if (locHierarchy.isNotEmpty) {
      if (locHierarchy.length <= 3) {
        detailedLocationStr = locHierarchy.join('  |  ');
      } else {
        final row1 = locHierarchy.sublist(0, 3).join('  |  ');
        final row2 = locHierarchy.sublist(3).join('  |  ');
        detailedLocationStr = '$row1\n$row2';
      }
    } else {
      detailedLocationStr = locationData?.address ?? 'Lokasi GPS tidak tersedia';
    }

    // 10. Paint text elements on canvas
    final double paddingX = cardX + accentWidth + (cardWidth * 0.025);
    double currentY = cardY + (cardHeight * 0.08);

    // Row 1: Time (Jam) & Date (Tanggal)
    final TextPainter timePainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$timeStr  ',
            style: TextStyle(
              color: const Color(0xFF00D4FF),
              fontSize: cardHeight * 0.18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          TextSpan(
            text: '|  $dateStr',
            style: TextStyle(
              color: Colors.white,
              fontSize: cardHeight * 0.13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      textDirection: ui.TextDirection.ltr,
    );
    timePainter.layout(maxWidth: cardWidth * 0.9);
    timePainter.paint(canvas, Offset(paddingX, currentY));

    currentY += timePainter.height + (cardHeight * 0.03);

    // Row 2: GPS Coordinates (Latitude & Longitude)
    final TextPainter gpsPainter = TextPainter(
      text: TextSpan(
        text: '$latStr   $lngStr',
        style: TextStyle(
          color: const Color(0xFFA78BFA),
          fontSize: cardHeight * 0.13,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    gpsPainter.layout(maxWidth: cardWidth * 0.9);
    gpsPainter.paint(canvas, Offset(paddingX, currentY));

    currentY += gpsPainter.height + (cardHeight * 0.03);

    // Row 3: Detailed Location (Disusun menyamping: 3 item per baris)
    final TextPainter locationPainter = TextPainter(
      text: TextSpan(
        text: detailedLocationStr,
        style: TextStyle(
          color: const Color(0xFF34D399),
          fontSize: cardHeight * 0.11,
          fontWeight: FontWeight.w500,
          height: 1.25,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 3,
      ellipsis: '...',
    );
    locationPainter.layout(maxWidth: cardWidth * 0.72);
    locationPainter.paint(canvas, Offset(paddingX, currentY));

    // Bottom Right App Branding: "GeoGPS Cam"
    final TextPainter brandPainter = TextPainter(
      text: TextSpan(
        text: 'GeoGPS Cam',
        style: TextStyle(
          color: const Color(0xFF38BDF8),
          fontSize: cardHeight * 0.14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    brandPainter.layout();
    brandPainter.paint(
      canvas,
      Offset(
        cardX + cardWidth - brandPainter.width - (cardWidth * 0.03),
        cardY + cardHeight - brandPainter.height - (cardHeight * 0.12),
      ),
    );

    // 11. Export canvas to high quality Image byte data
    final ui.Image watermarkedImage = await recorder
        .endRecording()
        .toImage(originalImage.width, originalImage.height);

    final ByteData? byteData = await watermarkedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw Exception('Gagal memproses watermark pada gambar');
    }

    return byteData.buffer.asUint8List();
  }
}

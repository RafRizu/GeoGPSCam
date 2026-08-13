import 'package:flutter/material.dart';
import 'package:geo_gps_cam/models/location_data.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Live watermark overlay shown during camera preview
class WatermarkOverlay extends StatelessWidget {
  final LocationDataModel? locationData;
  final DateTime time;

  const WatermarkOverlay({
    super.key,
    required this.locationData,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0C1E).withValues(alpha: 0.88),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF00D4FF).withValues(alpha: 0.6),
            width: 2,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Time block
              _buildBlock(
                icon: Icons.access_time_filled_rounded,
                iconColor: const Color(0xFF00D4FF),
                label: DateFormat('HH:mm:ss').format(time),
                sublabel: DateFormat('dd MMM yyyy').format(time),
                labelColor: const Color(0xFF00D4FF),
              ),
              const SizedBox(width: 12),
              // Coordinates block
              if (locationData != null) ...[
                _buildBlock(
                  icon: Icons.my_location_rounded,
                  iconColor: const Color(0xFF7B61FF),
                  label: locationData!.latitude.toStringAsFixed(6),
                  sublabel: '${locationData!.longitude.toStringAsFixed(6)} LNG',
                  labelColor: const Color(0xFF7B61FF),
                  prefix: 'LAT ',
                ),
              ],
            ],
          ),
          if (locationData != null) ...[
            const SizedBox(height: 6),
            // District row (Kabupaten/Kota)
            if (locationData!.district != null && locationData!.district!.isNotEmpty) ...[  
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_rounded,
                    color: Color(0xFF34D399),
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      locationData!.district!,
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
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                const Icon(
                  Icons.location_pin,
                  color: Color(0xFFFF6B6B),
                  size: 13,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    locationData!.address,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFF6B6B),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
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

  Widget _buildBlock({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String sublabel,
    required Color labelColor,
    String prefix = '',
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$prefix$label',
              style: GoogleFonts.robotoMono(
                color: labelColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              sublabel,
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

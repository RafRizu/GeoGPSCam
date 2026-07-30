import 'package:geo_gps_cam/models/location_data.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  Future<LocationDataModel?> getCurrentLocation() async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // Reverse geocode
      String address = 'Lokasi tidak dikenal';
      String? city;
      String? country;

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = <String>[];

          if (place.name != null && place.name!.isNotEmpty) {
            parts.add(place.name!);
          }
          if (place.street != null && place.street!.isNotEmpty &&
              place.street != place.name) {
            parts.add(place.street!);
          }
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            parts.add(place.subLocality!);
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            parts.add(place.locality!);
          }
          if (place.administrativeArea != null &&
              place.administrativeArea!.isNotEmpty) {
            parts.add(place.administrativeArea!);
          }

          address = parts.join(', ');
          city = place.locality;
          country = place.country;
        }
      } catch (e) {
        address = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      return LocationDataModel(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        city: city,
        country: country,
      );
    } catch (e) {
      return null;
    }
  }
}

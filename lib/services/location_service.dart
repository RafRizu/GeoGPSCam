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
      String? country;
      String? province;
      String? regency;
      String? district;
      String? subDistrict;
      String? street;

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = <String>[];

          if (place.street != null && place.street!.isNotEmpty) {
            street = place.street;
            parts.add(place.street!);
          } else if (place.name != null && place.name!.isNotEmpty) {
            street = place.name;
            parts.add(place.name!);
          }

          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            subDistrict = place.subLocality;
            parts.add(place.subLocality!);
          }

          if (place.locality != null && place.locality!.isNotEmpty) {
            district = place.locality;
            parts.add(place.locality!);
          }

          if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
            regency = place.subAdministrativeArea;
            parts.add(place.subAdministrativeArea!);
          }

          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
            province = place.administrativeArea;
            parts.add(place.administrativeArea!);
          }

          if (place.country != null && place.country!.isNotEmpty) {
            country = place.country;
            parts.add(place.country!);
          }

          address = parts.join(', ');
        }
      } catch (e) {
        address = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      return LocationDataModel(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        country: country,
        province: province,
        regency: regency,
        district: district,
        subDistrict: subDistrict,
        street: street,
      );
    } catch (e) {
      return null;
    }
  }
}

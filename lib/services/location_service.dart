import 'package:geo_gps_cam/models/location_data.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  LocationDataModel? _cachedLocation;
  DateTime? _lastFetchTime;

  /// Durasi cache: lokasi otomatis diperbarui setiap 15 menit
  static const Duration _cacheExpiry = Duration(minutes: 15);

  /// Apakah cache masih valid (belum lebih dari 15 menit)
  bool get isCacheValid {
    if (_cachedLocation == null || _lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheExpiry;
  }

  /// Sisa waktu hingga cache kadaluarsa
  Duration? get timeUntilNextUpdate {
    if (_lastFetchTime == null) return null;
    final elapsed = DateTime.now().difference(_lastFetchTime!);
    if (elapsed >= _cacheExpiry) return Duration.zero;
    return _cacheExpiry - elapsed;
  }

  /// Ambil lokasi saat ini.
  /// [forceRefresh]: jika true, selalu fetch ulang meskipun cache masih valid.
  /// Jika false, gunakan cache jika masih valid (< 15 menit).
  Future<LocationDataModel?> getCurrentLocation({bool forceRefresh = false}) async {
    // Gunakan cache jika masih valid dan tidak dipaksa refresh
    if (!forceRefresh && isCacheValid) {
      return _cachedLocation;
    }

    try {
      // Cek dan minta permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return _cachedLocation; // kembalikan cache lama jika ada
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return _cachedLocation; // kembalikan cache lama jika ada
      }

      // Ambil posisi: coba lastKnownPosition terlebih dahulu untuk respon instan jika tidak dipaksa refresh
      Position? position;
      if (!forceRefresh) {
        position = await Geolocator.getLastKnownPosition();
      }

      position ??= await Geolocator.getCurrentPosition(
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

          if (place.subAdministrativeArea != null &&
              place.subAdministrativeArea!.isNotEmpty) {
            regency = place.subAdministrativeArea;
            parts.add(place.subAdministrativeArea!);
          }

          if (place.administrativeArea != null &&
              place.administrativeArea!.isNotEmpty) {
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
        address =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      final result = LocationDataModel(
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

      // Simpan ke cache
      _cachedLocation = result;
      _lastFetchTime = DateTime.now();

      return result;
    } catch (e) {
      return _cachedLocation; // kembalikan cache lama jika error
    }
  }
}

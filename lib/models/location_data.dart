class LocationDataModel {
  final double latitude;
  final double longitude;
  final String address;
  final String? country; // Negara
  final String? province; // Provinsi (administrativeArea)
  final String? regency; // Kabupaten/Kota (subAdministrativeArea)
  final String? district; // Kecamatan (locality)
  final String? subDistrict; // Desa/Kelurahan (subLocality)
  final String? street; // Jalan/Blok (thoroughfare / subThoroughfare / street / name)

  const LocationDataModel({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.country,
    this.province,
    this.regency,
    this.district,
    this.subDistrict,
    this.street,
  });

  String get coordinatesString =>
      'Lat: ${latitude.toStringAsFixed(6)}\nLng: ${longitude.toStringAsFixed(6)}';

  String get shortCoordinates =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

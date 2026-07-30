class LocationDataModel {
  final double latitude;
  final double longitude;
  final String address;
  final String? city;
  final String? country;

  const LocationDataModel({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.city,
    this.country,
  });

  String get coordinatesString =>
      'Lat: ${latitude.toStringAsFixed(6)}\nLng: ${longitude.toStringAsFixed(6)}';

  String get shortCoordinates =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

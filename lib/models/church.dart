class Church {
  final String id;
  final String name;
  final String address;
  final double distance;
  final double latitude;
  final double longitude;
  final String? image;
  final List<String> feasts;

  Church({
    required this.id,
    required this.name,
    required this.address,
    required this.distance,
    required this.latitude,
    required this.longitude,
    this.image,
    required this.feasts,
  });
}

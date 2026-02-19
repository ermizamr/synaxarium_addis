class Feast {
  final String id;
  final String name;
  final String description;
  final String shortDescription;
  final String date;
  final List<String> churches;
  final bool isPremium;

  Feast({
    required this.id,
    required this.name,
    required this.description,
    required this.shortDescription,
    required this.date,
    required this.churches,
    required this.isPremium,
  });
}

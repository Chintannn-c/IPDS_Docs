class Item {
  final String id;
  final String name;
  final String description;
  final String type; // 'password' or 'text'

  Item({
    required this.id,
    required this.name,
    required this.description,
    this.type = 'text',
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: json['type'] ?? 'text',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'description': description, 'type': type};
  }
}

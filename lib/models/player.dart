class Player {
  final String id;
  final String name;
  final String position;
  final DateTime createdAt;

  Player({
    required this.id,
    required this.name,
    required this.position,
    required this.createdAt,
  });

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'] as String,
      name: map['name'] as String,
      position: map['position'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'position': position,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

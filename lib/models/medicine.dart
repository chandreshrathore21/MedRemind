class Medicine {
  final int? id;
  final String name;
  final String frequency;
  final String scheduleTime;
  final int inventoryCount;

  Medicine({
    this.id,
    required this.name,
    required this.frequency,
    required this.scheduleTime,
    required this.inventoryCount,
  });

  // Add the copyWith method here
  Medicine copyWith({
    int? id,
    String? name,
    String? frequency,
    String? scheduleTime,
    int? inventoryCount,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      frequency: frequency ?? this.frequency,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      inventoryCount: inventoryCount ?? this.inventoryCount,
    );
  }

  // Convert a Medicine into a Map for SQLite insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'frequency': frequency,
      'scheduleTime': scheduleTime,
      'inventoryCount': inventoryCount,
    };
  }

  // Convert a Map from SQLite into a Medicine object
  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'] as int?,
      name: map['name'] as String,
      frequency: map['frequency'] as String,
      scheduleTime: map['scheduleTime'] as String,
      inventoryCount: map['inventoryCount'] as int,
    );
  }
}
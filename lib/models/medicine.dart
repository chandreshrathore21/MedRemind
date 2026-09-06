class Medicine {
  final int? id;
  final String name;
  final String frequency;
  final int inventoryCount;
  final String scheduleTime;

  Medicine({
    this.id,
    required this.name,
    required this.frequency,
    required this.inventoryCount,
    required this.scheduleTime,
  });

  // Convert Map from SQLite row into Medicine object
  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      frequency: map['frequency'] as String? ?? '',
      inventoryCount: map['inventoryCount'] as int? ?? 0,
      scheduleTime: map['scheduleTime'] as String? ?? '',
    );
  }

  // Convert Medicine object into Map for SQLite insert/update
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'frequency': frequency,
      'inventoryCount': inventoryCount,
      'scheduleTime': scheduleTime,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }
}
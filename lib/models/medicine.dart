class Medicine {
  final int? id;
  final String name;
  final String frequency;
  final int inventoryCount;
  final String scheduleTime;
  final int skippedCount;
  final bool isAlarm; // Persistent alarm flag

  Medicine({
    this.id,
    required this.name,
    required this.frequency,
    required this.inventoryCount,
    required this.scheduleTime,
    this.skippedCount = 0,
    this.isAlarm = false,
  });

  Medicine copyWith({
    int? id,
    String? name,
    String? frequency,
    int? inventoryCount,
    String? scheduleTime,
    int? skippedCount,
    bool? isAlarm,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      frequency: frequency ?? this.frequency,
      inventoryCount: inventoryCount ?? this.inventoryCount,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      skippedCount: skippedCount ?? this.skippedCount,
      isAlarm: isAlarm ?? this.isAlarm,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'frequency': frequency,
      'inventoryCount': inventoryCount,
      'scheduleTime': scheduleTime,
      'skippedCount': skippedCount,
      'isAlarm': isAlarm ? 1 : 0, // Store as INTEGER in SQLite
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'],
      name: map['name'],
      frequency: map['frequency'],
      inventoryCount: map['inventoryCount'],
      scheduleTime: map['scheduleTime'],
      skippedCount: map['skippedCount'] ?? 0,
      isAlarm: (map['isAlarm'] ?? 0) == 1,
    );
  }
}
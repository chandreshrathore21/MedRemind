class Medicine {
  final int? id;
  final String name;
  final String dosage;
  final String frequency;
  final String scheduleTime;
  final DateTime? scheduledTime; // Nullable
  final int inventoryCount;
  final int skippedCount;
  final bool isAlarm;

  const Medicine({
    this.id,
    required this.name,
    this.dosage = '',
    required this.frequency,
    required this.scheduleTime,
    this.scheduledTime, // Optional parameter
    this.inventoryCount = 0,
    this.skippedCount = 0,
    this.isAlarm = false,
  });

  /// Copy instance with updated fields
  Medicine copyWith({
    int? id,
    String? name,
    String? dosage,
    String? frequency,
    String? scheduleTime,
    DateTime? scheduledTime,
    int? inventoryCount,
    int? skippedCount,
    bool? isAlarm,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      inventoryCount: inventoryCount ?? this.inventoryCount,
      skippedCount: skippedCount ?? this.skippedCount,
      isAlarm: isAlarm ?? this.isAlarm,
    );
  }

  /// Convert Medicine object into a Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'scheduleTime': scheduleTime,
      'scheduledTime': scheduledTime?.toIso8601String(),
      'inventoryCount': inventoryCount,
      'skippedCount': skippedCount,
      'isAlarm': isAlarm ? 1 : 0, // SQLite stores booleans as 1 or 0
    };
  }

  /// Construct Medicine object from SQLite Map
  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      dosage: map['dosage'] as String? ?? '',
      frequency: map['frequency'] as String? ?? '',
      scheduleTime: map['scheduleTime'] as String? ?? '00:00',
      scheduledTime: map['scheduledTime'] != null
          ? DateTime.parse(map['scheduledTime'])
          : DateTime.now(),
      inventoryCount: map['inventoryCount'] as int? ?? 0,
      skippedCount: map['skippedCount'] as int? ?? 0,
      isAlarm: (map['isAlarm'] as int? ?? 0) == 1,
    );
  }
}
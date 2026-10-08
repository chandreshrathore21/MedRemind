class OtcMedicine {
  final int? id;
  final String name;
  final int quantity;
  final String? expiryDate; // Format: YYYY-MM-DD
  final String category; // e.g., Painkiller, Fever, Cough & Cold

  const OtcMedicine({
    this.id,
    required this.name,
    required this.quantity,
    required this.category,
    this.expiryDate,
  });

  /// Create a copy of OtcMedicine with updated fields
  OtcMedicine copyWith({
    int? id,
    String? name,
    int? quantity,
    String? category,
    String? expiryDate,
  }) {
    return OtcMedicine(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  /// Convert OtcMedicine object to a Map for SQLite insertion/update
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'quantity': quantity,
      'category': category,
      'expiryDate': expiryDate,
    };
  }

  /// Construct OtcMedicine object safely from a SQLite Map
  factory OtcMedicine.fromMap(Map<String, dynamic> map) {
    return OtcMedicine(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 0,
      category: map['category'] as String? ?? 'General',
      expiryDate: map['expiryDate'] as String?,
    );
  }
}
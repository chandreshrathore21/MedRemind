class OtcMedicine {
  final int? id;
  final String name;
  final int quantity;
  final String? expiryDate; // Format: YYYY-MM-DD
  final String category;    // e.g., Painkiller, Fever, Cough & Cold

  OtcMedicine({
    this.id,
    required this.name,
    required this.quantity,
    required this.category,
    this.expiryDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'category': category,
      'expiryDate': expiryDate,
    };
  }

  factory OtcMedicine.fromMap(Map<String, dynamic> map) {
    return OtcMedicine(
      id: map['id'],
      name: map['name'],
      quantity: map['quantity'],
      category: map['category'] ?? 'General',
      expiryDate: map['expiryDate'],
    );
  }
}
class ReceiptItem {
  final String id;
  final String name;
  final int qty;
  final double totalPrice;
  final Set<String> assignedFriends; // Friend IDs claiming this item

  ReceiptItem({
    required this.id,
    required this.name,
    required this.qty,
    required this.totalPrice,
    Set<String>? assignedFriends,
  }) : assignedFriends = assignedFriends ?? {};

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      id: json['id']?.toString() ?? UniqueKey().toString(),
      name: json['name']?.toString() ?? 'Item',
      qty: (json['qty'] is num) ? (json['qty'] as num).toInt() : 1,
      totalPrice: (json['total_price'] is num) ? (json['total_price'] as num).toDouble() : 0.0,
    );
  }

  ReceiptItem copyWith({Set<String>? assignedFriends}) {
    return ReceiptItem(
      id: id,
      name: name,
      qty: qty,
      totalPrice: totalPrice,
      assignedFriends: assignedFriends ?? Set.from(this.assignedFriends),
    );
  }
}

class ReceiptData {
  final String currency;
  final List<ReceiptItem> items;
  final double subtotal;
  final double tax;
  final double serviceCharge;
  final double grandTotal;

  ReceiptData({
    required this.currency,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.serviceCharge,
    required this.grandTotal,
  });

  factory ReceiptData.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final parsedItems = rawItems.map((e) => ReceiptItem.fromJson(e as Map<String, dynamic>)).toList();
    
    final double calcSubtotal = parsedItems.fold(0.0, (acc, item) => acc + item.totalPrice);
    final double subtotal = (json['subtotal'] is num) ? (json['subtotal'] as num).toDouble() : calcSubtotal;
    final double tax = (json['tax'] is num) ? (json['tax'] as num).toDouble() : 0.0;
    final double serviceCharge = (json['service_charge'] is num) ? (json['service_charge'] as num).toDouble() : 0.0;
    final double grandTotal = (json['grand_total'] is num) 
        ? (json['grand_total'] as num).toDouble() 
        : (subtotal + tax + serviceCharge);

    return ReceiptData(
      currency: json['currency']?.toString() ?? 'INR',
      items: parsedItems,
      subtotal: subtotal,
      tax: tax,
      serviceCharge: serviceCharge,
      grandTotal: grandTotal,
    );
  }
}

class Friend {
  final String id;
  final String name;

  Friend({required this.id, required this.name});
}

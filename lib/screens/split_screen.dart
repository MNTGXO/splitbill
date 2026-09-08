import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../models/receipt.dart';

class SplitScreen extends StatefulWidget {
  final ReceiptData initialReceipt;

  const SplitScreen({super.key, required this.initialReceipt});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  late List<ReceiptItem> _items;
  final List<Friend> _friends = [
    Friend(id: '1', name: 'You'),
    Friend(id: '2', name: 'Alex'),
  ];
  String? _selectedFriendId = '1';
  final TextEditingController _friendController = TextEditingController();
  final TextEditingController _upiController = TextEditingController(text: "friend@upi");

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialReceipt.items);
  }

  void _addFriend() {
    final name = _friendController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      final newFriend = Friend(id: const Uuid().v4(), name: name);
      _friends.add(newFriend);
      _selectedFriendId = newFriend.id;
      _friendController.clear();
    });
    Navigator.pop(context);
  }

  void _toggleItemAssignment(String itemId) {
    if (_selectedFriendId == null) return;
    setState(() {
      final index = _items.indexWhere((it) => it.id == itemId);
      if (index == -1) return;

      final currentSet = Set<String>.from(_items[index].assignedFriends);
      if (currentSet.contains(_selectedFriendId)) {
        currentSet.remove(_selectedFriendId);
      } else {
        currentSet.add(_selectedFriendId!);
      }
      _items[index] = _items[index].copyWith(assignedFriends: currentSet);
    });
  }

  // Calculate proportional share including tax + service charge
  double _calculateFriendTotal(String friendId) {
    double itemShare = 0.0;
    double itemsTotal = 0.0;

    for (final item in _items) {
      itemsTotal += item.totalPrice;
      if (item.assignedFriends.contains(friendId)) {
        itemShare += item.totalPrice / item.assignedFriends.length;
      }
    }

    if (itemsTotal == 0) return 0.0;

    // Distribute taxes & extra fees proportionally to consumption
    final extraFees = widget.initialReceipt.tax + widget.initialReceipt.serviceCharge;
    final proportionalTaxFee = (itemShare / itemsTotal) * extraFees;

    return itemShare + proportionalTaxFee;
  }

  Future<void> _launchUPI(double amount, String friendName) async {
    final upiId = _upiController.text.trim();
    final uri = Uri.parse(
      'upi://pay?pa=$upiId&pn=${Uri.encodeComponent("SplitBill")}&am=${amount.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent("Bill split for $friendName")}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open payment app. UPI deep links require a supported UPI app on device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Add Friend'),
                content: TextField(
                  controller: _friendController,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Name (e.g., Sarah)'),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  FilledButton(onPressed: _addFriend, child: const Text('Add')),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Friend Selector Bar
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _friends.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final friend = _friends[i];
                final isSelected = friend.id == _selectedFriendId;
                return ChoiceChip(
                  label: Text(friend.name),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedFriendId = friend.id),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Items List
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (ctx, i) {
                final item = _items[i];
                final isAssignedToSelected = _selectedFriendId != null && item.assignedFriends.contains(_selectedFriendId);
                final assignedNames = _friends
                    .where((f) => item.assignedFriends.contains(f.id))
                    .map((f) => f.name)
                    .join(', ');

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: isAssignedToSelected ? 2 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isAssignedToSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                      width: isAssignedToSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    onTap: () => _toggleItemAssignment(item.id),
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      assignedNames.isEmpty ? 'Tap to claim' : 'Claimed by: $assignedNames',
                      style: TextStyle(
                        color: assignedNames.isEmpty ? Colors.grey : Colors.deepPurple,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Text(
                      '${widget.initialReceipt.currency} ${item.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Settlement Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total: ${widget.initialReceipt.currency} ${widget.initialReceipt.grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Tax/Fee: ${widget.initialReceipt.currency} ${(widget.initialReceipt.tax + widget.initialReceipt.serviceCharge).toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._friends.map((friend) {
                    final amount = _calculateFriendTotal(friend.id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(friend.name, style: const TextStyle(fontSize: 15)),
                          Row(
                            children: [
                              Text(
                                '${widget.initialReceipt.currency} ${amount.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                iconSize: 20,
                                icon: const Icon(Icons.payment, color: Colors.green),
                                onPressed: amount > 0 ? () => _launchUPI(amount, friend.name) : null,
                              )
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

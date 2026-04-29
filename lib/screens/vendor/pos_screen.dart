import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'vendor_scanner_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final String _vendorId = "tJOwwgGfgPWDeMuYLaLozMyGQc52";

  final Map<String, Map<String, dynamic>> _selectedItems = {};
  double _totalBill = 0.0;

  void _addItem(String name, double price) {
    setState(() {
      if (_selectedItems.containsKey(name)) {
        _selectedItems[name]!['quantity'] += 1;
      } else {
        _selectedItems[name] = {'price': price, 'quantity': 1};
      }
      _totalBill += price;
    });
  }

  void _removeItem(String name) {
    setState(() {
      if (_selectedItems.containsKey(name)) {
        double price = _selectedItems[name]!['price'];

        if (_selectedItems[name]!['quantity'] > 1) {
          _selectedItems[name]!['quantity'] -= 1;
        } else {
          _selectedItems.remove(name);
        }
        _totalBill -= price;
      }
    });
  }

  void _clearCart() {
    setState(() {
      _selectedItems.clear();
      _totalBill = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("Billing", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(_vendorId)
                  .collection('menu')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var item = snapshot.data!.docs[index];
                    String name = item['name'];
                    double price = (item['price'] as num).toDouble();

                    return InkWell(
                      onTap: () => _addItem(name, price),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text("₹$price", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          if (_selectedItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              height: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Items Added:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _selectedItems.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                          child: InputChip(
                            label: Text("${entry.key} x${entry.value['quantity']}"),
                            labelStyle: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                            backgroundColor: Colors.blueAccent.withOpacity(0.1),
                            onDeleted: () => _removeItem(entry.key),
                            deleteIcon: const Icon(Icons.remove_circle, size: 18, color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: BorderSide.none,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

          _buildCheckoutBar(),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Total Bill", style: TextStyle(color: Colors.grey)),
                  Text("₹${_totalBill.toStringAsFixed(2)}",
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
              TextButton(
                onPressed: _clearCart,
                child: const Text("Clear All", style: TextStyle(color: Colors.redAccent, fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              onPressed: _totalBill <= 0
                  ? null
                  : () async {
                // --- UPDATED LOGIC HERE ---
                // We await the scanner screen. If payment succeeds, it returns true.
                final paymentSuccess = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VendorScannerScreen(
                      amount: _totalBill / 100,
                      rupeeAmount: _totalBill,
                    ),
                  ),
                );

                // Automatically clear the cart if the transaction was successful
                if (paymentSuccess == true) {
                  _clearCart();
                }
              },
              child: const Text(
                "CHARGE STUDENT",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
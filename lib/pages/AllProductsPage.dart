import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'OrdersPage.dart';

class AllProductsPage extends StatefulWidget {
  @override
  _AllProductsPageState createState() => _AllProductsPageState();
}

class _AllProductsPageState extends State<AllProductsPage> {
  List<Map<String, dynamic>> _products = [];
  Map<String, int> _cart = {};
  final _customerNameController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerPhoneNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    final response = await http.get(Uri.parse('http://192.168.174.246:8000/product/agri/'));
    if (response.statusCode == 200) {
      List<dynamic> productData = json.decode(response.body);
      setState(() {
        _products = productData.map((item) {
          return {
            'id': item['id'],
            'name': item['name'],
            'price': double.tryParse(item['price'].toString()) ?? 0.0
          };
        }).toList();
      });
    } else {
      throw Exception('Failed to load products');
    }
  }

  void _addToCart(String productId) {
    setState(() {
      if (_cart.containsKey(productId)) {
        _cart[productId] = _cart[productId]! + 1;
      } else {
        _cart[productId] = 1;
      }
    });
  }

  void _removeFromCart(String productId) {
    setState(() {
      if (_cart.containsKey(productId) && _cart[productId]! > 0) {
        _cart[productId] = _cart[productId]! - 1;
      }
    });
  }

  double _calculateTotalPrice() {
    double totalPrice = 0.0;
    _cart.forEach((productId, quantity) {
      final product = _products.firstWhere((prod) => prod['id'].toString() == productId);
      totalPrice += product['price'] * quantity;
    });
    return totalPrice;
  }

  Future<void> _createOrder() async {
    if (_cart.isEmpty) return;

    final customerResponse = await http.post(
      Uri.parse('http://192.168.174.246:8000/product/customers/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': _customerNameController.text,
        'address': _customerAddressController.text,
        'phone_number': _customerPhoneNumberController.text,
      }),
    );

    if (customerResponse.statusCode == 201) {
      final customer = json.decode(customerResponse.body);
      final customerId = customer['id'];

      for (var entry in _cart.entries) {
        await http.post(
          Uri.parse('http://192.168.174.246:8000/product/orders/'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'customer': customerId,
            'agri_item': entry.key,
            'quantity': entry.value,
          }),
        );
      }

      setState(() {
        _cart.clear();
        _customerNameController.clear();
        _customerAddressController.clear();
        _customerPhoneNumberController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Order placed successfully!'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to create customer'),
      ));
    }
  }

  void _viewOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OrdersPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Products'),
        backgroundColor: Colors.green,
      ),
      body: _products.isEmpty
          ? Center(
        child: CircularProgressIndicator(),
      )
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                final productId = product['id'].toString();
                return Container(
                  margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  decoration: BoxDecoration(
                    color: index % 2 == 0 ? Colors.green[100] : Colors.green[200],
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    title: Text(
                      product['name'],
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Price: \TK${product['price']}',
                      style: TextStyle(color: Colors.black54),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: () {
                            _removeFromCart(productId);
                          },
                        ),
                        Text(_cart[productId]?.toString() ?? '0'),
                        IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () {
                            _addToCart(productId);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _customerNameController,
                  decoration: InputDecoration(
                    labelText: 'Customer Name',
                  ),
                ),
                TextField(
                  controller: _customerAddressController,
                  decoration: InputDecoration(
                    labelText: 'Customer Address',
                  ),
                ),
                TextField(
                  controller: _customerPhoneNumberController,
                  decoration: InputDecoration(
                    labelText: 'Customer Phone Number',
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _createOrder,
                  child: Text('Place Order'),
                ),
                SizedBox(height: 10), // Added gap
                ElevatedButton(
                  onPressed: _viewOrders,
                  child: Text('View Orders'),
                ),
                SizedBox(height: 10),
                Text(
                  'Total Price: \TK${_calculateTotalPrice().toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

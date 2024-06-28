import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OrdersPage extends StatelessWidget {
  Future<List<Map<String, dynamic>>?> _fetchOrders() async {
    final response = await http.get(Uri.parse('http://192.168.174.246:8000/product/orders/'));
    if (response.statusCode == 200) {
      List<dynamic> orderData = json.decode(response.body);
      return orderData.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load orders');
    }
  }

  Future<Map<String, dynamic>?> _fetchCustomer(String customerId) async {
    final response = await http.get(Uri.parse('http://192.168.174.246:8000/product/customers/$customerId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load customer');
    }
  }

  Future<List<Map<String, dynamic>>?> _fetchItemsForOrder(List<int> itemIds) async {
    final List<Future<Map<String, dynamic>>> futures = itemIds.map((itemId) async {
      final response = await http.get(Uri.parse('http://192.168.174.246:8000/product/agri/$itemId'));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load item');
      }
    }).toList();

    return Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Orders'),
        backgroundColor: Colors.green,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>?>(
        future: _fetchOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading orders: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No orders found'));
          } else {
            List<Map<String, dynamic>>? orders = snapshot.data;
            // Group orders by customer id
            Map<String, List<Map<String, dynamic>>> ordersByCustomer = {};
            orders?.forEach((order) {
              String customerId = order['customer'].toString();
              if (!ordersByCustomer.containsKey(customerId)) {
                ordersByCustomer[customerId] = [];
              }
              ordersByCustomer[customerId]?.add(order);
            });
            return ListView.builder(
              itemCount: ordersByCustomer.length,
              itemBuilder: (context, index) {
                String customerId = ordersByCustomer.keys.elementAt(index);
                List<Map<String, dynamic>> customerOrders = ordersByCustomer[customerId]!;
                return FutureBuilder<Map<String, dynamic>?>(
                  future: _fetchCustomer(customerId),
                  builder: (context, customerSnapshot) {
                    if (customerSnapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (customerSnapshot.hasError) {
                      return Center(child: Text('Error loading customer: ${customerSnapshot.error}'));
                    } else {
                      Map<String, dynamic>? customerData = customerSnapshot.data;
                      if (customerData != null) {
                        return _buildCustomerOrders(customerData, customerOrders);
                      } else {
                        return Center(child: Text('Customer data is null'));
                      }
                    }
                  },
                );
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildCustomerOrders(Map<String, dynamic> customerData, List<Map<String, dynamic>> orders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.all(10),
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer: ${customerData['name'] ?? 'N/A'}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Address: ${customerData['address'] ?? 'N/A'}'),
              Text('Phone: ${customerData['phone_number'] ?? 'N/A'}'),
              Divider(),
              Text(
                'Orders:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: orders.map<Widget>((order) {
                  return FutureBuilder<List<Map<String, dynamic>>?>(
                    future: _fetchItemsForOrder([order['agri_item']]),
                    builder: (context, itemSnapshot) {
                      if (itemSnapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (itemSnapshot.hasError) {
                        return Center(child: Text('Error loading items: ${itemSnapshot.error}'));
                      } else {
                        List<Map<String, dynamic>>? items = itemSnapshot.data;
                        if (items != null && items.isNotEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: items.map<Widget>((item) {
                              return Text('${item['name']} - Quantity: ${order['quantity']} - Price: \TK${item['price']}');
                            }).toList(),
                          );
                        } else {
                          return Center(child: Text('No items found'));
                        }
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        SizedBox(height: 10),
      ],
    );
  }
}

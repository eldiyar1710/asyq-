import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class ConfirmDeliveryScreen extends StatefulWidget {
  final String orderId;
  final String address;
  final List<dynamic> items;
  final double total;
  final String confirmationCode;

  const ConfirmDeliveryScreen({
    super.key,
    required this.orderId,
    required this.address,
    required this.items,
    required this.total,
    required this.confirmationCode,
  });

  @override
  State<ConfirmDeliveryScreen> createState() => _ConfirmDeliveryScreenState();
}

class _ConfirmDeliveryScreenState extends State<ConfirmDeliveryScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print(
      'ConfirmDeliveryScreen initialized with orderId: ${widget.orderId}, '
      'confirmationCode: ${widget.confirmationCode}',
    );
  }

  Future<void> _confirmDelivery() async {
    final enteredCode = _codeController.text.trim();
    print(
      'Entered code: $enteredCode, Expected code: ${widget.confirmationCode}',
    );

    if (enteredCode.isEmpty) {
      setState(() => _errorMessage = 'Кодты енгізіңіз');
      return;
    }

    if (enteredCode != widget.confirmationCode) {
      setState(() => _errorMessage = 'Растау коды қате');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('Пользователь не авторизован');
      }

      final orderRef = FirebaseDatabase.instance.ref(
        'orders/${widget.orderId}',
      );
      final orderSnapshot = await orderRef.get();
      if (!orderSnapshot.exists) {
        throw Exception('Тапсырыс табылмады');
      }

      final orderData = Map<String, dynamic>.from(orderSnapshot.value as Map);
      print('Order data: $orderData');

      if (orderData['status'] != 'in_transit') {
        throw Exception('Заказ не в статусе доставки');
      }

      if (orderData['courierId'] != userId) {
        throw Exception('Вы не назначены курьером для этого заказа');
      }

     
      await orderRef.update({
        'status': 'delivered',
        'deliveredAt': ServerValue.timestamp,
      });
      print('Order status updated to delivered for orderId: ${widget.orderId}');

      
      final buyerId = orderData['buyerId'];
      final sellerId = orderData['sellerId'];

      await FirebaseDatabase.instance
          .ref('notifications/buyers/$buyerId')
          .push()
          .set({
            'orderId': widget.orderId,
            'message': 'Сіздің тапсырысыңыз №${widget.orderId} жеткізілді',
            'timestamp': ServerValue.timestamp,
            'status': 'delivered',
            'items': widget.items,
            'total': widget.total,
            'confirmationCode': widget.confirmationCode,
          });
      print('Buyer notification sent for buyerId: $buyerId');

      await FirebaseDatabase.instance
          .ref('notifications/sellers/$sellerId')
          .push()
          .set({
            'orderId': widget.orderId,
            'message': 'Тапсырыс №${widget.orderId} жеткізілді',
            'timestamp': ServerValue.timestamp,
            'status': 'delivered',
            'items': widget.items,
            'total': widget.total,
          });
      print('Seller notification sent for sellerId: $sellerId');

      await FirebaseDatabase.instance.ref('notifications/couriers').push().set({
        'orderId': widget.orderId,
        'message': 'Сіз тапсырыс №${widget.orderId} жеткіздіңіз',
        'timestamp': ServerValue.timestamp,
        'status': 'delivered',
        'courierId': userId,
      });
      print('Courier notification sent for courierId: $userId');


      final notifSnapshot =
          await FirebaseDatabase.instance
              .ref('notifications/couriers')
              .orderByChild('orderId')
              .equalTo(widget.orderId)
              .get();
      if (notifSnapshot.exists) {
        final notifs = Map<String, dynamic>.from(notifSnapshot.value as Map);
        for (var notifId in notifs.keys) {
          await FirebaseDatabase.instance
              .ref('notifications/couriers/$notifId')
              .remove();
          print('Removed courier notification: $notifId');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Тапсырыс №${widget.orderId} жеткізілді')),
      );
      Navigator.pop(context);
    } catch (e) {
      print('Error confirming delivery: $e');
      setState(() => _errorMessage = 'Растау қатесі: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Жеткізуді растау №${widget.orderId}'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.greenAccent, Colors.blueAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.green.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Тапсырыс мәліметтері',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Мекенжай: ${widget.address}'),
                    Text(
                      'Сомасы: ${NumberFormat.currency(locale: 'kk_KZ', symbol: '₸').format(widget.total)}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Тауарлар: ${widget.items.isEmpty ? 'Жоқ' : widget.items.map((item) => item['name'] ?? 'Белгісіз').join(', ')}',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Растау коды (үшін ақпарат): ${widget.confirmationCode}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 500.ms),
            const SizedBox(height: 16),
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.blue.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Растау кодын енгізіңіз',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        labelText: 'Код',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        errorText: _errorMessage,
                      ),
                      keyboardType: TextInputType.text,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 24,
                            ),
                          ),
                          onPressed: _confirmDelivery,
                          child: const Text(
                            'Жеткізуді растау',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with SingleTickerProviderStateMixin {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final dbRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic> cartItems = {};
  bool _hasCart = false;
  double _balance = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  String _address = '';
  Map<String, dynamic> _userData = {};
  List<Map<String, dynamic>> _deliveredOrders = [];

  DatabaseReference get _userRef => dbRef.child('users/$userId');
  DatabaseReference get _cartRef => dbRef.child('cart/$userId');
  DatabaseReference get _transactionsRef => dbRef.child('transactions/$userId');

  @override
  void initState() {
    super.initState();
    _loadCart();
    _checkIfCartExists();
    _loadUserData();
    _loadDeliveredOrders();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCart() async {
    final snapshot = await _cartRef.get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() => cartItems = data);
    }
  }

  Future<void> _loadUserData() async {
    final snapshot = await _userRef.get();
    if (snapshot.exists) {
      setState(() {
        _userData = Map<String, dynamic>.from(snapshot.value as Map);
        _address = _userData['address'] ?? '';
      });
    }
  }

  Future<void> _loadDeliveredOrders() async {
    final snapshot =
        await FirebaseDatabase.instance
            .ref('orders')
            .orderByChild('buyerId')
            .equalTo(userId)
            .get();
    if (snapshot.exists) {
      final orders = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() {
        _deliveredOrders.clear();
        orders.forEach((key, value) {
          final order = Map<String, dynamic>.from(value);
          order['id'] = key;
          _deliveredOrders.add(order);
        });
      });
    }
  }

  Future<void> _checkIfCartExists() async {
    try {
      final userSnapshot = await _userRef.get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map;
        final cardInfo = userData['cardInfo'] as Map?;
        setState(() {
          _hasCart = userData['hasCard'] ?? false;
          _balance = (cardInfo?['balance'] ?? 0).toDouble();
        });
      }
    } catch (e) {
      print('Карта тексеру қатесі: $e');
    }
  }

  Future<void> _updateQuantity(String productId, double delta) async {
    double currentQty = (cartItems[productId]['quantity'] ?? 1).toDouble();
    double newQty = currentQty + delta;
    if (newQty <= 0) {
      await _cartRef.child(productId).remove();
      setState(() => cartItems.remove(productId));
    } else {
      await _cartRef.child(productId).child('quantity').set(newQty);
      setState(() => cartItems[productId]['quantity'] = newQty);
    }
  }

  double _calculateTotal() {
    double total = 0;
    cartItems.forEach((key, value) {
      double price = double.tryParse(value['price'].toString()) ?? 0;
      double qty = (value['quantity'] ?? 1).toDouble();
      double discount = (value['discount'] ?? 0).toDouble();
      double effectivePrice =
          discount > 0 ? price * (1 - discount / 100) : price;
      total += effectivePrice * qty;
    });
    return total;
  }

  String _generateConfirmationCode() {
    return (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
  }

  Future<void> _purchase() async {
    if (!_hasCart) {
      _showAddCartDialog();
      return;
    }

    double total = _calculateTotal();
    if (_balance < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Картада жеткілікті қаражат жоқ')),
      );
      return;
    }

    if (_address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Өтініш, профильде жеткізу мекен-жайын енгізіңіз'),
        ),
      );
      return;
    }

    try {
      final newBalance = _balance - total;
      final now = DateTime.now().millisecondsSinceEpoch;
      final confirmationCode = _generateConfirmationCode();

      await _userRef.child('cardInfo').update({'balance': newBalance});
      await _transactionsRef.push().set({
        'amount': total,
        'timestamp': now,
        'type': 'Сатып алу',
        'formattedDate': DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now()),
      });

      final orderRef = FirebaseDatabase.instance.ref('orders').push();
      final orderData = {
        'id': orderRef.key,
        'buyerId': userId,
        'items':
            cartItems.entries.map((entry) {
              final item = entry.value;
              return {
                'id': item['id'],
                'name': item['name'],
                'price': item['price'],
                'discount': item['discount'] ?? 0,
                'image': item['image'],
                'quantity': item['quantity'],
                'sellerId': item['sellerId'],
                'description': item['description'] ?? 'Сипаттама жоқ',
              };
            }).toList(),
        'total': total,
        'status': 'pending_seller',
        'timestamp': ServerValue.timestamp,
        'confirmationCode': confirmationCode,
        'address': _address,
        'courierId': null,
      };

      await orderRef.set(orderData);

      for (final entry in cartItems.entries) {
        final item = entry.value;
        final productSnapshot =
            await FirebaseDatabase.instance.ref('products/${item['id']}').get();
        if (productSnapshot.exists) {
          final sellerId = productSnapshot.child('userId').value.toString();
          await FirebaseDatabase.instance
              .ref('notifications/sellers/$sellerId')
              .push()
              .set({
                'orderId': orderRef.key,
                'message':
                    'Жаңа тапсырыс №${orderRef.key} күтуде. Растауды қажет етеді',
                'timestamp': ServerValue.timestamp,
                'buyerId': userId,
                'itemName': item['name'],
                'quantity': item['quantity'],
                'total': (item['price'] *
                        (1 - (item['discount'] ?? 0) / 100) *
                        item['quantity'])
                    .toStringAsFixed(2),
                'status': 'pending_seller',
              });
        }
      }

      await FirebaseDatabase.instance
          .ref('notifications/buyers/$userId')
          .push()
          .set({
            'orderId': orderRef.key,
            'message':
                'Сіздің тауарыңыз сәтті сатып алынды, курьерді күтіңіз. Растау коды: $confirmationCode',
            'timestamp': ServerValue.timestamp,
            'status': 'pending_seller',
          });

      await _cartRef.remove();
      setState(() {
        _balance = newBalance;
        cartItems.clear();
        _address = _userData['address'] ?? '';
      });

      // Растау кодымен AlertDialog көрсету
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Сатып алу сәтті'),
              content: Text(
                'Сіздің тауарыңыз ${total.toStringAsFixed(2)}₸ бағасына сәтті сатып алынды.\nРастау коды: $confirmationCode\nБұл кодты курьерге беру үшін сақтаңыз.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ЖАРАЙДЫ'),
                ),
              ],
            ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Сіздің тауарыңыз ${total.toStringAsFixed(2)}₸ бағасына сәтті сатып алынды, курьерді күтіңіз! Растау коды: $confirmationCode',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Сатып алу қатесі: $e')));
    }
  }

  Future<void> _submitReview(
    String orderId,
    String productId,
    double rating,
    String comment,
  ) async {
    try {
      await FirebaseDatabase.instance.ref('reviews').push().set({
        'orderId': orderId,
        'productId': productId,
        'buyerId': userId,
        'rating': rating,
        'comment': comment,
        'timestamp': ServerValue.timestamp,
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Пікір сәтті жіберілді')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Пікір жіберу қатесі: $e')));
    }
  }

  void _showAddCartDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Бекітілген карта жоқ'),
            content: const Text('Өтініш, сатып алу үшін карта бекітіңіз.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ЖАРАЙДЫ'),
              ),
            ],
          ),
    );
  }

  void _showReviewDialog(String orderId, String productId) {
    double rating = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Пікір қалдыру'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Рейтинг:'),
                Slider(
                  value: rating,
                  min: 0,
                  max: 5,
                  divisions: 5,
                  label: rating.toString(),
                  onChanged: (value) {
                    setState(() {
                      rating = value;
                    });
                  },
                ),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(labelText: 'Пікір'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Бас тарту'),
              ),
              TextButton(
                onPressed: () {
                  _submitReview(
                    orderId,
                    productId,
                    rating,
                    commentController.text,
                  );
                  Navigator.pop(context);
                },
                child: const Text('Жіберу'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Себет', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Баланс: ${_balance.toStringAsFixed(2)}₸',
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://thumbs.dreamstime.com/b/supermarket-waiting-line-symbol-images-buyer-basket-checkout-retail-woman-customer-purchase-cashbox-buy-web-banner-infographics-164150345.jpg',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 80,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (cartItems.isEmpty)
                          const Center(
                            child: Text(
                              'Себет бос',
                              style: TextStyle(fontSize: 18),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: cartItems.length,
                            itemBuilder: (context, index) {
                              String key = cartItems.keys.elementAt(index);
                              Map item = cartItems[key];
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 5,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(8),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      item['image'] ?? '',
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  title: Text(
                                    item['name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Бағасы: ${item['price']}₸'),
                                      if (item['discount'] != null &&
                                          item['discount'] > 0)
                                        Text(
                                          'Жеңілдік: ${item['discount']}%',
                                          style: const TextStyle(
                                            color: Colors.green,
                                          ),
                                        ),
                                      Text(
                                        'Сипаттама: ${item['description'] ?? 'Сипаттама жоқ'}',
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove,
                                          color: Colors.black54,
                                        ),
                                        onPressed:
                                            () => _updateQuantity(key, -1),
                                      ),
                                      Text('${item['quantity'] ?? 1}'),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add,
                                          color: Colors.black54,
                                        ),
                                        onPressed:
                                            () => _updateQuantity(key, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 16),
                        Text(
                          'Жеткізу мекен-жайы: ${_address.isEmpty ? 'Профильде мекен-жайды енгізіңіз' : _address}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Жалпы сомма: ${_calculateTotal().toStringAsFixed(2)}₸',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              221,
                              223,
                              161,
                              5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          onPressed: _purchase,
                          child: const Text('Сатып алу'),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Тапсырыстар тарихы',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_deliveredOrders.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Тапсырыстар жоқ'),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _deliveredOrders.length,
                            itemBuilder: (context, index) {
                              final order = _deliveredOrders[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ExpansionTile(
                                  title: Text('Тапсырыс №${order['id']}'),
                                  subtitle: Text(
                                    'Күйі: ${_getStatusText(order['status'])}\nКод: ${order['confirmationCode'] ?? 'Жоқ'}',
                                  ),
                                  children:
                                      order['items'].map<Widget>((item) {
                                        return ListTile(
                                          title: Text(item['name']),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Бағасы: ${item['price']}₸'),
                                              Text('Саны: ${item['quantity']}'),
                                              if (order['status'] ==
                                                  'delivered')
                                                ElevatedButton(
                                                  onPressed:
                                                      () => _showReviewDialog(
                                                        order['id'],
                                                        item['id'],
                                                      ),
                                                  child: const Text(
                                                    'Пікір қалдыру',
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending_seller':
        return 'Сатушы растауын күтуде';
      case 'preparing':
        return 'Тапсырыс дайындалуда';
      case 'new':
        return 'Жаңа, курьерді күтуде';
      case 'in_transit':
        return 'Жолда';
      case 'delivered':
        return 'Жеткізілді';
      case 'courier_rejected':
        return 'Курьер бас тартты';
      default:
        return 'Белгісіз';
    }
  }
}

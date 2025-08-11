import 'package:azyq/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SellerScreen extends StatefulWidget {
  const SellerScreen({super.key});

  @override
  State<SellerScreen> createState() => _SellerScreenState();
}

class _SellerScreenState extends State<SellerScreen> {
  bool _isSeller = false;
  bool _isLoading = true;
  final List<Map<String, dynamic>> _pendingOrders = [];
  final List<Map<String, dynamic>> _historyOrders = [];
  final List<Map<String, dynamic>> _notifications = [];
  late DatabaseReference _sellerNotifsRef;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Аутентификацияланған пайдаланушы табылмады, логинге бағыттау');
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final roleSnapshot =
        await FirebaseDatabase.instance.ref('users/${user.uid}/role').get();
    if (roleSnapshot.value != 'seller') {
      print('Пайдаланушы рөлі сатушы емес, басты бетке бағыттау');
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }

    setState(() {
      _isSeller = true;
      _isLoading = false;
      _sellerNotifsRef = FirebaseDatabase.instance.ref(
        'notifications/sellers/${user.uid}',
      );
    });

    _listenToPendingOrders();
    _listenToHistoryOrders();
    _listenToNotifications();
  }

  void _listenToPendingOrders() {
    if (!_isSeller) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print(
        'Күтудегі тапсырыстар тыңдаушысы үшін пайдаланушы идентификаторы табылмады',
      );
      return;
    }

    print('Сатушы идентификаторы үшін күтудегі тапсырыстарды тыңдау: $userId');
    FirebaseDatabase.instance
        .ref('orders')
        .orderByChild('sellerId')
        .equalTo(userId)
        .onValue
        .listen(
          (event) {
            print(
              'Күтудегі тапсырыстардың суреті алынды: ${event.snapshot.value}',
            );
            if (event.snapshot.exists) {
              final orders = Map<String, dynamic>.from(
                event.snapshot.value as Map,
              );
              setState(() {
                _pendingOrders.clear();
                orders.forEach((key, value) {
                  final order = Map<String, dynamic>.from(value);
                  order['id'] = key;
                  print(
                    'Тапсырыс өңделуде ${order['id']} күйімен: ${order['status']}',
                  );
                  if (order['status'] == 'pending_seller' ||
                      order['status'] == 'new') {
                    print(
                      'Тапсырыс қосу ${order['id']} күтудегі тапсырыстарға',
                    );
                    _pendingOrders.add(order);
                  }
                });
              });
            } else {
              print(
                'Сатушы идентификаторы үшін күтудегі тапсырыстар табылмады: $userId',
              );
              setState(() => _pendingOrders.clear());
            }
          },
          onError: (error) {
            print('Күтудегі тапсырыстарды тыңдау қатесі: $error');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Күтудегі тапсырыстарды жүктеу қатесі: $error'),
              ),
            );
          },
        );
  }

  void _listenToHistoryOrders() {
    if (!_isSeller) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    FirebaseDatabase.instance
        .ref('orders')
        .orderByChild('sellerId')
        .equalTo(userId)
        .onValue
        .listen(
          (event) {
            if (event.snapshot.exists) {
              final orders = Map<String, dynamic>.from(
                event.snapshot.value as Map,
              );
              setState(() {
                _historyOrders.clear();
                orders.forEach((key, value) {
                  final order = Map<String, dynamic>.from(value);
                  order['id'] = key;
                  if (order['status'] != 'pending_seller') {
                    _historyOrders.add(order);
                  }
                });
              });
            } else {
              setState(() => _historyOrders.clear());
            }
          },
          onError: (error) {
            print('Тарихты тыңдау қатесі: $error');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Тарихты жүктеу қатесі: $error')),
            );
          },
        );
  }

  void _listenToNotifications() {
    if (!_isSeller) return;
    _sellerNotifsRef.onValue.listen(
      (event) {
        if (event.snapshot.exists) {
          final notifs = Map<String, dynamic>.from(event.snapshot.value as Map);
          setState(() {
            _notifications.clear();
            notifs.forEach((key, value) {
              final notif = Map<String, dynamic>.from(value);
              notif['id'] = key;
              _notifications.add(notif);
            });
          });
        } else {
          setState(() => _notifications.clear());
        }
      },
      onError: (error) {
        print('Сатушы хабарландыруларын тыңдау қатесі: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Хабарландыруларды жүктеу қатесі: $error')),
        );
      },
    );
  }

  Future<void> _approveOrder(String orderId) async {
    try {
      final orderSnapshot =
          await FirebaseDatabase.instance.ref('orders/$orderId').get();
      if (!orderSnapshot.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Тапсырыс табылмады')));
        return;
      }

      final orderData = Map<String, dynamic>.from(orderSnapshot.value as Map);

      await FirebaseDatabase.instance.ref('orders/$orderId').update({
        'status': 'new',
        'approvedBySellerAt': ServerValue.timestamp,
      });

      final courierNotification = {
        'orderId': orderId,
        'buyerId': orderData['buyerId'],
        'sellerId': orderData['sellerId'],
        'message': 'Жаңа тапсырыс №$orderId жеткізуге дайын',
        'timestamp': ServerValue.timestamp,
        'status': 'new',
        'address': orderData['address'] ?? 'Белгісіз',
        'items': orderData['items'] ?? [],
        'total': orderData['total']?.toDouble() ?? 0.0,
        'confirmationCode': orderData['confirmationCode'] ?? '',
      };

      print('Курьер хабарландыруын жіберу: $courierNotification');
      await FirebaseDatabase.instance
          .ref('notifications/couriers')
          .push()
          .set(courierNotification);

      await FirebaseDatabase.instance
          .ref('notifications/sellers/${orderData['sellerId']}')
          .push()
          .set({
            'orderId': orderId,
            'message': 'Тапсырыс №$orderId курьерлерге жіберілді',
            'timestamp': ServerValue.timestamp,
            'status': 'new',
            'items': orderData['items'] ?? [],
            'total': orderData['total']?.toDouble() ?? 0.0,
          });

      await FirebaseDatabase.instance
          .ref('notifications/buyers/${orderData['buyerId']}')
          .push()
          .set({
            'orderId': orderId,
            'message': 'Сіздің тапсырысыңыз №$orderId сатушы растады',
            'timestamp': ServerValue.timestamp,
            'status': 'new',
          });

      setState(() {
        _notifications.removeWhere((notif) => notif['orderId'] == orderId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Тапсырыс №$orderId курьерлерге жіберілді')),
      );
    } catch (e) {
      print('_approveOrder қатесі: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Қате: $e')));
    }
  }

  Future<void> _rejectOrder(String orderId) async {
    try {
      await FirebaseDatabase.instance.ref('orders/$orderId').update({
        'status': 'seller_rejected',
        'rejectedBySellerAt': ServerValue.timestamp,
      });

      final orderSnapshot =
          await FirebaseDatabase.instance.ref('orders/$orderId').get();
      final orderData = Map<String, dynamic>.from(orderSnapshot.value as Map);

      await FirebaseDatabase.instance.ref('notifications/couriers').push().set({
        'orderId': orderId,
        'buyerId': orderData['buyerId'],
        'sellerId': orderData['sellerId'],
        'message': 'Тапсырыс №$orderId сатушыдан бас тартылды',
        'timestamp': ServerValue.timestamp,
        'status': 'seller_rejected',
        'address': orderData['address'] ?? 'Белгісіз',
        'items': orderData['items'] ?? [],
        'total': orderData['total']?.toDouble() ?? 0.0,
        'confirmationCode': orderData['confirmationCode'] ?? '',
      });

      await FirebaseDatabase.instance
          .ref('notifications/buyers/${orderData['buyerId']}')
          .push()
          .set({
            'orderId': orderId,
            'message': 'Сіздің тапсырысыңыз №$orderId сатушыдан бас тартылды',
            'timestamp': ServerValue.timestamp,
            'status': 'seller_rejected',
          });

      await FirebaseDatabase.instance
          .ref('notifications/sellers/${orderData['sellerId']}')
          .push()
          .set({
            'orderId': orderId,
            'message': 'Тапсырыс №$orderId сатушыдан бас тартылды',
            'timestamp': ServerValue.timestamp,
            'status': 'seller_rejected',
          });

      setState(() {
        _pendingOrders.removeWhere((order) => order['id'] == orderId);
        _notifications.removeWhere((notif) => notif['orderId'] == orderId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Тапсырыс №$orderId сатушыдан бас тартылды')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Қате: $e')));
    }
  }

  Future<void> _deleteNotification(String notifId) async {
    await _sellerNotifsRef.child(notifId).remove();
    setState(() {
      _notifications.removeWhere((notif) => notif['id'] == notifId);
    });
  }

  Future<void> _transferToCourier(String orderId) async {
    try {
      final orderSnapshot =
          await FirebaseDatabase.instance.ref('orders/$orderId').get();
      if (!orderSnapshot.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Тапсырыс табылмады')));
        return;
      }

      final orderData = Map<String, dynamic>.from(orderSnapshot.value as Map);
      await FirebaseDatabase.instance.ref('orders/$orderId').update({
        'status': 'new',
        'readyForCourierAt': ServerValue.timestamp,
      });

      await FirebaseDatabase.instance.ref('notifications/couriers').push().set({
        'orderId': orderId,
        'buyerId': orderData['buyerId'],
        'sellerId': orderData['sellerId'],
        'message': 'Тапсырыс №$orderId жеткізуге дайын',
        'timestamp': ServerValue.timestamp,
        'status': 'new',
        'address': orderData['address'] ?? 'Белгісіз',
        'items': orderData['items'] ?? [],
        'total': orderData['total']?.toDouble() ?? 0.0,
      });

      await FirebaseDatabase.instance
          .ref('notifications/buyers/${orderData['buyerId']}')
          .push()
          .set({
            'orderId': orderId,
            'message': 'Сіздің тапсырысыңыз №$orderId жеткізуге дайын',
            'timestamp': ServerValue.timestamp,
            'status': 'new',
          });

      await FirebaseDatabase.instance
          .ref('notifications/sellers/${orderData['sellerId']}')
          .push()
          .set({
            'orderId': orderId,
            'message': 'Тапсырыс №$orderId курьерлерге жіберілді',
            'timestamp': ServerValue.timestamp,
            'status': 'new',
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Тапсырыс №$orderId курьерлерге жіберілді')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Қате: $e')));
    }
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final timestamp =
        notif['timestamp'] != null
            ? DateFormat('dd.MM.yyyy HH:mm').format(
              DateTime.fromMillisecondsSinceEpoch(notif['timestamp'] as int),
            )
            : 'Күні көрсетілмеген';

    return Dismissible(
      key: Key(notif['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteNotification(notif['id']),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: const Icon(Icons.notifications, color: Colors.orange),
          title: Text(notif['message'] ?? 'Хабарландыру'),
          subtitle: Text('Күні: $timestamp\nКүйі: ${notif['status']}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (notif['status'] == 'pending_seller' &&
                  notif['orderId'] != null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _approveOrder(notif['orderId']),
                  child: const Text(
                    'Растау',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _deleteNotification(notif['id']),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final timestamp =
        order['timestamp'] != null
            ? DateFormat('dd.MM.yyyy HH:mm').format(
              DateTime.fromMillisecondsSinceEpoch(order['timestamp'] as int),
            )
            : 'Күні көрсетілмеген';
    final items = order['items'] as List<dynamic>? ?? [];

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: const Icon(Icons.local_shipping, color: Colors.blue),
          title: Text('Тапсырыс №${order['id']}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Сатып алушы: ${order['buyerId'] ?? 'Белгісіз'}'),
              Text('Сомасы: ${order['total'] ?? 0}₸'),
              Text('Күні: $timestamp'),
              Text(
                'Растау коды: ${order['confirmationCode'] ?? 'Көрсетілмеген'}',
              ),
              Text('Мекенжай: ${order['address'] ?? 'Көрсетілмеген'}'),
              Text('Күйі: ${order['status'] ?? 'Белгісіз'}'),
              const SizedBox(height: 4),
              Text(
                'Тауарлар: ${items.isEmpty ? 'Жоқ' : items.map((item) => item['name'] ?? 'Белгісіз').join(', ')}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          trailing:
              order['status'] == 'pending_seller'
                  ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _approveOrder(order['id']),
                        child: const Text(
                          'Жинау',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _rejectOrder(order['id']),
                        child: const Text(
                          'Бас тарту',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  )
                  : order['status'] == 'preparing'
                  ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _transferToCourier(order['id']),
                    child: const Text(
                      'Курьерге беру',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                  : Text(
                    'Күйі: ${order['status']}',
                    style: const TextStyle(color: Colors.grey),
                  ),
        ),
      ),
    );
  }

  Widget _buildHistoryOrderCard(Map<String, dynamic> order) {
    final timestamp =
        order['timestamp'] != null
            ? DateFormat('dd.MM.yyyy HH:mm').format(
              DateTime.fromMillisecondsSinceEpoch(order['timestamp'] as int),
            )
            : 'Күні көрсетілмеген';
    final items = order['items'] as List<dynamic>? ?? [];

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: const Icon(Icons.history, color: Colors.grey),
          title: Text('Тапсырыс №${order['id']}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Сатып алушы: ${order['buyerId'] ?? 'Белгісіз'}'),
              Text('Сомасы: ${order['total'] ?? 0}₸'),
              Text('Күні: $timestamp'),
              Text(
                'Растау коды: ${order['confirmationCode'] ?? 'Көрсетілмеген'}',
              ),
              Text('Мекенжай: ${order['address'] ?? 'Көрсетілмеген'}'),
              Text('Күйі: ${order['status'] ?? 'Белгісіз'}'),
              const SizedBox(height: 4),
              Text(
                'Тауарлар: ${items.isEmpty ? 'Жоқ' : items.map((item) => item['name'] ?? 'Белгісіз').join(', ')}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          trailing: const Icon(Icons.history, color: Colors.grey),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isSeller) {
      return const Scaffold(
        body: Center(child: Text('Қате: Сіз сатушы емессіз')),
      );
    }

    final totalOrders = _pendingOrders.length + _historyOrders.length;
    final deliveredCount =
        _historyOrders.where((o) => o['status'] == 'delivered').length;
    final rejectedCount =
        _historyOrders.where((o) => o['status'] == 'seller_rejected').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Сатушы панелі',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Хабарландырулар',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          if (_notifications.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Хабарландырулар жоқ',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._notifications.map(_buildNotificationCard),
          const SizedBox(height: 24),
          const Text(
            'Күтудегі тапсырыстар',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          if (_pendingOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Күтудегі тапсырыстар жоқ',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._pendingOrders.map(_buildOrderCard),
          const SizedBox(height: 24),
          const Text(
            'Тапсырыстар тарихы',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          if (_historyOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Тарих бос', style: TextStyle(color: Colors.grey)),
            )
          else
            ..._historyOrders.map(_buildHistoryOrderCard),
          const SizedBox(height: 24),
          Card(
            margin: const EdgeInsets.all(8),
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📊 тапсырыстар статистикасы',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🛒 Барлық тапсырыстар:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$totalOrders',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '✅ Жеткізілді:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        '$deliveredCount',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '❌ Сатушыдан бас тартылды:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        '$rejectedCount',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

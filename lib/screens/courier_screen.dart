import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'confirm_delivery_screen.dart'; // Добавляем импорт для экрана подтверждения

class CourierScreen extends StatefulWidget {
  const CourierScreen({super.key});

  @override
  State<CourierScreen> createState() => _CourierScreenState();
}

class _CourierScreenState extends State<CourierScreen> {
  final List<Map<String, dynamic>> _orders = [];
  final List<Map<String, dynamic>> _historyOrders = [];
  late DatabaseReference _courierNotificationsRef;
  bool _hasNewOrderNotification = true;
  bool _isCourier = false;
  String _confirmationCode = '';
  Map<String, String> _buyerAddresses = {};
  Map<String, List<Map<String, dynamic>>> _orderItems = {};

  @override
  void initState() {
    super.initState();
    _courierNotificationsRef = FirebaseDatabase.instance.ref(
      'notifications/couriers',
    );
    _checkUserRole();
    _listenToCourierNotifications();
    _listenToHistoryOrders();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final roleSnapshot =
        await FirebaseDatabase.instance.ref('users/${user.uid}/role').get();
    if (roleSnapshot.value != 'courier') {
      setState(() => _isCourier = false);
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() => _isCourier = true);
    }
  }

  Future<void> _loadBuyerAddress(String buyerId) async {
    final snapshot =
        await FirebaseDatabase.instance.ref('users/$buyerId').get();
    if (snapshot.exists) {
      final userData = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() {
        _buyerAddresses[buyerId] = userData['address'] ?? 'Белгісіз';
      });
    }
  }

  Future<void> _loadOrderItems(String orderId) async {
    final snapshot =
        await FirebaseDatabase.instance.ref('orders/$orderId').get();
    if (snapshot.exists) {
      final orderData = Map<String, dynamic>.from(snapshot.value as Map);
      final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
      setState(() {
        _orderItems[orderId] = items;
      });
    }
  }

  void _listenToCourierNotifications() {
    print('Starting to listen for courier notifications');
    _courierNotificationsRef.onChildAdded.listen(
      (event) async {
        print('Received notification: ${event.snapshot.value}');
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          final orderData = Map<String, dynamic>.from(data);
          orderData['notificationId'] = event.snapshot.key;

          // Проверяем, что заказ не привязан к курьеру
          final orderSnapshot =
              await FirebaseDatabase.instance
                  .ref('orders/${orderData['orderId']}')
                  .get();
          if (orderSnapshot.exists) {
            final orderDetails = Map<String, dynamic>.from(
              orderSnapshot.value as Map,
            );
            if (orderDetails['courierId'] != null) {
              print('Order already taken by courier: ${orderData['orderId']}');
              return; // Пропускаем, если заказ уже принят
            }

            // Загружаем адрес и товары
            await _loadBuyerAddress(orderData['buyerId']);
            await _loadOrderItems(orderData['orderId']);

            setState(() {
              if (!_orders.any((o) => o['orderId'] == orderData['orderId'])) {
                print('Adding new order: ${orderData['orderId']}');
                _orders.add(orderData);
                _hasNewOrderNotification = true;
              }
            });

            // Показываем уведомление
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('📦 Новый заказ: №${orderData['orderId']}'),
                ),
              );
            }
          } else {
            print('Order not found: ${orderData['orderId']}');
          }
        }
      },
      onError: (error) {
        print('Error in courier notifications: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка получения уведомлений: $error')),
          );
        }
      },
    );
  }

  void _listenToHistoryOrders() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    FirebaseDatabase.instance
        .ref('orders')
        .orderByChild('courierId')
        .equalTo(userId)
        .onValue
        .listen((event) async {
          if (event.snapshot.exists) {
            final orders = Map<String, dynamic>.from(
              event.snapshot.value as Map,
            );
            setState(() {
              _historyOrders.clear();
              orders.forEach((key, value) {
                final orderData = Map<String, dynamic>.from(value);
                orderData['orderId'] = key;
                _historyOrders.add(orderData);
              });
            });

            // Очистка уведомлений для завершенных заказов
            for (var order in _historyOrders) {
              if (order['status'] == 'delivered') {
                final notifSnapshot =
                    await FirebaseDatabase.instance
                        .ref('notifications/couriers')
                        .orderByChild('orderId')
                        .equalTo(order['orderId'])
                        .get();
                if (notifSnapshot.exists) {
                  final notifs = Map<String, dynamic>.from(
                    notifSnapshot.value as Map,
                  );
                  notifs.forEach((notifId, _) {
                    FirebaseDatabase.instance
                        .ref('notifications/couriers/$notifId')
                        .remove();
                  });
                }
              }
            }
          } else {
            setState(() => _historyOrders.clear());
          }
        });
  }

  Future<void> _acceptOrder(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final orderSnapshot =
          await FirebaseDatabase.instance.ref('orders/$orderId').get();
      if (!orderSnapshot.exists ||
          orderSnapshot.child('courierId').value != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заказ уже принят другим курьером')),
        );
        return;
      }

      // Обновляем статус заказа и добавляем ID курьера
      await FirebaseDatabase.instance.ref('orders/$orderId').update({
        'status': 'in_transit',
        'courierId': user.uid,
        'acceptedAt': ServerValue.timestamp,
      });

      // Удаляем уведомление о новом заказе
      await FirebaseDatabase.instance
          .ref('notifications/couriers/${orderData['notificationId']}')
          .remove();

      // Отправляем уведомления
      await FirebaseDatabase.instance
          .ref('notifications/buyers/${orderData['buyerId']}')
          .push()
          .set({
            'orderId': orderId,
            'message': 'Ваш заказ №$orderId принят курьером',
            'timestamp': ServerValue.timestamp,
            'status': 'in_transit',
          });

      await FirebaseDatabase.instance
          .ref('notifications/sellers/${orderData['sellerId']}')
          .push()
          .set({
            'orderId': orderId,
            'message': 'Заказ №$orderId принят курьером',
            'timestamp': ServerValue.timestamp,
            'status': 'in_transit',
          });

      // Обновляем локальное состояние
      setState(() {
        _orders.removeWhere((order) => order['orderId'] == orderId);
        _historyOrders.add({
          ...orderData,
          'status': 'in_transit',
          'courierId': user.uid,
        });
      });

      // Показываем диалог с кодом подтверждения
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Код подтверждения'),
              content: Text(
                'Код подтверждения для заказа №$orderId: ${orderData['confirmationCode']}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Заказ №$orderId принят')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при принятии заказа: $e')));
    }
  }

  Future<void> _rejectOrder(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    try {
      await FirebaseDatabase.instance.ref('orders/$orderId').update({
        'status': 'courier_rejected',
        'courierId': null,
      });

      await FirebaseDatabase.instance
          .ref('notifications/couriers/${orderData['notificationId']}')
          .remove();

      await FirebaseDatabase.instance
          .ref('notifications/buyers/${orderData['buyerId']}')
          .push()
          .set({
            'orderId': orderId,
            'message': 'Курьер отказался от заказа №$orderId',
            'timestamp': ServerValue.timestamp,
            'status': 'courier_rejected',
          });

      await FirebaseDatabase.instance
          .ref('notifications/sellers/${orderData['sellerId']}')
          .push()
          .set({
            'orderId': orderId,
            'message': 'Курьер отказался от заказа №$orderId',
            'timestamp': ServerValue.timestamp,
            'status': 'courier_rejected',
          });

      final existingNotifications =
          await FirebaseDatabase.instance
              .ref('notifications/couriers')
              .orderByChild('orderId')
              .equalTo(orderId)
              .get();
      if (existingNotifications.exists) {
        return;
      }

      await FirebaseDatabase.instance.ref('notifications/couriers').push().set({
        'orderId': orderId,
        'buyerId': orderData['buyerId'],
        'sellerId': orderData['sellerId'],
        'message': 'Жаңа тапсырыс №$orderId жүктемелік',
        'timestamp': ServerValue.timestamp,
        'status': 'new',
        'address': orderData['address'] ?? 'Неизвестно',
        'items': orderData['items'] ?? [],
        'total': orderData['total']?.toDouble() ?? 0.0,
      });

      setState(() {
        _orders.removeWhere((order) => order['orderId'] == orderId);
        _historyOrders.add({...orderData, 'status': 'courier_rejected'});
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Тапсырыс қабылдауда қате: $e')));
    }
  }

  Future<void> _addToCart(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final cartRef = FirebaseDatabase.instance.ref('cart/${user.uid}');
    final orderItems = _orderItems[orderId] ?? [];
    for (var item in orderItems) {
      await cartRef.child('$orderId-${item['id']}').set({
        'orderId': orderId,
        'itemId': item['id'],
        'name': item['name'],
        'price': item['price'],
        'quantity': item['quantity'] ?? 1,
      });
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Тауарлар себетке қосылды')));
  }

  Future<void> _deleteHistoryOrder(
    String orderId,
    String notificationId,
  ) async {
    await FirebaseDatabase.instance
        .ref('notifications/couriers/$notificationId')
        .remove();
    setState(() {
      _historyOrders.removeWhere((order) => order['orderId'] == orderId);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Тарихтан тапсырыс өшірілді')));
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    return FutureBuilder(
      future: FirebaseDatabase.instance.ref('orders/${order['orderId']}').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data?.value == null) {
          return const SizedBox.shrink();
        }
        final orderData = Map<String, dynamic>.from(
          snapshot.data!.value as Map,
        );
        final timestamp =
            orderData['timestamp'] != null
                ? DateFormat('dd.MM.yyyy HH:mm').format(
                  DateTime.fromMillisecondsSinceEpoch(
                    orderData['timestamp'] as int,
                  ),
                )
                : 'Деректер белгісіз';
        final confirmationCode = orderData['confirmationCode'] ?? 'Белгісіз';
        final address = _buyerAddresses[order['buyerId']] ?? 'Жүктелуде...';
        final items = _orderItems[order['orderId']] ?? [];

        Color statusColor;
        IconData statusIcon;
        String statusText;
        String message;

        switch (order['status']) {
          case 'new':
            statusColor = Colors.orange;
            statusIcon = Icons.access_time;
            statusText = 'Жаңа';
            message = 'Жаңа тапсырыс';
            break;
          case 'seller_rejected':
            statusColor = Colors.red;
            statusIcon = Icons.cancel;
            statusText = 'Сатушыдан бас тартылды';
            message = 'Сатушы тапсырыстан бас тартты';
            break;
          case 'in_transit':
            statusColor = Colors.blue;
            statusIcon = Icons.local_shipping;
            statusText = 'Жолда';
            message = 'Тапсырыс жолда';
            break;
          case 'delivered':
            statusColor = Colors.green;
            statusIcon = Icons.check_circle;
            statusText = 'Жеткізілді';
            message = 'Тапсырыс жеткізілді';
            break;
          default:
            statusColor = Colors.grey;
            statusIcon = Icons.info_outline;
            statusText = 'Белгісіз';
            message = 'Белгісіз күй';
        }

        return Dismissible(
          key: Key(order['orderId']),
          direction: DismissDirection.horizontal,
          onDismissed: (direction) {
            if (direction == DismissDirection.startToEnd) {
              _rejectOrder(order['orderId'], order);
            } else if (direction == DismissDirection.endToStart) {
              _addToCart(order['orderId']);
            }
          },
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.close, color: Colors.white),
          ),
          secondaryBackground: Container(
            color: Colors.green,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.shopping_cart, color: Colors.white),
          ),
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, statusColor.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                title: Row(
                  children: [
                    Icon(statusIcon, color: statusColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Тапсырыс №${order['orderId']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Күйі: $statusText'),
                    Text('Хабар: $message'),
                    Text('Сатып алушы: ${order['buyerId']}'),
                    Text('Күні: $timestamp'),
                    Text('Растау коды: $confirmationCode'),
                    Text('Мекенжай: $address'),
                    const SizedBox(height: 4),
                    Text(
                      'Тауарлар: ${items.isEmpty ? 'Жоқ' : items.map((item) => item['name']).join(', ')}',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                trailing:
                    order['status'] == 'new' ||
                            order['status'] == 'seller_rejected'
                        ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              onPressed:
                                  () => _acceptOrder(order['orderId'], order),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed:
                                  () => _rejectOrder(order['orderId'], order),
                            ),
                          ],
                        )
                        : order['status'] == 'in_transit'
                        ? IconButton(
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => ConfirmDeliveryScreen(
                                      orderId: order['orderId'],
                                      address: address,
                                      total:
                                          orderData['total']?.toDouble() ?? 0.0,
                                      items: items,
                                      confirmationCode: confirmationCode,
                                    ),
                              ),
                            );
                          },
                        )
                        : null,
              ),
            ),
          ),
        ).animate().fadeIn(
          delay: Duration(milliseconds: 200 * index),
          duration: 500.ms,
        );
      },
    );
  }

  Widget _buildHistoryOrderCard(Map<String, dynamic> order, int index) {
    return FutureBuilder(
      future: FirebaseDatabase.instance.ref('orders/${order['orderId']}').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data?.value == null) {
          return const SizedBox.shrink();
        }
        final orderData = Map<String, dynamic>.from(
          snapshot.data!.value as Map,
        );
        final timestamp =
            orderData['timestamp'] != null
                ? DateFormat('dd.MM.yyyy HH:mm').format(
                  DateTime.fromMillisecondsSinceEpoch(
                    orderData['timestamp'] as int,
                  ),
                )
                : 'Деректер белгісіз';
        final confirmationCode = orderData['confirmationCode'] ?? 'Белгісіз';
        final address = _buyerAddresses[order['buyerId']] ?? 'Жүктелуде...';
        final items = _orderItems[order['orderId']] ?? [];

        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) {
                final items = _orderItems[order['orderId']] ?? [];
                return AlertDialog(
                  title: Text('Тапсырыс №${order['orderId']} тауарлары'),
                  content:
                      items.isEmpty
                          ? const Text('Тауарлар жоқ')
                          : SingleChildScrollView(
                            child: Column(
                              children:
                                  items
                                      .map(
                                        (item) => ListTile(
                                          title: Text(
                                            item['name'] ?? 'Белгісіз',
                                          ),
                                          subtitle: Text(
                                            'Бағасы: ${item['price'] ?? 0}₸, Саны: ${item['quantity'] ?? 1}',
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Жабу'),
                    ),
                  ],
                );
              },
            );
          },
          onLongPress: () {
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Тапсырысты өшіру'),
                    content: const Text(
                      'Бұл тапсырысты тарихтан өшіргіңіз келеді ме?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Жоқ'),
                      ),
                      TextButton(
                        onPressed: () {
                          _deleteHistoryOrder(
                            order['orderId'],
                            order['notificationId'],
                          );
                          Navigator.pop(context);
                        },
                        child: const Text('Иә'),
                      ),
                    ],
                  ),
            );
          },
          child: Card(
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
              child: ListTile(
                title: Text(
                  'Тапсырыс №${order['orderId']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Сатып алушы: ${order['buyerId']}'),
                    Text('Күні: $timestamp'),
                    Text('Растау коды: $confirmationCode'),
                    Text('Мекенжай: $address'),
                    Text('Күй: ${order['status']}'),
                    const SizedBox(height: 4),
                    Text(
                      'Тауарлар: ${items.isEmpty ? 'Жоқ' : items.map((item) => item['name']).join(', ')}',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                trailing:
                    order['status'] == 'in_transit'
                        ? IconButton(
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => ConfirmDeliveryScreen(
                                      orderId: order['orderId'],
                                      address: address,
                                      total:
                                          orderData['total']?.toDouble() ?? 0.0,
                                      items: items,
                                      confirmationCode: confirmationCode,
                                    ),
                              ),
                            );
                          },
                        )
                        : const Icon(Icons.history, color: Colors.grey),
              ),
            ),
          ),
        ).animate().fadeIn(
          delay: Duration(milliseconds: 200 * index),
          duration: 500.ms,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCourier) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final deliveredCount =
        _historyOrders.where((o) => o['status'] == 'delivered').length;
    final rejectedCount =
        _historyOrders.where((o) => o['status'] == 'courier_rejected').length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.greenAccent, Colors.blueAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Новые заказы',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (_orders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Нет новых заказов',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else
              ..._orders.asMap().entries.map(
                (entry) => _buildOrderCard(entry.value, entry.key),
              ),
            const SizedBox(height: 16),
            const Text(
              'Мои заказы',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            StreamBuilder(
              stream:
                  FirebaseDatabase.instance
                      .ref('orders')
                      .orderByChild('courierId')
                      .equalTo(FirebaseAuth.instance.currentUser?.uid)
                      .onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Нет заказов в доставке',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }
                final orders = Map<String, dynamic>.from(
                  snapshot.data!.snapshot.value as Map,
                );
                return Column(
                  children:
                      orders.entries.map((entry) {
                        final order = Map<String, dynamic>.from(entry.value);
                        order['id'] = entry.key;
                        final address =
                            _buyerAddresses[order['buyerId']] ?? 'Загрузка...';
                        final items = _orderItems[order['id']] ?? [];

                        // Загружаем адрес и товары, если они еще не загружены
                        if (_buyerAddresses[order['buyerId']] == null) {
                          _loadBuyerAddress(order['buyerId']);
                        }
                        if (_orderItems[order['id']] == null) {
                          _loadOrderItems(order['id']);
                        }

                        return Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.white, Colors.yellow.shade50],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ListTile(
                              title: Text(
                                'Заказ №${order['id']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Адрес: $address'),
                                  Text('Статус: ${order['status']}'),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Товары: ${items.isEmpty ? 'Нет' : items.map((item) => item['name']).join(', ')}',
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                              trailing:
                                  order['status'] == 'in_transit'
                                      ? IconButton(
                                        icon: const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (
                                                    context,
                                                  ) => ConfirmDeliveryScreen(
                                                    orderId: order['id'],
                                                    address: address,
                                                    total:
                                                        order['total']
                                                            ?.toDouble() ??
                                                        0.0,
                                                    items: items,
                                                    confirmationCode:
                                                        order['confirmationCode'] ??
                                                        'Неизвестно',
                                                  ),
                                            ),
                                          );
                                        },
                                      )
                                      : null,
                            ),
                          ),
                        );
                      }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'История заказов',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (_historyOrders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'История пуста',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else
              ..._historyOrders.asMap().entries.map(
                (entry) => _buildHistoryOrderCard(entry.value, entry.key),
              ),
            const SizedBox(height: 16),
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.purple.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📊 Статистика доставок',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('✅ Доставлено: $deliveredCount'),
                      Text('❌ Отклонено: $rejectedCount'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

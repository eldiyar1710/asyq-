import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SellerNotificationsScreen extends StatefulWidget {
  const SellerNotificationsScreen({super.key});

  @override
  _SellerNotificationsScreenState createState() =>
      _SellerNotificationsScreenState();
}

class _SellerNotificationsScreenState extends State<SellerNotificationsScreen> {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (userId != null) {
      _loadNotifications();
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пайдаланушы авторизацияланбаған')),
      );
    }
  }

  Future<void> _loadNotifications() async {
    final notificationsRef = FirebaseDatabase.instance.ref(
      'notifications/sellers/$userId',
    );
    try {
      // Жаңа хабарландыруларды жүктеу
      final snapshot = await notificationsRef.get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _notifications.clear();
          data.forEach((key, value) {
            _notifications.add({
              'id': key,
              ...Map<String, dynamic>.from(value),
            });
          });
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }

      notificationsRef.onChildAdded.listen((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          setState(() {
            _notifications.add({
              'id': event.snapshot.key,
              ...Map<String, dynamic>.from(data),
            });
          });
        }
      });

      notificationsRef.onChildRemoved.listen((event) {
        setState(() {
          _notifications.removeWhere((n) => n['id'] == event.snapshot.key);
        });
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Хабарландыруларды жүктеу қатесі: $e')),
      );
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseDatabase.instance
          .ref('notifications/sellers/$userId/$notificationId')
          .remove();
      setState(() {
        _notifications.removeWhere((n) => n['id'] == notificationId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хабарландыру оқылды деп белгіленді')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Хабарландыруды өшіру қатесі: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сатушы хабарландырулары'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _notifications.isEmpty
              ? const Center(child: Text('Жаңа хабарландырулар жоқ'))
              : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  final timestamp =
                      notification['timestamp'] is int
                          ? DateTime.fromMillisecondsSinceEpoch(
                            notification['timestamp'],
                          )
                          : DateTime.now();
                  final formattedDate = DateFormat(
                    'dd.MM.yyyy HH:mm',
                  ).format(timestamp);

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        notification['message'] ?? 'Жаңа хабарландыру',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            'Тапсырыс №${notification['orderId'] ?? 'белгісіз'}',
                          ),
                          Text(
                            'Тауар: ${notification['itemName'] ?? 'көрсетілмеген'}',
                          ),
                          Text(
                            'Саны: ${notification['quantity']?.toString() ?? 'көрсетілмеген'}',
                          ),
                          Text('Сомасы: ${notification['total'] ?? '0'}₸'),
                          Text('Күні: $formattedDate'),
                          if (notification['status'] != null)
                            Text(
                              'Күйі: ${_getStatusText(notification['status'])}',
                              style: TextStyle(
                                color: _getStatusColor(notification['status']),
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                        onPressed: () => _markAsRead(notification['id']),
                      ),
                    ),
                  );
                },
              ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'new':
        return 'Новый';
      case 'preparing':
        return 'Готовится';
      case 'in_transit':
        return 'В пути';
      case 'delivered':
        return 'Доставлен';
      case 'courier_rejected':
        return 'Курьер отказался';
      default:
        return 'Неизвестно';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new':
        return Colors.orange;
      case 'in_transit':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'courier_rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

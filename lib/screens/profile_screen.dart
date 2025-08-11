import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'confirm_delivery_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  bool _loading = true;
  Map<String, dynamic>? _userData;
  bool _isUploading = false;
  String? _uploadError;
  double _balance = 0;
  bool _hasCard = false;
  late final DatabaseReference _userRef;
  late final DatabaseReference _generalNotifsRef;
  List<Map<String, dynamic>> _buyerOrders = [];
  late final DatabaseReference _buyerOrdersRef;
  late final DatabaseReference _buyerNotifsRef;
  List<Map<String, dynamic>> _newOrders = [];
  List<Map<String, dynamic>> _historyOrders = [];
  late final DatabaseReference _courierNotifsRef;
  bool _hasNewOrderNotification = false;
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _isEditing = false;
  bool _isSelectionMode = false;
  Set<String> _selectedOrderIds = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _userRef = FirebaseDatabase.instance.ref('users/${user!.uid}');
    _generalNotifsRef = FirebaseDatabase.instance.ref(
      'notifications/${user!.uid}',
    );
    _buyerOrdersRef = FirebaseDatabase.instance.ref('orders');
    _buyerNotifsRef = FirebaseDatabase.instance.ref(
      'notifications/buyers/${user!.uid}',
    );
    _courierNotifsRef = FirebaseDatabase.instance.ref('notifications/couriers');
    _loadUserData();
    _listenToGeneralNotifications();
    _listenToBuyerOrders();
    _listenToCourierNotifications();
    _loadProducts();
    _loadReviews();
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final snapshot = await _userRef.get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() {
        _userData = data;
        _hasCard = data['hasCard'] ?? false;
        _balance = (data['cardInfo']?['balance'] ?? 0).toDouble();
        _nameController.text = data['name'] ?? '';
        _addressController.text = data['address'] ?? '';
        _loading = false;
      });
      _controller.forward();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _uploadImage() async {
    try {
      setState(() => _isUploading = true);
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final ref = FirebaseStorage.instance
          .ref()
          .child('user_images')
          .child('${user!.uid}.jpg');
      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();
      await user!.updatePhotoURL(url);
      await _userRef.update({'avatarUrl': url});
      setState(() => _isUploading = false);
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadError = 'Жүктеу қатесі: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Жүктеу қатесі: $e')));
      }
    }
  }

  Future<void> _addCard() async {
    const initialBalance = 100000.0;
    await _userRef.update({
      'hasCard': true,
      'cardInfo': {
        'balance': initialBalance,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
    });
    setState(() {
      _hasCard = true;
      _balance = initialBalance;
    });
  }

  Future<void> _changePassword() async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Құпия сөзді қалпына келтіру хаты жіберілді'),
      ),
    );
  }

  Future<void> _updateUserData() async {
    try {
      await _userRef.update({
        'name': _nameController.text,
        'address': _addressController.text,
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Деректер жаңартылды')));
      setState(() {
        _isEditing = false;
      });
      _loadUserData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Қате: $e')));
    }
  }

  void _listenToGeneralNotifications() {
    _generalNotifsRef.onValue.listen((event) {});
  }

  Future<void> _deleteGeneralNotif(String key) async {
    await _generalNotifsRef.child(key).remove();
  }

  Widget _buildGeneralNotification(String key, Map data) {
    return Dismissible(
      key: Key(key),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteGeneralNotif(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: const Icon(Icons.notifications),
          title: Text(data['title'] ?? data['message'] ?? 'Хабарландыру'),
          subtitle: data['body'] != null ? Text(data['body']) : null,
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _deleteGeneralNotif(key),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralNotifsSection() {
    return StreamBuilder<DatabaseEvent>(
      stream: _generalNotifsRef.onValue,
      builder: (ctx, snap) {
        if (snap.hasData && snap.data!.snapshot.value != null) {
          final m = Map<String, dynamic>.from(snap.data!.snapshot.value as Map);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Хабарландырулар',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...m.entries.map(
                (e) => _buildGeneralNotification(e.key, e.value),
              ),
            ],
          );
        }
        return const SizedBox();
      },
    );
  }

  void _listenToBuyerOrders() {
    _buyerOrdersRef.onValue.listen((evt) {
      final d = evt.snapshot.value as Map<dynamic, dynamic>?;
      if (d != null) {
        final list = <Map<String, dynamic>>[];
        d.forEach((k, v) {
          final ord = Map<String, dynamic>.from(v);
          if (ord['buyerId'] == user!.uid) {
            ord['id'] = k;
            list.add(ord);
          }
        });
        setState(() => _buyerOrders = list);
      }
    });
  }

  Widget _buildBuyerOrderCard(Map ord) {
    final status = ord['status'] ?? 'белгісіз';
    Color c;
    IconData ic;
    String statusText;
    switch (status) {
      case 'new':
        c = Colors.orange;
        ic = Icons.access_time;
        statusText = 'Жаңа';
        break;
      case 'in_transit':
        c = Colors.blue;
        ic = Icons.local_shipping;
        statusText = 'Жолда';
        break;
      case 'delivered':
        c = Colors.green;
        ic = Icons.check_circle;
        statusText = 'Жеткізілді';
        break;
      default:
        c = Colors.grey;
        ic = Icons.info_outline;
        statusText = 'Белгісіз';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: c.withOpacity(0.2), blurRadius: 6)],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: c.withOpacity(0.2),
          child: Icon(ic, color: c),
        ),
        title: Text('Тапсырыс №${ord['id']}'),
        subtitle: Text(
          'Күйі: $statusText\nМекенжай: ${ord['address'] ?? 'Көрсетілмеген'}\nРастау коды: ${ord['confirmationCode'] ?? 'Көрсетілмеген'}',
        ),
        trailing:
            status == 'in_transit'
                ? IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () {
                    _showConfirmationCodeDialog(ord);
                  },
                )
                : null,
      ),
    );
  }

  Future<void> _showConfirmationCodeDialog(Map ord) async {
    final TextEditingController codeController = TextEditingController();
    final String orderId = ord['id'];
    final String correctCode = ord['confirmationCode'] ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Тапсырыс №$orderId растау'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Сатып алушыдан растау кодын енгізіңіз:'),
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'Растау коды',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Болдырмау'),
            ),
            ElevatedButton(
              onPressed: () async {
                final enteredCode = codeController.text.trim();
                if (enteredCode == correctCode) {
                  await _confirmDelivery(orderId, ord);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Растау коды қате!')));
                }
              },
              child: Text('Растау'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelivery(String orderId, Map ord) async {
    try {
      // Тапсырыс күйін жаңарту
      await FirebaseDatabase.instance.ref('orders/$orderId').update({
        'status': 'delivered',
        'deliveredAt': ServerValue.timestamp,
      });

      // Курьер хабарламасын өшіру, егер бар болса
      if (ord['notificationId'] != null) {
        await _courierNotifsRef.child(ord['notificationId']).remove();
      }

      // Барлық тараптарға хабарламалар жіберу
      await FirebaseDatabase.instance
          .ref('notifications/buyers/${ord['buyerId']}')
          .push()
          .set({
            'orderId': orderId,
            'message': 'Сіздің тапсырысыңыз №$orderId жеткізілді',
            'timestamp': ServerValue.timestamp,
            'status': 'delivered',
          });

      await FirebaseDatabase.instance
          .ref('notifications/sellers/${ord['sellerId']}')
          .push()
          .set({
            'orderId': orderId,
            'message': 'Тапсырыс №$orderId жеткізілді',
            'timestamp': ServerValue.timestamp,
            'status': 'delivered',
          });

      // Курьерге хабарлама
      await FirebaseDatabase.instance.ref('notifications/couriers').push().set({
        'orderId': orderId,
        'message': 'Сіз тапсырыс №$orderId жеткіздіңіз',
        'timestamp': ServerValue.timestamp,
        'status': 'delivered',
        'courierId': FirebaseAuth.instance.currentUser?.uid,
      });

      // Осы тапсырысқа байланысты ескі хабарламаларды өшіру
      final notifSnapshot =
          await FirebaseDatabase.instance
              .ref('notifications/couriers')
              .orderByChild('orderId')
              .equalTo(orderId)
              .get();
      if (notifSnapshot.exists) {
        final notifs = Map<String, dynamic>.from(notifSnapshot.value as Map);
        notifs.forEach((notifId, _) {
          FirebaseDatabase.instance
              .ref('notifications/couriers/$notifId')
              .remove();
        });
      }

      setState(() {
        _newOrders.removeWhere((o) => o['orderId'] == orderId);
        final historyOrder = _historyOrders.firstWhere(
          (o) => o['orderId'] == orderId,
          orElse: () => {...ord, 'status': 'delivered'},
        );
        historyOrder['status'] = 'delivered';
        if (!_historyOrders.contains(historyOrder)) {
          _historyOrders.add(historyOrder);
        }
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Тапсырыс №$orderId жеткізілді')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Қате: $e')));
    }
  }

  Future<void> _loadProducts() async {
    final snapshot =
        await FirebaseDatabase.instance
            .ref('products')
            .orderByChild('userId')
            .equalTo(user!.uid)
            .get();
    if (snapshot.exists) {
      final products = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() {
        _products.clear();
        products.forEach((key, value) {
          final product = Map<String, dynamic>.from(value);
          product['id'] = key;
          _products.add(product);
        });
      });
    }
  }

  Future<void> _loadReviews() async {
    final snapshot = await FirebaseDatabase.instance.ref('reviews').get();
    if (snapshot.exists) {
      final reviews = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() {
        _reviews.clear();
        reviews.forEach((key, value) {
          final review = Map<String, dynamic>.from(value);
          review['id'] = key;
          if (_products.any(
            (product) => product['id'] == review['productId'],
          )) {
            _reviews.add(review);
          }
        });
      });
    }
  }

  List<Widget> _buildBuyerSection() {
    return [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Менің тапсырыстарым',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      if (_buyerOrders.isEmpty)
        const Text('Тапсырыстар жоқ')
      else
        ..._buyerOrders.map(_buildBuyerOrderCard),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildSellerSection() {
    return [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Сатушы',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      ElevatedButton.icon(
        icon: const Icon(Icons.add_business),
        label: const Text('Тауар қосу'),
        onPressed: () => Navigator.pushNamed(context, '/addProduct'),
      ),
      const SizedBox(height: 10),
      ElevatedButton.icon(
        icon: const Icon(Icons.list_alt),
        label: const Text('Тапсырыстарды басқару'),
        onPressed: () => Navigator.pushNamed(context, '/seller'),
      ),
      const SizedBox(height: 20),
      const Text(
        'Тауарларға пікірлер',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      if (_reviews.isEmpty)
        const Padding(padding: EdgeInsets.all(8), child: Text('Пікірлер жоқ'))
      else
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _reviews.length,
          itemBuilder: (context, index) {
            final review = _reviews[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text('Рейтинг: ${review['rating']}'),
                subtitle: Text('Пікір: ${review['comment']}'),
              ),
            );
          },
        ),
      const SizedBox(height: 24),
    ];
  }

  void _listenToCourierNotifications() {
    _courierNotifsRef.onChildAdded.listen((evt) async {
      final d = evt.snapshot.value as Map?;
      if (d != null) {
        final orderId = d['orderId'] as String;
        final orderSnapshot = await _buyerOrdersRef.child(orderId).get();
        if (orderSnapshot.exists) {
          final orderData = Map<String, dynamic>.from(
            orderSnapshot.value as Map,
          );
          // Тапсырыс басқа курьермен қабылданбағанын тексеру
          if (orderData['status'] != 'new' || orderData['courierId'] != null)
            return;

          final ord = Map<String, dynamic>.from(d);
          ord['notificationId'] = evt.snapshot.key;
          ord['address'] = orderData['address'] ?? 'Белгісіз';
          ord['items'] = orderData['items'] ?? [];
          ord['total'] = orderData['total']?.toDouble() ?? 0.0;
          ord['confirmationCode'] = orderData['confirmationCode'] ?? '';
          ord['buyerId'] = orderData['buyerId'];
          ord['sellerId'] = orderData['sellerId'];
          setState(() {
            if (ord['status'] == 'new') {
              if (!_newOrders.any((o) => o['orderId'] == ord['orderId'])) {
                _newOrders.add(ord);
                _hasNewOrderNotification = true;
              }
            } else {
              if (!_historyOrders.any((o) => o['orderId'] == ord['orderId'])) {
                _historyOrders.add(ord);
              }
            }
          });
        }
      }
    });
  }

  Future<void> _acceptOrder(String orderId, Map ord) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    try {
      // Тапсырыс басқа курьермен қабылданбағанын тексеру
      final orderSnapshot =
          await FirebaseDatabase.instance.ref('orders/$orderId').get();
      if (!orderSnapshot.exists ||
          orderSnapshot.child('courierId').value != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Тапсырыс басқа курьермен қабылданды')),
        );
        return;
      }

      await FirebaseDatabase.instance.ref('orders/$orderId').update({
        'status': 'in_transit',
        'courierId': u.uid,
        'acceptedAt': ServerValue.timestamp,
      });
      await _courierNotifsRef.child(ord['notificationId']).remove();
      await FirebaseDatabase.instance
          .ref('notifications/buyers/${ord['buyerId']}')
          .push()
          .set({
            'orderId': orderId,
            'message': 'Сіздің тапсырысыңыз №$orderId жолда',
            'timestamp': ServerValue.timestamp,
            'status': 'in_transit',
          });
      await FirebaseDatabase.instance
          .ref('notifications/sellers/${ord['sellerId']}')
          .push()
          .set({
            'orderId': orderId,
            'message': 'Тапсырыс №$orderId жолда',
            'timestamp': ServerValue.timestamp,
            'status': 'in_transit',
          });
      // Курьерге хабарлама
      await FirebaseDatabase.instance.ref('notifications/couriers').push().set({
        'orderId': orderId,
        'message': 'Сіз тапсырыс №$orderId қабылдадыңыз',
        'timestamp': ServerValue.timestamp,
        'status': 'in_transit',
        'courierId': u.uid,
      });
      setState(() {
        _newOrders.removeWhere((o) => o['orderId'] == orderId);
        _historyOrders.add({
          ...ord,
          'status': 'in_transit',
          'courierId': u.uid,
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Тапсырыс қабылдауда қате: $e')));
    }
  }

  Future<void> _rejectOrder(String orderId, Map ord) async {
    try {
      await FirebaseDatabase.instance.ref('orders/$orderId').update({
        'status': 'courier_rejected',
        'courierId': null,
      });
      await _courierNotifsRef.child(ord['notificationId']).remove();
      await FirebaseDatabase.instance
          .ref('notifications/sellers/${ord['sellerId']}')
          .push()
          .set({
            'orderId': orderId,
            'message': 'Курьер тапсырыс №$orderId қабылдама алмады',
            'timestamp': ServerValue.timestamp,
            'status': 'courier_rejected',
          });
      await FirebaseDatabase.instance
          .ref('notifications/buyers/${ord['buyerId']}')
          .push()
          .set({
            'orderId': orderId,
            'message': 'Курьер тапсырыс №$orderId қабылдама алмады',
            'timestamp': ServerValue.timestamp,
            'status': 'courier_rejected',
          });
      await _courierNotifsRef.push().set({
        'orderId': orderId,
        'buyerId': ord['buyerId'],
        'sellerId': ord['sellerId'],
        'message': 'Жаңа тапсырыс №$orderId жүктелді',
        'timestamp': ServerValue.timestamp,
        'status': 'new',
        'address': ord['address'] ?? 'Белгісіз',
        'items': ord['items'] ?? [],
        'total': ord['total']?.toDouble() ?? 0.0,
      });
      setState(() {
        _newOrders.removeWhere((o) => o['orderId'] == orderId);
        _historyOrders.add({...ord, 'status': 'courier_rejected'});
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Тапсырыс бас тартуда қате: $e')));
    }
  }

  Future<void> _deleteHistoryOrder(
    String notificationId,
    String orderId,
  ) async {
    await _courierNotifsRef.child(notificationId).remove();
    setState(() {
      _historyOrders.removeWhere((o) => o['orderId'] == orderId);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Тапсырыс тарихтан өшірілді')));
  }

  Future<void> _deleteSelectedOrders() async {
    for (var orderId in _selectedOrderIds) {
      final order = _historyOrders.firstWhere((o) => o['orderId'] == orderId);
      await _courierNotifsRef.child(order['notificationId']).remove();
    }
    setState(() {
      _historyOrders.removeWhere(
        (o) => _selectedOrderIds.contains(o['orderId']),
      );
      _selectedOrderIds.clear();
      _isSelectionMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Таңдалған тапсырыстар өшірілді')),
    );
  }

  void _toggleSelection(String orderId) {
    setState(() {
      if (_selectedOrderIds.contains(orderId)) {
        _selectedOrderIds.remove(orderId);
      } else {
        _selectedOrderIds.add(orderId);
      }
      if (_selectedOrderIds.isEmpty) {
        _isSelectionMode = false;
      } else {
        _isSelectionMode = true;
      }
    });
  }

  Widget _buildCourierCard(Map ord) {
    final isHistory = ord['status'] != 'new';
    final isSelected = _selectedOrderIds.contains(ord['orderId']);
    Color c;
    IconData ic;
    String statusText;
    switch (ord['status']) {
      case 'new':
        c = Colors.orange;
        ic = Icons.access_time;
        statusText = 'Жаңа';
        break;
      case 'in_transit':
        c = Colors.blue;
        ic = Icons.local_shipping;
        statusText = 'Жолда';
        break;
      case 'delivered':
        c = Colors.green;
        ic = Icons.check_circle;
        statusText = 'Жеткізілді';
        break;
      case 'courier_rejected':
        c = Colors.red;
        ic = Icons.cancel;
        statusText = 'Қабылданбады';
        break;
      default:
        c = Colors.grey;
        ic = Icons.info_outline;
        statusText = 'Белгісіз';
    }

    final items = ord['items'] as List<dynamic>? ?? [];

    return Dismissible(
      key: Key(ord['orderId']),
      direction:
          isHistory ? DismissDirection.horizontal : DismissDirection.none,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        _deleteHistoryOrder(ord['notificationId'], ord['orderId']);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                isSelected
                    ? [Colors.green.shade100, Colors.green.shade50]
                    : [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: c.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          onTap: isHistory ? () => _toggleSelection(ord['orderId']) : null,
          onLongPress:
              isHistory ? () => _toggleSelection(ord['orderId']) : null,
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: c.withOpacity(0.2),
                child: Icon(ic, color: c),
              ),
              if (isSelected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          title: Text('Тапсырыс №${ord['orderId']}'),
          subtitle: Text(
            'Күйі: $statusText\n${ord['message'] ?? ''}\nМекенжай: ${ord['address'] ?? 'Көрсетілмеген'}' +
                (ord['status'] == 'in_transit' || ord['status'] == 'new'
                    ? '\nРастау коды: ${ord['confirmationCode'] ?? 'Көрсетілмеген'}'
                    : '') +
                '\nТауарлар: ${items.isEmpty ? 'Жоқ' : items.map((item) => item['name']).join(', ')}',
          ),
          trailing:
              !isHistory
                  ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _acceptOrder(ord['orderId'], ord),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _rejectOrder(ord['orderId'], ord),
                      ),
                    ],
                  )
                  : ord['status'] == 'in_transit'
                  ? IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => ConfirmDeliveryScreen(
                                orderId: ord['orderId'],
                                address: ord['address'] ?? 'Белгісіз',
                                total: ord['total']?.toDouble() ?? 0.0,
                                items: ord['items'] ?? [],
                                confirmationCode: ord['confirmationCode'] ?? '',
                              ),
                        ),
                      );
                    },
                  )
                  : const Icon(Icons.history, color: Colors.grey),
        ),
      ),
    );
  }

  List<Widget> _buildCourierSection() {
    final deliveredCount =
        _historyOrders
            .where(
              (o) => o['status'] == 'delivered' || o['status'] == 'доставлен',
            )
            .length;
    final rejectedCount =
        _historyOrders.where((o) => o['status'] == 'courier_rejected').length;
    return [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Жаңа тапсырыстар',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      if (_newOrders.isEmpty)
        const Text('Жаңа тапсырыстар жоқ')
      else
        ..._newOrders.map(_buildCourierCard),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Тапсырыстар тарихы',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_isSelectionMode)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _deleteSelectedOrders,
              ),
          ],
        ),
      ),
      if (_historyOrders.isEmpty)
        const Text('Тарих бос')
      else
        ..._historyOrders.map(_buildCourierCard),
      const SizedBox(height: 24),
      _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Жеткізу статистикасы',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text('✅ Жеткізілді: $deliveredCount'),
            Text('❌ Қабылданбады: $rejectedCount'),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Пайдаланушы авторизацияланбаған')),
      );
    }
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final role = _userData?['role'] as String? ?? 'buyer';
    String roleText;
    switch (role) {
      case 'buyer':
        roleText = 'Сатып алушы';
        break;
      case 'seller':
        roleText = 'Сатушы';
        break;
      case 'courier':
        roleText = 'Курьер';
        break;
      default:
        roleText = 'Белгісіз';
    }
    final avatarUrl = _userData?['avatarUrl'] as String?;
    final email = _userData?['email'] as String? ?? '';
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Профиль', style: TextStyle(color: Colors.black)),
        actions: [
          IconButton(
            icon: const Icon(Icons.credit_card, color: Colors.black),
            onPressed: _hasCard ? null : _addCard,
          ),
          IconButton(
            icon: const Icon(Icons.assignment, color: Colors.black),
            onPressed: _changePassword,
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.black),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1581090700227-1c065c5857f7?auto=format&fit=crop&w=1350&q=80',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          FadeTransition(
            opacity: _fadeAnimation,
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
                      color: Colors.black12,
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _uploadImage,
                        child: Hero(
                          tag: 'avatar',
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage:
                                avatarUrl != null
                                    ? NetworkImage(avatarUrl)
                                    : null,
                            backgroundColor: Colors.white,
                            child:
                                avatarUrl == null
                                    ? const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.grey,
                                    )
                                    : null,
                          ),
                        ),
                      ),
                    ),
                    if (_isUploading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_uploadError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _uploadError!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 24),
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Жеке деректер',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.green,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isEditing = true;
                                  });
                                },
                              ),
                            ],
                          ),
                          _buildInfoRow('Электрондық пошта:', email),
                          const SizedBox(height: 10),
                          if (!_isEditing) ...[
                            _buildInfoRow(
                              'Аты:',
                              _userData?['name'] ?? 'Көрсетілмеген',
                            ),
                            const SizedBox(height: 10),
                            _buildInfoRow(
                              'Мекенжай:',
                              _userData?['address'] ?? 'Көрсетілмеген',
                            ),
                          ],
                          if (_isEditing) ...[
                            TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Аты',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'Мекенжай',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: _updateUserData,
                              child: const Text(
                                'Өзгерістерді сақтау',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _buildCard(child: _buildInfoRow('Рөл:', roleText)),
                    if (role == 'courier' && _userData?['age'] != null)
                      _buildCard(
                        child: _buildInfoRow(
                          'Жасы:',
                          _userData!['age'].toString(),
                        ),
                      ),
                    _buildCard(child: _buildBalanceRow()),
                    _buildCard(child: _buildGeneralNotifsSection()),
                    if (role == 'buyer') ..._buildBuyerSection(),
                    if (role == 'seller') ..._buildSellerSection(),
                    if (role == 'courier') ..._buildCourierSection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            blurRadius: 15,
            color: Colors.black12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _buildBalanceRow() {
    return Row(
      children: [
        const Text('Баланс: ', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          '${NumberFormat.currency(locale: 'kk_KZ', symbol: '₸').format(_balance)}',
          style: TextStyle(
            color: _hasCard ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (!_hasCard)
          TextButton(
            onPressed: _addCard,
            child: const Text('Картаны белсендіру'),
          ),
      ],
    );
  }
}

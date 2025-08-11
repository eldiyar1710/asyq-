import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'catalog_screen.dart';
import 'cart_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'courier_home_screen.dart';

enum ProductType { milk, fruits, berries, meat, fish, vegetables }

class StorageInfoScreen extends StatelessWidget {
  const StorageInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тауарларды сақтау ережелері'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Сүт өнімдері 🥛🧀',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Сақтау мерзімі: 5–7 күн (ашылған соң)'),
            const Text('• Температура: +2°C – +4°C'),
            const Text(
              '• Сақтау әдісі: Тоңазытқышта жабық контейнерде немесе өз орамында.',
            ),
            const Divider(height: 24),
            const Text(
              '2. Ет және балық 🍖🐟',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Сақтау мерзімі:'),
            const Text('  • Шикі ет: 1–3 күн'),
            const Text('  • Піскен ет: 3–4 күн'),
            const Text('  • Балық: 1–2 күн'),
            const Text('• Температура: 0°C – +2°C'),
            const Text(
              '• Сақтау әдісі: Тығыз жабылған контейнерде, тоңазытқыштың ең салқын бөлігінде. Ұзақ сақтау үшін мұздату қажет.',
            ),
            const Divider(height: 24),
            const Text(
              '3. Жемістер мен көкөністер 🍎🥕',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Сақтау мерзімі: 5–14 күн (түріне байланысты)'),
            const Text('• Температура: +4°C – +8°C'),
            const Text('• Сақтау әдісі:'),
            const Text(
              '  • Жемістер – арнайы бөлімде (кейбіреуі тоңазытқышсыз сақталады, мысалы, банан мен лимон)',
            ),
            const Text('  • Көкөністер – полиэтилен пакетімен немесе қағазда.'),
            const Divider(height: 24),
            const Text(
              '4. Жұмыртқа 🥚',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Сақтау мерзімі: 3–4 апта'),
            const Text('• Температура: +2°C – +5°C'),
            const Text('• Сақтау әдісі: Тоңазытқышта, тік қойып сақтау.'),
            const Divider(height: 24),
            const Text(
              '5. Нан және наубайхана өнімдері 🍞🥐',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Сақтау мерзімі: 2–3 күн (бөлме температурасында), 7 күнге дейін (тоңазытқышта)',
            ),
            const Text('• Температура: +18°C – +20°C'),
            const Text(
              '• Сақтау әдісі: Қағаз пакетте немесе нан қорабында. Ұзақ сақтау үшін мұздатып қоюға болады.',
            ),
            const Divider(height: 24),
            const Text(
              '6. Консервілер 🥫',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Сақтау мерзімі: Ашылмаған — 1–2 жыл, ашылған — 2–3 күн',
            ),
            const Text('• Температура: +4°C (ашылғаннан кейін)'),
            const Text(
              '• Сақтау әдісі: Ашылғаннан кейін — әйнек немесе пластик ыдысқа салып, тоңазытқышта.',
            ),
            const Divider(height: 24),
            const Text(
              '7. Мұздатылған өнімдер ❄️',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Сақтау мерзімі: 3 айдан 12 айға дейін (өнімге байланысты)',
            ),
            const Text('• Температура: –18°C'),
            const Text(
              '• Сақтау әдісі: Герметикалық оралған күйде мұздатқышта.',
            ),
          ],
        ),
      ),
    );
  }
}

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Рецепттер'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Таңғы ас — Авокадо-тосты 🥑🍞',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Құрамы:'),
            const Text('• 1 тілім нан'),
            const Text('• ½ авокадо'),
            const Text('• 1 қайнатылған жұмыртқа'),
            const Text('• Тұз, бұрыш, лимон шырыны'),
            const SizedBox(height: 8),
            const Text('Дайындау:'),
            const Text('1. Нанды қуырып алыңыз.'),
            const Text('2. Авокадоны езіп, тұз, бұрыш, лимон шырынын қосыңыз.'),
            const Text('3. Нанның үстіне жағып, жұмыртқа тілімдерін қойыңыз.'),
            const Divider(height: 24),
            const Text(
              '2. Таңғы ас — Йогурт пен жеміс ботқасы 🍓🥣',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Құрамы:'),
            const Text('• 4 ас қасық сұлы'),
            const Text('• 1 стақан сүт немесе су'),
            const Text('• 3 ас қасық йогурт'),
            const Text('• Жемістер (банан, құлпынай, т.б.)'),
            const SizedBox(height: 8),
            const Text('Дайындау:'),
            const Text(
              '1. Сұлыны сүтпен бірге қайнатып, жұмсарғанша пісіріңіз.',
            ),
            const Text('2. Жоғарынан йогурт пен жемістерді қосыңыз.'),
            const Divider(height: 24),
            const Text(
              '3. Түскі ас — Қарақұмық пен тауық еті 🥩🍚',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Құрамы:'),
            const Text('• 100 г тауық еті'),
            const Text('• ½ стақан қарақұмық'),
            const Text('• Пияз, сәбіз'),
            const Text('• Тұз, дәмдеуіштер'),
            const SizedBox(height: 8),
            const Text('Дайындау:'),
            const Text('1. Қарақұмықты 15 минут қайнатыңыз.'),
            const Text('2. Тауықты қуырып, көкөністер қосыңыз.'),
            const Text('3. Қарақұмықпен араластырыңыз.'),
            const Divider(height: 24),
            const Text(
              '4. Кешкі ас — Көкөніс сорпасы 🥦🥕',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Құрамы:'),
            const Text('• Картоп, сәбіз, брокколи'),
            const Text('• Пияз, сарымсақ'),
            const Text('• Тұз, лавр жапырағы'),
            const SizedBox(height: 8),
            const Text('Дайындау:'),
            const Text('1. Көкөністерді турап, қайнаған суға салыңыз.'),
            const Text(
              '2. Дәміне қарай тұз, жапырақ қосып 20 минут пісіріңіз.',
            ),
            const Divider(height: 24),
            const Text(
              '5. Кешкі ас — Жеңіл салат 🥗',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Құрамы:'),
            const Text('• Қияр, қызанақ, жапырақты салат'),
            const Text('• Зәйтүн майы'),
            const Text('• Лимон шырыны, тұз'),
            const SizedBox(height: 8),
            const Text('Дайындау:'),
            const Text('1. Барлық көкөністі тураңыз.'),
            const Text('2. Май мен лимонмен араластырыңыз.'),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final databaseRef = FirebaseDatabase.instance.ref();

  String name = '';
  String role = '';
  List<Map<String, dynamic>> allProducts = [];

  final List<Map<String, dynamic>> categories = [
    {
      'icon': Icons.local_drink,
      'label': 'Сүт',
      'type': ProductType.milk,
      'background':
          'https://encrypted-tbn0.gstatic.com/images?q=tbn9GcSagetn0fua1839eP0i0oqvM63pdlwP0DHW9g&s',
    },
    {
      'icon': Icons.apple,
      'label': 'Жемістер',
      'type': ProductType.fruits,
      'background':
          'https://encrypted-tbn0.gstatic.com/images?q=tbn9GcTDbNyySuf4W9DehG-Aj1RFNDJ83I4Vbmy5pQ&s',
    },
    {
      'icon': Icons.grass,
      'label': 'Жидектер',
      'type': ProductType.berries,
      'background': 'https://stolicaonego.ru/images/news/505/505278/main.jpg',
    },
    {
      'icon': Icons.set_meal,
      'label': 'Ет',
      'type': ProductType.meat,
      'background':
          'https://encrypted-tbn0.gstatic.com/images?q=tbn9GcRrr4sbCLsqvapA-XxwGjFqaVyw0Kx7iQaLRQ&s',
    },
    {
      'icon': Icons.set_meal_outlined,
      'label': 'Балық',
      'type': ProductType.fish,
      'background':
          'https://encrypted-tbn0.gstatic.com/images?q=tbn9GcRcYFS-3vIORSAndHDyGRpy24aggo5LIk0e-A&s',
    },
    {
      'icon': Icons.eco,
      'label': 'Овощи',
      'type': ProductType.vegetables,
      'background': 'https://cdn-icons-png.flaticon.com/512/766/766330.png',
    },
  ];

  final List<String> bannerImages = [
    'https://encrypted-tbn0.gstatic.com/images?q=tbn9GcR5iEDONBcC9Iv9Akxg-ZjddEGvSm5Nve9Jpg&s',
    'https://www.diabetesaustralia.com.au/wp-content/uploads/fruit-and-veg-1208790371.jpg',
    'https://images.squarespace-cdn.com/content/v1/59f0e6beace8641044d76e9c/1669587646206-6Z76MY4X3GBFKIUQZJ4R/Social+Meat.jpeg',
  ];

  int _currentBannerIndex = 1;
  Timer? _bannerTimer;
  Timer? _searchTimer;
  String _lastSearchText = '';

  int _currentIndex = 2;
  List<Widget> _pages = [];
  List<String> floatingEmojis = [''];
  double offsetX = 0.2;
  double offsetY = 0.4;

  @override
  void initState() {
    super.initState();
    _playNatureSounds();
    getUserData();
    fetchProducts();
    startBannerTimer();
    accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        offsetX = event.x;
        offsetY = event.y;
      });
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _searchTimer?.cancel();
    super.dispose();
  }

  void startBannerTimer() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          _currentBannerIndex = (_currentBannerIndex + 1) % bannerImages.length;
        });
      }
    });
  }

  Future<void> getUserData() async {
    if (user != null) {
      final snapshot = await databaseRef.child('users/${user!.uid}').get();
      if (!snapshot.exists || snapshot.value == null) {
        setState(() => role = 'buyer');
        return;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final userRole = data['role'] ?? 'buyer';

      setState(() {
        name = data['name'] ?? '';
        role = userRole;
      });

      if (userRole == 'buyer') {
        setState(() {
          _pages = [
            buildMainPage(),
            const CatalogScreen(initialFilter: null, initialSearch: ''),
            const CartScreen(),
            const FavoritesScreen(),
            const ProfileScreen(),
          ];
        });
      } else if (userRole == 'courier') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CourierHomeScreen()),
          );
        });
      } else if (userRole == 'seller') {
        setState(() {
          _pages = [const ProfileScreen()];
        });
      }
    }
  }

  Future<void> fetchProducts() async {
    final snapshot = await databaseRef.child('products').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      List<Map<String, dynamic>> products = [];
      data.forEach((key, value) {
        final product = Map<String, dynamic>.from(value);
        product['id'] = key;
        products.add(product);
      });
      setState(() => allProducts = products);
    }
  }

  Future<Map<String, dynamic>> _getProductRating(String productId) async {
    final reviewsRef = databaseRef.child('reviews/$productId');
    final snapshot = await reviewsRef.get();
    if (!snapshot.exists) return {'average': 0.0, 'count': 0};
    final reviews = Map<dynamic, dynamic>.from(snapshot.value as Map);
    if (reviews.isEmpty) return {'average': 0.0, 'count': 0};
    double totalRating = reviews.values.fold(
      0,
      (sum, review) => sum + (review['rating'] ?? 0),
    );
    return {'average': totalRating / reviews.length, 'count': reviews.length};
  }

  Future<void> _playNatureSounds() async {}

  Widget buildMainPage() {
    final lowestPrice =
        List<Map<String, dynamic>>.from(allProducts)
          ..sort((a, b) => (a['price'] ?? 0).compareTo(b['price'] ?? 0))
          ..take(5);

    final highestDiscount =
        List<Map<String, dynamic>>.from(allProducts)
          ..sort((a, b) => (b['discount'] ?? 0).compareTo(a['discount'] ?? 0))
          ..take(5);

    List<Map<String, dynamic>> highRated = [];
    Future.wait(
      allProducts.map((product) async {
        final ratingData = await _getProductRating(product['id']);
        product['averageRating'] = ratingData['average'];
        product['reviewCount'] = ratingData['count'];
        if (ratingData['average'] >= 4.0 && ratingData['count'] >= 3) {
          highRated.add(product);
        }
      }),
    ).then((_) {
      highRated.sort(
        (a, b) => (b['averageRating'] ?? 0).compareTo(a['averageRating'] ?? 0),
      );
      highRated = highRated.take(5).toList();
    });

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(
                'https://impro.usercontent.one/appid/oneComShop/domain/myexoticfruit.com/media/myexoticfruit.com/webshopmedia/dragonfruit%20red-1561254739488.jpg?&withoutEnlargement&resize=1920+9999&webp&quality=85',
              ),
              fit: BoxFit.cover,
              opacity: 0.3,
            ),
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 45),
              Text(
                'Қош келдіңіз, $name 👋',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Тауарлар немесе қызметтер іздеу...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  if (value.trim().isEmpty || value == _lastSearchText) return;
                  _searchTimer?.cancel();
                  _searchTimer = Timer(const Duration(milliseconds: 500), () {
                    _lastSearchText = value;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => CatalogScreen(
                              initialSearch: value,
                              initialFilter: null,
                            ),
                      ),
                    );
                  });
                },
              ),
              const SizedBox(height: 16),

              Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StorageInfoScreen(),
                        ),
                      );
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      child: ClipRRect(
                        key: ValueKey(_currentBannerIndex),
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          bannerImages[_currentBannerIndex],
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RecipesScreen(),
                        ),
                      );
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      child: ClipRRect(
                        key: ValueKey(_currentBannerIndex + 100),
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          bannerImages[(_currentBannerIndex + 1) %
                              bannerImages.length],
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Санаттар',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children:
                    categories.map((category) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => CatalogScreen(
                                    initialFilter: category['type'],
                                    initialSearch: '',
                                  ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade300,
                                blurRadius: 8,
                                offset: const Offset(2, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(category['icon'], size: 30),
                              const SizedBox(height: 8),
                              Text(
                                category['label'],
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ).animate().scale(duration: 500.ms),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ұсыныстар',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              const Text(
                'Ең төмен баға',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: lowestPrice.length,
                  itemBuilder: (context, index) {
                    final product = lowestPrice[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => CatalogScreen(
                                  initialFilter: null,
                                  initialSearch: product['name'] ?? '',
                                ),
                          ),
                        );
                      },
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade300,
                              blurRadius: 8,
                              offset: const Offset(2, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: Image.network(
                                product['image'] ?? '',
                                width: double.infinity,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) => const Icon(
                                      Icons.broken_image,
                                      size: 50,
                                    ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['name'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${product['price'] ?? 0} ₸',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fade(duration: 400.ms),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Ең үлкен жеңілдіктер',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: highestDiscount.length,
                  itemBuilder: (context, index) {
                    final product = highestDiscount[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => CatalogScreen(
                                  initialFilter: null,
                                  initialSearch: product['name'] ?? '',
                                ),
                          ),
                        );
                      },
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade300,
                              blurRadius: 8,
                              offset: const Offset(2, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: Image.network(
                                product['image'] ?? '',
                                width: double.infinity,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) => const Icon(
                                      Icons.broken_image,
                                      size: 50,
                                    ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['name'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${product['price'] ?? 0} ₸',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                  ),
                                  if ((product['discount'] ?? 0) > 0)
                                    Text(
                                      'Жеңілдік: ${product['discount']}%',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fade(duration: 400.ms),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Жоғары рейтинг',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: highRated.length,
                  itemBuilder: (context, index) {
                    final product = highRated[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => CatalogScreen(
                                  initialFilter: null,
                                  initialSearch: product['name'] ?? '',
                                ),
                          ),
                        );
                      },
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade300,
                              blurRadius: 8,
                              offset: const Offset(2, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: Image.network(
                                product['image'] ?? '',
                                width: double.infinity,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) => const Icon(
                                      Icons.broken_image,
                                      size: 50,
                                    ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['name'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${product['price'] ?? 0} ₸',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                  ),
                                  FutureBuilder<Map<String, dynamic>>(
                                    future: _getProductRating(product['id']),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData)
                                        return const SizedBox();
                                      final ratingData = snapshot.data!;
                                      return Text(
                                        'Рейтинг: ${ratingData['average'].toStringAsFixed(1)} (${ratingData['count']} пікір)',
                                        style: const TextStyle(fontSize: 12),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fade(duration: 400.ms),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        Positioned(
          top: MediaQuery.of(context).size.height * 0.5 + offsetY * 10,
          left: MediaQuery.of(context).size.width * 0.5 + offsetX * 10,
          child: Text(
            floatingEmojis[Random().nextInt(floatingEmojis.length)],
            style: const TextStyle(fontSize: 30),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (role == 'seller') {
      return const ProfileScreen();
    }

    if (_pages.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Басты бет'),
          BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Каталог'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Себет',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Таңдаулылар',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
        ],
      ),
    );
  }
}

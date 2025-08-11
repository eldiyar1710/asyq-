import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum ProductType { milk, fruits, berries, meat, fish, vegetables }

extension ProductTypeExtension on ProductType {
  String get label {
    switch (this) {
      case ProductType.milk:
        return 'Сүт';
      case ProductType.fruits:
        return 'Жемістер';
      case ProductType.berries:
        return 'Жидектер';
      case ProductType.meat:
        return 'Ет';
      case ProductType.fish:
        return 'Балық';
      case ProductType.vegetables:
        return 'көк өніс';
    }
  }

  String get emoji {
    switch (this) {
      case ProductType.milk:
        return '🥛';
      case ProductType.fruits:
        return '🍎';
      case ProductType.berries:
        return '🍓';
      case ProductType.meat:
        return '🍖';
      case ProductType.fish:
        return '🐟';
      case ProductType.vegetables:
        return '🥦🥕🍅';
    }
  }
}

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final Map product;

  const ProductDetailScreen({
    Key? key,
    required this.productId,
    required this.product,
  }) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _commentController = TextEditingController();
  double _rating = 0;
  final DatabaseReference _reviewsRef = FirebaseDatabase.instance.ref().child(
    'reviews',
  );
  final user = FirebaseAuth.instance.currentUser;

  Future<void> _submitReview() async {
    if (_rating == 0 ||
        _commentController.text.trim().isEmpty ||
        user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Рейтинг пен пікір енгізіңіз')),
      );
      return;
    }

    final reviewRef = _reviewsRef.child(widget.productId).push();
    await reviewRef.set({
      'userId': user!.uid,
      'rating': _rating,
      'comment': _commentController.text.trim(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'likes': 0,
      'dislikes': 0,
    });

    _commentController.clear();
    setState(() => _rating = 0);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Пікір қосылды')));
  }

  Future<void> _toggleLike(String reviewId, Map review, bool isLike) async {
    if (user == null) return;
    final reviewRef = _reviewsRef.child(widget.productId).child(reviewId);
    final newLikes = (review['likes'] ?? 0) + (isLike ? 1 : 0);
    final newDislikes = (review['dislikes'] ?? 0) + (isLike ? 0 : 1);
    await reviewRef.update({'likes': newLikes, 'dislikes': newDislikes});
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final emoji =
        ProductType.values
            .firstWhere(
              (t) => t.label == product['type'],
              orElse: () => ProductType.milk,
            )
            .emoji;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '$emoji ${product['name']}',
          style: const TextStyle(color: Colors.black),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
              'https://images.unsplash.com/photo-1581090700227-1c065c5857f7?auto=format&fit=crop&w=1350&q=80',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 80),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      product['image'] ?? '',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
                      errorBuilder:
                          (context, error, stackTrace) =>
                              const Icon(Icons.broken_image, size: 50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$emoji ${product['name'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Бағасы: ${product['price']}₸',
                    style: const TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                  if ((product['discount'] ?? 0) > 0)
                    Text(
                      'Жеңілдік: ${product['discount']}%',
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Сипаттамасы: ${product['description'] ?? 'Сипаттама жоқ'}',
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  const Divider(thickness: 1),
                  const SizedBox(height: 16),
                  const Text(
                    'Пікір қалдыру',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () => setState(() => _rating = index + 1),
                      );
                    }),
                  ),
                  TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      labelText: 'Пікіріңіз',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _submitReview,
                    child: const Text(
                      'Пікір жіберу',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(thickness: 1),
                  const SizedBox(height: 16),
                  const Text(
                    'Пікірлер',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<DatabaseEvent>(
                    stream: _reviewsRef.child(widget.productId).onValue,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData ||
                          snapshot.data?.snapshot.value == null) {
                        return const Text('Пікірлер жоқ');
                      }
                      final reviews = Map<dynamic, dynamic>.from(
                        snapshot.data!.snapshot.value as Map,
                      );
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: reviews.length,
                        itemBuilder: (context, index) {
                          final reviewId = reviews.keys.elementAt(index);
                          final review = reviews[reviewId];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Рейтинг: ${review['rating']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Row(
                                        children: List.generate(
                                          review['rating'].round(),
                                          (i) => const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(review['comment']),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.thumb_up,
                                          color: Colors.green,
                                        ),
                                        onPressed:
                                            () => _toggleLike(
                                              reviewId,
                                              review,
                                              true,
                                            ),
                                      ),
                                      Text('${review['likes'] ?? 0}'),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.thumb_down,
                                          color: Colors.red,
                                        ),
                                        onPressed:
                                            () => _toggleLike(
                                              reviewId,
                                              review,
                                              false,
                                            ),
                                      ),
                                      Text('${review['dislikes'] ?? 0}'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    Key? key,
    required initialFilter,
    required String initialSearch,
  }) : super(key: key);

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final DatabaseReference _productsRef = FirebaseDatabase.instance.ref().child(
    'products',
  );
  final DatabaseReference _cartRef = FirebaseDatabase.instance.ref().child(
    'cart',
  );
  final DatabaseReference _reviewsRef = FirebaseDatabase.instance.ref().child(
    'reviews',
  );
  final Set<String> _favorites = {};
  ProductType? _selectedFilter;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final favRef = FirebaseDatabase.instance.ref().child('favorites/$userId');
    final snapshot = await favRef.get();
    if (snapshot.exists) {
      final favorites = Map<dynamic, dynamic>.from(snapshot.value as Map);
      setState(() {
        _favorites.addAll(favorites.keys.map((key) => key.toString()));
      });
    }
  }

  void _toggleFavorite(String productId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final favRef = FirebaseDatabase.instance.ref().child(
      'favorites/$userId/$productId',
    );
    if (_favorites.contains(productId)) {
      await favRef.remove();
      setState(() => _favorites.remove(productId));
    } else {
      await favRef.set(true);
      setState(() => _favorites.add(productId));
    }
  }

  void _addToCart(String productId, Map product) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final cartItemRef = _cartRef.child(userId).child(productId);

    await cartItemRef.set({
      'name': product['name'],
      'price': product['price'],
      'image': product['image'],
      'discount': product['discount'] ?? 0,
      'quantity': 1,
      'sellerId': product['userId'],
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Тауар себетке қосылды')));
  }

  bool _matchesFilter(Map product) =>
      _selectedFilter == null || product['type'] == _selectedFilter!.label;
  bool _matchesSearch(Map product) =>
      product['name']?.toString().toLowerCase().contains(
        _searchQuery.toLowerCase(),
      ) ??
      false;

  Future<double> _getAverageRating(String productId) async {
    final snapshot = await _reviewsRef.child(productId).get();
    if (!snapshot.exists) return 0.0;
    final reviews = Map<dynamic, dynamic>.from(snapshot.value as Map);
    if (reviews.isEmpty) return 0.0;
    double totalRating = reviews.values.fold(
      0,
      (sum, review) => sum + (review['rating'] ?? 0),
    );
    return totalRating / reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Санаттар',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Іздеу...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<ProductType?>(
                  hint: const Text('Фильтр'),
                  value: _selectedFilter,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Барлығы')),
                    ...ProductType.values.map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text('${e.emoji} ${e.label}'),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedFilter = val),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _productsRef.onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData ||
                    snapshot.data?.snapshot.value == null) {
                  return const Center(child: Text('Қолжетімді тауарлар жоқ'));
                }
                Map<dynamic, dynamic> products =
                    snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final filtered =
                    products.entries.where((entry) {
                      final product = entry.value;
                      return _matchesFilter(product) && _matchesSearch(product);
                    }).toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    String productId = filtered[index].key;
                    Map product = filtered[index].value;
                    bool isFavorite = _favorites.contains(productId);
                    String emoji =
                        ProductType.values
                            .firstWhere(
                              (t) => t.label == product['type'],
                              orElse: () => ProductType.milk,
                            )
                            .emoji;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ProductDetailScreen(
                                  productId: productId,
                                  product: product,
                                ),
                          ),
                        );
                      },
                      child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade300,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                    child: Image.network(
                                      product['image'] ?? '',
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.broken_image,
                                                size: 50,
                                              ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$emoji ${product['name'] ?? ''}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Бағасы: ${product['price']}₸',
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if ((product['discount'] ?? 0) > 0)
                                        Text(
                                          'Жеңілдік: ${product['discount']}%',
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 14,
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      FutureBuilder<double>(
                                        future: _getAverageRating(productId),
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData)
                                            return const SizedBox();
                                          return Row(
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                color: Colors.amber,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                snapshot.data!.toStringAsFixed(
                                                  1,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isFavorite
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color:
                                              isFavorite
                                                  ? Colors.red
                                                  : Colors.grey,
                                        ),
                                        onPressed:
                                            () => _toggleFavorite(productId),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_shopping_cart,
                                          color: Colors.green,
                                        ),
                                        onPressed:
                                            () =>
                                                _addToCart(productId, product),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 100.ms * index, duration: 400.ms)
                          .slideY(begin: 0.05),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

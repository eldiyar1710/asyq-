import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<dynamic, dynamic>> _favorites = [];
  String _sortBy = 'name_asc';
  late AnimationController _animationController;
  bool _isSelectionMode = false;
  Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    if (userId == null) return;
    final favSnapshot = await _dbRef.child('favorites/$userId').get();

    List<Map<dynamic, dynamic>> temp = [];
    if (favSnapshot.exists) {
      Map<dynamic, dynamic> favData = favSnapshot.value as Map;
      for (var entry in favData.entries) {
        final productSnapshot =
            await _dbRef.child('products/${entry.key}').get();
        if (productSnapshot.exists) {
          Map product = productSnapshot.value as Map;
          product['id'] = entry.key;
          temp.add(product);
        }
      }
    }
    setState(() {
      _favorites = temp;
      _applySorting();
    });
  }

  void _applySorting() {
    setState(() {
      if (_sortBy == 'price_asc') {
        _favorites.sort((a, b) => (a['price'] as num).compareTo(b['price']));
      } else if (_sortBy == 'price_desc') {
        _favorites.sort((a, b) => (b['price'] as num).compareTo(a['price']));
      } else if (_sortBy == 'name_asc') {
        _favorites.sort(
          (a, b) => (a['name'] as String).toLowerCase().compareTo(
            (b['name'] as String).toLowerCase(),
          ),
        );
      } else if (_sortBy == 'discount_desc') {
        _favorites.sort(
          (a, b) => (b['discount'] as num).compareTo(a['discount'] as num),
        );
      }
    });
  }

  Future<void> _buyProduct(Map product) async {
    final cartRef = _dbRef.child('cart/${userId}/${product['id']}');
    DatabaseEvent event = await cartRef.once();
    if (event.snapshot.value != null) {
      int currentQuantity = (event.snapshot.value as Map)['quantity'] ?? 1;
      await cartRef.update({'quantity': currentQuantity + 1});
    } else {
      await cartRef.set({
        'id': product['id'],
        'name': product['name'],
        'price': product['price'],
        'image': product['image'],
        'quantity': 1,
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Тауар "${product['name']}" себетке қосылды'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _buySelectedProducts() async {
    List<Map> selectedProducts =
        _selectedIndices.map((index) => _favorites[index]).toList();
    for (var product in selectedProducts) {
      await _buyProduct(product);
    }
    setState(() {
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
  }

  void _openProductDetail(Map product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(product: product),
      ),
    );
  }

  Future<void> _removeFromFavorites(Map product) async {
    if (userId == null) return;
    await _dbRef.child('favorites/$userId/${product['id']}').remove();
  }

  void _removeSelectedProducts() async {
    List<Map> selectedProducts =
        _selectedIndices.map((index) => _favorites[index]).toList();
    for (var product in selectedProducts) {
      await _removeFromFavorites(product);
    }
    setState(() {
      _favorites.removeWhere((product) => selectedProducts.contains(product));
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Таңдалған тауарлар өшірілді'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
      if (_selectedIndices.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Фон
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://static.vecteezy.com/system/resources/previews/016/773/211/original/a-couple-is-shopping-in-the-grocery-market-store-a-woman-holding-a-trolley-and-a-man-holds-gifts-chinese-new-year-shopping-illustration-vector.jpg',
                ),
                fit: BoxFit.cover,
                opacity: 0.9,
              ),
            ),
          ),
          Container(color: Colors.white.withOpacity(0.85)),
          SafeArea(
            child: Column(
              children: [
                AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: Text(
                    _isSelectionMode
                        ? 'Таңдалған: ${_selectedIndices.length}'
                        : 'Таңдаулылар',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  centerTitle: true,
                  leading:
                      _isSelectionMode
                          ? IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.black87,
                            ),
                            onPressed: () {
                              setState(() {
                                _isSelectionMode = false;
                                _selectedIndices.clear();
                              });
                            },
                          )
                          : null,
                  actions: [
                    if (!_isSelectionMode)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.sort, color: Colors.black87),
                        onSelected: (val) {
                          _sortBy = val;
                          _applySorting();
                        },
                        itemBuilder:
                            (ctx) => const [
                              PopupMenuItem(
                                value: 'name_asc',
                                child: Text('Атауы бойынша А-Я'),
                              ),
                              PopupMenuItem(
                                value: 'price_asc',
                                child: Text('Бағасы бойынша ↑'),
                              ),
                              PopupMenuItem(
                                value: 'price_desc',
                                child: Text('Бағасы бойынша ↓'),
                              ),
                              PopupMenuItem(
                                value: 'discount_desc',
                                child: Text('Жеңілдік бойынша'),
                              ),
                            ],
                      ),
                  ],
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadFavorites,
                    child:
                        _favorites.isEmpty
                            ? const Center(
                              child: Text(
                                'Таңдаулы тауарлар жоқ',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.black54,
                                ),
                              ),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _favorites.length,
                              itemBuilder: (ctx, index) {
                                final product = _favorites[index];
                                final isSelected = _selectedIndices.contains(
                                  index,
                                );
                                return Dismissible(
                                  key: ValueKey(product['id']),
                                  direction: DismissDirection.horizontal,
                                  background: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    alignment: Alignment.centerLeft,
                                    color: Colors.green,
                                    child: const Icon(
                                      Icons.shopping_cart,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                  secondaryBackground: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    alignment: Alignment.centerRight,
                                    color: Colors.red,
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                  onDismissed: (direction) async {
                                    if (direction ==
                                        DismissDirection.startToEnd) {
                                      setState(() {
                                        _favorites.removeAt(index);
                                      });
                                      await _buyProduct(product);
                                    } else {
                                      setState(() {
                                        _favorites.removeAt(index);
                                      });
                                      await _removeFromFavorites(product);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Таңдаулылардан өшірілді: ${product['name']}',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  child: FadeTransition(
                                    opacity: _animationController,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.1),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: _animationController,
                                          curve: Curves.easeOut,
                                        ),
                                      ),
                                      child: GestureDetector(
                                        onTap:
                                            _isSelectionMode
                                                ? () => _toggleSelection(index)
                                                : () =>
                                                    _openProductDetail(product),
                                        onLongPress: () {
                                          setState(() {
                                            _isSelectionMode = true;
                                            _toggleSelection(index);
                                          });
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                isSelected
                                                    ? Colors.green.withOpacity(
                                                      0.1,
                                                    )
                                                    : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border:
                                                isSelected
                                                    ? Border.all(
                                                      color: Colors.green,
                                                      width: 2,
                                                    )
                                                    : null,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey.withOpacity(
                                                  0.3,
                                                ),
                                                blurRadius: 12,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: ListTile(
                                            contentPadding:
                                                const EdgeInsets.all(12),
                                            leading: Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Image.network(
                                                    product['image'],
                                                    width: 60,
                                                    height: 60,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) => const Icon(
                                                          Icons.broken_image,
                                                          size: 60,
                                                          color: Colors.grey,
                                                        ),
                                                  ),
                                                ),
                                                if (isSelected)
                                                  Positioned(
                                                    top: 0,
                                                    right: 0,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            2,
                                                          ),
                                                      decoration:
                                                          const BoxDecoration(
                                                            color: Colors.green,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                      child: const Icon(
                                                        Icons.check,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            title: Text(
                                              product['name'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                                fontSize: 16,
                                              ),
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Бағасы: ${product['price']}₸',
                                                  style: const TextStyle(
                                                    color: Colors.black54,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                if ((product['discount']
                                                        as num) >
                                                    0)
                                                  Text(
                                                    'Жеңілдік: ${product['discount']}%',
                                                    style: const TextStyle(
                                                      color: Colors.orange,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            trailing:
                                                !_isSelectionMode
                                                    ? ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.green,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 16,
                                                              vertical: 8,
                                                            ),
                                                      ),
                                                      onPressed:
                                                          () => _buyProduct(
                                                            product,
                                                          ),
                                                      child: const Text(
                                                        'Сатып алу',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    )
                                                    : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ),
                if (_isSelectionMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onPressed: _removeSelectedProducts,
                          child: const Text(
                            'Барлығын өшіру',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 5,
                            ),
                          ),
                          onPressed: _buySelectedProducts,
                          child: const Text(
                            'Барлығын сатып алу',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProductDetailScreen extends StatefulWidget {
  final Map product;
  const ProductDetailScreen({super.key, required this.product});

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

    final reviewRef = _reviewsRef.child(widget.product['id']).push();
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

  Future<double> _getAverageRating() async {
    final snapshot = await _reviewsRef.child(widget.product['id']).get();
    if (!snapshot.exists || snapshot.value == null) return 0.0;
    final reviews = Map<dynamic, dynamic>.from(snapshot.value as Map);
    if (reviews.isEmpty) return 0.0;
    double totalRating = reviews.values.fold(
      0,
      (sum, review) => sum + (review['rating'] ?? 0),
    );
    return totalRating / reviews.length;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.product['name'],
          style: const TextStyle(color: Colors.black87, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: FutureBuilder<double>(
        future: _getAverageRating(),
        builder: (context, snapshot) {
          final averageRating = snapshot.data ?? 0.0;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        widget.product['image'],
                        width: 250,
                        height: 250,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) => const Icon(
                              Icons.broken_image,
                              size: 100,
                              color: Colors.grey,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.product['name'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Бағасы: ${widget.product['price']}₸',
                    style: const TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  if ((widget.product['discount'] as num) > 0)
                    Text(
                      'Жеңілдік: ${widget.product['discount']}%',
                      style: const TextStyle(fontSize: 18, color: Colors.green),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Сипаттамасы: ${widget.product['description'] ?? 'Сипаттама жоқ'}',
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Рейтинг: ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(
                        5,
                        (i) => Icon(
                          Icons.star,
                          color: i < averageRating ? Colors.amber : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum ProductType { milk, fruits, berries, meat, fish, vegetables }

extension ProductTypeExtension on ProductType {
  String get asString {
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
        return 'көк-өніс';
    }
  }
}

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _warehouseController = TextEditingController();
  final _discountController = TextEditingController();
  final _quantityController = TextEditingController();
  final _imageUrlController = TextEditingController();

  ProductType? _selectedType;
  File? _selectedImage;
  String? _editingProductId;
  String? _editingImageUrl;
  bool _isLoading = false;
  final _picker = ImagePicker();
  final user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _reviewsRef = FirebaseDatabase.instance.ref().child(
    'reviews',
  );

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'product_images/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await storageRef.putFile(image);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('Суретті жүктеу қатесі: $e');
      return null;
    }
  }

  Future<void> _addOrUpdateProduct() async {
    if (!_formKey.currentState!.validate() || _selectedType == null) return;
    setState(() => _isLoading = true);

    try {
      final price = double.parse(_priceController.text.trim());
      final discount = double.tryParse(_discountController.text.trim()) ?? 0.0;
      final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
      String? imageUrl = _editingImageUrl;

      if (_selectedImage != null) {
        imageUrl = await _uploadImage(_selectedImage!);
        if (imageUrl == null) throw 'Суретті жүктеу мүмкін болмады';
      } else if (_imageUrlController.text.isNotEmpty) {
        imageUrl = _imageUrlController.text.trim();
      }

      final productRef = FirebaseDatabase.instance.ref('products');
      final productKey = _editingProductId ?? productRef.push().key;
      if (productKey == null) return;

      final productData = {
        'id': productKey,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': price,
        'warehouse': _warehouseController.text.trim(),
        'type': _selectedType!.asString,
        'discount': discount,
        'quantity': quantity,
        'image': imageUrl ?? '',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'userId': user?.uid ?? '',
      };

      await productRef.child(productKey).set(productData);

      if (discount > 20) {
        await FirebaseDatabase.instance
            .ref('discounts/$productKey')
            .set(productData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editingProductId != null ? 'Тауар жаңартылды' : 'Тауар қосылды',
          ),
        ),
      );
      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Қате: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _warehouseController.clear();
    _discountController.clear();
    _quantityController.clear();
    _imageUrlController.clear();
    _selectedImage = null;
    _editingProductId = null;
    _editingImageUrl = null;
    _selectedType = null;
  }

  void _editProduct(Map product) {
    setState(() {
      _editingProductId = product['id'];
      _nameController.text = product['name'];
      _descriptionController.text = product['description'];
      _priceController.text = product['price'].toString();
      _warehouseController.text = product['warehouse'];
      _discountController.text = product['discount'].toString();
      _quantityController.text = product['quantity'].toString();
      _imageUrlController.text = product['image'];
      _editingImageUrl = product['image'];
      _selectedType = ProductType.values.firstWhere(
        (e) => e.asString == product['type'],
        orElse: () => ProductType.milk,
      );
    });
  }

  Stream<List<Map>> getMyProductsStream() {
    return FirebaseDatabase.instance.ref('products').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];
      return data.values
          .where((item) => item['userId'] == user?.uid)
          .map<Map>((item) => Map<String, dynamic>.from(item))
          .toList();
    });
  }

  Future<Map<String, dynamic>> _getProductRating(String productId) async {
    final snapshot = await _reviewsRef.child(productId).get();
    if (!snapshot.exists) return {'average': 0.0, 'count': 0};
    final reviews = Map<dynamic, dynamic>.from(snapshot.value as Map);
    if (reviews.isEmpty) return {'average': 0.0, 'count': 0};
    double totalRating = reviews.values.fold(
      0,
      (sum, review) => sum + (review['rating'] ?? 0),
    );
    return {'average': totalRating / reviews.length, 'count': reviews.length};
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildRoundedTextField(
    TextEditingController controller,
    String label, [
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  ]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator:
            (value) =>
                value == null || value.isEmpty ? '$label енгізіңіз' : null,
        decoration: _inputDecoration(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Тауар қосу'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
              'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?fit=crop&w=1350&q=80',
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _selectedImage != null
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedImage!,
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        )
                        : (_editingImageUrl?.isNotEmpty ?? false)
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _editingImageUrl!,
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        )
                        : const Icon(
                          Icons.image,
                          size: 100,
                          color: Colors.grey,
                        ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(
                            Icons.photo_library,
                            color: Colors.black54,
                          ),
                          label: const Text(
                            'Галерея',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(
                            Icons.camera_alt,
                            color: Colors.black54,
                          ),
                          label: const Text(
                            'Камера',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildRoundedTextField(_nameController, 'Атауы'),
                    _buildRoundedTextField(
                      _priceController,
                      'Бағасы',
                      TextInputType.number,
                    ),
                    _buildRoundedTextField(
                      _discountController,
                      'Жеңілдік (%)',
                      TextInputType.number,
                    ),
                    _buildRoundedTextField(
                      _quantityController,
                      'Саны',
                      TextInputType.number,
                    ),
                    _buildRoundedTextField(_warehouseController, 'Қойма'),
                    _buildRoundedTextField(
                      _descriptionController,
                      'Сипаттама',
                      TextInputType.multiline,
                      3,
                    ),
                    DropdownButtonFormField<ProductType>(
                      decoration: _inputDecoration('Санат'),
                      value: _selectedType,
                      items:
                          ProductType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type.asString.toUpperCase()),
                            );
                          }).toList(),
                      onChanged: (val) => setState(() => _selectedType = val),
                      validator:
                          (val) => val == null ? 'Санатты таңдаңыз' : null,
                    ),
                    const SizedBox(height: 10),
                    _buildRoundedTextField(
                      _imageUrlController,
                      'Сурет URL (міндетті емес)',
                    ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontSize: 18),
                          ),
                          onPressed: _addOrUpdateProduct,
                          child: Text(
                            _editingProductId != null
                                ? 'Өзгерістерді сақтау'
                                : 'Тауар қосу',
                          ),
                        ),
                    const SizedBox(height: 20),
                    const Divider(thickness: 1),
                    const SizedBox(height: 10),
                    const Text(
                      'Менің тауарларым',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    StreamBuilder<List<Map>>(
                      stream: getMyProductsStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Text('Қосылған тауарлар жоқ');
                        }
                        final products = snapshot.data!;
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        product['image'] ?? '',
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.broken_image,
                                                  size: 60,
                                                ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product['name'],
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Бағасы: ${product['price']}₸',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          FutureBuilder<Map<String, dynamic>>(
                                            future: _getProductRating(
                                              product['id'],
                                            ),
                                            builder: (context, snapshot) {
                                              if (!snapshot.hasData)
                                                return const SizedBox();
                                              final ratingData = snapshot.data!;
                                              return Row(
                                                children: [
                                                  const Icon(
                                                    Icons.star,
                                                    color: Colors.amber,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${ratingData['average'].toStringAsFixed(1)} (${ratingData['count']} пікір)',
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
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.green,
                                      ),
                                      onPressed: () => _editProduct(product),
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(
                              delay: 100.ms * index,
                              duration: 400.ms,
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
      ),
    );
  }
}

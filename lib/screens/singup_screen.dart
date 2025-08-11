import 'dart:async';
import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

enum UserRole { buyer, seller, courier }

extension UserRoleExtension on UserRole {
  String get asString {
    switch (this) {
      case UserRole.buyer:
        return 'buyer';
      case UserRole.seller:
        return 'seller';
      case UserRole.courier:
        return 'courier';
    }
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  final _warehouseController = TextEditingController();
  final _ageController = TextEditingController();

  UserRole? _selectedRole;
  bool _isLoading = false;
  int _currentImageIndex = 0;
  Timer? _timer;

  final List<String> _backgroundImages = [
    'https://miro.medium.com/v2/resize:fit:1200/0*lQf_opGhPZHnUisW.png', // қойма
    'https://filearchive.cnews.ru/img/book/2023/04/04/logistics_systems.webp', // жеткізу
    'https://mc.today/wp-content/uploads/2023/08/Depositphotos_104486710_L-1024x682.jpg', // логистика
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      setState(() {
        _currentImageIndex =
            (_currentImageIndex + 1) % _backgroundImages.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _warehouseController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future _signUp() async {
    if (!_formKey.currentState!.validate() || _selectedRole == null) return;
    setState(() => _isLoading = true);
    try {
      UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      final user = cred.user;
      if (user == null) return;
      String role = _selectedRole!.asString;
      final userData = {'email': user.email, 'role': role};
      if (role == 'buyer') {
        userData['deliveryAddress'] = _addressController.text.trim();
      } else if (role == 'seller') {
        userData['dispatchAddress'] = _addressController.text.trim();
        userData['warehouseAddress'] = _warehouseController.text.trim();
      } else if (role == 'courier') {
        userData['age'] = _ageController.text.trim();
      }
      DatabaseReference ref = FirebaseDatabase.instance.ref(
        'users/${user.uid}',
      );
      await ref.set(userData);
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Қате: ${e.message}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login'); // Кіру экранына өту
  }

  Widget _buildRoleSpecificFields() {
    switch (_selectedRole) {
      case UserRole.buyer:
        return _buildInputField(
          controller: _addressController,
          label: 'Жеткізу мекенжайы',
          validator:
              (val) =>
                  (val == null || val.isEmpty)
                      ? 'Жеткізу мекенжайын енгізіңіз'
                      : null,
        );
      case UserRole.seller:
        return Column(
          children: [
            _buildInputField(
              controller: _addressController,
              label: 'Жөнелту мекенжайы',
              validator:
                  (val) =>
                      (val == null || val.isEmpty)
                          ? 'Жөнелту мекенжайын енгізіңіз'
                          : null,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _warehouseController,
              label: 'Қойма мекенжайы',
              validator:
                  (val) =>
                      (val == null || val.isEmpty)
                          ? 'Қойма мекенжайын енгізіңіз'
                          : null,
            ),
          ],
        );
      case UserRole.courier:
        return _buildInputField(
          controller: _ageController,
          label: 'Жасы',
          keyboardType: TextInputType.number,
          validator: (val) {
            if (val == null || val.isEmpty) return 'Жасын енгізіңіз';
            int? age = int.tryParse(val);
            if (age == null || age < 18) return 'Ең төмені 18 жас';
            return null;
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(0, 245, 242, 242),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: _signOut,
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(_backgroundImages[_currentImageIndex]),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.white.withOpacity(0.7),
              BlendMode.lighten,
            ),
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Тіркелу',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildInputField(
                      controller: _emailController,
                      label: 'Email',
                      validator:
                          (val) =>
                              (val == null || !EmailValidator.validate(val))
                                  ? 'Email дұрыс емес'
                                  : null,
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      controller: _passwordController,
                      label: 'Құпия сөз',
                      keyboardType: TextInputType.visiblePassword,
                      validator:
                          (val) =>
                              (val == null || val.length < 6)
                                  ? 'Ең аздау 6 таңба'
                                  : null,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Рөлді таңдаңыз:',
                      style: TextStyle(fontSize: 16),
                    ),
                    ListTile(
                      title: const Text('Сатып алушы'),
                      leading: Radio<UserRole>(
                        value: UserRole.buyer,
                        groupValue: _selectedRole,
                        onChanged: (UserRole? val) {
                          setState(() => _selectedRole = val);
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('Сатушы'),
                      leading: Radio<UserRole>(
                        value: UserRole.seller,
                        groupValue: _selectedRole,
                        onChanged: (UserRole? val) {
                          setState(() => _selectedRole = val);
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('Курьер'),
                      leading: Radio<UserRole>(
                        value: UserRole.courier,
                        groupValue: _selectedRole,
                        onChanged: (UserRole? val) {
                          setState(() => _selectedRole = val);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildRoleSpecificFields(),
                    const SizedBox(height: 30),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                          onPressed: _signUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Тіркелу',
                            style: TextStyle(fontSize: 18),
                          ),
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

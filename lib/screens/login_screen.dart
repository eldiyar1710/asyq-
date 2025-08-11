import 'package:azyq/services/snack_bar.dart';
import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isHiddenPassword = true;
  TextEditingController emailTextInputController = TextEditingController();
  TextEditingController passwordTextInputController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    emailTextInputController.dispose();
    passwordTextInputController.dispose();
    super.dispose();
  }

  void togglePasswordView() {
    setState(() {
      isHiddenPassword = !isHiddenPassword;
    });
  }

  Future<void> login() async {
    final navigator = Navigator.of(context);
    final isValid = formKey.currentState!.validate();
    if (!isValid) return;

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailTextInputController.text.trim(),
        password: passwordTextInputController.text.trim(),
      );

      if (!mounted) return;

      navigator.pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        SnackBarService.showSnackBar(
          context,
          'Email немесе құпия сөз қате. Қайталап көріңіз',
          true,
        );
        return;
      } else {
        SnackBarService.showSnackBar(
          context,
          'Белгісіз қате! Қайталап көріңіз немесе қолдау қызметіне хабарласыңыз.',
          true,
        );
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(
            child: Image.network(
              'https://static.tildacdn.info/tild3762-3136-4266-a434-613862666132/undraw_Creation_re_d.png',
              fit: BoxFit.cover,
            ),
          ),

          Container(color: Colors.black.withOpacity(0.2)),

          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    height: 230,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Positioned(
                          top: -60,
                          left: -60,
                          child: Container(
                                width: 180,
                                height: 180,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2C3E50),
                                  shape: BoxShape.circle,
                                ),
                              )
                              .animate()
                              .fade(duration: 600.ms)
                              .slideY(begin: -0.3),
                        ),
                        Positioned(
                          top: 80,
                          right: -20,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 50, 201, 231),
                              shape: BoxShape.circle,
                            ),
                          ).animate().fade(duration: 800.ms).slideX(begin: 0.5),
                        ),
                        Positioned(
                          top: -10,
                          right: 70,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 105, 69, 188),
                              shape: BoxShape.circle,
                            ),
                          ).animate().fade(duration: 800.ms).slideX(begin: 0.5),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Cәтті \ оралумен',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 254, 211, 0),
                          height: 1.2,
                        ),
                      ),
                    ),
                  ).animate().fade(delay: 300.ms).slideX(begin: -0.2),

                  const SizedBox(height: 40),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Form(
                      key: formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            keyboardType: TextInputType.emailAddress,
                            controller: emailTextInputController,
                            validator:
                                (email) =>
                                    email != null &&
                                            !EmailValidator.validate(email)
                                        ? 'Дұрыс Email енгізіңіз'
                                        : null,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'Email енгізіңіз',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white70,
                            ),
                          ).animate().fade(delay: 500.ms).slideY(begin: 0.1),

                          const SizedBox(height: 24),

                          TextFormField(
                            controller: passwordTextInputController,
                            obscureText: isHiddenPassword,
                            validator:
                                (value) =>
                                    value != null && value.length < 6
                                        ? 'Кемінде 6 таңба'
                                        : null,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            decoration: InputDecoration(
                              labelText: 'Құпия сөз',
                              hintText: 'Құпия сөзді енгізіңіз',
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white70,
                              suffixIcon: InkWell(
                                onTap: togglePasswordView,
                                child: Icon(
                                  isHiddenPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                          ).animate().fade(delay: 600.ms).slideY(begin: 0.1),

                          const SizedBox(height: 30),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                255,
                                244,
                                177,
                                9,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: login,
                            child: const Text(
                              'Кіру',
                              style: TextStyle(fontSize: 16),
                            ),
                          ).animate().fade(delay: 700.ms).slideY(begin: 0.1),

                          const SizedBox(height: 20),

                          TextButton(
                            onPressed:
                                () =>
                                    Navigator.of(context).pushNamed('/signup'),
                            child: const Text(
                              'Тіркелу',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ).animate().fade(delay: 800.ms),

                          TextButton(
                            onPressed:
                                () => Navigator.of(
                                  context,
                                ).pushNamed('/reset_password'),
                            child: const Text('Құпия сөзді қалпына келтіру'),
                          ).animate().fade(delay: 900.ms),
                        ],
                      ),
                    ),
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

class SnackBarService {
  static void showSnackBar(BuildContext context, String s, bool bool) {}
}

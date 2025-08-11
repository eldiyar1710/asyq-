import 'dart:async';
import 'package:azyq/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:azyq/screens/home_screen.dart';
import 'package:azyq/services/snack_bar.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isEmailVerified = false;
  bool canResendEmail = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;
    if (!isEmailVerified) {
      sendVerificationEmail();
      timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => checkEmailVerified(),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future checkEmailVerified() async {
    await FirebaseAuth.instance.currentUser!.reload();
    setState(() {
      isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;
    });
    if (isEmailVerified) timer?.cancel();
  }

  Future sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      await user.sendEmailVerification();
      setState(() => canResendEmail = false);
      await Future.delayed(const Duration(seconds: 5));
      setState(() => canResendEmail = true);
    } catch (e) {
      if (mounted) {
        SnackBarService.showSnackBar(context, '$e', true);
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      isEmailVerified
          ? const HomeScreen()
          : Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(title: const Text('Email растау')),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Email растау қажет',
                      style: TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Email мекенжайыңызды растау үшін жіберілген хатты тексеріңіз',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await FirebaseAuth.instance.currentUser
                              ?.sendEmailVerification();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Растау хаты қайта жіберілді'),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Қате: $e')));
                        }
                      },
                      child: const Text('Хатты қайта жіберу'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (mounted) {
                          Navigator.of(context).pushReplacementNamed('/login');
                        }
                      },
                      child: const Text('Шығу'),
                    ),
                  ],
                ),
              ),
            ),
          );
}

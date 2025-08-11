import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:azyq/screens/add_product_screen.dart';
import 'package:azyq/screens/cart_screen.dart';
import 'package:azyq/screens/home_screen.dart';
import 'package:azyq/screens/login_screen.dart';
import 'package:azyq/screens/order_screen.dart';
import 'package:azyq/screens/profile_screen.dart';
import 'package:azyq/screens/reset_password_screen.dart';
import 'package:azyq/screens/singup_screen.dart';
import 'package:azyq/screens/verify_email_screen.dart';
import 'package:azyq/screens/seller_screen.dart';
import 'package:azyq/screens/courier_screen.dart';
import 'package:azyq/screens/courier_home_screen.dart';
import 'package:azyq/screens/confirm_delivery_screen.dart';
import 'package:azyq/screens/seller_notifications_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Azyq',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/login': (context) => const LoginScreen(),
        '/addProduct': (context) => const AddProductScreen(),
        '/order': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>?;
          return OrderScreen(productData: args ?? {});
        },
        '/profile': (context) => const ProfileScreen(),
        '/reset_password': (context) => const ResetPasswordScreen(),
        '/verify_email': (context) => const VerifyEmailScreen(),
        '/seller': (context) => const SellerScreen(),
        '/courier': (context) => const CourierScreen(),
        '/cart': (context) => const CartScreen(),
        '/courier_home': (context) => const CourierHomeScreen(),
        '/confirm_delivery': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>?;
          return ConfirmDeliveryScreen(
            orderId: args?['orderId'] as String? ?? '',
            address: args?['address'] as String? ?? '',
            items: args?['items'] as List<Map<String, dynamic>>? ?? [],
            total: args?['total'] as double? ?? 0.0,
            confirmationCode: '',
          );
        },
        '/seller_notifications': (context) => const SellerNotificationsScreen(),
      },
      onUnknownRoute:
          (settings) => MaterialPageRoute(
            builder:
                (context) => const Scaffold(
                  body: Center(child: Text('Маршрут не найден')),
                ),
          ),
    );
  }
}

class FirebaseStream {
  const FirebaseStream();
}

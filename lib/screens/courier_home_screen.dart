import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'courier_screen.dart';
import 'profile_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CourierHomeScreen extends StatefulWidget {
  const CourierHomeScreen({super.key});

  @override
  State<CourierHomeScreen> createState() => _CourierHomeScreenState();
}

class _CourierHomeScreenState extends State<CourierHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [CourierScreen(), ProfileScreen()];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(title: const Text('Курьер панелі')),
      body: Stack(
        children: [
          SizedBox(
            height: size.height,
            width: size.width,
            child: Image.network(
              'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQhAulsx5rV2lImXmjyVR34ta_hLUIETXEazQ&s',
              fit: BoxFit.cover,
            ),
          ),

          Container(
                margin: const EdgeInsets.only(
                  top: 50,
                  left: 10,
                  right: 10,
                  bottom: 70,
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: _pages[_currentIndex],
              )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, duration: 800.ms, curve: Curves.easeOutBack)
              .scaleXY(
                begin: 0.95,
                end: 1.0,
                duration: 800.ms,
                curve: Curves.elasticOut,
              ),
        ],
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          selectedItemColor: Colors.green.shade700,
          unselectedItemColor: Colors.grey.shade600,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping),
              label: 'Тапсырыстар',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
          ],
        ),
      ),
    );
  }
}

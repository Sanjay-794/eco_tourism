import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'main_screen.dart';
import 'trek_details.dart';
import 'eco_calculator.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() =>
      _NavigationScreenState();
}

class _NavigationScreenState
    extends State<NavigationScreen> {

  int index = 0;

  final screens = [
    HomeScreen(),
    TrekDetails(),
    MainScreen(),
    EcoCalculator(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: screens[index],

      bottomNavigationBar: BottomNavigationBar(
  currentIndex: index,

  onTap: (i) {
    setState(() {
      index = i;
    });
  },

  type: BottomNavigationBarType.fixed,

  backgroundColor: Colors.black,

  selectedItemColor: Colors.greenAccent,
  unselectedItemColor: Colors.white54,

  showUnselectedLabels: true,

  items: const [
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: "Home",
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.map),
      label: "Trail",
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.warning),
      label: "Emergency",
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.eco),
      label: "Eco",
    ),
  ],
),
    );
  }
}
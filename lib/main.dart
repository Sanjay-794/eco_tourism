
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/main_screen.dart';
import 'screens/trek_details.dart';
import 'screens/eco_calculator.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainScreen(),
      home: TrekDetails(),
      home: EcoCalculator(),
    );
  }
}
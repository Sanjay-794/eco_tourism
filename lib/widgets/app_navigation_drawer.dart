import 'package:flutter/material.dart';
import 'package:eco_tourism/screens/how_it_works_screen.dart';
import 'package:eco_tourism/screens/my_activity_screen.dart';
import 'package:eco_tourism/screens/plan_trek_screen.dart';

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0A0F1E),
      child: SafeArea(
        child: Column(
          children: [
            const ListTile(
              title: Text(
                'TrailSafe Menu',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.white),
              title: const Text('My Activity', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Check-ins history and undo',
                style: TextStyle(color: Colors.white60),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyActivityScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.route, color: Colors.white),
              title: const Text('Plan My Trek', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Get suggested treks by inputs',
                style: TextStyle(color: Colors.white60),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PlanTrekScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white),
              title: const Text('How It Works', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'See app features in an interactive guide',
                style: TextStyle(color: Colors.white60),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HowItWorksScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

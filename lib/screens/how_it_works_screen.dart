import 'package:flutter/material.dart';

class HowItWorksScreen extends StatefulWidget {
  const HowItWorksScreen({super.key});

  @override
  State<HowItWorksScreen> createState() => _HowItWorksScreenState();
}

class _HowItWorksScreenState extends State<HowItWorksScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _pages = const [
    {
      'title': 'Discover Trails',
      'subtitle': 'Find nearby treks with live map markers and route lines.',
      'icon': Icons.map,
      'color': Color(0xFF1E88E5),
      'details': [
        'Tap any trail marker on map',
        'See route from your location',
        'Check weather and distance instantly',
      ],
    },
    {
      'title': 'Safety Intelligence',
      'subtitle': 'Get live status from temperature, rain percentage, and conditions.',
      'icon': Icons.shield,
      'color': Color(0xFF00897B),
      'details': [
        'SAFE, RISKY, DANGER status',
        'Blinking alert for severe weather',
        'Rain percentage and condition insights',
      ],
    },
    {
      'title': 'Smart Check-In',
      'subtitle': 'One active check-in per device with undo anytime.',
      'icon': Icons.verified_user,
      'color': Color(0xFFF9A825),
      'details': [
        'Avoid duplicate check-ins',
        'Undo from My Activity screen',
        'Track your check-in history locally',
      ],
    },
    {
      'title': 'Emergency SOS',
      'subtitle': 'Activate SOS to log alert and contact emergency services fast.',
      'icon': Icons.sos,
      'color': Color(0xFFD32F2F),
      'details': [
        'Logs SOS event to Firestore',
        'Captures location when available',
        'Starts emergency call flow instantly',
      ],
    },
    {
      'title': 'Plan My Trek',
      'subtitle': 'Get recommendations by distance, difficulty, and live safety status.',
      'icon': Icons.route,
      'color': Color(0xFF7CB342),
      'details': [
        'Difficulty from baseStatus',
        'Weather-based status filtering',
        'Distance from your current location',
      ],
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_currentIndex == _pages.length - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050A16),
        foregroundColor: Colors.greenAccent,
        title: const Text('How It Works'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildIndicator(),
            const SizedBox(height: 16),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (value) {
                  setState(() {
                    _currentIndex = value;
                  });
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _HowCard(
                    title: page['title'] as String,
                    subtitle: page['subtitle'] as String,
                    icon: page['icon'] as IconData,
                    color: page['color'] as Color,
                    details: (page['details'] as List<dynamic>).cast<String>(),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentIndex == _pages.length - 1
                        ? Colors.greenAccent
                        : Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _currentIndex == _pages.length - 1
                      ? () => Navigator.of(context).pop()
                      : _goNext,
                  icon: Icon(
                    _currentIndex == _pages.length - 1
                        ? Icons.check_circle
                        : Icons.arrow_forward,
                  ),
                  label: Text(
                    _currentIndex == _pages.length - 1
                        ? 'Start Using App'
                        : 'Next Feature',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (index) {
        final active = index == _currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 26 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? Colors.greenAccent : Colors.white24,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

class _HowCard extends StatelessWidget {
  const _HowCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.details,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.25),
              const Color(0xFF0C1428),
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              ...details.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, color: color, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          line,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

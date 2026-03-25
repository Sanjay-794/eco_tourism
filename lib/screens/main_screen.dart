import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:eco_tourism/widgets/app_navigation_drawer.dart';
import 'package:eco_tourism/widgets/custom_app_bar.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({
    super.key,
    this.trailName,
    this.emergencyData,
    this.trailId,
  });

  final String? trailName;
  final Map<String, dynamic>? emergencyData;
  final String? trailId;

  Future<void> _callNumber(BuildContext context, String number) async {
    final cleaned = number.trim();
    if (cleaned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available.')),
      );
      return;
    }

    final uri = Uri.parse('tel:$cleaned');
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open dialer.')),
      );
    }
  }

  List<Map<String, String>> _buildEmergencyCards() {
    final data = emergencyData ?? {};

    final police = (data['police'] ?? '100').toString();
    final ambulance = (data['ambulance'] ?? '108').toString();
    final rescue = (data['rescue'] ?? '1070').toString();
    final localContact = (data['local_contact'] ?? '').toString();

    final cards = <Map<String, String>>[
      {
        'title': 'Police',
        'subtitle': 'Law Enforcement Services',
        'type': 'EMERGENCY',
        'phone': police,
      },
      {
        'title': 'Ambulance',
        'subtitle': 'Paramedic & EMS Response',
        'type': 'MEDICAL',
        'phone': ambulance,
      },
      {
        'title': 'Mountain Rescue',
        'subtitle': 'Search & Rescue Teams',
        'type': 'SPECIALIZED',
        'phone': rescue,
      },
    ];

    if (localContact.isNotEmpty) {
      cards.add(
        {
          'title': 'Local Contact',
          'subtitle': 'Nearby Support Contact',
          'type': 'LOCAL',
          'phone': localContact,
        },
      );
    }

    return cards;
  }

  IconData _cardIcon(String title) {
    if (title == 'Police') return Icons.shield;
    if (title == 'Ambulance') return Icons.medical_services;
    if (title == 'Mountain Rescue') return Icons.terrain;
    return Icons.phone;
  }

  Future<Position?> _tryGetCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  Future<void> _activateSos(
    BuildContext context,
    List<Map<String, String>> emergencyCards,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final primaryNumber =
        emergencyCards.isNotEmpty ? (emergencyCards.first['phone'] ?? '') : '';

    if (primaryNumber.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No emergency contact number found.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          color: Color(0xFF101010),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.redAccent),
                SizedBox(width: 12),
                Text(
                  'Activating SOS...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    var logSaved = false;

    try {
      final position = await _tryGetCurrentLocation();

      await FirebaseFirestore.instance.collection('sosAlerts').add({
        'trailId': trailId,
        'trailName': trailName ?? 'Unknown Trail',
        'status': 'ACTIVE',
        'source': 'mobile_app',
        'createdAt': FieldValue.serverTimestamp(),
        'primaryContact': primaryNumber,
        'contacts': emergencyCards,
        'location': position != null
            ? {
                'lat': position.latitude,
                'lng': position.longitude,
                'accuracy': position.accuracy,
              }
            : null,
      });
      logSaved = true;

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (!context.mounted) return;

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text(
          logSaved
              ? 'SOS activated. Calling emergency contact now.'
              : 'SOS call is active. Unable to save alert log, but calling now.',
        ),
      ),
    );

    await _callNumber(context, primaryNumber);
  }

  @override
  Widget build(BuildContext context) {
    final emergencyCards = _buildEmergencyCards();
    final screenTitle = trailName != null
        ? 'EMERGENCY HUB • $trailName'
        : 'EMERGENCY HUB';

    return Scaffold(
      backgroundColor: Colors.black,
      drawer: const AppNavigationDrawer(),
      body: Column(
        children: [
          CustomAppBar(
            title: 'EMERGENCY',
            onMenuTap: () => Scaffold.of(context).openDrawer(),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                /// TITLE
                Text(
                  screenTitle,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  trailName != null
                      ? 'Emergency support contacts for this trail location.'
                      : 'Immediate assistance and critical survival protocols.',
                  style: const TextStyle(
                    color: Colors.white54,
                  ),
                ),

                const SizedBox(height: 20),

                /// SOS CARD
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Colors.red,
                        Colors.redAccent
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [

                      const Text(
                        "Broadcast SOS Signal",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        "Sends GPS location to nearest rescue team",
                        style: TextStyle(
                          color: Colors.white70,
                        ),
                      ),

                      const SizedBox(height: 12),

                      ElevatedButton(
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.white,
                          foregroundColor:
                              Colors.red,
                        ),
                        onPressed: () => _activateSos(context, emergencyCards),
                        child: const Text(
                            "ACTIVATE NOW"),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /// CONTACT CARDS
                ...emergencyCards.map(
                  (item) => _contactCard(
                    context,
                    title: item['title'] ?? 'Emergency',
                    subtitle: item['subtitle'] ?? 'Support Service',
                    serviceType: item['type'] ?? 'SERVICE',
                    phoneNumber: item['phone'] ?? '',
                  ),
                ),

                const SizedBox(height: 20),

                /// SAFETY TIPS SECTION FROM FIRESTORE
                if (trailId != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Safety Tips",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "FOR THIS TRAIL",
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSafetyTipsSection(),
                    ],
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        ),
      ),
    ],
    ),
  );
}

  /// CONTACT CARD
  Widget _contactCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String serviceType,
    required String phoneNumber,
  }) {
    const coralColor = Color(0xFFFF7F6B);
    
    return Container(
      margin:
          const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(color: coralColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                _cardIcon(title),
                color: coralColor,
              ),
              Text(
                serviceType,
                style: const TextStyle(
                  color: Colors.white38,
                  letterSpacing: 1.1,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white54,
            ),
          ),

          const SizedBox(height: 10),

          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: coralColor, width: 1.5),
              foregroundColor: coralColor,
              minimumSize: const Size.fromHeight(42),
            ),
            onPressed: () => _callNumber(context, phoneNumber),
            child:
                Text('CALL $phoneNumber'),
          )
        ],
      ),
    );
  }

  /// BUILD SAFETY TIPS SECTION
  Widget _buildSafetyTipsSection() {
    if (trailId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('safetyTips')
          .where('trailId', isEqualTo: trailId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Error: ${snapshot.error}',
            style: const TextStyle(color: Colors.white70),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final tips = snapshot.data!.docs;
        if (tips.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'No safety tips available for this trail.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return Column(
          children: tips.map((doc) {
            final data = doc.data();
            final title = (data['title'] ?? 'Safety Tip').toString();
            final description = (data['description'] ?? '').toString();
            final type = (data['type'] ?? 'COMMON').toString().toUpperCase();
            final icon = data['icon'] as String?;
            final image = data['image'] as String?;

            return _safetyTipCard(
              title: title,
              description: description,
              type: type,
              iconName: icon,
              imageUrl: image,
            );
          }).toList(),
        );
      },
    );
  }

  /// SAFETY TIP CARD WIDGET
  Widget _safetyTipCard({
    required String title,
    required String description,
    required String type,
    String? iconName,
    String? imageUrl,
  }) {
    IconData? iconData;
    if (iconName != null) {
      iconData = _getIconFromName(iconName);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.blueGrey.withValues(alpha: 0.2),
        border: Border.all(color: Colors.white12),
        image: imageUrl != null && imageUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.5),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: imageUrl != null && imageUrl.isNotEmpty
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black.withValues(alpha: 0.35),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon on left (if available)
                if (iconData != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 2),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        iconData,
                        color: Colors.greenAccent,
                        size: 20,
                      ),
                    ),
                  ),
                // Title and Type Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: type == 'SPECIFIC'
                                  ? Colors.orange.withValues(alpha: 0.2)
                                  : Colors.blue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: type == 'SPECIFIC'
                                    ? Colors.orange.withValues(alpha: 0.5)
                                    : Colors.blue.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                color: type == 'SPECIFIC'
                                    ? Colors.orange
                                    : Colors.blue,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Map icon name to IconData
  IconData? _getIconFromName(String iconName) {
    final nameMap = {
      'shield': Icons.shield,
      'warning': Icons.warning,
      'info': Icons.info,
      'medical_services': Icons.medical_services,
      'health_and_safety': Icons.health_and_safety,
      'water': Icons.water,
      'terrain': Icons.terrain,
      'cloud': Icons.cloud,
      'wind_power': Icons.wind_power,
      'wb_sunny': Icons.wb_sunny,
      'ac_unit': Icons.ac_unit,
      'bolt': Icons.bolt,
      'emergency': Icons.emergency,
      'backpack': Icons.backpack,
      'hiking': Icons.hiking,
      'map': Icons.map,
      'compass_calibration': Icons.compass_calibration,
      'night_shelter': Icons.night_shelter,
      'fire_extinguisher': Icons.fire_extinguisher,
      'volunteer_activism': Icons.volunteer_activism,
      'pets': Icons.pets,
    };

    return nameMap[iconName.toLowerCase()];
  }
}
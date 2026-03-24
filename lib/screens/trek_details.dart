import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:eco_tourism/services/weather_service.dart';

class TrekDetails extends StatefulWidget {
  const TrekDetails({super.key});

  @override
  State<TrekDetails> createState() => _TrekDetailsState();
}

class _TrekDetailsState extends State<TrekDetails> {
  String? _expandedTrailId;
  final Map<String, Map<String, dynamic>?> _weatherByTrailId = {};
  final Set<String> _weatherLoading = {};

  @override
  void initState() {
    super.initState();
    _logSingleFetchStatus();
  }

  Future<void> _loadWeatherForTrail(
    String trailId,
    double? lat,
    double? lng,
  ) async {
    if (lat == null || lng == null) return;
    if (_weatherByTrailId.containsKey(trailId)) return;
    if (_weatherLoading.contains(trailId)) return;

    _weatherLoading.add(trailId);

    try {
      final weather = await WeatherService().getWeather(lat, lng);
      if (!mounted) return;
      setState(() {
        _weatherByTrailId[trailId] = weather;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weatherByTrailId[trailId] = null;
      });
    } finally {
      _weatherLoading.remove(trailId);
    }
  }

  Future<void> _logSingleFetchStatus() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('trails')
          .limit(5)
          .get();

      debugPrint('[TRAIL SCREEN] Single fetch success. docs=${snapshot.docs.length}');
      for (final doc in snapshot.docs) {
        debugPrint('[TRAIL SCREEN] docId=${doc.id} data=${doc.data()}');
      }
    } on FirebaseException catch (e) {
      debugPrint('[TRAIL SCREEN] Single fetch FirebaseException code=${e.code} message=${e.message}');
    } catch (e) {
      debugPrint('[TRAIL SCREEN] Single fetch unknown error: $e');
    }
  }

  int _toCheckInCount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _safetyFromWeather(String baseStatus, Map<String, dynamic>? weather) {
    if (weather == null) {
      return baseStatus.toUpperCase();
    }

    final weatherList = weather['weather'];
    if (weatherList is List && weatherList.isNotEmpty) {
      final condition = (weatherList.first['main'] ?? '').toString();

      if (condition == 'Rain' ||
          condition == 'Thunderstorm' ||
          condition == 'Snow') {
        return 'DANGER';
      }

      if (condition == 'Clouds' ||
          condition == 'Mist' ||
          condition == 'Fog' ||
          condition == 'Haze') {
        return 'CAUTION';
      }

      return 'SAFE';
    }

    return baseStatus.toUpperCase();
  }

  Color _statusColor(String status) {
    if (status == 'DANGER') return Colors.redAccent;
    if (status == 'CAUTION') return Colors.amber;
    return Colors.greenAccent;
  }

  String _conditionLabel(Map<String, dynamic>? weather) {
    if (weather == null) return '--';
    final weatherList = weather['weather'];
    if (weatherList is List && weatherList.isNotEmpty) {
      return (weatherList.first['main'] ?? '--').toString();
    }
    return '--';
  }

  String _temperatureLabel(Map<String, dynamic>? weather) {
    if (weather == null) return '--';
    final main = weather['main'];
    if (main is Map && main['temp'] != null) {
      return '${main['temp']}°C';
    }
    return '--';
  }

  String _rainLabel(Map<String, dynamic>? weather) {
    if (weather == null) return '--';

    final rain = weather['rain'];
    if (rain is Map && rain['1h'] != null) {
      return '${rain['1h']} mm';
    }

    final weatherList = weather['weather'];
    if (weatherList is List && weatherList.isNotEmpty) {
      final condition = (weatherList.first['main'] ?? '').toString();
      if (condition == 'Rain' || condition == 'Thunderstorm') {
        return 'Yes';
      }
      return 'No';
    }

    return '--';
  }

  IconData _conditionIcon(Map<String, dynamic>? weather) {
    final condition = _conditionLabel(weather);
    if (condition == 'Rain' || condition == 'Drizzle') {
      return Icons.water_drop;
    }
    if (condition == 'Thunderstorm') {
      return Icons.bolt;
    }
    if (condition == 'Snow') {
      return Icons.ac_unit;
    }
    if (condition == 'Clouds' || condition == 'Mist' || condition == 'Fog') {
      return Icons.cloud;
    }
    return Icons.wb_sunny;
  }

  double _crowdDensityValue(int checkInCount) {
    final clamped = checkInCount.clamp(0, 40);
    return clamped / 40;
  }

  String _crowdDensityLabel(int checkInCount) {
    if (checkInCount < 8) return 'Low Activity';
    if (checkInCount < 20) return 'Moderate Activity';
    return 'High Activity';
  }

  Future<void> _openInMap(double? lat, double? lng) async {
    if (lat == null || lng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location coordinates not available.')),
      );
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open map application.')),
      );
    }
  }

  void _showEmergencyInfo() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Emergency Info',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Police: 100\nAmbulance: 108\nDisaster Helpline: 1070',
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkIn(String trailId) async {
    final firestore = FirebaseFirestore.instance;
    final trailRef = firestore.collection('trails').doc(trailId);
    final checkinRef = firestore.collection('checkins').doc();

    final batch = firestore.batch();
    batch.update(trailRef, {
      'checkInCount': FieldValue.increment(1),
      'lastUpdated': Timestamp.now(),
    });
    batch.set(checkinRef, {
      'trailId': trailId,
      'timestamp': Timestamp.now(),
    });

    await batch.commit();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checked in successfully')),
    );
  }

  String _formatDate(dynamic rawDate) {
    if (rawDate is Timestamp) {
      final dt = rawDate.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Trails'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('trails')
            .snapshots(),
        builder: (context, snapshot) {
          debugPrint(
            '[TRAIL SCREEN] Stream state=${snapshot.connectionState} hasData=${snapshot.hasData} '
            'hasError=${snapshot.hasError}',
          );

          if (snapshot.hasError) {
            debugPrint('[TRAIL SCREEN] Stream error: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Unable to load trails\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = [...snapshot.data!.docs]
            ..sort(
              (a, b) => _toCheckInCount(b.data()['checkInCount'])
                  .compareTo(_toCheckInCount(a.data()['checkInCount'])),
            );

          debugPrint('[TRAIL SCREEN] Stream docs received=${docs.length}');
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No trails found',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final name = (data['name'] ?? 'Unnamed Trail').toString();
              final baseStatus = (data['baseStatus'] ?? 'SAFE').toString();
              final checkInCountValue = _toCheckInCount(data['checkInCount']);
              final checkInCount = checkInCountValue.toString();
              final lat = (data['lat'] as num?)?.toDouble();
              final lng = (data['lng'] as num?)?.toDouble();
              final updatedAt = _formatDate(data['lastUpdated']);
              final trailBg = (data['trailBg'] ?? '').toString();
              final aboutTrail = (data['aboutTrail'] ??
                      '$name is a scenic trail in your selected region. Follow weather and crowd updates before starting your trek.')
                  .toString();

              _loadWeatherForTrail(doc.id, lat, lng);

              final weather = _weatherByTrailId[doc.id];
              final weatherLoading = _weatherLoading.contains(doc.id);
              final status = _safetyFromWeather(baseStatus, weather);
              final statusColor = _statusColor(status);
              final isExpanded = _expandedTrailId == doc.id;

              String weatherText = '--';
              if (weatherLoading) {
                weatherText = 'Loading weather...';
              } else if (weather != null && weather['main'] is Map) {
                weatherText = '${(weather['main']['temp'] ?? '--')}°C';
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _expandedTrailId = isExpanded ? null : doc.id;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1220).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isExpanded ? Colors.greenAccent : Colors.white24,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x44000000),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: statusColor.withValues(alpha: 0.45)),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            weatherText,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            'Check-ins: $checkInCount',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to ${isExpanded ? 'collapse' : 'expand'} details',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      if (isExpanded) ...[
                        const SizedBox(height: 12),

                        /// Trail background image
                        if (trailBg.isNotEmpty)
                          Container(
                            height: 200,
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              image: DecorationImage(
                                image: NetworkImage(trailBg),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: Colors.black.withValues(alpha: 0.3),
                              ),
                            ),
                          ),

                        /// Realtime weather conditions from API for this trail location
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CONDITIONS',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _temperatureLabel(weather),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _conditionLabel(weather),
                                        style: const TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Icon(
                                        _conditionIcon(weather),
                                        color: Colors.limeAccent,
                                        size: 34,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Rain: ${_rainLabel(weather)}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Crowd Density: ${_crowdDensityLabel(checkInCountValue)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 6,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          ),
                          child: Slider(
                            min: 0,
                            max: 1,
                            value: _crowdDensityValue(checkInCountValue),
                            onChanged: (_) {},
                            activeColor: Colors.greenAccent,
                            inactiveColor: Colors.white24,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'About this trail',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          aboutTrail,
                          style: const TextStyle(color: Colors.white70, height: 1.45),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Location: ${lat?.toStringAsFixed(5) ?? 'N/A'}, ${lng?.toStringAsFixed(5) ?? 'N/A'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Last updated: $updatedAt',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          onPressed: () => _checkIn(doc.id),
                          child: const Text('CHECK-IN'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            side: const BorderSide(color: Colors.white30),
                          ),
                          onPressed: _showEmergencyInfo,
                          child: const Text(
                            'VIEW EMERGENCY INFO',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            side: const BorderSide(color: Colors.white30),
                          ),
                          onPressed: () => _openInMap(lat, lng),
                          child: const Text(
                            'OPEN IN MAP',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
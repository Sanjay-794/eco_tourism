import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:eco_tourism/services/weather_service.dart';
import 'package:eco_tourism/screens/main_screen.dart';
import 'package:eco_tourism/services/checkin_service.dart';
import 'package:eco_tourism/widgets/app_navigation_drawer.dart';
import 'package:eco_tourism/widgets/custom_app_bar.dart';

class TrekDetails extends StatefulWidget {
  const TrekDetails({super.key});

  @override
  State<TrekDetails> createState() => _TrekDetailsState();
}

class _TrekDetailsState extends State<TrekDetails> {
  String? _expandedTrailId;
  String? _checkedInTrailId;
  final Map<String, Map<String, dynamic>?> _weatherByTrailId = {};
  final Set<String> _weatherLoading = {};
  Timer? _blinkTimer;
  bool _alertVisible = true;

  @override
  void initState() {
    super.initState();
    _logSingleFetchStatus();
    _loadCheckedInTrailId();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (!mounted) return;
      setState(() {
        _alertVisible = !_alertVisible;
      });
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCheckedInTrailId() async {
    final checkedId = await CheckInService.getCheckedInTrailId();
    if (!mounted) return;
    setState(() {
      _checkedInTrailId = checkedId;
    });
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
      final normalized = baseStatus.toUpperCase();
      return normalized == 'CAUTION' ? 'RISKY' : normalized;
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
        return 'RISKY';
      }

      return 'SAFE';
    }

    final normalized = baseStatus.toUpperCase();
    return normalized == 'CAUTION' ? 'RISKY' : normalized;
  }

  Color _statusColor(String status) {
    if (status == 'DANGER') return Colors.redAccent;
    if (status == 'RISKY') return Colors.amber;
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

  int _rainPercentValue(Map<String, dynamic>? weather) {
    if (weather == null) return 0;

    final rain = weather['rain'];
    if (rain is Map && rain['1h'] != null) {
      final mm = (rain['1h'] as num).toDouble();
      return (mm * 20).clamp(0, 100).round();
    }

    final weatherList = weather['weather'];
    if (weatherList is List && weatherList.isNotEmpty) {
      final condition = (weatherList.first['main'] ?? '').toString();
      if (condition == 'Thunderstorm') return 90;
      if (condition == 'Rain') return 70;
      if (condition == 'Drizzle') return 40;
      if (condition == 'Snow') return 75;
    }

    final clouds = weather['clouds'];
    if (clouds is Map && clouds['all'] != null) {
      return (clouds['all'] as num).round().clamp(0, 100);
    }

    return 0;
  }

  bool _hasSevereWeather(Map<String, dynamic>? weather) {
    if (weather == null) return false;
    final temp = ((weather['main'] as Map?)?['temp'] as num?)?.toDouble();
    final rainPercent = _rainPercentValue(weather);

    final veryLowTemp = temp != null && temp < 0;
    final heavyRain = rainPercent > 60;
    return veryLowTemp || heavyRain;
  }

  String _alertReason(Map<String, dynamic>? weather) {
    if (weather == null) return 'Unsafe weather conditions';

    final temp = ((weather['main'] as Map?)?['temp'] as num?)?.toDouble();
    final rainPercent = _rainPercentValue(weather);

    if (temp != null && temp < 0 && rainPercent > 60) {
      return 'Temp below 0°C and rain $rainPercent%';
    }
    if (temp != null && temp < 0) {
      return 'Temperature dropped below 0°C';
    }
    if (rainPercent > 60) {
      return 'Heavy rain expected ($rainPercent%)';
    }
    return 'Unsafe weather conditions';
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

  void _openEmergencyScreen(
    String trailId,
    String trailName,
    dynamic emergencyData,
  ) {
    final parsedEmergencyData = emergencyData is Map<String, dynamic>
        ? emergencyData
        : null;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MainScreen(
          trailId: trailId,
          trailName: trailName,
          emergencyData: parsedEmergencyData,
        ),
      ),
    );
  }

  Future<void> _checkIn(String trailId, String trailName) async {
    final result = await CheckInService.checkInOnce(
      trailId,
      trailName: trailName,
    );
    if (!mounted) return;

    if (result == CheckInResult.success) {
      setState(() {
        _checkedInTrailId = trailId;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checked in to $trailName. Alerts are now enabled.')),
      );
      return;
    }

    if (result == CheckInResult.alreadyCheckedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Already checked in to $trailName.')),
      );
      return;
    }

    if (result == CheckInResult.alreadyCheckedAnotherTrail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only have one active check-in. Undo current check-in from My Activity first.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to check in right now.')),
    );
  }

  Future<void> _undoCheckIn(String trailId) async {
    final result = await CheckInService.undoCheckIn(trailId);
    if (!mounted) return;

    if (result == UndoCheckInResult.success) {
      setState(() {
        _checkedInTrailId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in undone. You can check in another trek now.')),
      );
      return;
    }

    if (result == UndoCheckInResult.notCheckedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This trek is not currently active for this device.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to undo check-in right now.')),
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
      drawer: const AppNavigationDrawer(),
      appBar: CustomAppBar(
        title: 'TRAILS',
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
              final isCheckedByThisDevice = _checkedInTrailId == doc.id;
              final isCheckLocked =
                  _checkedInTrailId != null && _checkedInTrailId != doc.id;
              final showAlert = _hasSevereWeather(weather);

              String weatherText = '--';
              if (weatherLoading) {
                weatherText = 'Loading weather...';
              } else if (weather != null && weather['main'] is Map) {
                weatherText = '${(weather['main']['temp'] ?? '--')}°C  |  Rain ${_rainPercentValue(weather)}%';
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
                      if (isCheckedByThisDevice)
                        Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 16, color: Colors.cyanAccent),
                              SizedBox(width: 6),
                              Text(
                                'Checked in',
                                style: TextStyle(
                                  color: Colors.cyanAccent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (showAlert)
                        AnimatedOpacity(
                          opacity: _alertVisible ? 1 : 0.28,
                          duration: const Duration(milliseconds: 320),
                          child: Container(
                            margin: const EdgeInsets.only(top: 8, bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.7)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'ALERT: ${_alertReason(weather)}',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                                        'Rain: ${_rainPercentValue(weather)}%',
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
                            backgroundColor: isCheckedByThisDevice
                                ? Colors.orangeAccent
                                : isCheckLocked
                                    ? Colors.grey
                                    : Colors.greenAccent,
                            foregroundColor:
                                isCheckedByThisDevice || isCheckLocked ? Colors.white70 : Colors.black,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          onPressed: isCheckLocked
                              ? null
                              : () {
                                  if (isCheckedByThisDevice) {
                                    _undoCheckIn(doc.id);
                                  } else {
                                    _checkIn(doc.id, name);
                                  }
                                },
                          child: Text(
                            isCheckedByThisDevice
                                ? 'UNDO CHECK-IN'
                                : isCheckLocked
                                    ? 'CHECK-IN LOCKED'
                                    : 'CHECK-IN',
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            side: const BorderSide(color: Colors.white30),
                          ),
                          onPressed: () =>
                              _openEmergencyScreen(doc.id, name, data['emergency']),
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
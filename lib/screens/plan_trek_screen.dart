import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:eco_tourism/services/weather_service.dart';

class PlanTrekScreen extends StatefulWidget {
  const PlanTrekScreen({super.key});

  @override
  State<PlanTrekScreen> createState() => _PlanTrekScreenState();
}

class _PlanTrekScreenState extends State<PlanTrekScreen> {
  final TextEditingController _distanceController = TextEditingController();
  String _selectedStatus = 'ANY';
  String _selectedDifficulty = 'ANY';
  bool _loading = false;
  Position? _currentPosition;
  List<Map<String, dynamic>> _suggestedTrails = [];

  @override
  void initState() {
    super.initState();
    // Show all available treks initially from Firestore.
    _planTrek();
  }

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  Future<void> _ensureCurrentPosition() async {
    if (_currentPosition != null) return;

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    _currentPosition = await Geolocator.getCurrentPosition();
  }

  double? _calculatedDistanceFromCurrent(Map<String, dynamic> trail) {
    if (_currentPosition == null) return null;
    final lat = (trail['lat'] as num?)?.toDouble();
    final lng = (trail['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    // Same approach used in Home screen map calculation.
    final meters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng,
    );
    return meters / 1000;
  }

  String _trailStatus(Map<String, dynamic> trail) {
    return _normalizeStatus(
      (trail['calculatedStatus'] ?? trail['baseStatus'] ?? 'UNKNOWN')
          .toString()
          .toUpperCase(),
    );
  }

  String _trailDifficulty(Map<String, dynamic> trail) {
    // Use baseStatus from Firestore as requested.
    return (trail['baseStatus'] ?? 'UNKNOWN').toString().toUpperCase();
  }

  String _normalizeStatus(String status) {
    if (status == 'CAUTION') return 'RISKY';
    return status;
  }

  String _statusFromWeather(Map<String, dynamic>? weather) {
    if (weather == null) return 'UNKNOWN';

    final temp = ((weather['main'] as Map?)?['temp'] as num?)?.toDouble();
    final weatherList = weather['weather'];
    final condition =
        (weatherList is List && weatherList.isNotEmpty)
            ? (weatherList.first['main'] ?? '').toString()
            : '';

    int rainPercent = 0;
    final rain = weather['rain'];
    if (rain is Map && rain['1h'] != null) {
      final mm = (rain['1h'] as num?)?.toDouble() ?? 0;
      rainPercent = (mm * 20).clamp(0, 100).round();
    } else {
      if (condition == 'Thunderstorm') rainPercent = 90;
      if (condition == 'Rain') rainPercent = 70;
      if (condition == 'Drizzle') rainPercent = 40;
      if (condition == 'Snow') rainPercent = 75;

      if (rainPercent == 0) {
        final clouds = ((weather['clouds'] as Map?)?['all'] as num?)?.toInt();
        if (clouds != null) {
          rainPercent = clouds.clamp(0, 100);
        }
      }
    }

    var severity = 0; // 0=SAFE, 1=RISKY, 2=DANGER

    // Temperature rule: >10 SAFE, >5 RISKY, <=5 DANGER.
    if (temp != null) {
      if (temp <= 5) {
        severity = 2;
      } else if (temp <= 10) {
        severity = severity < 1 ? 1 : severity;
      }
    }

    // Rain percentage contribution.
    if (rainPercent >= 70) {
      severity = 2;
    } else if (rainPercent >= 40) {
      severity = severity < 1 ? 1 : severity;
    }

    // Other weather condition contribution.
    if (condition == 'Thunderstorm' || condition == 'Snow') {
      severity = 2;
    } else if (condition == 'Rain' ||
        condition == 'Drizzle' ||
        condition == 'Clouds' ||
        condition == 'Mist' ||
        condition == 'Fog' ||
        condition == 'Haze') {
      severity = severity < 1 ? 1 : severity;
    }

    if (severity == 2) return 'DANGER';
    if (severity == 1) return 'RISKY';
    return 'SAFE';
  }

  Future<Map<String, dynamic>> _enrichTrail(Map<String, dynamic> trail) async {
    final lat = (trail['lat'] as num?)?.toDouble();
    final lng = (trail['lng'] as num?)?.toDouble();

    trail['calculatedDistanceKm'] = _calculatedDistanceFromCurrent(trail);

    if (lat == null || lng == null) {
      trail['calculatedStatus'] = _normalizeStatus(
        (trail['baseStatus'] ?? 'UNKNOWN').toString().toUpperCase(),
      );
      return trail;
    }

    try {
      final weather = await WeatherService().getWeather(lat, lng);
      trail['calculatedStatus'] = _normalizeStatus(_statusFromWeather(weather));
    } catch (_) {
      trail['calculatedStatus'] = _normalizeStatus(
        (trail['baseStatus'] ?? 'UNKNOWN').toString().toUpperCase(),
      );
    }
    return trail;
  }

  Future<void> _planTrek() async {
    final maxDistance = double.tryParse(_distanceController.text.trim());

    setState(() {
      _loading = true;
      _suggestedTrails = [];
    });

    try {
      await _ensureCurrentPosition();

      final snapshot = await FirebaseFirestore.instance.collection('trails').get();
      final trails = snapshot.docs.map<Map<String, dynamic>>((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      final enriched = await Future.wait(trails.map(_enrichTrail));

      final filtered = enriched.where((trail) {
        final status = _trailStatus(trail);
        final difficulty = _trailDifficulty(trail);
        final distance = (trail['calculatedDistanceKm'] as num?)?.toDouble();

        final statusOk = _selectedStatus == 'ANY' || status == _selectedStatus;
        final difficultyOk =
            _selectedDifficulty == 'ANY' || difficulty == _selectedDifficulty;
        final distanceOk = maxDistance == null || distance == null || distance <= maxDistance;

        return statusOk && difficultyOk && distanceOk;
      }).toList();

      filtered.sort((a, b) {
        final countA = (a['checkInCount'] is num) ? (a['checkInCount'] as num).toInt() : 0;
        final countB = (b['checkInCount'] is num) ? (b['checkInCount'] as num).toInt() : 0;
        return countB.compareTo(countA);
      });

      setState(() {
        _suggestedTrails = filtered;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to fetch trek suggestions right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.greenAccent,
        title: const Text('Plan My Trek'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set your preferences',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _distanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Max distance (km)',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.greenAccent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              dropdownColor: const Color(0xFF121212),
              style: const TextStyle(color: Colors.white),
              items: const ['ANY', 'SAFE', 'RISKY', 'DANGER']
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value ?? 'ANY';
                });
              },
              decoration: InputDecoration(
                labelText: 'Status',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.greenAccent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedDifficulty,
              dropdownColor: const Color(0xFF121212),
              style: const TextStyle(color: Colors.white),
              items: const ['ANY', 'EASY', 'MODERATE', 'HARD', 'EXTREME']
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDifficulty = value ?? 'ANY';
                });
              },
              decoration: InputDecoration(
                labelText: 'Difficulty',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.greenAccent),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loading ? null : _planTrek,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(_loading ? 'Finding...' : 'Suggest Treks'),
            ),
            const SizedBox(height: 18),
            const Text(
              'Suggested Treks',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_suggestedTrails.isEmpty && !_loading)
              const Text(
                'No suggestions yet. Set filters and tap Suggest Treks.',
                style: TextStyle(color: Colors.white60),
              ),
            ..._suggestedTrails.map((trail) {
              final name = (trail['name'] ?? 'Unnamed Trail').toString();
              final status = _trailStatus(trail);
              final difficulty = _trailDifficulty(trail);
              final distance = (trail['calculatedDistanceKm'] as num?)?.toDouble();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF101827),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Status: $status', style: const TextStyle(color: Colors.white70)),
                    Text('Difficulty: $difficulty', style: const TextStyle(color: Colors.white70)),
                    Text(
                      'Distance: ${distance != null ? '${distance.toStringAsFixed(1)} km' : 'N/A'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

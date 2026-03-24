import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:eco_tourism/services/weather_service.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:eco_tourism/services/route_service.dart';
import 'package:eco_tourism/services/trail_service.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Main Screen Widget
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// State Class (IMPORTANT: All mutable state goes here)
class _HomeScreenState extends State<HomeScreen> {

  /// Stores currently selected trail (null initially)
  Map<String, dynamic>? selectedTrail;

  Map<String, dynamic>? weatherData;

  LatLng? currentLocation;

  List<LatLng> routePoints = [];
  List<LatLng> highlightedTrailPoints = [];

  final MapController mapController = MapController();

  TextEditingController searchController = TextEditingController();

  List<dynamic> searchResults = [];
  bool isSearching = false;

  Timer? debounce;

  final TrailService _trailService = TrailService();


  /// search locations
  Future<void> searchLocation(String query) async {
    if (query.isEmpty) return;

    final url =
        "https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      setState(() {
        searchResults = data;
        isSearching = true;
      });
    }
  }



  String locationName = "";

  Future<void> getPlaceName(double lat, double lng) async {
    final url =
        "https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      setState(() {
        locationName = data["display_name"];
      });
    }
  }

  double calculateDistance() {
    if (currentLocation == null || selectedTrail == null) return 0;

    return Geolocator.distanceBetween(
      currentLocation!.latitude,
      currentLocation!.longitude,
      selectedTrail!["lat"],
      selectedTrail!["lng"],
    ) / 1000; // km
  }

  String getSafetyStatus() {
    if (weatherData == null) {
      return selectedTrail?["baseStatus"] ?? "SAFE";
    }

    final condition = weatherData!['weather'][0]['main'];

    if (condition == "Rain" || condition == "Thunderstorm") {
      return "DANGER";
    } else if (condition == "Clouds") {
      return "CAUTION";
    } else {
      return "SAFE";
    }
  }

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services are disabled");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final position = await Geolocator.getCurrentPosition();

    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
    });

    // ✅ Move map AFTER getting location
    mapController.move(currentLocation!, 13);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      /// Using Stack to layer map + UI + overlay
      body: Stack(
        children: [

          /// ================= MAP BACKGROUND =================
          Positioned.fill(
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: LatLng(32.2432, 77.1892),
                initialZoom: 10,

                onTap: (tapPosition, point) async {

                  setState(() {
                    selectedTrail = {
                      "lat": point.latitude,
                      "lng": point.longitude,
                    };
                    weatherData = null;
                    routePoints = [];
                    highlightedTrailPoints = [];
                  });

                  try {
                    await getPlaceName(point.latitude, point.longitude);
                    final weather = await WeatherService()
                        .getWeather(point.latitude, point.longitude);

                    final prototypeRoute = currentLocation != null
                        ? await _trailService.getPrototypeTrailRoute(
                            currentLocation!,
                            point,
                          )
                        : <LatLng>[];

                    final nearestTrail = await _resolveTrailHighlight(point);

                    List<LatLng> resolvedRoute = prototypeRoute;
                    List<LatLng> resolvedTrail = nearestTrail;

                    if (resolvedRoute.isEmpty && currentLocation != null) {
                      try {
                        resolvedRoute = await RouteService().getRoute(
                          currentLocation!,
                          LatLng(point.latitude, point.longitude),
                        );
                      } catch (_) {
                        resolvedRoute = [];
                      }

                    }

                    setState(() {
                      weatherData = weather;
                      routePoints = resolvedRoute;
                      highlightedTrailPoints = resolvedTrail;
                    });

                  } catch (e) {
                    print(e);
                  }
                },
              ),

              children: [

                /// Pure OpenStreetMap base layer.
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                  maxNativeZoom: 19,
                  maxZoom: 19,
                  userAgentPackageName: 'com.example.eco_tourism',
                ),

                /// Highlights selected trek as red dashed-style path.
                PolylineLayer<Object>(
                  polylines: _buildDashedTrailPolylines(highlightedTrailPoints),
                ),

                /// ================= ROUTE TO TRAIL START =================
                /// Renders the calculated route from current location to trail start
                PolylineLayer<Object>(
                  polylines: routePoints.isNotEmpty
                      ? [
                    /// Outer stroke for visibility (darker outline)
                    Polyline(
                      points: routePoints,
                      strokeWidth: 8,
                      color: Colors.black.withOpacity(0.6),
                    ),
                    /// Inner bright route (main highlight)
                    Polyline(
                      points: routePoints,
                      strokeWidth: 5,
                      color: Colors.yellow,
                    ),
                  ]
                      : [],
                ),

                /// ================= MARKERS =================
                ///
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('trails')
                      .snapshots(),
                  builder: (context, snapshot) {

                    if (snapshot.hasError) {
                      return const SizedBox();
                    }

                    if (!snapshot.hasData) {
                      return const SizedBox();
                    }

                    final docs = snapshot.data!.docs;

                    print("📦 Total docs: ${docs.length}");

                    for (var doc in docs) {
                      print("🧾 Doc ID: ${doc.id}");
                      print("📍 Data: ${doc.data()}");
                    }

                    if (docs.isNotEmpty) {
                      final first = docs.first.data();

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        mapController.move(
                          LatLng(
                            (first['lat'] as num).toDouble(),
                            (first['lng'] as num).toDouble(),
                          ),
                          13,
                        );
                      });
                    }

                    print("Docs length: ${docs.length}");

                    return MarkerLayer(
                      markers: docs.where((doc) {
                        final data = doc.data();
                        return data['lat'] is num && data['lng'] is num;
                      }).map((doc) {
                        final data = doc.data();

                        return Marker(
                          point: LatLng(
                            (data['lat'] as num).toDouble(),
                            (data['lng'] as num).toDouble(),
                          ),
                          width: 100,
                          height: 100,
                          child: GestureDetector(
                            onTap: () async {
                              setState(() {
                                selectedTrail = {
                                  "id": doc.id,
                                  ...data,
                                };
                                  locationName = (data['name'] ?? 'Unknown Trail').toString();
                              });

                              try {
                                final weather = await WeatherService()
                                    .getWeather(data['lat'], data['lng']);

                                final targetPoint = LatLng(data['lat'], data['lng']);
                                final prototypeRoute = currentLocation != null
                                    ? await _trailService.getPrototypeTrailRoute(
                                        currentLocation!,
                                        targetPoint,
                                      )
                                    : <LatLng>[];

                                final nearestTrail = await _resolveTrailHighlight(targetPoint);

                                List<LatLng> resolvedRoute = prototypeRoute;
                                List<LatLng> resolvedTrail = nearestTrail;

                                if (resolvedRoute.isEmpty && currentLocation != null) {
                                  try {
                                    resolvedRoute = await RouteService().getRoute(
                                      currentLocation!,
                                      targetPoint,
                                    );
                                  } catch (_) {
                                    resolvedRoute = [];
                                  }

                                }

                                setState(() {
                                  weatherData = weather;
                                  routePoints = resolvedRoute;
                                  highlightedTrailPoints = resolvedTrail;
                                });
                              } catch (e) {
                                print(e);
                              }
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 35,
                                  color: (data['checkInCount'] ?? 0) > 10
                                      ? Colors.red
                                      : (data['checkInCount'] ?? 0) > 5
                                          ? Colors.yellow
                                          : Colors.green,
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  color: Colors.black,
                                  child: Text(
                                    "${data['name']} (${data['checkInCount'] ?? 0})",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),


                MarkerLayer(
                  markers: currentLocation != null
                      ? [
                    Marker(
                      point: currentLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 30,
                      ),
                    ),
                  ]
                      : [],
                ),

            // PolylineLayer<Object>(
            //       polylines: (currentLocation != null && selectedTrail != null)
            //           ? [
            //         Polyline(
            //           points: [
            //             currentLocation!,
            //             LatLng(
            //               selectedTrail!["lat"],
            //               selectedTrail!["lng"],
            //             ),
            //           ],
            //           strokeWidth: 4,
            //           color: Colors.blue,
            //         ),
            //       ]
            //           : [],
            //     ),
                // MarkerLayer(
                //   markers: trails.map((trail) {
                //     return Marker(
                //       point: LatLng(trail["lat"], trail["lng"]),
                //       width: 40,
                //       height: 40,
                //
                //       /// Detect tap on marker
                //       child: GestureDetector(
                //
                //         /// getting the weather data on tap and updating the state to show in bottom card
                //         onTap: () async {
                //           final weather = await WeatherService()
                //               .getWeather(trail["lat"], trail["lng"]);
                //
                //           setState(() {
                //             selectedTrail = trail;
                //             weatherData = weather;
                //           });
                //         },
                //
                //         /// Marker icon color based on status
                //         child: Icon(
                //           Icons.location_on,
                //           size: 35,
                //           color: trail["status"] == "Safe"
                //               ? Colors.green
                //               : trail["status"] == "Caution"
                //               ? Colors.yellow
                //               : Colors.red,
                //         ),
                //       ),
                //     );
                //   }).toList(),
                // ),
              ],
            ),
          ),

          // Required map attribution for OpenTopoMap and source data.
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Map data: OpenStreetMap contributors | Base map: OpenStreetMap Standard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          /// ================= DARK OVERLAY =================
          /// Makes UI readable over map
          Positioned.fill(
            child: IgnorePointer(
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
          ),

          /// ================= FOREGROUND UI =================
    GestureDetector(
    onTap: () {
    FocusScope.of(context).unfocus();
    setState(() {
    isSearching = false;
    });
    },
    child: SafeArea(
            child: Column(
              children: [

                /// ================= TOP BAR =================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [

                      /// Menu Icon
                      Icon(Icons.menu, color: Colors.greenAccent),

                      /// App Title
                      Text(
                        "TRAILSAFE",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),

                      /// Profile Avatar
                      CircleAvatar(
                        backgroundImage: NetworkImage("https://i.pravatar.cc/100"),
                      ),
                    ],
                  ),
                ),

                /// ================= SEARCH BAR =================
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: searchController,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (value) {
                        if (debounce?.isActive ?? false) debounce!.cancel();

                        debounce = Timer(const Duration(milliseconds: 500), () {
                          searchLocation(value);
                        });
                      },
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search, color: Colors.white54),
                        hintText: "Search location...",
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),

                if (isSearching && searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final place = searchResults[index];

                        return ListTile(
                          title: Text(
                            place["display_name"],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),

                          onTap: () async {
                            final lat = double.parse(place["lat"]);
                            final lng = double.parse(place["lon"]);

                            final point = LatLng(lat, lng);

                            // Move map
                            mapController.move(point, 14);

                            // Update state
                            setState(() {
                              selectedTrail = {
                                "lat": lat,
                                "lng": lng,
                              };
                              locationName = place["display_name"];
                              searchResults = [];
                              isSearching = false;
                              searchController.text = place["display_name"];

                              // 🔥 ADD THESE
                              weatherData = null;
                              routePoints = [];
                              highlightedTrailPoints = [];
                            });

                            try {
                              final weather = await WeatherService()
                                  .getWeather(lat, lng);

                              final prototypeRoute = currentLocation != null
                                  ? await _trailService.getPrototypeTrailRoute(
                                      currentLocation!,
                                      point,
                                    )
                                  : <LatLng>[];

                              final nearestTrail = await _resolveTrailHighlight(point);

                              List<LatLng> resolvedRoute = prototypeRoute;
                              List<LatLng> resolvedTrail = nearestTrail;

                              if (resolvedRoute.isEmpty && currentLocation != null) {
                                try {
                                  resolvedRoute = await RouteService().getRoute(
                                    currentLocation!,
                                    point,
                                  );
                                } catch (_) {
                                  resolvedRoute = [];
                                }

                              }

                              setState(() {
                                weatherData = weather;
                                routePoints = resolvedRoute;
                                highlightedTrailPoints = resolvedTrail;
                              });

                            } catch (e) {
                              print(e);
                            }
                          },
                        );
                      },
                    ),
                  ),

                /// Pushes bottom card to bottom
                const Spacer(),

                /// ================= BOTTOM INFO CARD =================
                /// Show only when a marker is selected
                if (selectedTrail != null)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        /// Trail Name
                        Text(
                          locationName.isNotEmpty ? locationName : "Loading...",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // const SizedBox(height: 6),

                        Text(
                          "Check-ins: ${selectedTrail!['checkInCount'] ?? 0}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),

                        /// Status + Distance Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [

                            /// 🌡 Temperature
                            Text(
                              weatherData != null
                                  ? "${weatherData!['main']['temp']}°C"
                                  : "--",
                              style: const TextStyle(color: Colors.white),
                            ),

                            /// ⚠️ Safety Status (NEW LOGIC)
                            Text(
                              getSafetyStatus(),
                              style: TextStyle(
                                color: getSafetyStatus() == "SAFE"
                                    ? Colors.green
                                    : getSafetyStatus() == "CAUTION"
                                    ? Colors.yellow
                                    : Colors.red,
                              ),
                            ),

                            /// 📏 Distance
                            Text(
                              currentLocation != null
                                  ? "${calculateDistance().toStringAsFixed(2)} km"
                                  : "--",
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        /// Info Chips (static for now)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _chip("68°F"),
                            _chip("Difficulty"),
                            _chip("Cell Service"),
                          ],
                        ),

                        const SizedBox(height: 12),

                        /// Action Button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            minimumSize: const Size.fromHeight(45),
                          ),
                          onPressed: () async {
                            if (selectedTrail == null) return;

                            final trailId = selectedTrail!["id"];

                            await FirebaseFirestore.instance
                                .collection('trails')
                                .doc(trailId)
                                .update({
                              'checkInCount': FieldValue.increment(1),
                              'lastUpdated': Timestamp.now(),
                            });

                            // 🔥 UPDATE LOCAL STATE ALSO
                            setState(() {
                              selectedTrail!['checkInCount'] =
                                  (selectedTrail!['checkInCount'] ?? 0) + 1;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Checked-in successfully 🚀")),
                            );
                          },
                          child: const Text(
                            "CHECK-IN",
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
    ),
        ],
      ),

    );
  }

  Future<List<LatLng>> _resolveTrailHighlight(LatLng point) async {
    const radii = [2200, 3500, 5000];

    for (final radius in radii) {
      final endToEnd = await _trailService.getEndToEndTrailPath(
        point,
        radiusMeters: radius,
        maxSnapDistanceMeters: 450,
      );
      if (endToEnd.length > 1) {
        return endToEnd;
      }
    }

    for (final radius in radii) {
      final nearest = await _trailService.getNearestHikingTrail(
        point,
        radiusMeters: radius,
        maxSnapDistanceMeters: 550,
      );
      if (nearest.length > 1) {
        return nearest;
      }
    }

    return [];
  }

  List<Polyline<Object>> _buildDashedTrailPolylines(List<LatLng> points) {
    if (points.length < 2) {
      return const [];
    }

    final dashed = <Polyline<Object>>[];
    for (var i = 0; i < points.length - 1; i += 2) {
      dashed.add(
        Polyline(
          points: [points[i], points[i + 1]],
          strokeWidth: 6,
          color: Colors.redAccent,
        ),
      );
    }

    return dashed;
  }

  /// ================= CHIP WIDGET =================
  /// Reusable small info container
  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}


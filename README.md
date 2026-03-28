# TrailSafe - Smart Eco-Tourism Prototype

TrailSafe is a Flutter-based eco-tourism and hiking safety prototype focused on:
- Discovering trail locations on an interactive map
- Highlighting trek routes and nearby trail geometry using OpenStreetMap data
- Showing weather-aware safety hints for selected trail points
- Tracking trail engagement via Firestore check-ins
- Providing emergency info and an eco-footprint calculator in a single app

The current build is optimized for rapid prototyping and demo workflows.

## Intro

TrailSafe combines map-first exploration with lightweight safety tooling for trekkers:
- Home tab: map, location search, route/trail highlighting, weather snapshot, check-in action
- Trail tab: Firestore-powered trail list/details with weather/crowd indicators
- Emergency tab: quick-access emergency UI patterns and protocol cards
- Eco tab: basic transport footprint calculator

The app uses a practical hybrid strategy for path visualization:
- Standard route path from OSRM (approach route)
- Trail geometry from OpenStreetMap via Overpass (trek-oriented overlay)

## Tech Stack

- Flutter (Dart)
- Firebase Core + Cloud Firestore
- flutter_map + OpenStreetMap tiles
- latlong2 (geo primitives and distance helpers)
- geolocator (device location + permissions)
- http (Nominatim, Overpass, OSRM, OpenWeather requests)
- url_launcher (open map links from trail details)

## Why This Stack

This stack was chosen for speed of delivery, ease of integration, and prototype friendliness.

- Flutter
Reason: Fast UI iteration across Android, iOS, Web, Linux, macOS, and Windows from one codebase.

- Firestore
Reason: Realtime data stream for trails/check-ins without standing up a custom backend.

- flutter_map + OSM ecosystem
Reason: Open geodata, simple tile integration, and no heavy proprietary SDK lock-in for prototype mapping.

- Overpass + OSRM + Nominatim
Reason: Lightweight REST-based geospatial workflow:
- Overpass for trail network extraction
- OSRM for quick route line generation
- Nominatim for search/reverse geocoding

- OpenWeather
Reason: Fast weather context to derive demo safety states (safe/caution/danger).

- geolocator
Reason: Straightforward location permission handling and distance calculations for trek UX.

## Project Structure

```text
eco_tourism/
	lib/
		main.dart                      # App bootstrap, Firebase init, root MaterialApp
		firebase_options.dart          # FlutterFire generated platform config
		screens/
			navigation_screen.dart       # Bottom navigation shell (Home/Trail/Emergency/Eco)
			home_screen.dart             # Map-first experience, search, route/trail highlight, check-ins
			trek_details.dart            # Firestore-backed trail details and weather/crowd indicators
			main_screen.dart             # Emergency hub UI
			eco_calculator.dart          # Carbon footprint calculator UI
		services/
			weather_service.dart         # OpenWeather API integration
			route_service.dart           # OSRM route fetching
			trail_service.dart           # OSM Overpass trail graph + path logic + caching
	assets/
		bg.jpg
		waterfall.jpg
	android/ ios/ web/ linux/ macos/ windows/
																	# Flutter platform runners
	test/
		widget_test.dart
```

## Core Architecture Notes

- UI Layer
Stateful widget screens own local interaction state for fast iteration in prototype mode.

- Data Layer
Service classes in lib/services isolate external API calls and map/trail computation logic.

- Realtime Trail Data
Firestore streams power live trail marker/state updates and check-in counters.

- Trail Highlight Strategy
TrailService builds a local graph from Overpass responses and tries end-to-end selection first, with fallback behavior for reliability in sparse/disconnected regions.

## Setup

Follow the setup:

### Prerequisites

- Flutter SDK (compatible with Dart >= 3.3.0 < 4.0.0)
- A configured Firebase project (flutterfire options already included in repository)
- Internet access for OSM/OSRM/Nominatim/OpenWeather APIs

### Install and run

```bash
flutter pub get
flutter run
```

Run on web server (example):

```bash
flutter run -d web-server
```

## Configuration Notes

- Weather API key is currently embedded in weather_service.dart for prototype use.
- For production, move secrets to secure config and avoid committing keys.

## Prototype Scope

This repository is intentionally prototype-oriented:
- Fast UI iteration over strict architecture layering
- Public/open APIs for trail and route exploration
- Lightweight caching and fallback logic to keep demo interactions responsive

## Roadmap Ideas (Optional)

- Move API secrets to environment configuration
- Replace debug prints with structured logging
- Add stronger test coverage for TrailService path selection and map interaction flows
- Add offline-ready vector map/routing pipeline for Organic Maps-like behavior

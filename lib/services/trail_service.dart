import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class TrailService {
  static const _overpassEndpoint = 'https://overpass-api.de/api/interpreter';
  final Distance _distance = const Distance();
  final Map<String, _TrailNetwork> _networkCache = {};

  Future<List<LatLng>> getPrototypeTrailRoute(
    LatLng start,
    LatLng end,
  ) async {
    final directDistanceMeters = _distance(start, end);
    final radiusMeters = _adaptiveRadius(directDistanceMeters);

    final network = await _fetchTrailNetwork(center: end, radiusMeters: radiusMeters);
    if (network.nodesById.isEmpty || network.ways.isEmpty) {
      return [];
    }

    final adjacency = _buildAdjacency(network);
    if (adjacency.isEmpty) {
      return [];
    }

    final startNodeId = _nearestNodeId(start, network.nodesById);
    final endNodeId = _nearestNodeId(end, network.nodesById);
    if (startNodeId == null || endNodeId == null) {
      return [];
    }

    final startSnapMeters = _distance(start, network.nodesById[startNodeId]!);
    final endSnapMeters = _distance(end, network.nodesById[endNodeId]!);
    if (startSnapMeters > 600 || endSnapMeters > 300) {
      return [];
    }

    final nodePath = _aStarPathfind(
      startNodeId: startNodeId,
      endNodeId: endNodeId,
      adjacency: adjacency,
      nodesById: network.nodesById,
    );

    if (nodePath.isEmpty) {
      return [];
    }

    return nodePath
        .map((nodeId) => network.nodesById[nodeId])
        .whereType<LatLng>()
        .toList();
  }

  Future<List<LatLng>> getNearestHikingTrail(
    LatLng tapPoint, {
    int radiusMeters = 1200,
    double maxSnapDistanceMeters = 250,
  }) async {
    final network = await _fetchTrailNetwork(center: tapPoint, radiusMeters: radiusMeters);
    final nodesById = network.nodesById;
    final ways = network.ways;

    List<LatLng> nearest = [];
    double nearestDistance = double.infinity;

    for (final way in ways) {
      final nodeIds = (way['nodes'] as List<dynamic>? ?? const [])
          .whereType<int>()
          .toList();

      if (nodeIds.length < 2) continue;

      final polyline = <LatLng>[];
      for (final nodeId in nodeIds) {
        final nodePoint = nodesById[nodeId];
        if (nodePoint != null) {
          polyline.add(nodePoint);
        }
      }

      if (polyline.length < 2) continue;

      final distanceToTap = _minVertexDistanceMeters(tapPoint, polyline);
      if (distanceToTap < nearestDistance) {
        nearestDistance = distanceToTap;
        nearest = polyline;
      }
    }

    if (nearest.isEmpty || nearestDistance > maxSnapDistanceMeters) {
      return [];
    }

    return nearest;
  }

  Future<List<LatLng>> getEndToEndTrailPath(
    LatLng tapPoint, {
    int radiusMeters = 2200,
    double maxSnapDistanceMeters = 350,
  }) async {
    final network = await _fetchTrailNetwork(
      center: tapPoint,
      radiusMeters: radiusMeters,
    );
    if (network.nodesById.isEmpty || network.ways.isEmpty) {
      return [];
    }

    final adjacency = _buildAdjacency(network);
    if (adjacency.isEmpty) {
      return [];
    }

    final seedNode = _nearestNodeId(tapPoint, network.nodesById);
    if (seedNode == null) {
      return [];
    }

    final snapDistance = _distance(tapPoint, network.nodesById[seedNode]!);
    if (snapDistance > maxSnapDistanceMeters) {
      return [];
    }

    final componentNodes = _collectConnectedComponent(seedNode, adjacency);
    if (componentNodes.length < 2) {
      return [];
    }

    final firstRun = _dijkstra(seedNode, adjacency, componentNodes);
    final farA = _farthestNode(firstRun.distances);
    if (farA == null) {
      return [];
    }

    final secondRun = _dijkstra(farA, adjacency, componentNodes);
    final farB = _farthestNode(secondRun.distances);
    if (farB == null) {
      return [];
    }

    final nodePath = _reconstructFromParents(farA, farB, secondRun.parents);
    if (nodePath.length < 2) {
      return [];
    }

    return nodePath
        .map((nodeId) => network.nodesById[nodeId])
        .whereType<LatLng>()
        .toList();
  }

  int _adaptiveRadius(double directDistanceMeters) {
    final base = (directDistanceMeters * 0.85).round() + 1200;
    if (base < 1200) return 1200;
    if (base > 7000) return 7000;
    return base;
  }

  Future<_TrailNetwork> _fetchTrailNetwork({
    required LatLng center,
    required int radiusMeters,
  }) async {
    final key = _cacheKey(center, radiusMeters);
    final cached = _networkCache[key];
    if (cached != null) {
      return cached;
    }

    final query = '''
[out:json][timeout:25];
(
  way(around:$radiusMeters,${center.latitude},${center.longitude})["highway"~"path|footway|track|bridleway|steps"];
  way(around:$radiusMeters,${center.latitude},${center.longitude})["route"="hiking"];
);
(._;>;);
out body;
''';

    final response = await http.post(
      Uri.parse(_overpassEndpoint),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'data': query},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch hiking trails from OpenStreetMap/Overpass.');
    }

    final Map<String, dynamic> decoded = jsonDecode(response.body);
    final elements = (decoded['elements'] as List<dynamic>? ?? const []);

    final Map<int, LatLng> nodesById = {};
    final List<Map<String, dynamic>> ways = [];

    for (final element in elements) {
      if (element is! Map<String, dynamic>) continue;

      final type = element['type'];
      if (type == 'node') {
        final id = element['id'];
        final lat = element['lat'];
        final lon = element['lon'];
        if (id is int && lat is num && lon is num) {
          nodesById[id] = LatLng(lat.toDouble(), lon.toDouble());
        }
      } else if (type == 'way') {
        ways.add(element);
      }
    }

    final network = _TrailNetwork(nodesById: nodesById, ways: ways);
    if (_networkCache.length > 24) {
      _networkCache.clear();
    }
    _networkCache[key] = network;
    return network;
  }

  String _cacheKey(LatLng center, int radiusMeters) {
    final lat = center.latitude.toStringAsFixed(3);
    final lng = center.longitude.toStringAsFixed(3);
    return '$lat,$lng:$radiusMeters';
  }

  Map<int, List<_GraphEdge>> _buildAdjacency(_TrailNetwork network) {
    final adjacency = <int, List<_GraphEdge>>{};

    for (final way in network.ways) {
      final nodeIds = (way['nodes'] as List<dynamic>? ?? const [])
          .whereType<int>()
          .toList();

      if (nodeIds.length < 2) continue;

      for (var i = 0; i < nodeIds.length - 1; i++) {
        final a = nodeIds[i];
        final b = nodeIds[i + 1];
        final pa = network.nodesById[a];
        final pb = network.nodesById[b];
        if (pa == null || pb == null) continue;

        final w = _distance(pa, pb);

        adjacency.putIfAbsent(a, () => []).add(_GraphEdge(to: b, weight: w));
        adjacency.putIfAbsent(b, () => []).add(_GraphEdge(to: a, weight: w));
      }
    }

    return adjacency;
  }

  int? _nearestNodeId(LatLng point, Map<int, LatLng> nodesById) {
    int? bestId;
    var bestDistance = double.infinity;

    nodesById.forEach((nodeId, nodePoint) {
      final d = _distance(point, nodePoint);
      if (d < bestDistance) {
        bestDistance = d;
        bestId = nodeId;
      }
    });

    return bestId;
  }

  List<int> _aStarPathfind({
    required int startNodeId,
    required int endNodeId,
    required Map<int, List<_GraphEdge>> adjacency,
    required Map<int, LatLng> nodesById,
  }) {
    final openSet = <int>{startNodeId};
    final cameFrom = <int, int>{};
    final gScore = <int, double>{startNodeId: 0};
    final fScore = <int, double>{
      startNodeId: _distance(nodesById[startNodeId]!, nodesById[endNodeId]!),
    };

    while (openSet.isNotEmpty) {
      final current = _lowestScoreNode(openSet, fScore);
      if (current == null) break;

      if (current == endNodeId) {
        return _reconstructPath(cameFrom, current);
      }

      openSet.remove(current);

      for (final edge in adjacency[current] ?? const <_GraphEdge>[]) {
        final tentative = (gScore[current] ?? double.infinity) + edge.weight;
        if (tentative < (gScore[edge.to] ?? double.infinity)) {
          cameFrom[edge.to] = current;
          gScore[edge.to] = tentative;
          final heuristic = _distance(nodesById[edge.to]!, nodesById[endNodeId]!);
          fScore[edge.to] = tentative + heuristic;
          openSet.add(edge.to);
        }
      }
    }

    return [];
  }

  int? _lowestScoreNode(Set<int> openSet, Map<int, double> fScore) {
    int? best;
    var bestScore = double.infinity;

    for (final node in openSet) {
      final score = fScore[node] ?? double.infinity;
      if (score < bestScore) {
        best = node;
        bestScore = score;
      }
    }

    return best;
  }

  List<int> _reconstructPath(Map<int, int> cameFrom, int current) {
    final path = <int>[current];
    var cursor = current;

    while (cameFrom.containsKey(cursor)) {
      cursor = cameFrom[cursor]!;
      path.add(cursor);
    }

    return path.reversed.toList();
  }

  Set<int> _collectConnectedComponent(
    int seed,
    Map<int, List<_GraphEdge>> adjacency,
  ) {
    final visited = <int>{};
    final stack = <int>[seed];

    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      if (!visited.add(node)) {
        continue;
      }

      for (final edge in adjacency[node] ?? const <_GraphEdge>[]) {
        if (!visited.contains(edge.to)) {
          stack.add(edge.to);
        }
      }
    }

    return visited;
  }

  _DijkstraResult _dijkstra(
    int start,
    Map<int, List<_GraphEdge>> adjacency,
    Set<int> allowed,
  ) {
    final distances = <int, double>{start: 0};
    final parents = <int, int>{};
    final queue = <int>{start};

    while (queue.isNotEmpty) {
      int? current;
      var best = double.infinity;
      for (final n in queue) {
        final d = distances[n] ?? double.infinity;
        if (d < best) {
          best = d;
          current = n;
        }
      }
      if (current == null) {
        break;
      }

      queue.remove(current);

      for (final edge in adjacency[current] ?? const <_GraphEdge>[]) {
        if (!allowed.contains(edge.to)) {
          continue;
        }

        final tentative = (distances[current] ?? double.infinity) + edge.weight;
        if (tentative < (distances[edge.to] ?? double.infinity)) {
          distances[edge.to] = tentative;
          parents[edge.to] = current;
          queue.add(edge.to);
        }
      }
    }

    return _DijkstraResult(distances: distances, parents: parents);
  }

  int? _farthestNode(Map<int, double> distances) {
    int? node;
    var maxDist = -1.0;
    distances.forEach((k, v) {
      if (v > maxDist && v.isFinite) {
        maxDist = v;
        node = k;
      }
    });
    return node;
  }

  List<int> _reconstructFromParents(
    int start,
    int end,
    Map<int, int> parents,
  ) {
    final path = <int>[end];
    var cursor = end;

    while (cursor != start) {
      final parent = parents[cursor];
      if (parent == null) {
        return [];
      }
      cursor = parent;
      path.add(cursor);
    }

    return path.reversed.toList();
  }

  double _minVertexDistanceMeters(LatLng point, List<LatLng> polyline) {
    var minDistance = double.infinity;
    for (final p in polyline) {
      final d = _distance(point, p);
      if (d < minDistance) {
        minDistance = d;
      }
    }
    return minDistance;
  }
}

class _TrailNetwork {
  const _TrailNetwork({
    required this.nodesById,
    required this.ways,
  });

  final Map<int, LatLng> nodesById;
  final List<Map<String, dynamic>> ways;
}

class _GraphEdge {
  const _GraphEdge({
    required this.to,
    required this.weight,
  });

  final int to;
  final double weight;
}

class _DijkstraResult {
  const _DijkstraResult({
    required this.distances,
    required this.parents,
  });

  final Map<int, double> distances;
  final Map<int, int> parents;
}

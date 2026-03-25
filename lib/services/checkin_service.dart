import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eco_tourism/services/alert_notification_service.dart';

enum CheckInResult {
  success,
  alreadyCheckedIn,
  alreadyCheckedAnotherTrail,
  failed,
}

enum UndoCheckInResult {
  success,
  notCheckedIn,
  failed,
}

class CheckInService {
  CheckInService._();

  static const String _deviceIdKey = 'device_id';
  static const String _checkedInTrailIdKey = 'checked_in_trail_id';
  static const String _historyKey = 'checkin_history';

  static Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated =
        'dev_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';
    await prefs.setString(_deviceIdKey, generated);
    return generated;
  }

  static Future<CheckInResult> checkInOnce(
    String trailId, {
    String? trailName,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final deviceId = await _getOrCreateDeviceId();
      final alreadyCheckedTrailId = await getCheckedInTrailId();

      if (alreadyCheckedTrailId == trailId) {
        await AlertNotificationService.subscribeToTrailAlerts(trailId);
        return CheckInResult.alreadyCheckedIn;
      }

      if (alreadyCheckedTrailId != null && alreadyCheckedTrailId.isNotEmpty) {
        return CheckInResult.alreadyCheckedAnotherTrail;
      }

      final trailRef = firestore.collection('trails').doc(trailId);

      final batch = firestore.batch();
      batch.set(firestore.collection('checkins').doc(), {
          'trailId': trailId,
          'deviceId': deviceId,
          'timestamp': Timestamp.now(),
      });
      batch.update(trailRef, {
        'checkInCount': FieldValue.increment(1),
        'lastUpdated': Timestamp.now(),
      });

      await batch.commit();

      await _saveCheckedInTrailId(trailId);
      await _saveOrUpdateHistory(trailId, trailName ?? 'Unknown Trail', true);
      await AlertNotificationService.subscribeToTrailAlerts(trailId);
      return CheckInResult.success;
    } catch (_) {
      return CheckInResult.failed;
    }
  }

  static Future<UndoCheckInResult> undoCheckIn(String trailId) async {
    try {
      final activeTrailId = await getCheckedInTrailId();
      if (activeTrailId != trailId) {
        return UndoCheckInResult.notCheckedIn;
      }

      final firestore = FirebaseFirestore.instance;
      final trailRef = firestore.collection('trails').doc(trailId);
      final deviceId = await _getOrCreateDeviceId();

      await firestore.runTransaction((transaction) async {
        final trailSnap = await transaction.get(trailRef);
        final data = trailSnap.data() ?? <String, dynamic>{};
        final rawCount = data['checkInCount'];
        int count = 0;
        if (rawCount is int) count = rawCount;
        if (rawCount is num) count = rawCount.toInt();

        transaction.update(trailRef, {
          'checkInCount': count > 0 ? count - 1 : 0,
          'lastUpdated': Timestamp.now(),
        });

        transaction.set(firestore.collection('checkins').doc(), {
          'trailId': trailId,
          'deviceId': deviceId,
          'event': 'UNDO',
          'timestamp': Timestamp.now(),
        });
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_checkedInTrailIdKey);
      await _saveOrUpdateHistory(trailId, null, false);
      await AlertNotificationService.unsubscribeFromTrailAlerts(trailId);

      return UndoCheckInResult.success;
    } catch (_) {
      return UndoCheckInResult.failed;
    }
  }

  static Future<void> _saveCheckedInTrailId(String trailId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_checkedInTrailIdKey, trailId);
  }

  static Future<String?> getCheckedInTrailId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_checkedInTrailIdKey);
  }

  static Future<List<Map<String, dynamic>>> getCheckInHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getStringList(_historyKey) ?? <String>[];

    final history = encoded
        .map((entry) => jsonDecode(entry) as Map<String, dynamic>)
        .toList();

    history.sort((a, b) {
      final aDate = DateTime.tryParse(a['checkedInAt']?.toString() ?? '') ?? DateTime(1970);
      final bDate = DateTime.tryParse(b['checkedInAt']?.toString() ?? '') ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    return history;
  }

  static Future<void> _saveOrUpdateHistory(
    String trailId,
    String? trailName,
    bool isActive,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getStringList(_historyKey) ?? <String>[];
    final history = encoded
        .map((entry) => jsonDecode(entry) as Map<String, dynamic>)
        .toList();

    final existingIndex = history.indexWhere((item) => item['trailId'] == trailId);
    final nowIso = DateTime.now().toIso8601String();

    if (existingIndex >= 0) {
      final existing = history[existingIndex];
      history[existingIndex] = {
        ...existing,
        'trailName': trailName ?? existing['trailName'] ?? 'Unknown Trail',
        'isActive': isActive,
        if (isActive) 'checkedInAt': nowIso,
        if (!isActive) 'undoneAt': nowIso,
      };
    } else {
      history.add({
        'trailId': trailId,
        'trailName': trailName ?? 'Unknown Trail',
        'checkedInAt': nowIso,
        'isActive': isActive,
      });
    }

    final updated = history.map((item) => jsonEncode(item)).toList();
    await prefs.setStringList(_historyKey, updated);
  }
}

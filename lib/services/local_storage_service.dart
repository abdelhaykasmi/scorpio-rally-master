import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Local storage service using SharedPreferences for offline capability
class LocalStorageService {
  static const String _passagesKey = 'offline_passages';
  static const String _currentUserKey = 'current_user';
  static const String _currentEventKey = 'current_event';
  static const String _usersKey = 'cached_users';
  static const String _checkpointsKey = 'cached_checkpoints';
  static const String _eventsKey = 'cached_events';

  static LocalStorageService? _instance;
  static LocalStorageService get instance {
    _instance ??= LocalStorageService._();
    return _instance!;
  }
  LocalStorageService._();

  // ── Current User ──────────────────────────────────────────
  Future<void> saveCurrentUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, jsonEncode(user.toMap()..['id'] = user.id));
  }

  Future<AppUser?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_currentUserKey);
    if (str == null) return null;
    try {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return AppUser.fromMap(map, map['id'] ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  // ── Offline Passages ──────────────────────────────────────
  Future<List<CheckpointPassage>> getPendingPassages() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_passagesKey) ?? '[]';
    try {
      final list = jsonDecode(str) as List;
      return list
          .map((e) => CheckpointPassage.fromMap(
              Map<String, dynamic>.from(e as Map), e['id']?.toString() ?? ''))
          .where((p) => p.syncStatus == SyncStatus.pending)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<CheckpointPassage>> getAllLocalPassages() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_passagesKey) ?? '[]';
    try {
      final list = jsonDecode(str) as List;
      return list
          .map((e) => CheckpointPassage.fromMap(
              Map<String, dynamic>.from(e as Map), e['id']?.toString() ?? ''))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePassageLocally(CheckpointPassage passage) async {
    final all = await getAllLocalPassages();
    // Check for duplicate at same checkpoint
    final exists = all.any((p) =>
        p.participantId == passage.participantId &&
        p.checkpointId == passage.checkpointId &&
        p.eventId == passage.eventId);
    if (!exists) {
      all.add(passage);
      await _saveAllPassages(all);
    }
  }

  Future<CheckpointPassage?> findDuplicate(
      String participantId, String checkpointId, String eventId) async {
    final all = await getAllLocalPassages();
    try {
      return all.firstWhere((p) =>
          p.participantId == participantId &&
          p.checkpointId == checkpointId &&
          p.eventId == eventId);
    } catch (_) {
      return null;
    }
  }

  Future<void> markPassageSynced(String passageId) async {
    final all = await getAllLocalPassages();
    final updated = all.map((p) {
      if (p.id == passageId) return p.copyWith(syncStatus: SyncStatus.synced);
      return p;
    }).toList();
    await _saveAllPassages(updated);
  }

  Future<void> _saveAllPassages(List<CheckpointPassage> passages) async {
    final prefs = await SharedPreferences.getInstance();
    final list = passages.map((p) => p.toMap()..['id'] = p.id).toList();
    await prefs.setString(_passagesKey, jsonEncode(list));
  }

  // ── Cached Users ──────────────────────────────────────────
  Future<void> cacheUsers(List<AppUser> users) async {
    final prefs = await SharedPreferences.getInstance();
    final list = users.map((u) => u.toMap()..['id'] = u.id).toList();
    await prefs.setString(_usersKey, jsonEncode(list));
  }

  Future<List<AppUser>> getCachedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_usersKey) ?? '[]';
    try {
      final list = jsonDecode(str) as List;
      return list
          .map((e) => AppUser.fromMap(
              Map<String, dynamic>.from(e as Map), e['id']?.toString() ?? ''))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Cached Events ─────────────────────────────────────────
  Future<void> cacheEvents(List<RallyEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final list = events.map((e) => e.toMap()..['id'] = e.id).toList();
    await prefs.setString(_eventsKey, jsonEncode(list));
  }

  Future<List<RallyEvent>> getCachedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_eventsKey) ?? '[]';
    try {
      final list = jsonDecode(str) as List;
      return list
          .map((e) => RallyEvent.fromMap(
              Map<String, dynamic>.from(e as Map), e['id']?.toString() ?? ''))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<RallyEvent?> getActiveEvent() async {
    final events = await getCachedEvents();
    try {
      return events.firstWhere((e) => e.isActive);
    } catch (_) {
      return null;
    }
  }

  // ── Cached Checkpoints ────────────────────────────────────
  Future<void> cacheCheckpoints(List<Checkpoint> checkpoints) async {
    final prefs = await SharedPreferences.getInstance();
    final list = checkpoints.map((c) => c.toMap()..['id'] = c.id).toList();
    await prefs.setString(_checkpointsKey, jsonEncode(list));
  }

  Future<List<Checkpoint>> getCachedCheckpoints(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_checkpointsKey) ?? '[]';
    try {
      final list = jsonDecode(str) as List;
      return list
          .map((e) => Checkpoint.fromMap(
              Map<String, dynamic>.from(e as Map), e['id']?.toString() ?? ''))
          .where((c) => c.eventId == eventId)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    } catch (_) {
      return [];
    }
  }

  // ── Passages by Checkpoint ────────────────────────────────
  Future<List<CheckpointPassage>> getPassagesForCheckpoint(
      String checkpointId, String eventId) async {
    final all = await getAllLocalPassages();
    return all
        .where((p) => p.checkpointId == checkpointId && p.eventId == eventId)
        .toList()
      ..sort((a, b) => b.localTime.compareTo(a.localTime));
  }

  Future<List<CheckpointPassage>> getPassagesForParticipant(
      String participantId, String eventId) async {
    final all = await getAllLocalPassages();
    return all
        .where((p) => p.participantId == participantId && p.eventId == eventId)
        .toList()
      ..sort((a, b) => a.localTime.compareTo(b.localTime));
  }

  // ── Clear ─────────────────────────────────────────────────
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import 'local_storage_service.dart';

enum SyncState { unknown, online, offline, syncing }

/// Tracks Supabase connectivity and drives bidirectional sync:
///   - pull: Supabase → local cache  (so refresh sees latest data from any device)
///   - push: local cache → Supabase  (so data created offline reaches the DB)
///
/// Auto-sync runs on startup (pull only — safe, non-destructive).
/// Manual "SYNC NOW" does push + pull.
class SyncService extends ChangeNotifier {
  static SyncService? _instance;
  static SyncService get instance {
    _instance ??= SyncService._();
    return _instance!;
  }
  SyncService._();

  SyncState _state = SyncState.unknown;
  String? _lastError;

  SyncState get state => _state;
  String? get lastError => _lastError;
  bool get isOnline => _state == SyncState.online;
  bool get isOffline => _state == SyncState.offline;

  // ── Startup: check connectivity then pull ─────────────────
  /// Called once at app startup. If reachable, immediately pulls all
  /// remote data into local cache so every screen sees the latest state.
  Future<void> initSync() async {
    final online = await checkConnectivity();
    if (online) {
      try {
        await _pullFromSupabase();
      } catch (_) {
        // Pull failed — local cache stays valid, no data lost
      }
    }
  }

  // ── Connectivity probe ────────────────────────────────────
  Future<bool> checkConnectivity() async {
    try {
      await SupabaseService.instance.pingSupabase();
      _state = SyncState.online;
      _lastError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _state = SyncState.offline;
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Pull: Supabase → local cache ──────────────────────────
  /// Fetches all tables from Supabase and merges into local cache.
  /// Safe to call at any time — merge logic never overwrites local-only data.
  Future<void> _pullFromSupabase() async {
    // Users
    try {
      final remoteUsers = await SupabaseService.instance.getUsers();
      if (remoteUsers.isNotEmpty) {
        await LocalStorageService.instance.mergeUsers(remoteUsers);
      }
    } catch (_) {}

    // Events
    try {
      final remoteEvents = await SupabaseService.instance.getEvents();
      if (remoteEvents.isNotEmpty) {
        await LocalStorageService.instance.mergeEvents(remoteEvents);
      }
    } catch (_) {}

    // Checkpoints — for every event we know about
    try {
      final allEvents = await LocalStorageService.instance.getCachedEvents();
      for (final e in allEvents) {
        try {
          final remoteCps =
              await SupabaseService.instance.getCheckpoints(e.id);
          if (remoteCps.isNotEmpty) {
            await LocalStorageService.instance
                .mergeCheckpoints(remoteCps, e.id);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  // ── Push: local cache → Supabase ─────────────────────────
  /// Upserts all local data to Supabase. Collects per-item errors so a
  /// single bad record doesn't abort the whole sync.
  /// Returns a result object with counts and the first error message (if any).
  Future<SyncResult> _pushToSupabase() async {
    int users = 0, events = 0, checkpoints = 0, passages = 0, errors = 0;
    String? firstError;

    void recordError(Object e) {
      errors++;
      firstError ??= e.toString();
    }

    // Users
    final localUsers = await LocalStorageService.instance.getCachedUsers();
    for (final u in localUsers) {
      try {
        await SupabaseService.instance.upsertUser(u);
        users++;
      } catch (e) {
        recordError(e);
      }
    }

    // Events
    final localEvents = await LocalStorageService.instance.getCachedEvents();
    for (final e in localEvents) {
      try {
        await SupabaseService.instance.upsertEvent(e);
        events++;
      } catch (e) {
        recordError(e);
      }
    }

    // Checkpoints
    for (final e in localEvents) {
      final cps =
          await LocalStorageService.instance.getCachedCheckpoints(e.id);
      for (final cp in cps) {
        try {
          await SupabaseService.instance.upsertCheckpoint(cp);
          checkpoints++;
        } catch (e) {
          recordError(e);
        }
      }
    }

    // Pending passages
    final pending =
        await LocalStorageService.instance.getPendingPassages();
    for (final p in pending) {
      try {
        await SupabaseService.instance.recordPassage(p);
        passages++;
      } catch (e) {
        recordError(e);
      }
    }

    return SyncResult(
      users: users,
      events: events,
      checkpoints: checkpoints,
      passages: passages,
      errors: errors,
      firstError: firstError,
    );
  }

  // ── Full sync: push + pull ────────────────────────────────
  /// Manual "SYNC NOW": pushes all local data to Supabase, then pulls
  /// remote data back so the local cache is fully up-to-date.
  /// Returns a human-readable summary. Throws on connectivity failure.
  Future<String> syncAllToSupabase() async {
    _state = SyncState.syncing;
    _lastError = null;
    notifyListeners();

    // Re-check connectivity first
    try {
      await SupabaseService.instance.pingSupabase();
    } catch (e) {
      _state = SyncState.offline;
      _lastError = e.toString();
      notifyListeners();
      throw Exception(
          'Cannot reach database. Check your Supabase project is active and '
          'RLS policies allow anon access.\n\nError: $e');
    }

    try {
      // 1. Push local → remote
      final result = await _pushToSupabase();

      // 2. Pull remote → local (so UI sees latest data from all devices)
      await _pullFromSupabase();

      _state = SyncState.online;
      _lastError = null;
      notifyListeners();

      if (result.errors > 0) {
        // Surface the actual error so user/admin can diagnose
        throw Exception(
            '${result.errors} item(s) failed to sync.\n\n'
            'Most likely cause: Supabase RLS (Row Level Security) is blocking '
            'writes from the anon key.\n\n'
            'Fix: In Supabase dashboard → Table Editor → each table → '
            'Policies → add policy:\n'
            '  Name: allow_all\n'
            '  For: ALL operations\n'
            '  USING expression: true\n'
            '  WITH CHECK expression: true\n\n'
            'First error: ${result.firstError}');
      }

      return 'Synced: ${result.users} users, ${result.events} events, '
          '${result.checkpoints} checkpoints, ${result.passages} passages';
    } catch (e) {
      _state = SyncState.offline;
      _lastError = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}

class SyncResult {
  final int users, events, checkpoints, passages, errors;
  final String? firstError;
  const SyncResult({
    required this.users,
    required this.events,
    required this.checkpoints,
    required this.passages,
    required this.errors,
    this.firstError,
  });
}

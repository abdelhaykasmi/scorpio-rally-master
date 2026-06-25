import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import 'local_storage_service.dart';

export 'supabase_service.dart' show SchemaStatus;

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
  SchemaStatus? _schemaStatus;

  SyncState get state => _state;
  String? get lastError => _lastError;
  bool get isOnline => _state == SyncState.online;
  bool get isOffline => _state == SyncState.offline;
  SchemaStatus? get schemaStatus => _schemaStatus;
  bool get hasSchemaIssues => _schemaStatus != null && !_schemaStatus!.isHealthy;

  // ── Startup: check connectivity then pull ─────────────────
  /// Called once at app startup. If reachable, immediately pulls all
  /// remote data into local cache so every screen sees the latest state.
  /// Also runs a background schema probe so the admin sees schema issues
  /// immediately after login.
  Future<void> initSync() async {
    final online = await checkConnectivity();
    if (online) {
      // Run schema probe and data pull concurrently
      await Future.wait([
        _runSchemaProbe(),
        _pullFromSupabase().catchError((_) {}),
      ]);
    }
  }

  // ── Schema probe ──────────────────────────────────────────
  Future<void> _runSchemaProbe() async {
    try {
      final status = await SupabaseService.instance.probeSchema();
      _schemaStatus = status;
      notifyListeners();
    } catch (_) {
      // Schema probe failed — ignore, connectivity error takes precedence
    }
  }

  /// Manually re-run the schema probe and return the result.
  /// Called by admin after running the SQL fix.
  Future<SchemaStatus> recheckSchema() async {
    try {
      final status = await SupabaseService.instance.probeSchema();
      _schemaStatus = status;
      notifyListeners();
      return status;
    } catch (e) {
      throw Exception('Schema check failed: $e');
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
      // 1. Run schema probe (parallel with push for speed)
      final schemaFuture = _runSchemaProbe();

      // 2. Push local → remote
      final result = await _pushToSupabase();

      // 3. Pull remote → local (so UI sees latest data from all devices)
      await _pullFromSupabase();

      // 4. Wait for schema probe to complete
      await schemaFuture;

      _state = SyncState.online;
      _lastError = null;
      notifyListeners();

      if (result.errors > 0) {
        // Build a targeted error message based on schema probe results
        final sb = StringBuffer();
        sb.writeln('${result.errors} item(s) failed to sync.');
        sb.writeln();

        if (_schemaStatus != null && !_schemaStatus!.isHealthy) {
          sb.writeln('DATABASE SCHEMA ISSUES DETECTED:');
          for (final issue in _schemaStatus!.issues) {
            sb.writeln('  • $issue');
          }
          sb.writeln();
          sb.writeln('Run the SQL in Settings → Setup Database Schema to fix.');
        } else {
          sb.writeln('Most likely cause: Supabase RLS (Row Level Security) is '
              'blocking writes from the anon key.');
          sb.writeln();
          sb.writeln('Fix: In Supabase SQL Editor run:');
          sb.writeln('''
CREATE POLICY "allow_all" ON rally_events FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all" ON checkpoints   FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all" ON app_users     FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all" ON checkpoint_passages FOR ALL USING (true) WITH CHECK (true);''');
        }
        sb.writeln();
        sb.writeln('First error: ${result.firstError}');
        throw Exception(sb.toString());
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

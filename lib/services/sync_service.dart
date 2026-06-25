import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'supabase_service.dart';
import 'local_storage_service.dart';

enum SyncState { unknown, online, offline, syncing }

/// Tracks Supabase connectivity and drives the "push all local data" sync.
class SyncService extends ChangeNotifier {
  static SyncService? _instance;
  static SyncService get instance {
    _instance ??= SyncService._();
    return _instance!;
  }
  SyncService._();

  SyncState _state = SyncState.unknown;
  String? _lastError;
  DateTime? _lastChecked;

  SyncState get state => _state;
  String? get lastError => _lastError;
  bool get isOnline => _state == SyncState.online;
  bool get isOffline => _state == SyncState.offline;

  // ── Connectivity probe ────────────────────────────────────
  /// Lightweight check: can we read from Supabase?
  Future<bool> checkConnectivity() async {
    try {
      await SupabaseService.instance.pingSupabase();
      _state = SyncState.online;
      _lastError = null;
      _lastChecked = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      _state = SyncState.offline;
      _lastError = e.toString();
      _lastChecked = DateTime.now();
      notifyListeners();
      return false;
    }
  }

  // ── Full sync: push all local data to Supabase ────────────
  /// Reads everything from local cache and upserts it all to Supabase.
  /// Returns a summary string.
  Future<String> syncAllToSupabase() async {
    _state = SyncState.syncing;
    notifyListeners();

    int users = 0, events = 0, checkpoints = 0, passages = 0, errors = 0;

    try {
      // ── Users ──────────────────────────────────────────
      final localUsers = await LocalStorageService.instance.getCachedUsers();
      for (final u in localUsers) {
        try {
          await SupabaseService.instance.upsertUser(u);
          users++;
        } catch (_) {
          errors++;
        }
      }

      // ── Events ─────────────────────────────────────────
      final localEvents = await LocalStorageService.instance.getCachedEvents();
      for (final e in localEvents) {
        try {
          await SupabaseService.instance.upsertEvent(e);
          events++;
        } catch (_) {
          errors++;
        }
      }

      // ── Checkpoints ────────────────────────────────────
      // Collect all checkpoint event IDs from local events
      for (final e in localEvents) {
        final cps =
            await LocalStorageService.instance.getCachedCheckpoints(e.id);
        for (final cp in cps) {
          try {
            await SupabaseService.instance.upsertCheckpoint(cp);
            checkpoints++;
          } catch (_) {
            errors++;
          }
        }
      }

      // ── Passages ───────────────────────────────────────
      final pending =
          await LocalStorageService.instance.getPendingPassages();
      for (final p in pending) {
        try {
          await SupabaseService.instance.recordPassage(p);
          passages++;
        } catch (_) {
          errors++;
        }
      }

      _state = SyncState.online;
      _lastError = null;
      notifyListeners();

      final summary =
          'Synced: $users users, $events events, $checkpoints checkpoints, $passages passages'
          '${errors > 0 ? " ($errors errors)" : ""}';
      return summary;
    } catch (e) {
      _state = SyncState.offline;
      _lastError = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}

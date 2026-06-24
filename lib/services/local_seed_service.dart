import '../models/models.dart';
import 'local_storage_service.dart';

/// Seeds the minimum required local data so the app can function offline.
///
/// Only seeds ONE super-admin user (admin / admin123).
/// No demo organizers, riders, events, checkpoints, or passages.
/// All other data must be created by the admin through the app.
///
/// Also purges any stale demo data from the previous version that used
/// hardcoded IDs like 'org_1', 'p_001', 'event_2024', etc.
///
/// Passwords stored as pre-computed SHA-256 hashes only.
class LocalSeedService {
  static LocalSeedService? _instance;
  static LocalSeedService get instance {
    _instance ??= LocalSeedService._();
    return _instance!;
  }
  LocalSeedService._();

  bool _seeded = false;

  // Pre-computed SHA-256 of "admin123" — no plain password in source or JS
  static const _hAdmin =
      '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9';

  // Legacy demo user IDs that were seeded in previous versions
  static const _legacyIds = {
    'admin_1', 'org_1', 'org_2', 'org_3',
    'p_001', 'p_002', 'p_003', 'p_004', 'p_005',
  };

  Future<void> seedDemoDataIfNeeded() async {
    if (_seeded) return;
    _seeded = true;

    final existing = await LocalStorageService.instance.getCachedUsers();

    // ── Detect and purge legacy demo seed ─────────────────────
    // If ANY of the old hardcoded IDs are present, the cache holds stale
    // demo data. Wipe everything and re-seed with admin only.
    final hasLegacyData =
        existing.any((u) => _legacyIds.contains(u.id));

    if (hasLegacyData) {
      // Clear ALL local storage (users, events, checkpoints, passages, settings)
      await LocalStorageService.instance.clearAll();
    } else if (existing.isNotEmpty) {
      // Fresh data created by the admin — nothing to seed
      return;
    }

    // Seed admin only
    final admin = AppUser(
      id: 'admin_local',
      username: 'admin',
      passwordHash: _hAdmin,
      role: UserRole.superAdmin,
      isActive: true,
      fullName: 'Administrator',
    );
    await LocalStorageService.instance.cacheUsers([admin]);
  }
}

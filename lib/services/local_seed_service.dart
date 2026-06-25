import '../models/models.dart';
import 'local_storage_service.dart';

/// Seeds the minimum required local data so the app can function offline
/// when Supabase has never been reached yet (true first install).
///
/// Rules:
///  1. If a superAdmin already exists in local cache → do NOTHING.
///     (Real admin data from Supabase was already pulled — never overwrite it.)
///  2. If legacy demo IDs exist (from old app version) → purge & re-seed admin.
///  3. If cache is completely empty → seed the default admin.
///
/// This means:
///  • After initSync() pulls from Supabase, the real admin is in cache → no seed.
///  • On a truly fresh device with no Supabase connection → local admin works.
///  • Never wipes real admin data created through the app.
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

  // Legacy demo user IDs seeded in previous app versions — safe to purge
  static const _legacyIds = {
    'admin_1', 'org_1', 'org_2', 'org_3',
    'p_001', 'p_002', 'p_003', 'p_004', 'p_005',
  };

  Future<void> seedDemoDataIfNeeded() async {
    if (_seeded) return;
    _seeded = true;

    final existing = await LocalStorageService.instance.getCachedUsers();

    // ── Guard: real admin already in cache ───────────────────
    // If there's already a superAdmin (from Supabase pull or previous session),
    // do absolutely nothing — we must never overwrite real data.
    final hasSuperAdmin =
        existing.any((u) => u.role == UserRole.superAdmin);
    if (hasSuperAdmin) return;

    // ── Purge legacy demo seed ────────────────────────────────
    final hasLegacyData =
        existing.any((u) => _legacyIds.contains(u.id));
    if (hasLegacyData) {
      await LocalStorageService.instance.clearAll();
    } else if (existing.isNotEmpty) {
      // Non-legacy, non-admin users exist (shouldn't happen, but be safe)
      return;
    }

    // ── Seed fallback admin (offline-only) ───────────────────
    // This admin only exists locally until Supabase sync runs.
    // ID 'admin_local' is intentionally different from real Supabase UUIDs
    // so mergeUsers() will keep both until the real admin is confirmed.
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

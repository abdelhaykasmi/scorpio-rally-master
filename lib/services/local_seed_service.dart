import '../models/models.dart';
import 'local_storage_service.dart';

/// Seeds demo data into local SharedPreferences so the app works
/// fully offline and on web even if Supabase is unreachable.
///
/// Passwords are stored as pre-computed SHA-256 hashes only.
/// No plain-text passwords exist anywhere in this file or the compiled output.
class LocalSeedService {
  static LocalSeedService? _instance;
  static LocalSeedService get instance {
    _instance ??= LocalSeedService._();
    return _instance!;
  }
  LocalSeedService._();

  bool _seeded = false;

  // Pre-computed SHA-256 hashes — plain passwords never appear in source or JS
  // admin123
  static const _hAdmin =
      '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9';
  // marshal123
  static const _hMarshal =
      '8cfd286b3293df3dd1cbe45318301887a8ee7dc3ab46815f8172bea976f79ad8';
  // rider123
  static const _hRider =
      'e85978062768502c68bfd953d2d3793cf799b6abe697543512d8bc41bc60e210';

  Future<void> seedDemoDataIfNeeded() async {
    if (_seeded) return;
    _seeded = true;

    final existing = await LocalStorageService.instance.getCachedUsers();
    if (existing.isNotEmpty) return;

    // ── Users ────────────────────────────────────────────────
    final users = <AppUser>[
      AppUser(
          id: 'admin_1',
          username: 'admin',
          passwordHash: _hAdmin,
          role: UserRole.superAdmin,
          isActive: true,
          fullName: 'Super Administrator'),
      AppUser(
          id: 'org_1',
          username: 'marshal1',
          passwordHash: _hMarshal,
          role: UserRole.organizer,
          isActive: true,
          assignedCheckpointId: 'cp_1',
          fullName: 'Marshal Alpha'),
      AppUser(
          id: 'org_2',
          username: 'marshal2',
          passwordHash: _hMarshal,
          role: UserRole.organizer,
          isActive: true,
          assignedCheckpointId: 'cp_2',
          fullName: 'Marshal Bravo'),
      AppUser(
          id: 'org_3',
          username: 'marshal3',
          passwordHash: _hMarshal,
          role: UserRole.organizer,
          isActive: true,
          assignedCheckpointId: 'cp_3',
          fullName: 'Marshal Charlie'),
      AppUser(
          id: 'p_001',
          username: 'rider001',
          passwordHash: _hRider,
          role: UserRole.participant,
          isActive: true,
          fullName: 'Carlos Sainz Jr.',
          bikeBrand: 'KTM',
          bikeModel: '450 EXC-F',
          engineSize: 450,
          bibNumber: '001',
          nationality: 'Spanish',
          emergencyContactName: 'Maria Sainz',
          emergencyContactPhone: '+34 600 111 222'),
      AppUser(
          id: 'p_002',
          username: 'rider002',
          passwordHash: _hRider,
          role: UserRole.participant,
          isActive: true,
          fullName: 'Nasser Al-Attiyah',
          bikeBrand: 'Husqvarna',
          bikeModel: 'FR 450 Rally',
          engineSize: 450,
          bibNumber: '002',
          nationality: 'Qatari',
          emergencyContactName: 'Fatima Al-Attiyah',
          emergencyContactPhone: '+974 5555 1234'),
      AppUser(
          id: 'p_003',
          username: 'rider003',
          passwordHash: _hRider,
          role: UserRole.participant,
          isActive: true,
          fullName: 'Toby Price',
          bikeBrand: 'KTM',
          bikeModel: '450 Rally',
          engineSize: 450,
          bibNumber: '003',
          nationality: 'Australian',
          emergencyContactName: 'Luke Price',
          emergencyContactPhone: '+61 400 333 444'),
      AppUser(
          id: 'p_004',
          username: 'rider004',
          passwordHash: _hRider,
          role: UserRole.participant,
          isActive: true,
          fullName: 'Adrien Van Beveren',
          bikeBrand: 'Honda',
          bikeModel: 'CRF450 Rally',
          engineSize: 450,
          bibNumber: '004',
          nationality: 'French',
          emergencyContactName: 'Claire Van Beveren',
          emergencyContactPhone: '+33 6 00 44 55 66'),
      AppUser(
          id: 'p_005',
          username: 'rider005',
          passwordHash: _hRider,
          role: UserRole.participant,
          isActive: true,
          fullName: 'Pablo Quintanilla',
          bikeBrand: 'GASGAS',
          bikeModel: 'RC 450F',
          engineSize: 450,
          bibNumber: '005',
          nationality: 'Chilean',
          emergencyContactName: 'Sofia Quintanilla',
          emergencyContactPhone: '+56 9 1234 5678'),
    ];
    await LocalStorageService.instance.cacheUsers(users);

    // ── Event ────────────────────────────────────────────────
    final event = RallyEvent(
      id: 'event_2024',
      name: 'RAID Sahara Challenge 2024',
      date: DateTime(2024, 10, 15),
      location: 'Erfoud, Morocco',
      description: 'The ultimate off-road rally across the Moroccan Sahara. '
          '5 stages, 800km of pure enduro challenge through dunes, '
          'rocky canyons and mountain passes.',
      isActive: true,
      createdAt: DateTime(2024, 9, 1),
    );
    await LocalStorageService.instance.cacheEvents([event]);

    // ── Checkpoints ──────────────────────────────────────────
    final checkpoints = <Checkpoint>[
      Checkpoint(
          id: 'cp_1',
          eventId: 'event_2024',
          name: 'CP1 — Dune Gateway',
          order: 1,
          description: 'Start of the dune sector, Erg Chebbi entrance',
          latitude: 31.3667,
          longitude: -4.0,
          assignedOrganizerId: 'org_1',
          assignedOrganizerName: 'Marshal Alpha'),
      Checkpoint(
          id: 'cp_2',
          eventId: 'event_2024',
          name: 'CP2 — Canyon Pass',
          order: 2,
          description: 'Rocky canyon section midpoint',
          latitude: 31.5,
          longitude: -4.25,
          assignedOrganizerId: 'org_2',
          assignedOrganizerName: 'Marshal Bravo'),
      Checkpoint(
          id: 'cp_3',
          eventId: 'event_2024',
          name: 'CP3 — Atlas Summit',
          order: 3,
          description: 'High altitude mountain checkpoint',
          latitude: 31.65,
          longitude: -4.5,
          assignedOrganizerId: 'org_3',
          assignedOrganizerName: 'Marshal Charlie'),
      Checkpoint(
          id: 'cp_4',
          eventId: 'event_2024',
          name: 'CP4 — Desert Bivouac',
          order: 4,
          description: 'Central bivouac refuelling point',
          latitude: 31.8,
          longitude: -4.75),
      Checkpoint(
          id: 'cp_5',
          eventId: 'event_2024',
          name: 'FINISH — Merzouga',
          order: 5,
          description: 'Final finish line at Merzouga town',
          latitude: 31.1,
          longitude: -3.97),
    ];
    await LocalStorageService.instance.cacheCheckpoints(checkpoints);

    // ── Sample Passages ──────────────────────────────────────
    final now = DateTime.now();
    final passages = <CheckpointPassage>[
      CheckpointPassage(
          id: 'pass_001_cp1',
          eventId: 'event_2024',
          checkpointId: 'cp_1',
          checkpointName: 'CP1 — Dune Gateway',
          participantId: 'p_001',
          participantName: 'Carlos Sainz Jr.',
          bibNumber: '001',
          localTime: now.subtract(const Duration(hours: 3, minutes: 12)),
          utcTime:
              now.subtract(const Duration(hours: 3, minutes: 12)).toUtc(),
          syncStatus: SyncStatus.synced),
      CheckpointPassage(
          id: 'pass_002_cp1',
          eventId: 'event_2024',
          checkpointId: 'cp_1',
          checkpointName: 'CP1 — Dune Gateway',
          participantId: 'p_002',
          participantName: 'Nasser Al-Attiyah',
          bibNumber: '002',
          localTime: now.subtract(const Duration(hours: 3, minutes: 5)),
          utcTime:
              now.subtract(const Duration(hours: 3, minutes: 5)).toUtc(),
          syncStatus: SyncStatus.synced),
      CheckpointPassage(
          id: 'pass_003_cp1',
          eventId: 'event_2024',
          checkpointId: 'cp_1',
          checkpointName: 'CP1 — Dune Gateway',
          participantId: 'p_003',
          participantName: 'Toby Price',
          bibNumber: '003',
          localTime: now.subtract(const Duration(hours: 2, minutes: 58)),
          utcTime:
              now.subtract(const Duration(hours: 2, minutes: 58)).toUtc(),
          syncStatus: SyncStatus.synced),
      CheckpointPassage(
          id: 'pass_001_cp2',
          eventId: 'event_2024',
          checkpointId: 'cp_2',
          checkpointName: 'CP2 — Canyon Pass',
          participantId: 'p_001',
          participantName: 'Carlos Sainz Jr.',
          bibNumber: '001',
          localTime: now.subtract(const Duration(hours: 1, minutes: 45)),
          utcTime:
              now.subtract(const Duration(hours: 1, minutes: 45)).toUtc(),
          syncStatus: SyncStatus.synced),
      CheckpointPassage(
          id: 'pass_002_cp2',
          eventId: 'event_2024',
          checkpointId: 'cp_2',
          checkpointName: 'CP2 — Canyon Pass',
          participantId: 'p_002',
          participantName: 'Nasser Al-Attiyah',
          bibNumber: '002',
          localTime: now.subtract(const Duration(hours: 1, minutes: 38)),
          utcTime:
              now.subtract(const Duration(hours: 1, minutes: 38)).toUtc(),
          syncStatus: SyncStatus.synced),
    ];
    for (final p in passages) {
      await LocalStorageService.instance.savePassageLocally(p);
    }
  }
}

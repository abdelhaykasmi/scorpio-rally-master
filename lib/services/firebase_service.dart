import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/models.dart';
import 'local_storage_service.dart';

/// Converts gpxBytes (transient) to a base64 data-URI stored in gpxFileUrl.
RallyEvent _injectGpxBytes(RallyEvent event) {
  if (event.gpxBytes != null && event.gpxBytes!.isNotEmpty) {
    final b64 = base64Encode(event.gpxBytes!);
    return event.copyWith(
      gpxFileUrl: 'data:application/gpx+xml;base64,$b64',
      gpxFileName: event.gpxFileName,
    );
  }
  return event;
}

/// Firebase-compatible service — uses local storage as the single source of truth
/// for the demo/web preview. In production, swap the _store* methods to Firestore calls.
class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance {
    _instance ??= FirebaseService._();
    return _instance!;
  }
  FirebaseService._();

  bool _seeded = false;

  // ── Password Hashing ──────────────────────────────────────
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ── Seed Demo Data ────────────────────────────────────────
  Future<void> seedDemoDataIfNeeded() async {
    if (_seeded) return;
    _seeded = true;

    final existing = await LocalStorageService.instance.getCachedUsers();
    if (existing.isNotEmpty) return;

    // Seed users
    final users = <AppUser>[
      AppUser(
        id: 'admin_1',
        username: 'admin',
        passwordHash: hashPassword('admin123'),
        role: UserRole.superAdmin,
        isActive: true,
        fullName: 'Super Administrator',
      ),
      AppUser(
        id: 'org_1',
        username: 'marshal1',
        passwordHash: hashPassword('marshal123'),
        role: UserRole.organizer,
        isActive: true,
        assignedCheckpointId: 'cp_1',
        fullName: 'Marshal Alpha',
      ),
      AppUser(
        id: 'org_2',
        username: 'marshal2',
        passwordHash: hashPassword('marshal123'),
        role: UserRole.organizer,
        isActive: true,
        assignedCheckpointId: 'cp_2',
        fullName: 'Marshal Bravo',
      ),
      AppUser(
        id: 'org_3',
        username: 'marshal3',
        passwordHash: hashPassword('marshal123'),
        role: UserRole.organizer,
        isActive: true,
        assignedCheckpointId: 'cp_3',
        fullName: 'Marshal Charlie',
      ),
      AppUser(
        id: 'p_001',
        username: 'rider001',
        passwordHash: hashPassword('rider123'),
        role: UserRole.participant,
        isActive: true,
        fullName: 'Carlos Sainz Jr.',
        bikeBrand: 'KTM',
        bikeModel: '450 EXC-F',
        engineSize: 450,
        bibNumber: '001',
        nationality: 'Spanish',
        emergencyContactName: 'Maria Sainz',
        emergencyContactPhone: '+34 600 111 222',
      ),
      AppUser(
        id: 'p_002',
        username: 'rider002',
        passwordHash: hashPassword('rider123'),
        role: UserRole.participant,
        isActive: true,
        fullName: 'Nasser Al-Attiyah',
        bikeBrand: 'Husqvarna',
        bikeModel: 'FR 450 Rally',
        engineSize: 450,
        bibNumber: '002',
        nationality: 'Qatari',
        emergencyContactName: 'Fatima Al-Attiyah',
        emergencyContactPhone: '+974 5555 1234',
      ),
      AppUser(
        id: 'p_003',
        username: 'rider003',
        passwordHash: hashPassword('rider123'),
        role: UserRole.participant,
        isActive: true,
        fullName: 'Toby Price',
        bikeBrand: 'KTM',
        bikeModel: '450 Rally',
        engineSize: 450,
        bibNumber: '003',
        nationality: 'Australian',
        emergencyContactName: 'Luke Price',
        emergencyContactPhone: '+61 400 333 444',
      ),
      AppUser(
        id: 'p_004',
        username: 'rider004',
        passwordHash: hashPassword('rider123'),
        role: UserRole.participant,
        isActive: true,
        fullName: 'Adrien Van Beveren',
        bikeBrand: 'Honda',
        bikeModel: 'CRF450 Rally',
        engineSize: 450,
        bibNumber: '004',
        nationality: 'French',
        emergencyContactName: 'Claire Van Beveren',
        emergencyContactPhone: '+33 6 00 44 55 66',
      ),
      AppUser(
        id: 'p_005',
        username: 'rider005',
        passwordHash: hashPassword('rider123'),
        role: UserRole.participant,
        isActive: true,
        fullName: 'Pablo Quintanilla',
        bikeBrand: 'GASGAS',
        bikeModel: 'RC 450F',
        engineSize: 450,
        bibNumber: '005',
        nationality: 'Chilean',
        emergencyContactName: 'Sofia Quintanilla',
        emergencyContactPhone: '+56 9 1234 5678',
      ),
    ];
    await LocalStorageService.instance.cacheUsers(users);

    // Seed event
    final event = RallyEvent(
      id: 'event_2024',
      name: 'RAID Sahara Challenge 2024',
      date: DateTime(2024, 10, 15),
      location: 'Erfoud, Morocco',
      description: 'The ultimate off-road rally across the Moroccan Sahara. 5 stages, 800km of pure enduro challenge through dunes, rocky canyons and mountain passes.',
      isActive: true,
      primaryColor: 'E53935',
      secondaryColor: 'B71C1C',
      createdAt: DateTime(2024, 9, 1),
    );
    await LocalStorageService.instance.cacheEvents([event]);

    // Seed checkpoints
    final checkpoints = <Checkpoint>[
      Checkpoint(
        id: 'cp_1',
        eventId: 'event_2024',
        name: 'CP1 — Dune Gateway',
        order: 1,
        description: 'Start of the dune sector, Erg Chebbi entrance',
        latitude: 31.3667,
        longitude: -4.0000,
        assignedOrganizerId: 'org_1',
        assignedOrganizerName: 'Marshal Alpha',
      ),
      Checkpoint(
        id: 'cp_2',
        eventId: 'event_2024',
        name: 'CP2 — Canyon Pass',
        order: 2,
        description: 'Rocky canyon section midpoint',
        latitude: 31.5000,
        longitude: -4.2500,
        assignedOrganizerId: 'org_2',
        assignedOrganizerName: 'Marshal Bravo',
      ),
      Checkpoint(
        id: 'cp_3',
        eventId: 'event_2024',
        name: 'CP3 — Atlas Summit',
        order: 3,
        description: 'High altitude mountain checkpoint',
        latitude: 31.6500,
        longitude: -4.5000,
        assignedOrganizerId: 'org_3',
        assignedOrganizerName: 'Marshal Charlie',
      ),
      Checkpoint(
        id: 'cp_4',
        eventId: 'event_2024',
        name: 'CP4 — Desert Bivouac',
        order: 4,
        description: 'Central bivouac refuelling point',
        latitude: 31.8000,
        longitude: -4.7500,
        assignedOrganizerId: null,
        assignedOrganizerName: null,
      ),
      Checkpoint(
        id: 'cp_5',
        eventId: 'event_2024',
        name: 'FINISH — Merzouga',
        order: 5,
        description: 'Final finish line at Merzouga town',
        latitude: 31.1000,
        longitude: -3.9700,
        assignedOrganizerId: null,
        assignedOrganizerName: null,
      ),
    ];
    await LocalStorageService.instance.cacheCheckpoints(checkpoints);

    // Seed some passages for demo
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
        utcTime: now.subtract(const Duration(hours: 3, minutes: 12)).toUtc(),
        syncStatus: SyncStatus.synced,
      ),
      CheckpointPassage(
        id: 'pass_002_cp1',
        eventId: 'event_2024',
        checkpointId: 'cp_1',
        checkpointName: 'CP1 — Dune Gateway',
        participantId: 'p_002',
        participantName: 'Nasser Al-Attiyah',
        bibNumber: '002',
        localTime: now.subtract(const Duration(hours: 3, minutes: 5)),
        utcTime: now.subtract(const Duration(hours: 3, minutes: 5)).toUtc(),
        syncStatus: SyncStatus.synced,
      ),
      CheckpointPassage(
        id: 'pass_003_cp1',
        eventId: 'event_2024',
        checkpointId: 'cp_1',
        checkpointName: 'CP1 — Dune Gateway',
        participantId: 'p_003',
        participantName: 'Toby Price',
        bibNumber: '003',
        localTime: now.subtract(const Duration(hours: 2, minutes: 58)),
        utcTime: now.subtract(const Duration(hours: 2, minutes: 58)).toUtc(),
        syncStatus: SyncStatus.synced,
      ),
      CheckpointPassage(
        id: 'pass_001_cp2',
        eventId: 'event_2024',
        checkpointId: 'cp_2',
        checkpointName: 'CP2 — Canyon Pass',
        participantId: 'p_001',
        participantName: 'Carlos Sainz Jr.',
        bibNumber: '001',
        localTime: now.subtract(const Duration(hours: 1, minutes: 45)),
        utcTime: now.subtract(const Duration(hours: 1, minutes: 45)).toUtc(),
        syncStatus: SyncStatus.synced,
      ),
      CheckpointPassage(
        id: 'pass_002_cp2',
        eventId: 'event_2024',
        checkpointId: 'cp_2',
        checkpointName: 'CP2 — Canyon Pass',
        participantId: 'p_002',
        participantName: 'Nasser Al-Attiyah',
        bibNumber: '002',
        localTime: now.subtract(const Duration(hours: 1, minutes: 38)),
        utcTime: now.subtract(const Duration(hours: 1, minutes: 38)).toUtc(),
        syncStatus: SyncStatus.synced,
      ),
      CheckpointPassage(
        id: 'pass_004_cp1',
        eventId: 'event_2024',
        checkpointId: 'cp_1',
        checkpointName: 'CP1 — Dune Gateway',
        participantId: 'p_004',
        participantName: 'Adrien Van Beveren',
        bibNumber: '004',
        localTime: now.subtract(const Duration(hours: 2, minutes: 50)),
        utcTime: now.subtract(const Duration(hours: 2, minutes: 50)).toUtc(),
        syncStatus: SyncStatus.synced,
      ),
    ];

    for (final p in passages) {
      await LocalStorageService.instance.savePassageLocally(p);
    }
  }

  // ── Auth ──────────────────────────────────────────────────
  Future<AppUser?> signIn(String username, String password) async {
    await seedDemoDataIfNeeded();
    final users = await LocalStorageService.instance.getCachedUsers();
    final hash = hashPassword(password);
    try {
      return users.firstWhere(
        (u) => u.username == username && u.passwordHash == hash && u.isActive,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    await LocalStorageService.instance.clearCurrentUser();
  }

  // ── Users CRUD ────────────────────────────────────────────
  Future<List<AppUser>> getUsers() async {
    return LocalStorageService.instance.getCachedUsers();
  }

  Future<List<AppUser>> getParticipants() async {
    final users = await LocalStorageService.instance.getCachedUsers();
    return users.where((u) => u.role == UserRole.participant && u.isActive).toList();
  }

  Future<List<AppUser>> getOrganizers() async {
    final users = await LocalStorageService.instance.getCachedUsers();
    return users.where((u) => u.role == UserRole.organizer && u.isActive).toList();
  }

  Future<void> createUser(AppUser user) async {
    final users = await LocalStorageService.instance.getCachedUsers();
    users.add(user);
    await LocalStorageService.instance.cacheUsers(users);
  }

  Future<void> updateUser(AppUser user) async {
    final users = await LocalStorageService.instance.getCachedUsers();
    final idx = users.indexWhere((u) => u.id == user.id);
    if (idx >= 0) {
      users[idx] = user;
      await LocalStorageService.instance.cacheUsers(users);
    }
  }

  Future<void> deleteUser(String userId) async {
    final users = await LocalStorageService.instance.getCachedUsers();
    final updated = users.where((u) => u.id != userId).toList();
    await LocalStorageService.instance.cacheUsers(updated);
  }

  Future<AppUser?> getUserById(String id) async {
    final users = await LocalStorageService.instance.getCachedUsers();
    try {
      return users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Events CRUD ───────────────────────────────────────────
  Future<List<RallyEvent>> getEvents() async {
    return LocalStorageService.instance.getCachedEvents();
  }

  Future<RallyEvent?> getActiveEvent() async {
    return LocalStorageService.instance.getActiveEvent();
  }

  Future<void> createEvent(RallyEvent event) async {
    final resolved = _injectGpxBytes(event);
    final events = await LocalStorageService.instance.getCachedEvents();
    events.add(resolved);
    await LocalStorageService.instance.cacheEvents(events);
  }

  Future<void> updateEvent(RallyEvent event) async {
    final resolved = _injectGpxBytes(event);
    final events = await LocalStorageService.instance.getCachedEvents();
    final idx = events.indexWhere((e) => e.id == resolved.id);
    if (idx >= 0) {
      events[idx] = resolved;
      await LocalStorageService.instance.cacheEvents(events);
    }
  }

  Future<void> activateEvent(String eventId) async {
    final events = await LocalStorageService.instance.getCachedEvents();
    final updated = events.map((e) => e.copyWith(isActive: e.id == eventId)).toList();
    await LocalStorageService.instance.cacheEvents(updated);
  }

  Future<void> deleteEvent(String eventId) async {
    final events = await LocalStorageService.instance.getCachedEvents();
    final updated = events.where((e) => e.id != eventId).toList();
    await LocalStorageService.instance.cacheEvents(updated);
  }

  // ── Checkpoints CRUD ──────────────────────────────────────
  Future<List<Checkpoint>> getCheckpoints(String eventId) async {
    return LocalStorageService.instance.getCachedCheckpoints(eventId);
  }

  Future<void> createCheckpoint(Checkpoint checkpoint) async {
    final all = await _getAllCheckpoints();
    all.add(checkpoint);
    await LocalStorageService.instance.cacheCheckpoints(all);
  }

  Future<List<Checkpoint>> _getAllCheckpoints() async {
    final prefs = await SharedPreferencesHelper.getCheckpoints();
    return prefs;
  }

  Future<void> updateCheckpoint(Checkpoint checkpoint) async {
    final all = await _getAllCheckpoints();
    final idx = all.indexWhere((c) => c.id == checkpoint.id);
    if (idx >= 0) {
      all[idx] = checkpoint;
      await LocalStorageService.instance.cacheCheckpoints(all);
    }
  }

  Future<void> deleteCheckpoint(String checkpointId) async {
    final all = await _getAllCheckpoints();
    final updated = all.where((c) => c.id != checkpointId).toList();
    await LocalStorageService.instance.cacheCheckpoints(updated);
  }

  // ── Passages ──────────────────────────────────────────────
  Future<void> recordPassage(CheckpointPassage passage) async {
    await LocalStorageService.instance.savePassageLocally(passage);
    // In production: also write to Firestore
  }

  Future<CheckpointPassage?> findDuplicate(
      String participantId, String checkpointId, String eventId) async {
    return LocalStorageService.instance.findDuplicate(
        participantId, checkpointId, eventId);
  }

  Future<List<CheckpointPassage>> getPassagesForCheckpoint(
      String checkpointId, String eventId) async {
    return LocalStorageService.instance.getPassagesForCheckpoint(
        checkpointId, eventId);
  }

  Future<List<CheckpointPassage>> getPassagesForParticipant(
      String participantId, String eventId) async {
    return LocalStorageService.instance.getPassagesForParticipant(
        participantId, eventId);
  }

  Future<List<CheckpointPassage>> getAllPassagesForEvent(String eventId) async {
    final all = await LocalStorageService.instance.getAllLocalPassages();
    return all.where((p) => p.eventId == eventId).toList();
  }

  Future<int> getPendingCount() async {
    final pending = await LocalStorageService.instance.getPendingPassages();
    return pending.length;
  }

  Future<void> syncPendingPassages() async {
    final pending = await LocalStorageService.instance.getPendingPassages();
    // In production: push each to Firestore
    // For demo: just mark them synced
    for (final p in pending) {
      await LocalStorageService.instance.markPassageSynced(p.id);
    }
  }
}

// Helper to access all checkpoints regardless of event
class SharedPreferencesHelper {
  static Future<List<Checkpoint>> getCheckpoints() async {
    return LocalStorageService.instance.getCachedCheckpoints('');
  }
}

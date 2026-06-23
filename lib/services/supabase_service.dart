import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'local_storage_service.dart';

// ── Supabase client shorthand ─────────────────────────────
SupabaseClient get _sb => Supabase.instance.client;

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

/// Column name mappings: Dart field → Supabase column
/// AppUser  → app_users
/// RallyEvent → rally_events
/// Checkpoint → checkpoints
/// CheckpointPassage → checkpoint_passages

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance {
    _instance ??= SupabaseService._();
    return _instance!;
  }
  SupabaseService._();

  // ── Password Hashing ──────────────────────────────────────
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ── Seed check (one-time) ─────────────────────────────────
  Future<bool> _isSeeded() async {
    try {
      final res = await _sb
          .from('app_users')
          .select('id')
          .limit(1);
      return (res as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── Seed Demo Data ────────────────────────────────────────
  Future<void> seedDemoDataIfNeeded() async {
    if (await _isSeeded()) return;

    // ── 1. Users ──────────────────────────────────────────
    final usersData = [
      {
        'username': 'admin',
        'password_hash': hashPassword('admin123'),
        'role': 'superAdmin',
        'is_active': true,
        'full_name': 'Super Administrator',
      },
      {
        'username': 'marshal1',
        'password_hash': hashPassword('marshal123'),
        'role': 'organizer',
        'is_active': true,
        'full_name': 'Marshal Alpha',
      },
      {
        'username': 'marshal2',
        'password_hash': hashPassword('marshal123'),
        'role': 'organizer',
        'is_active': true,
        'full_name': 'Marshal Bravo',
      },
      {
        'username': 'marshal3',
        'password_hash': hashPassword('marshal123'),
        'role': 'organizer',
        'is_active': true,
        'full_name': 'Marshal Charlie',
      },
      {
        'username': 'rider001',
        'password_hash': hashPassword('rider123'),
        'role': 'participant',
        'is_active': true,
        'full_name': 'Carlos Sainz Jr.',
        'bike_brand': 'KTM',
        'bike_model': '450 EXC-F',
        'engine_size': 450,
        'bib_number': '001',
        'nationality': 'Spanish',
        'emergency_contact_name': 'Maria Sainz',
        'emergency_contact_phone': '+34 600 111 222',
      },
      {
        'username': 'rider002',
        'password_hash': hashPassword('rider123'),
        'role': 'participant',
        'is_active': true,
        'full_name': 'Nasser Al-Attiyah',
        'bike_brand': 'Husqvarna',
        'bike_model': 'FR 450 Rally',
        'engine_size': 450,
        'bib_number': '002',
        'nationality': 'Qatari',
        'emergency_contact_name': 'Fatima Al-Attiyah',
        'emergency_contact_phone': '+974 5555 1234',
      },
      {
        'username': 'rider003',
        'password_hash': hashPassword('rider123'),
        'role': 'participant',
        'is_active': true,
        'full_name': 'Toby Price',
        'bike_brand': 'KTM',
        'bike_model': '450 Rally',
        'engine_size': 450,
        'bib_number': '003',
        'nationality': 'Australian',
        'emergency_contact_name': 'Luke Price',
        'emergency_contact_phone': '+61 400 333 444',
      },
      {
        'username': 'rider004',
        'password_hash': hashPassword('rider123'),
        'role': 'participant',
        'is_active': true,
        'full_name': 'Adrien Van Beveren',
        'bike_brand': 'Honda',
        'bike_model': 'CRF450 Rally',
        'engine_size': 450,
        'bib_number': '004',
        'nationality': 'French',
        'emergency_contact_name': 'Claire Van Beveren',
        'emergency_contact_phone': '+33 6 00 44 55 66',
      },
      {
        'username': 'rider005',
        'password_hash': hashPassword('rider123'),
        'role': 'participant',
        'is_active': true,
        'full_name': 'Pablo Quintanilla',
        'bike_brand': 'GASGAS',
        'bike_model': 'RC 450F',
        'engine_size': 450,
        'bib_number': '005',
        'nationality': 'Chilean',
        'emergency_contact_name': 'Sofia Quintanilla',
        'emergency_contact_phone': '+56 9 1234 5678',
      },
    ];

    final insertedUsers = await _sb
        .from('app_users')
        .insert(usersData)
        .select('id, username, role');

    // Build username→id map for FK references
    final userIdMap = <String, String>{};
    for (final u in insertedUsers as List) {
      userIdMap[u['username'] as String] = u['id'] as String;
    }

    // ── 2. Event ──────────────────────────────────────────
    final insertedEvents = await _sb
        .from('rally_events')
        .insert({
          'name': 'RAID Sahara Challenge 2024',
          'date': '2024-10-15',
          'location': 'Erfoud, Morocco',
          'description':
              'The ultimate off-road rally across the Moroccan Sahara. '
              '5 stages, 800km of pure enduro challenge through dunes, '
              'rocky canyons and mountain passes.',
          'is_active': true,
        })
        .select('id')
        .single();

    final eventId = insertedEvents['id'] as String;

    // ── 3. Checkpoints ────────────────────────────────────
    final cpData = [
      {
        'event_id': eventId,
        'name': 'CP1 — Dune Gateway',
        'description': 'Start of the dune sector, Erg Chebbi entrance',
        'order_index': 1,
        'latitude': 31.3667,
        'longitude': -4.0000,
        'assigned_organizer_id': userIdMap['marshal1'],
      },
      {
        'event_id': eventId,
        'name': 'CP2 — Canyon Pass',
        'description': 'Rocky canyon section midpoint',
        'order_index': 2,
        'latitude': 31.5000,
        'longitude': -4.2500,
        'assigned_organizer_id': userIdMap['marshal2'],
      },
      {
        'event_id': eventId,
        'name': 'CP3 — Atlas Summit',
        'description': 'High altitude mountain checkpoint',
        'order_index': 3,
        'latitude': 31.6500,
        'longitude': -4.5000,
        'assigned_organizer_id': userIdMap['marshal3'],
      },
      {
        'event_id': eventId,
        'name': 'CP4 — Desert Bivouac',
        'description': 'Central bivouac refuelling point',
        'order_index': 4,
        'latitude': 31.8000,
        'longitude': -4.7500,
      },
      {
        'event_id': eventId,
        'name': 'FINISH — Merzouga',
        'description': 'Final finish line at Merzouga town',
        'order_index': 5,
        'latitude': 31.1000,
        'longitude': -3.9700,
      },
    ];

    final insertedCps = await _sb
        .from('checkpoints')
        .insert(cpData)
        .select('id, name, order_index');

    // Sort checkpoints by order_index
    final cpsSorted = List<Map<String, dynamic>>.from(
        (insertedCps as List).map((e) => Map<String, dynamic>.from(e)));
    cpsSorted.sort((a, b) =>
        (a['order_index'] as int).compareTo(b['order_index'] as int));

    final cp1Id = cpsSorted[0]['id'] as String;
    final cp2Id = cpsSorted[1]['id'] as String;

    // ── 4. Sample Passages ────────────────────────────────
    final now = DateTime.now().toUtc();
    final passagesData = [
      {
        'event_id': eventId,
        'checkpoint_id': cp1Id,
        'participant_id': userIdMap['rider001'],
        'participant_name': 'Carlos Sainz Jr.',
        'bib_number': '001',
        'local_time':
            now.subtract(const Duration(hours: 3, minutes: 12)).toIso8601String(),
        'sync_status': 'synced',
      },
      {
        'event_id': eventId,
        'checkpoint_id': cp1Id,
        'participant_id': userIdMap['rider002'],
        'participant_name': 'Nasser Al-Attiyah',
        'bib_number': '002',
        'local_time':
            now.subtract(const Duration(hours: 3, minutes: 5)).toIso8601String(),
        'sync_status': 'synced',
      },
      {
        'event_id': eventId,
        'checkpoint_id': cp1Id,
        'participant_id': userIdMap['rider003'],
        'participant_name': 'Toby Price',
        'bib_number': '003',
        'local_time':
            now.subtract(const Duration(hours: 2, minutes: 58)).toIso8601String(),
        'sync_status': 'synced',
      },
      {
        'event_id': eventId,
        'checkpoint_id': cp2Id,
        'participant_id': userIdMap['rider001'],
        'participant_name': 'Carlos Sainz Jr.',
        'bib_number': '001',
        'local_time':
            now.subtract(const Duration(hours: 1, minutes: 45)).toIso8601String(),
        'sync_status': 'synced',
      },
      {
        'event_id': eventId,
        'checkpoint_id': cp2Id,
        'participant_id': userIdMap['rider002'],
        'participant_name': 'Nasser Al-Attiyah',
        'bib_number': '002',
        'local_time':
            now.subtract(const Duration(hours: 1, minutes: 38)).toIso8601String(),
        'sync_status': 'synced',
      },
    ];

    await _sb.from('checkpoint_passages').insert(passagesData);

    // Update assigned_checkpoint_id on marshals
    if (userIdMap['marshal1'] != null) {
      await _sb
          .from('app_users')
          .update({'assigned_checkpoint_id': cp1Id})
          .eq('id', userIdMap['marshal1']!);
    }
    if (userIdMap['marshal2'] != null) {
      await _sb
          .from('app_users')
          .update({'assigned_checkpoint_id': cp2Id})
          .eq('id', userIdMap['marshal2']!);
    }
    if (userIdMap['marshal3'] != null && cpsSorted.length > 2) {
      await _sb
          .from('app_users')
          .update({'assigned_checkpoint_id': cpsSorted[2]['id'] as String})
          .eq('id', userIdMap['marshal3']!);
    }
  }

  // ── Auth ──────────────────────────────────────────────────
  Future<AppUser?> signIn(String username, String password) async {
    final hash = hashPassword(password);
    try {
      final res = await _sb
          .from('app_users')
          .select()
          .eq('username', username)
          .eq('password_hash', hash)
          .eq('is_active', true)
          .limit(1);
      if ((res as List).isEmpty) return null;
      return _userFromRow(res.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── Users CRUD ────────────────────────────────────────────
  Future<List<AppUser>> getUsers() async {
    final res = await _sb.from('app_users').select().order('created_at');
    return (res as List).map((r) => _userFromRow(r as Map<String, dynamic>)).toList();
  }

  Future<List<AppUser>> getParticipants() async {
    final res = await _sb
        .from('app_users')
        .select()
        .eq('role', 'participant')
        .eq('is_active', true)
        .order('bib_number');
    return (res as List).map((r) => _userFromRow(r as Map<String, dynamic>)).toList();
  }

  Future<List<AppUser>> getOrganizers() async {
    final res = await _sb
        .from('app_users')
        .select()
        .eq('role', 'organizer')
        .eq('is_active', true);
    return (res as List).map((r) => _userFromRow(r as Map<String, dynamic>)).toList();
  }

  Future<AppUser?> getUserById(String id) async {
    try {
      final res = await _sb.from('app_users').select().eq('id', id).single();
      return _userFromRow(res as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> createUser(AppUser user) async {
    await _sb.from('app_users').insert(_userToRow(user));
  }

  Future<void> updateUser(AppUser user) async {
    await _sb.from('app_users').update(_userToRow(user)).eq('id', user.id);
  }

  Future<void> deleteUser(String userId) async {
    await _sb.from('app_users').delete().eq('id', userId);
  }

  // ── Events CRUD ───────────────────────────────────────────
  Future<List<RallyEvent>> getEvents() async {
    final res = await _sb.from('rally_events').select().order('created_at', ascending: false);
    return (res as List).map((r) => _eventFromRow(r as Map<String, dynamic>)).toList();
  }

  Future<RallyEvent?> getActiveEvent() async {
    try {
      final res = await _sb
          .from('rally_events')
          .select()
          .eq('is_active', true)
          .limit(1);
      if ((res as List).isEmpty) return null;
      return _eventFromRow(res.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> createEvent(RallyEvent event) async {
    final resolved = _injectGpxBytes(event);
    await _sb.from('rally_events').insert(_eventToRow(resolved));
  }

  Future<void> updateEvent(RallyEvent event) async {
    final resolved = _injectGpxBytes(event);
    await _sb.from('rally_events').update(_eventToRow(resolved)).eq('id', resolved.id);
  }

  Future<void> activateEvent(String eventId) async {
    // Deactivate all first, then activate the target
    await _sb.from('rally_events').update({'is_active': false});
    await _sb.from('rally_events').update({'is_active': true}).eq('id', eventId);
  }

  Future<void> deleteEvent(String eventId) async {
    await _sb.from('rally_events').delete().eq('id', eventId);
  }

  // ── Checkpoints CRUD ──────────────────────────────────────
  Future<List<Checkpoint>> getCheckpoints(String eventId) async {
    final res = await _sb
        .from('checkpoints')
        .select()
        .eq('event_id', eventId)
        .order('order_index');
    return (res as List).map((r) => _checkpointFromRow(r as Map<String, dynamic>)).toList();
  }

  Future<void> createCheckpoint(Checkpoint checkpoint) async {
    await _sb.from('checkpoints').insert(_checkpointToRow(checkpoint));
  }

  Future<void> updateCheckpoint(Checkpoint checkpoint) async {
    await _sb.from('checkpoints').update(_checkpointToRow(checkpoint)).eq('id', checkpoint.id);
  }

  Future<void> deleteCheckpoint(String checkpointId) async {
    await _sb.from('checkpoints').delete().eq('id', checkpointId);
  }

  // ── Passages ──────────────────────────────────────────────
  Future<void> recordPassage(CheckpointPassage passage) async {
    // Save locally for offline resilience
    await LocalStorageService.instance.savePassageLocally(passage);
    // Write to Supabase (ignore duplicate error: unique constraint)
    try {
      await _sb.from('checkpoint_passages').insert({
        'id': passage.id,
        'event_id': passage.eventId,
        'checkpoint_id': passage.checkpointId,
        'participant_id': passage.participantId,
        'participant_name': passage.participantName,
        'bib_number': passage.bibNumber,
        'local_time': passage.localTime.toIso8601String(),
        'sync_status': 'synced',
      });
      await LocalStorageService.instance.markPassageSynced(passage.id);
    } catch (_) {
      // Will be synced later
    }
  }

  Future<CheckpointPassage?> findDuplicate(
      String participantId, String checkpointId, String eventId) async {
    // Check locally first (faster)
    final localDup = await LocalStorageService.instance
        .findDuplicate(participantId, checkpointId, eventId);
    if (localDup != null) return localDup;
    // Then Supabase
    try {
      final res = await _sb
          .from('checkpoint_passages')
          .select()
          .eq('participant_id', participantId)
          .eq('checkpoint_id', checkpointId)
          .eq('event_id', eventId)
          .limit(1);
      if ((res as List).isEmpty) return null;
      return _passageFromRow(res.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<CheckpointPassage>> getPassagesForCheckpoint(
      String checkpointId, String eventId) async {
    try {
      final res = await _sb
          .from('checkpoint_passages')
          .select()
          .eq('checkpoint_id', checkpointId)
          .eq('event_id', eventId);
      final list = (res as List)
          .map((r) => _passageFromRow(r as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.localTime.compareTo(a.localTime));
      return list;
    } catch (_) {
      // Fallback to local
      return LocalStorageService.instance.getPassagesForCheckpoint(checkpointId, eventId);
    }
  }

  Future<List<CheckpointPassage>> getPassagesForParticipant(
      String participantId, String eventId) async {
    try {
      final res = await _sb
          .from('checkpoint_passages')
          .select()
          .eq('participant_id', participantId)
          .eq('event_id', eventId);
      final list = (res as List)
          .map((r) => _passageFromRow(r as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => a.localTime.compareTo(b.localTime));
      return list;
    } catch (_) {
      return LocalStorageService.instance.getPassagesForParticipant(participantId, eventId);
    }
  }

  Future<List<CheckpointPassage>> getAllPassagesForEvent(String eventId) async {
    try {
      final res = await _sb
          .from('checkpoint_passages')
          .select()
          .eq('event_id', eventId);
      return (res as List)
          .map((r) => _passageFromRow(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final local = await LocalStorageService.instance.getAllLocalPassages();
      return local.where((p) => p.eventId == eventId).toList();
    }
  }

  Future<int> getPendingCount() async {
    final pending = await LocalStorageService.instance.getPendingPassages();
    return pending.length;
  }

  Future<void> syncPendingPassages() async {
    final pending = await LocalStorageService.instance.getPendingPassages();
    for (final p in pending) {
      try {
        await _sb.from('checkpoint_passages').insert({
          'id': p.id,
          'event_id': p.eventId,
          'checkpoint_id': p.checkpointId,
          'participant_id': p.participantId,
          'participant_name': p.participantName,
          'bib_number': p.bibNumber,
          'local_time': p.localTime.toIso8601String(),
          'sync_status': 'synced',
        });
        await LocalStorageService.instance.markPassageSynced(p.id);
      } catch (_) {
        // Already synced or duplicate — mark locally anyway
        await LocalStorageService.instance.markPassageSynced(p.id);
      }
    }
  }

  // ── App Settings ──────────────────────────────────────────
  Future<String?> getSetting(String key) async {
    try {
      final res = await _sb
          .from('app_settings')
          .select('value')
          .eq('key', key)
          .single();
      return res['value'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> setSetting(String key, String value) async {
    await _sb.from('app_settings').upsert({'key': key, 'value': value});
  }

  // ── Row Mappers ───────────────────────────────────────────

  AppUser _userFromRow(Map<String, dynamic> r) {
    return AppUser(
      id: r['id'] as String,
      username: r['username'] as String,
      passwordHash: r['password_hash'] as String,
      role: UserRole.values.firstWhere(
        (v) => v.name == (r['role'] as String),
        orElse: () => UserRole.participant,
      ),
      isActive: r['is_active'] as bool? ?? true,
      assignedCheckpointId: r['assigned_checkpoint_id'] as String?,
      fullName: r['full_name'] as String?,
      bikeBrand: r['bike_brand'] as String?,
      bikeModel: r['bike_model'] as String?,
      engineSize: r['engine_size'] as int?,
      bibNumber: r['bib_number'] as String?,
      nationality: r['nationality'] as String?,
      emergencyContactName: r['emergency_contact_name'] as String?,
      emergencyContactPhone: r['emergency_contact_phone'] as String?,
    );
  }

  Map<String, dynamic> _userToRow(AppUser u) {
    return {
      'username': u.username,
      'password_hash': u.passwordHash,
      'role': u.role.name,
      'is_active': u.isActive,
      'assigned_checkpoint_id': u.assignedCheckpointId,
      'full_name': u.fullName,
      'bike_brand': u.bikeBrand,
      'bike_model': u.bikeModel,
      'engine_size': u.engineSize,
      'bib_number': u.bibNumber,
      'nationality': u.nationality,
      'emergency_contact_name': u.emergencyContactName,
      'emergency_contact_phone': u.emergencyContactPhone,
    };
  }

  RallyEvent _eventFromRow(Map<String, dynamic> r) {
    return RallyEvent(
      id: r['id'] as String,
      name: r['name'] as String,
      date: DateTime.tryParse(r['date'] as String? ?? '') ?? DateTime.now(),
      location: r['location'] as String,
      description: r['description'] as String? ?? '',
      isActive: r['is_active'] as bool? ?? false,
      gpxFileUrl: r['gpx_file_url'] as String?,
      gpxFileName: r['gpx_file_name'] as String?,
      createdAt:
          DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> _eventToRow(RallyEvent e) {
    return {
      'name': e.name,
      'date': e.date.toIso8601String().split('T').first, // DATE only
      'location': e.location,
      'description': e.description,
      'is_active': e.isActive,
      'gpx_file_url': e.gpxFileUrl,
      'gpx_file_name': e.gpxFileName,
    };
  }

  Checkpoint _checkpointFromRow(Map<String, dynamic> r) {
    return Checkpoint(
      id: r['id'] as String,
      eventId: r['event_id'] as String,
      name: r['name'] as String,
      order: r['order_index'] as int? ?? 0,
      description: r['description'] as String?,
      latitude: (r['latitude'] as num?)?.toDouble(),
      longitude: (r['longitude'] as num?)?.toDouble(),
      assignedOrganizerId: r['assigned_organizer_id'] as String?,
      assignedOrganizerName: null, // not stored in DB, resolved separately
    );
  }

  Map<String, dynamic> _checkpointToRow(Checkpoint c) {
    return {
      'event_id': c.eventId,
      'name': c.name,
      'description': c.description,
      'order_index': c.order,
      'latitude': c.latitude,
      'longitude': c.longitude,
      'assigned_organizer_id': c.assignedOrganizerId,
    };
  }

  CheckpointPassage _passageFromRow(Map<String, dynamic> r) {
    final localTime = DateTime.tryParse(r['local_time'] as String? ?? '') ??
        DateTime.now();
    return CheckpointPassage(
      id: r['id'] as String,
      eventId: r['event_id'] as String,
      checkpointId: r['checkpoint_id'] as String,
      checkpointName: r['checkpoint_name'] as String? ?? '',
      participantId: r['participant_id'] as String,
      participantName: r['participant_name'] as String,
      bibNumber: r['bib_number'] as String,
      localTime: localTime,
      utcTime: localTime.toUtc(),
      syncStatus: SyncStatus.values.firstWhere(
        (s) => s.name == (r['sync_status'] as String? ?? 'synced'),
        orElse: () => SyncStatus.synced,
      ),
    );
  }
}

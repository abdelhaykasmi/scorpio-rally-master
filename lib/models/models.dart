// ============================================================
// DATA MODELS
// ============================================================

enum UserRole { participant, organizer, superAdmin }

enum SyncStatus { synced, pending, error }

class AppUser {
  final String id;
  final String username;
  final String passwordHash;
  final UserRole role;
  final bool isActive;
  final String? assignedCheckpointId; // for organizer
  // Participant profile fields
  final String? fullName;
  final String? bikeBrand;
  final String? bikeModel;
  final int? engineSize;
  final String? bibNumber;
  final String? nationality;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  AppUser({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    this.isActive = true,
    this.assignedCheckpointId,
    this.fullName,
    this.bikeBrand,
    this.bikeModel,
    this.engineSize,
    this.bibNumber,
    this.nationality,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    return AppUser(
      id: id,
      username: map['username'] ?? '',
      passwordHash: map['passwordHash'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == (map['role'] ?? 'participant'),
        orElse: () => UserRole.participant,
      ),
      isActive: map['isActive'] ?? true,
      assignedCheckpointId: map['assignedCheckpointId'],
      fullName: map['fullName'],
      bikeBrand: map['bikeBrand'],
      bikeModel: map['bikeModel'],
      engineSize: map['engineSize'],
      bibNumber: map['bibNumber'],
      nationality: map['nationality'],
      emergencyContactName: map['emergencyContactName'],
      emergencyContactPhone: map['emergencyContactPhone'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'passwordHash': passwordHash,
      'role': role.name,
      'isActive': isActive,
      'assignedCheckpointId': assignedCheckpointId,
      'fullName': fullName,
      'bikeBrand': bikeBrand,
      'bikeModel': bikeModel,
      'engineSize': engineSize,
      'bibNumber': bibNumber,
      'nationality': nationality,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
    };
  }

  AppUser copyWith({
    String? id,
    String? username,
    String? passwordHash,
    UserRole? role,
    bool? isActive,
    String? assignedCheckpointId,
    String? fullName,
    String? bikeBrand,
    String? bikeModel,
    int? engineSize,
    String? bibNumber,
    String? nationality,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      assignedCheckpointId: assignedCheckpointId ?? this.assignedCheckpointId,
      fullName: fullName ?? this.fullName,
      bikeBrand: bikeBrand ?? this.bikeBrand,
      bikeModel: bikeModel ?? this.bikeModel,
      engineSize: engineSize ?? this.engineSize,
      bibNumber: bibNumber ?? this.bibNumber,
      nationality: nationality ?? this.nationality,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
    );
  }
}

class RallyEvent {
  final String id;
  final String name;
  final DateTime date;
  final String location;
  final String description;
  final bool isActive;
  final String? gpxFileUrl;    // stored URL / base64 key after save
  final String? gpxFileName;   // display name
  final List<int>? gpxBytes;   // transient: raw bytes from FilePicker (not persisted directly)
  final String? logoUrl;
  final String primaryColor;
  final String secondaryColor;
  final DateTime createdAt;

  RallyEvent({
    required this.id,
    required this.name,
    required this.date,
    required this.location,
    required this.description,
    this.isActive = false,
    this.gpxFileUrl,
    this.gpxFileName,
    this.gpxBytes,
    this.logoUrl,
    this.primaryColor = 'E53935',
    this.secondaryColor = 'B71C1C',
    required this.createdAt,
  });

  factory RallyEvent.fromMap(Map<String, dynamic> map, String id) {
    return RallyEvent(
      id: id,
      name: map['name'] ?? '',
      date: map['date'] != null
          ? (map['date'] is DateTime
              ? map['date']
              : DateTime.tryParse(map['date'].toString()) ?? DateTime.now())
          : DateTime.now(),
      location: map['location'] ?? '',
      description: map['description'] ?? '',
      isActive: map['isActive'] ?? false,
      gpxFileUrl: map['gpxFileUrl'],
      gpxFileName: map['gpxFileName'],
      logoUrl: map['logoUrl'],
      primaryColor: map['primaryColor'] ?? 'E53935',
      secondaryColor: map['secondaryColor'] ?? 'B71C1C',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is DateTime
              ? map['createdAt']
              : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'date': date.toIso8601String(),
      'location': location,
      'description': description,
      'isActive': isActive,
      'gpxFileUrl': gpxFileUrl,
      'gpxFileName': gpxFileName,
      'logoUrl': logoUrl,
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  RallyEvent copyWith({
    String? id,
    String? name,
    DateTime? date,
    String? location,
    String? description,
    bool? isActive,
    String? gpxFileUrl,
    String? gpxFileName,
    List<int>? gpxBytes,
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
  }) {
    return RallyEvent(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      location: location ?? this.location,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      gpxFileUrl: gpxFileUrl ?? this.gpxFileUrl,
      gpxFileName: gpxFileName ?? this.gpxFileName,
      gpxBytes: gpxBytes ?? this.gpxBytes,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      createdAt: createdAt,
    );
  }
}

class Checkpoint {
  final String id;
  final String eventId;
  final String name;
  final int order;
  final String? description;
  final double? latitude;
  final double? longitude;
  final String? assignedOrganizerId;
  final String? assignedOrganizerName;

  Checkpoint({
    required this.id,
    required this.eventId,
    required this.name,
    required this.order,
    this.description,
    this.latitude,
    this.longitude,
    this.assignedOrganizerId,
    this.assignedOrganizerName,
  });

  factory Checkpoint.fromMap(Map<String, dynamic> map, String id) {
    return Checkpoint(
      id: id,
      eventId: map['eventId'] ?? '',
      name: map['name'] ?? '',
      order: map['order'] ?? 0,
      description: map['description'],
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      assignedOrganizerId: map['assignedOrganizerId'],
      assignedOrganizerName: map['assignedOrganizerName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'name': name,
      'order': order,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'assignedOrganizerId': assignedOrganizerId,
      'assignedOrganizerName': assignedOrganizerName,
    };
  }

  Checkpoint copyWith({
    String? id,
    String? eventId,
    String? name,
    int? order,
    String? description,
    double? latitude,
    double? longitude,
    String? assignedOrganizerId,
    String? assignedOrganizerName,
  }) {
    return Checkpoint(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      name: name ?? this.name,
      order: order ?? this.order,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      assignedOrganizerId: assignedOrganizerId ?? this.assignedOrganizerId,
      assignedOrganizerName: assignedOrganizerName ?? this.assignedOrganizerName,
    );
  }
}

class CheckpointPassage {
  final String id;
  final String eventId;
  final String checkpointId;
  final String checkpointName;
  final String participantId;
  final String participantName;
  final String bibNumber;
  final DateTime localTime;
  final DateTime utcTime;
  final SyncStatus syncStatus;
  final String? deviceId;

  CheckpointPassage({
    required this.id,
    required this.eventId,
    required this.checkpointId,
    required this.checkpointName,
    required this.participantId,
    required this.participantName,
    required this.bibNumber,
    required this.localTime,
    required this.utcTime,
    this.syncStatus = SyncStatus.pending,
    this.deviceId,
  });

  factory CheckpointPassage.fromMap(Map<String, dynamic> map, String id) {
    return CheckpointPassage(
      id: id,
      eventId: map['eventId'] ?? '',
      checkpointId: map['checkpointId'] ?? '',
      checkpointName: map['checkpointName'] ?? '',
      participantId: map['participantId'] ?? '',
      participantName: map['participantName'] ?? '',
      bibNumber: map['bibNumber'] ?? '',
      localTime: map['localTime'] != null
          ? DateTime.tryParse(map['localTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      utcTime: map['utcTime'] != null
          ? DateTime.tryParse(map['utcTime'].toString()) ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      syncStatus: SyncStatus.values.firstWhere(
        (s) => s.name == (map['syncStatus'] ?? 'synced'),
        orElse: () => SyncStatus.synced,
      ),
      deviceId: map['deviceId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'checkpointId': checkpointId,
      'checkpointName': checkpointName,
      'participantId': participantId,
      'participantName': participantName,
      'bibNumber': bibNumber,
      'localTime': localTime.toIso8601String(),
      'utcTime': utcTime.toIso8601String(),
      'syncStatus': syncStatus.name,
      'deviceId': deviceId,
    };
  }

  CheckpointPassage copyWith({SyncStatus? syncStatus}) {
    return CheckpointPassage(
      id: id,
      eventId: eventId,
      checkpointId: checkpointId,
      checkpointName: checkpointName,
      participantId: participantId,
      participantName: participantName,
      bibNumber: bibNumber,
      localTime: localTime,
      utcTime: utcTime,
      syncStatus: syncStatus ?? this.syncStatus,
      deviceId: deviceId,
    );
  }
}

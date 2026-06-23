import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/app_settings_provider.dart';
import '../../services/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/qr_helper.dart';
import '../../widgets/common_widgets.dart';
import 'qr_scanner_screen.dart';

class OrganizerHome extends StatefulWidget {
  const OrganizerHome({super.key});

  @override
  State<OrganizerHome> createState() => _OrganizerHomeState();
}

class _OrganizerHomeState extends State<OrganizerHome> {
  int _currentIndex = 0;
  Checkpoint? _checkpoint;
  RallyEvent? _event;
  bool _isSyncing = false;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = context.read<AuthProvider>().currentUser;
    final event = await SupabaseService.instance.getActiveEvent();
    if (user?.assignedCheckpointId != null && event != null) {
      final checkpoints =
          await SupabaseService.instance.getCheckpoints(event.id);
      Checkpoint? cp;
      try {
        cp = checkpoints
            .firstWhere((c) => c.id == user!.assignedCheckpointId);
      } catch (_) {}
      final pending = await SupabaseService.instance.getPendingCount();
      if (mounted) {
        setState(() {
          _checkpoint = cp;
          _event = event;
          _pendingCount = pending;
        });
      }
    }
  }

  Future<void> _sync() async {
    setState(() => _isSyncing = true);
    await SupabaseService.instance.syncPendingPassages();
    final pending = await SupabaseService.instance.getPendingCount();
    setState(() {
      _isSyncing = false;
      _pendingCount = pending;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync complete — all records uploaded'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _DashboardTab(
            checkpoint: _checkpoint,
            event: _event,
            pendingCount: _pendingCount,
            isSyncing: _isSyncing,
            onSync: _sync,
            onRefresh: _loadData,
          ),
          _ScannerTab(
            checkpoint: _checkpoint,
            event: _event,
            onPassageRecorded: () {
              _loadData();
            },
          ),
          _LeaderboardTab(event: _event),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.qr_code_scanner),
                  if (_pendingCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$_pendingCount',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Scanner',
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
          ],
        ),
      ),
    );
  }
}

// ── Dashboard Tab ─────────────────────────────────────────
class _DashboardTab extends StatefulWidget {
  final Checkpoint? checkpoint;
  final RallyEvent? event;
  final int pendingCount;
  final bool isSyncing;
  final VoidCallback onSync;
  final VoidCallback onRefresh;

  const _DashboardTab({
    required this.checkpoint,
    required this.event,
    required this.pendingCount,
    required this.isSyncing,
    required this.onSync,
    required this.onRefresh,
  });

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  List<CheckpointPassage> _passages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _DashboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checkpoint?.id != oldWidget.checkpoint?.id) _load();
  }

  Future<void> _load() async {
    if (widget.checkpoint != null && widget.event != null) {
      final passages = await SupabaseService.instance.getPassagesForCheckpoint(
          widget.checkpoint!.id, widget.event!.id);
      if (mounted) setState(() {
        _passages = passages;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final fs = context.watch<AppSettingsProvider>().fontScaleOrganizer;
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(user, fs),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                widget.onRefresh();
                await _load();
              },
              color: AppColors.accent,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSyncCard(),
                  const SizedBox(height: 16),
                  _buildCheckpointCard(),
                  const SizedBox(height: 16),
                  _buildPassageStats(),
                  const SizedBox(height: 16),
                  const SectionHeader(
                      title: 'Passages Today',
                      padding: EdgeInsets.zero),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.accent))
                  else if (_passages.isEmpty)
                    const EmptyState(
                      icon: Icons.qr_code_scanner,
                      title: 'No passages yet',
                      subtitle: 'Scan a participant QR code to begin recording',
                    )
                  else
                    ..._passages.map((p) => _buildPassageRow(p)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppUser? user, double fs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield, color: AppColors.accent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CHECKPOINT MARSHAL',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15 * fs,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    )),
                Text(user?.fullName ?? '',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 11 * fs)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textMuted, size: 20),
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.pendingCount == 0
            ? AppColors.success.withValues(alpha: 0.08)
            : AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.pendingCount == 0
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            widget.pendingCount == 0 ? Icons.cloud_done : Icons.cloud_off,
            color: widget.pendingCount == 0
                ? AppColors.success
                : AppColors.error,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Builder(builder: (ctx) {
              final fs = ctx.watch<AppSettingsProvider>().fontScaleOrganizer;
              return Text(
                widget.pendingCount == 0
                    ? 'All records synced'
                    : '${widget.pendingCount} record(s) pending sync',
                style: TextStyle(
                  color: widget.pendingCount == 0
                      ? AppColors.success
                      : AppColors.error,
                  fontWeight: FontWeight.w700,
                  fontSize: 13 * fs,
                ),
              );
            }),
          ),
          ElevatedButton.icon(
            onPressed: widget.isSyncing ? null : widget.onSync,
            icon: widget.isSyncing
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.sync, size: 14),
            label: const Text('SYNC', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckpointCard() {
    if (widget.checkpoint == null) {
      return const CarbonCard(
        child: EmptyState(
          icon: Icons.location_off,
          title: 'No checkpoint assigned',
          subtitle: 'Contact the admin to get your checkpoint assigned',
        ),
      );
    }
    final cp = widget.checkpoint!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.flag, color: Colors.white70, size: 14),
            const SizedBox(width: 6),
            const Text('YOUR CHECKPOINT',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
          ]),
          const SizedBox(height: 10),
          Builder(builder: (ctx) {
            final fs = ctx.watch<AppSettingsProvider>().fontScaleOrganizer;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cp.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20 * fs,
                      fontWeight: FontWeight.w900,
                    )),
                if (cp.description != null)
                  Text(cp.description!,
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12 * fs)),
                if (cp.latitude != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      const Icon(Icons.location_on,
                          color: Colors.white70, size: 12),
                      const SizedBox(width: 4),
                      Text(
                          '${cp.latitude!.toStringAsFixed(4)}, ${cp.longitude!.toStringAsFixed(4)}',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 11 * fs)),
                    ]),
                  ),
                const SizedBox(height: 10),
                Text(widget.event?.name ?? '',
                    style: TextStyle(
                        color: Colors.white60, fontSize: 11 * fs)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPassageStats() {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'Passages Today',
            value: '${_passages.length}',
            icon: Icons.check_circle,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            label: 'Pending Sync',
            value: '${widget.pendingCount}',
            icon: Icons.cloud_off,
            color: widget.pendingCount > 0
                ? AppColors.error
                : AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildPassageRow(CheckpointPassage p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.15),
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                p.bibNumber,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Builder(builder: (ctx) {
              final fs = ctx.watch<AppSettingsProvider>().fontScaleOrganizer;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.participantName,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14 * fs,
                      )),
                  Text(
                    DateFormat('HH:mm:ss · dd MMM').format(p.localTime),
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12 * fs),
                  ),
                ],
              );
            }),
          ),
          Icon(
            p.syncStatus == SyncStatus.synced
                ? Icons.cloud_done
                : Icons.cloud_upload,
            color: p.syncStatus == SyncStatus.synced
                ? AppColors.success
                : AppColors.warning,
            size: 18,
          ),
        ],
      ),
    );
  }
}

// ── Scanner Tab ───────────────────────────────────────────
class _ScannerTab extends StatefulWidget {
  final Checkpoint? checkpoint;
  final RallyEvent? event;
  final VoidCallback onPassageRecorded;

  const _ScannerTab({
    required this.checkpoint,
    required this.event,
    required this.onPassageRecorded,
  });

  @override
  State<_ScannerTab> createState() => _ScannerTabState();
}

class _ScannerTabState extends State<_ScannerTab> {
  void _openScanner() {
    if (widget.checkpoint == null || widget.event == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No checkpoint assigned. Contact admin.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QRScannerScreen(
          checkpoint: widget.checkpoint!,
          event: widget.event!,
          onPassageRecorded: () {
            widget.onPassageRecorded();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                Icon(Icons.qr_code_scanner, color: AppColors.accent, size: 24),
                SizedBox(width: 12),
                Text('QR SCANNER',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    )),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withValues(alpha: 0.1),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.4),
                          width: 2),
                    ),
                    child: const Icon(Icons.qr_code_scanner,
                        size: 80, color: AppColors.accent),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    widget.checkpoint?.name ?? 'No checkpoint assigned',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the button below to scan\na participant QR code',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 14, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 56,
                    width: 240,
                    child: ElevatedButton.icon(
                      onPressed: _openScanner,
                      icon: const Icon(Icons.camera_alt, size: 22),
                      label: const Text('OPEN SCANNER',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'All passages are stored locally\nand synced when online',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Leaderboard Tab ───────────────────────────────────────
class _LeaderboardTab extends StatefulWidget {
  final RallyEvent? event;
  const _LeaderboardTab({required this.event});

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  List<_LeaderEntry> _entries = [];
  List<Checkpoint> _checkpoints = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.event == null) {
      setState(() => _loading = false);
      return;
    }
    final participants = await SupabaseService.instance.getParticipants();
    final checkpoints =
        await SupabaseService.instance.getCheckpoints(widget.event!.id);
    final passages = await SupabaseService.instance
        .getAllPassagesForEvent(widget.event!.id);

    final entries = <_LeaderEntry>[];
    for (final p in participants) {
      final times = <String, DateTime>{};
      for (final cp in checkpoints) {
        final pass = passages.where(
          (pp) => pp.participantId == p.id && pp.checkpointId == cp.id,
        ).firstOrNull;
        if (pass != null) times[cp.id] = pass.localTime;
      }
      final first = checkpoints.isNotEmpty ? times[checkpoints.first.id] : null;
      final last = times.isNotEmpty
          ? times.values.reduce((a, b) => a.isAfter(b) ? a : b)
          : null;
      entries.add(_LeaderEntry(
        participant: p,
        times: times,
        checkpointsCount: times.length,
        totalTime: first != null && last != null ? last.difference(first) : null,
      ));
    }
    entries.sort((a, b) {
      if (a.totalTime == null && b.totalTime == null) return 0;
      if (a.totalTime == null) return 1;
      if (b.totalTime == null) return -1;
      return a.totalTime!.compareTo(b.totalTime!);
    });

    setState(() {
      _entries = entries;
      _checkpoints = checkpoints;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.leaderboard, color: AppColors.accent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(builder: (ctx) {
                    final fs = ctx.watch<AppSettingsProvider>().fontScaleOrganizer;
                    return Text('LEADERBOARD',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16 * fs,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ));
                  }),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.textMuted),
                  onPressed: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_entries.isEmpty) {
      return const EmptyState(
          icon: Icons.leaderboard, title: 'No data yet');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _entries.length,
      itemBuilder: (context, i) {
        final e = _entries[i];
        final rank = i + 1;
        Color rankColor = AppColors.textMuted;
        if (rank == 1) rankColor = const Color(0xFFFFD700);
        if (rank == 2) rankColor = const Color(0xFFC0C0C0);
        if (rank == 3) rankColor = const Color(0xFFCD7F32);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: rank <= 3
                ? rankColor.withValues(alpha: 0.06)
                : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: rank <= 3
                  ? rankColor.withValues(alpha: 0.3)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  rank == 1
                      ? '🥇'
                      : rank == 2
                          ? '🥈'
                          : rank == 3
                              ? '🥉'
                              : '$rank',
                  style: TextStyle(
                    color: rankColor,
                    fontSize: rank <= 3 ? 22 : 16,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.15),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: Center(
                  child: Text(
                    e.participant.bibNumber ?? '#',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(builder: (ctx) {
                      final fs = ctx.watch<AppSettingsProvider>().fontScaleOrganizer;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.participant.fullName ?? e.participant.username,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14 * fs,
                              )),
                          Text(
                            '${e.participant.bikeBrand ?? ''} ${e.participant.bikeModel ?? ''} · ${e.checkpointsCount}/${_checkpoints.length} CPs',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 11 * fs),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    e.totalTime != null
                        ? QRHelper.formatDuration(e.totalTime!)
                        : '—',
                    style: TextStyle(
                      color: rank <= 3 ? rankColor : AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const Text('elapsed',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeaderEntry {
  final AppUser participant;
  final Map<String, DateTime> times;
  final int checkpointsCount;
  final Duration? totalTime;

  _LeaderEntry({
    required this.participant,
    required this.times,
    required this.checkpointsCount,
    required this.totalTime,
  });
}

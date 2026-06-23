import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/qr_helper.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<_Entry> _entries = [];
  List<Checkpoint> _checkpoints = [];
  RallyEvent? _event;
  bool _loading = true;
  String _sortBy = 'total'; // 'total' | 'bib' | 'cp_{id}'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final event = await FirebaseService.instance.getActiveEvent();
    if (event == null) {
      setState(() => _loading = false);
      return;
    }
    final participants = await FirebaseService.instance.getParticipants();
    final checkpoints = await FirebaseService.instance.getCheckpoints(event.id);
    final passages =
        await FirebaseService.instance.getAllPassagesForEvent(event.id);

    final entries = participants.map((p) {
      final times = <String, DateTime>{};
      for (final cp in checkpoints) {
        final pass = passages
            .where((pp) =>
                pp.participantId == p.id && pp.checkpointId == cp.id)
            .firstOrNull;
        if (pass != null) times[cp.id] = pass.localTime;
      }
      final first =
          checkpoints.isNotEmpty ? times[checkpoints.first.id] : null;
      final last = times.isNotEmpty
          ? times.values.reduce((a, b) => a.isAfter(b) ? a : b)
          : null;

      final stageTimes = <Duration?>[];
      for (int i = 1; i < checkpoints.length; i++) {
        final t1 = times[checkpoints[i - 1].id];
        final t2 = times[checkpoints[i].id];
        stageTimes
            .add(t1 != null && t2 != null ? t2.difference(t1) : null);
      }

      return _Entry(
        participant: p,
        times: times,
        stageTimes: stageTimes,
        totalTime:
            first != null && last != null ? last.difference(first) : null,
      );
    }).toList();

    _sortEntries(entries);

    setState(() {
      _entries = entries;
      _checkpoints = checkpoints;
      _event = event;
      _loading = false;
    });
  }

  void _sortEntries(List<_Entry> entries) {
    if (_sortBy == 'total') {
      entries.sort((a, b) {
        if (a.totalTime == null && b.totalTime == null) return 0;
        if (a.totalTime == null) return 1;
        if (b.totalTime == null) return -1;
        return a.totalTime!.compareTo(b.totalTime!);
      });
    } else if (_sortBy == 'bib') {
      entries.sort((a, b) => (a.participant.bibNumber ?? '')
          .compareTo(b.participant.bibNumber ?? ''));
    }
  }

  void _resort(String by) {
    setState(() {
      _sortBy = by;
      _sortEntries(_entries);
    });
  }

  void _export() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Leaderboard export ready'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          if (!_loading && _event != null) _buildSortBar(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : _event == null
                    ? const EmptyState(
                        icon: Icons.event_busy, title: 'No active event')
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.leaderboard, color: AppColors.accent, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('LEADERBOARD',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                )),
          ),
          IconButton(
            icon: const Icon(Icons.download, color: AppColors.textMuted),
            onPressed: _export,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textMuted),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.surface.withValues(alpha: 0.5),
      child: Row(
        children: [
          const Text('SORT BY:',
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(width: 10),
          _sortChip('Total Time', 'total'),
          const SizedBox(width: 6),
          _sortChip('Bib #', 'bib'),
        ],
      ),
    );
  }

  Widget _sortChip(String label, String key) {
    final sel = _sortBy == key;
    return GestureDetector(
      onTap: () => _resort(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel
              ? AppColors.accent.withValues(alpha: 0.2)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: sel
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? AppColors.accent : AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildContent() {
    if (_entries.isEmpty) {
      return const EmptyState(icon: Icons.people, title: 'No participants');
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Top 3 podium
          if (_entries.length >= 3) _buildPodium(),
          const SizedBox(height: 16),
          // Full table
          ..._entries.asMap().entries.map((e) {
            final rank = e.key + 1;
            final entry = e.value;
            return _buildRow(rank, entry);
          }),
        ],
      ),
    );
  }

  Widget _buildPodium() {
    final top3 = _entries.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events, color: AppColors.accent, size: 16),
              SizedBox(width: 6),
              Text('TOP 3 — PODIUM',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (top3.length > 1) Expanded(child: _podiumBlock(2, top3[1], 70)),
              if (top3.isNotEmpty)
                Expanded(child: _podiumBlock(1, top3[0], 90)),
              if (top3.length > 2) Expanded(child: _podiumBlock(3, top3[2], 50)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _podiumBlock(int rank, _Entry entry, double height) {
    const colors = {1: Color(0xFFFFD700), 2: Color(0xFFC0C0C0), 3: Color(0xFFCD7F32)};
    const medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    final color = colors[rank]!;
    return Column(
      children: [
        Text(medals[rank]!, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(
          entry.participant.fullName ??
              entry.participant.username,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 11),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          '#${entry.participant.bibNumber ?? '?'}',
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          entry.totalTime != null
              ? QRHelper.formatDuration(entry.totalTime!)
              : '—',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Center(
            child: Text('$rank',
                style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(int rank, _Entry entry) {
    const rankColors = {
      1: Color(0xFFFFD700),
      2: Color(0xFFC0C0C0),
      3: Color(0xFFCD7F32),
    };
    final rankColor = rankColors[rank] ?? AppColors.textMuted;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: rank <= 3
            ? rankColor.withValues(alpha: 0.05)
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: rank <= 3
              ? rankColor.withValues(alpha: 0.25)
              : AppColors.border,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: SizedBox(
            width: 32,
            child: Text(
              rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
              style: TextStyle(
                  color: rankColor,
                  fontSize: rank <= 3 ? 22 : 16,
                  fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text('#${entry.participant.bibNumber ?? '?'}',
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.participant.fullName ?? entry.participant.username,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.totalTime != null
                    ? QRHelper.formatDuration(entry.totalTime!)
                    : '—',
                style: TextStyle(
                    color: rank <= 3 ? rankColor : AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13),
              ),
              Text(
                '${entry.times.length}/${_checkpoints.length} CPs',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 10),
              ),
            ],
          ),
          collapsedIconColor: AppColors.textMuted,
          iconColor: AppColors.accent,
          children: [
            if (_checkpoints.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    const Divider(),
                    ..._checkpoints.asMap().entries.map((e) {
                      final i = e.key;
                      final cp = e.value;
                      final t = entry.times[cp.id];
                      Duration? stageTime;
                      if (i < entry.stageTimes.length) {
                        stageTime = entry.stageTimes[i];
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: t != null
                                    ? AppColors.success.withValues(alpha: 0.2)
                                    : AppColors.border.withValues(alpha: 0.5),
                              ),
                              child: Center(
                                child: Icon(
                                  t != null ? Icons.check : Icons.close,
                                  size: 12,
                                  color: t != null
                                      ? AppColors.success
                                      : AppColors.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(cp.name,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12)),
                            ),
                            if (t != null)
                              Text(
                                DateFormat('HH:mm:ss').format(t),
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              )
                            else
                              const Text('—',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12)),
                            if (stageTime != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  '+${QRHelper.formatDuration(stageTime)}',
                                  style: const TextStyle(
                                      color: AppColors.info,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Entry {
  final AppUser participant;
  final Map<String, DateTime> times;
  final List<Duration?> stageTimes;
  final Duration? totalTime;

  _Entry({
    required this.participant,
    required this.times,
    required this.stageTimes,
    required this.totalTime,
  });
}

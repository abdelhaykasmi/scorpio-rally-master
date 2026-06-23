import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/csv_exporter.dart';

class LiveDashboardScreen extends StatefulWidget {
  const LiveDashboardScreen({super.key});

  @override
  State<LiveDashboardScreen> createState() => _LiveDashboardScreenState();
}

class _LiveDashboardScreenState extends State<LiveDashboardScreen> {
  List<AppUser> _participants = [];
  List<Checkpoint> _checkpoints = [];
  List<CheckpointPassage> _passages = [];
  RallyEvent? _event;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final event = await SupabaseService.instance.getActiveEvent();
    final participants = await SupabaseService.instance.getParticipants();
    List<Checkpoint> checkpoints = [];
    List<CheckpointPassage> passages = [];
    if (event != null) {
      checkpoints = await SupabaseService.instance.getCheckpoints(event.id);
      passages = await SupabaseService.instance.getAllPassagesForEvent(event.id);
    }
    setState(() {
      _event = event;
      _participants = participants
        ..sort((a, b) => (a.bibNumber ?? '').compareTo(b.bibNumber ?? ''));
      _checkpoints = checkpoints;
      _passages = passages;
      _loading = false;
    });
  }

  void _exportCsv() {
    final csv = CsvExporter.exportPassages(_passages, _checkpoints);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Export ready — ${_passages.length} passages (${_participants.length} participants)'),
        backgroundColor: AppColors.success,
        action: SnackBarAction(
          label: 'COPY',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  CheckpointPassage? _findPassage(String participantId, String checkpointId) {
    try {
      return _passages.firstWhere(
        (p) => p.participantId == participantId && p.checkpointId == checkpointId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          if (_event != null) _buildEventBanner(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : _event == null
                    ? const EmptyState(
                        icon: Icons.event_busy, title: 'No active event')
                    : _buildGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final passed = _passages.length;
    final total = _participants.length * _checkpoints.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.grid_view, color: AppColors.accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LIVE DASHBOARD',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    )),
                Text(
                  '$passed / $total passages recorded',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download, color: AppColors.textMuted),
            onPressed: _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textMuted),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildEventBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.accent.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.flag, color: AppColors.accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_event!.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                )),
          ),
          _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final total = _participants.length * _checkpoints.length;
    final passed = _passages.length;
    final pct = total > 0 ? passed / total : 0.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.border,
              color: AppColors.success,
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${(pct * 100).toInt()}%',
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildGrid() {
    if (_participants.isEmpty) {
      return const EmptyState(
          icon: Icons.people_outline, title: 'No participants registered');
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Row(
            children: [
              _legend(AppColors.success, 'Passed'),
              const SizedBox(width: 16),
              _legend(AppColors.error.withValues(alpha: 0.5), 'Not passed'),
            ],
          ),
          const SizedBox(height: 12),
          // Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surface),
              dataRowColor: WidgetStateProperty.all(AppColors.cardBackground),
              border: TableBorder.all(
                color: AppColors.border,
                width: 1,
                borderRadius: BorderRadius.circular(8),
              ),
              columnSpacing: 16,
              horizontalMargin: 12,
              headingTextStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
              columns: [
                const DataColumn(label: Text('BIB')),
                const DataColumn(label: Text('RIDER')),
                ..._checkpoints.map(
                  (cp) => DataColumn(
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 90),
                      child: Text(cp.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  ),
                ),
                const DataColumn(label: Text('DONE')),
              ],
              rows: _participants.map((p) {
                final passedCount = _checkpoints
                    .where((cp) => _findPassage(p.id, cp.id) != null)
                    .length;
                return DataRow(
                  cells: [
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('#${p.bibNumber ?? '?'}',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            )),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 110,
                        child: Text(
                          p.fullName ?? p.username,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    ..._checkpoints.map((cp) {
                      final passage = _findPassage(p.id, cp.id);
                      return DataCell(
                        _passageCell(passage),
                      );
                    }),
                    DataCell(
                      Text(
                        '$passedCount/${_checkpoints.length}',
                        style: TextStyle(
                          color: passedCount == _checkpoints.length
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passageCell(CheckpointPassage? passage) {
    if (passage == null) {
      return Container(
        width: 60,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: Text('❌',
              style: TextStyle(fontSize: 14)),
        ),
      );
    }
    return Container(
      width: 68,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border:
            Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          DateFormat('HH:mm').format(passage.localTime),
          style: const TextStyle(
            color: AppColors.success,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style:
                const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}

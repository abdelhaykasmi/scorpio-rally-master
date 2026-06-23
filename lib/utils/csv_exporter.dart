import '../models/models.dart';
import 'package:intl/intl.dart';

class CsvExporter {
  static final _dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  static String exportParticipants(List<AppUser> participants) {
    final sb = StringBuffer();
    sb.writeln('Bib,Full Name,Bike Brand,Bike Model,Engine(cc),Nationality,Emergency Contact,Emergency Phone');
    for (final p in participants) {
      sb.writeln('${_q(p.bibNumber)},${_q(p.fullName)},${_q(p.bikeBrand)},${_q(p.bikeModel)},${p.engineSize ?? ""},${_q(p.nationality)},${_q(p.emergencyContactName)},${_q(p.emergencyContactPhone)}');
    }
    return sb.toString();
  }

  static String exportPassages(
      List<CheckpointPassage> passages, List<Checkpoint> checkpoints) {
    final sb = StringBuffer();
    sb.writeln('Bib,Participant,Checkpoint,Checkpoint Order,Local Time,UTC Time,Sync Status');
    final ordered = [...passages]..sort((a, b) => a.bibNumber.compareTo(b.bibNumber));
    for (final p in ordered) {
      final cp = checkpoints.where((c) => c.id == p.checkpointId).firstOrNull;
      sb.writeln('${_q(p.bibNumber)},${_q(p.participantName)},${_q(p.checkpointName)},${cp?.order ?? ""},${_q(_dateFmt.format(p.localTime))},${_q(_dateFmt.format(p.utcTime))},${p.syncStatus.name}');
    }
    return sb.toString();
  }

  static String exportLeaderboard(
    List<AppUser> participants,
    List<Checkpoint> checkpoints,
    List<CheckpointPassage> passages,
  ) {
    final sb = StringBuffer();
    final headers = ['Rank', 'Bib', 'Name'];
    for (final cp in checkpoints) {
      headers.add(cp.name);
    }
    for (int i = 0; i < checkpoints.length - 1; i++) {
      headers.add('Stage ${i + 1} Time');
    }
    headers.add('Total Time');
    sb.writeln(headers.join(','));

    final leaderboard = _buildLeaderboard(participants, checkpoints, passages);
    int rank = 1;
    for (final entry in leaderboard) {
      final row = [rank.toString(), _q(entry.bibNumber), _q(entry.name)];
      for (final cp in checkpoints) {
        final t = entry.times[cp.id];
        row.add(t != null ? _q(DateFormat('HH:mm:ss').format(t)) : '-');
      }
      for (final st in entry.stageTimes) {
        row.add(st != null ? _q(QrHelperDuration.formatDuration(st)) : '-');
      }
      row.add(entry.totalTime != null ? _q(QrHelperDuration.formatDuration(entry.totalTime!)) : '-');
      sb.writeln(row.join(','));
      rank++;
    }
    return sb.toString();
  }

  static List<_LeaderboardEntry> _buildLeaderboard(
    List<AppUser> participants,
    List<Checkpoint> checkpoints,
    List<CheckpointPassage> passages,
  ) {
    final entries = <_LeaderboardEntry>[];
    for (final p in participants) {
      final times = <String, DateTime>{};
      for (final cp in checkpoints) {
        final pass = passages.where(
          (pp) => pp.participantId == p.id && pp.checkpointId == cp.id,
        ).firstOrNull;
        if (pass != null) times[cp.id] = pass.localTime;
      }
      final stageTimes = <Duration?>[];
      for (int i = 1; i < checkpoints.length; i++) {
        final t1 = times[checkpoints[i - 1].id];
        final t2 = times[checkpoints[i].id];
        stageTimes.add(t1 != null && t2 != null ? t2.difference(t1) : null);
      }
      final first = times[checkpoints.first.id];
      final last = times.isNotEmpty
          ? times.values.reduce((a, b) => a.isAfter(b) ? a : b)
          : null;
      entries.add(_LeaderboardEntry(
        participantId: p.id,
        name: p.fullName ?? p.username,
        bibNumber: p.bibNumber ?? '',
        times: times,
        stageTimes: stageTimes,
        totalTime: first != null && last != null ? last.difference(first) : null,
      ));
    }
    entries.sort((a, b) {
      if (a.totalTime == null && b.totalTime == null) return 0;
      if (a.totalTime == null) return 1;
      if (b.totalTime == null) return -1;
      return a.totalTime!.compareTo(b.totalTime!);
    });
    return entries;
  }

  static String _q(String? s) {
    if (s == null) return '';
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}

class _LeaderboardEntry {
  final String participantId;
  final String name;
  final String bibNumber;
  final Map<String, DateTime> times;
  final List<Duration?> stageTimes;
  final Duration? totalTime;

  _LeaderboardEntry({
    required this.participantId,
    required this.name,
    required this.bibNumber,
    required this.times,
    required this.stageTimes,
    required this.totalTime,
  });
}

class QrHelperDuration {
  static String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }
}

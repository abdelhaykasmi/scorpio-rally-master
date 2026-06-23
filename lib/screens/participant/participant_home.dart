import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/qr_helper.dart';
import '../../widgets/common_widgets.dart';

class ParticipantHome extends StatefulWidget {
  const ParticipantHome({super.key});

  @override
  State<ParticipantHome> createState() => _ParticipantHomeState();
}

class _ParticipantHomeState extends State<ParticipantHome> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _QRCodeTab(),
          _PassageHistoryTab(),
          _EventInfoTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_2), label: 'My QR'),
          BottomNavigationBarItem(
              icon: Icon(Icons.route), label: 'Checkpoints'),
          BottomNavigationBarItem(
              icon: Icon(Icons.event), label: 'Event'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ── QR Code Tab ───────────────────────────────────────────
class _QRCodeTab extends StatefulWidget {
  const _QRCodeTab();

  @override
  State<_QRCodeTab> createState() => _QRCodeTabState();
}

class _QRCodeTabState extends State<_QRCodeTab> {
  RallyEvent? _event;
  String? _qrData;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final event = await FirebaseService.instance.getActiveEvent();
    if (!mounted) return;
    setState(() => _event = event);
    final user = context.read<AuthProvider>().currentUser;
    if (user != null && event != null) {
      final qr = QRHelper.generateQRData(
        participantId: user.id,
        fullName: user.fullName ?? user.username,
        bibNumber: user.bibNumber ?? 'N/A',
        bikeBrand: user.bikeBrand ?? '',
        bikeModel: user.bikeModel ?? '',
        eventId: event.id,
        eventName: event.name,
      );
      setState(() => _qrData = qr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(user),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_event != null) _buildEventBadge(),
                  const SizedBox(height: 24),
                  _buildQRCard(user),
                  const SizedBox(height: 20),
                  _buildBikeInfo(user),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppUser? user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                user?.bibNumber ?? '#',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.fullName ?? 'Rider',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${user?.bikeBrand ?? ''} ${user?.bikeModel ?? ''}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.two_wheeler, color: AppColors.accent, size: 28),
        ],
      ),
    );
  }

  Widget _buildEventBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag, color: AppColors.accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_event!.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    )),
                Text(
                  '${_event!.location} · ${DateFormat('dd MMM yyyy').format(_event!.date)}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const StatusBadge(
            label: 'ACTIVE',
            color: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildQRCard(AppUser? user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Text('CHECKPOINT QR CODE',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              )),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _qrData != null
                ? QrImageView(
                    data: _qrData!,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF1A1A1A),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF1A1A1A),
                    ),
                  )
                : const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, color: AppColors.textMuted, size: 14),
              const SizedBox(width: 6),
              Text(
                user?.fullName ?? '',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'BIB #${user?.bibNumber ?? 'N/A'}',
            style: const TextStyle(
                color: AppColors.accent,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          const Text(
            'Show this QR code at each checkpoint',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBikeInfo(AppUser? user) {
    return CarbonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.two_wheeler, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            const Text('BIKE DETAILS',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                )),
          ]),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                    'BRAND', user?.bikeBrand ?? '—', Icons.label),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _miniStat(
                    'MODEL', user?.bikeModel ?? '—', Icons.model_training),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _miniStat(
                    'ENGINE', '${user?.engineSize ?? '—'}cc', Icons.speed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 10)),
      ],
    );
  }
}

// ── Passage History Tab ───────────────────────────────────
class _PassageHistoryTab extends StatefulWidget {
  const _PassageHistoryTab();

  @override
  State<_PassageHistoryTab> createState() => _PassageHistoryTabState();
}

class _PassageHistoryTabState extends State<_PassageHistoryTab> {
  List<CheckpointPassage> _passages = [];
  List<Checkpoint> _checkpoints = [];
  RallyEvent? _event;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().currentUser;
    final event = await FirebaseService.instance.getActiveEvent();
    if (user != null && event != null) {
      final passages = await FirebaseService.instance
          .getPassagesForParticipant(user.id, event.id);
      final checkpoints =
          await FirebaseService.instance.getCheckpoints(event.id);
      setState(() {
        _passages = passages;
        _checkpoints = checkpoints;
        _event = event;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.route, color: AppColors.accent, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MY CHECKPOINTS',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    )),
                Text('Passage history for active event',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
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
    );
  }

  Widget _buildContent() {
    if (_event == null) {
      return const EmptyState(
        icon: Icons.event_busy,
        title: 'No Active Event',
        subtitle: 'No event is currently active.',
      );
    }

    final completed = _passages.length;
    final total = _checkpoints.length;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Progress card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$completed / $total checkpoints',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text('${total > 0 ? (completed / total * 100).toInt() : 0}%',
                        style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? completed / total : 0,
                    backgroundColor: AppColors.border,
                    color: AppColors.accent,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Checkpoint list
          ..._checkpoints.map((cp) {
            CheckpointPassage? passage;
            try {
              passage = _passages
                  .firstWhere((p) => p.checkpointId == cp.id);
            } catch (_) {}
            return _buildCheckpointRow(cp, passage);
          }),
        ],
      ),
    );
  }

  Widget _buildCheckpointRow(Checkpoint cp, CheckpointPassage? passage) {
    final passed = passage != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: passed
            ? AppColors.success.withValues(alpha: 0.08)
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: passed
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: passed
                  ? AppColors.success.withValues(alpha: 0.2)
                  : AppColors.surfaceVariant,
              border: Border.all(
                color: passed ? AppColors.success : AppColors.border,
              ),
            ),
            child: Center(
              child: passed
                  ? const Icon(Icons.check, color: AppColors.success, size: 20)
                  : Text('${cp.order}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      )),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cp.name,
                    style: TextStyle(
                      color: passed
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    )),
                if (passed && passage != null)
                  Text(
                    DateFormat('dd MMM · HH:mm:ss').format(passage.localTime),
                    style: const TextStyle(
                        color: AppColors.success, fontSize: 12),
                  )
                else
                  const Text('Not yet passed',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          if (passed)
            const Icon(Icons.verified, color: AppColors.success, size: 20),
        ],
      ),
    );
  }
}

// ── Event Info Tab ────────────────────────────────────────
class _EventInfoTab extends StatefulWidget {
  const _EventInfoTab();

  @override
  State<_EventInfoTab> createState() => _EventInfoTabState();
}

class _EventInfoTabState extends State<_EventInfoTab> {
  RallyEvent? _event;
  List<Checkpoint> _checkpoints = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final event = await FirebaseService.instance.getActiveEvent();
    if (event != null) {
      final cps = await FirebaseService.instance.getCheckpoints(event.id);
      setState(() {
        _event = event;
        _checkpoints = cps;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _event == null
                ? const EmptyState(
                    icon: Icons.event_busy,
                    title: 'No Active Event',
                  )
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        children: [
          Icon(Icons.event, color: AppColors.accent, size: 24),
          SizedBox(width: 12),
          Text('EVENT INFO',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              )),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final e = _event!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Main event card
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusBadge(
                  label: 'ACTIVE EVENT', color: Colors.white),
              const SizedBox(height: 12),
              Text(e.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(e.location,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.calendar_today,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(DateFormat('dd MMMM yyyy').format(e.date),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CarbonCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DESCRIPTION',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  )),
              const SizedBox(height: 10),
              Text(e.description,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // GPX download card
        GestureDetector(
          onTap: e.gpxFileUrl != null ? () => _downloadGpx() : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: e.gpxFileUrl != null
                  ? AppColors.accent.withValues(alpha: 0.1)
                  : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: e.gpxFileUrl != null
                    ? AppColors.accent.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  e.gpxFileUrl != null
                      ? Icons.download
                      : Icons.file_present_outlined,
                  color: e.gpxFileUrl != null
                      ? AppColors.accent
                      : AppColors.textMuted,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.gpxFileName ?? 'GPX Route File',
                        style: TextStyle(
                          color: e.gpxFileUrl != null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        e.gpxFileUrl != null
                            ? 'Tap to download for Garmin / Wikiloc'
                            : 'No GPX file uploaded yet',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (e.gpxFileUrl != null)
                  const Icon(Icons.arrow_forward_ios,
                      color: AppColors.accent, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Checkpoints list
        const SectionHeader(title: 'Checkpoints', padding: EdgeInsets.zero),
        const SizedBox(height: 8),
        ..._checkpoints.map((cp) => _buildCpRow(cp)),
      ],
    );
  }

  Widget _buildCpRow(Checkpoint cp) {
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.15),
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text('${cp.order}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  )),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cp.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    )),
                if (cp.description != null)
                  Text(cp.description!,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          if (cp.latitude != null && cp.longitude != null)
            const Icon(Icons.location_on,
                color: AppColors.textMuted, size: 16),
        ],
      ),
    );
  }

  void _downloadGpx() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('GPX file download started — open with Garmin or Wikiloc'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}

// ── Profile Tab ───────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
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
                const Icon(Icons.person, color: AppColors.accent, size: 24),
                const SizedBox(width: 12),
                const Text('PROFILE',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    )),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.read<AuthProvider>().signOut(),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Logout'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Avatar section
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.3),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            user?.bibNumber ?? '#',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(user?.fullName ?? 'Rider',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          )),
                      Text(user?.nationality ?? '',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _section('RIDER INFO', [
                  InfoRow(label: 'Full Name', value: user?.fullName ?? '—', icon: Icons.person),
                  InfoRow(label: 'Bib Number', value: '#${user?.bibNumber ?? '—'}', icon: Icons.tag),
                  InfoRow(label: 'Nationality', value: user?.nationality ?? '—', icon: Icons.flag),
                ]),
                const SizedBox(height: 16),
                _section('BIKE', [
                  InfoRow(label: 'Brand', value: user?.bikeBrand ?? '—', icon: Icons.two_wheeler),
                  InfoRow(label: 'Model', value: user?.bikeModel ?? '—', icon: Icons.model_training),
                  InfoRow(label: 'Engine', value: '${user?.engineSize ?? '—'}cc', icon: Icons.speed),
                ]),
                const SizedBox(height: 16),
                _section('EMERGENCY CONTACT', [
                  InfoRow(label: 'Contact Name', value: user?.emergencyContactName ?? '—', icon: Icons.contact_emergency),
                  InfoRow(label: 'Phone', value: user?.emergencyContactPhone ?? '—', icon: Icons.phone),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              )),
          const Divider(height: 16),
          ...rows,
        ],
      ),
    );
  }
}

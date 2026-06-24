import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/app_settings_provider.dart';
import '../../services/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/local_storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'admin_settings_screen.dart';
import 'events_screen.dart';
import 'users_screen.dart';
import 'live_dashboard_screen.dart';
import 'leaderboard_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _currentIndex = 0;

  void _goToTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettingsProvider>();
    final pages = [
      _AdminDashboardTab(onTabChange: _goToTab),
      const EventsScreen(),
      const UsersScreen(),
      const LiveDashboardScreen(),
      const LeaderboardScreen(),
      const AdminSettingsScreen(),
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: s.primaryColor,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.event), label: 'Events'),
            BottomNavigationBarItem(
                icon: Icon(Icons.people), label: 'Users'),
            BottomNavigationBarItem(
                icon: Icon(Icons.grid_view), label: 'Live'),
            BottomNavigationBarItem(
                icon: Icon(Icons.leaderboard), label: 'Ranks'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

// ── Admin Dashboard Home ──────────────────────────────────
class _AdminDashboardTab extends StatefulWidget {
  final void Function(int) onTabChange;
  const _AdminDashboardTab({required this.onTabChange});

  @override
  State<_AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<_AdminDashboardTab> {
  RallyEvent? _activeEvent;
  int _participantCount = 0;
  int _organizerCount = 0;
  int _totalPassages = 0;
  int _checkpointCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Try Supabase first
      RallyEvent? event;
      List participants = [];
      List organizers = [];
      int passages = 0;
      int cps = 0;

      try {
        event = await SupabaseService.instance.getActiveEvent();
      } catch (_) {
        event = await LocalStorageService.instance.getActiveEvent();
      }

      try {
        participants = await SupabaseService.instance.getParticipants();
      } catch (_) {
        final all = await LocalStorageService.instance.getCachedUsers();
        participants = all.where((u) => u.role == UserRole.participant).toList();
      }

      try {
        organizers = await SupabaseService.instance.getOrganizers();
      } catch (_) {
        final all = await LocalStorageService.instance.getCachedUsers();
        organizers = all.where((u) => u.role == UserRole.organizer).toList();
      }

      if (event != null) {
        try {
          final ps = await SupabaseService.instance.getAllPassagesForEvent(event.id);
          passages = ps.length;
        } catch (_) {
          final ps = await LocalStorageService.instance.getAllLocalPassages();
          passages = ps.where((p) => p.eventId == event!.id).length;
        }
        try {
          final cpList = await SupabaseService.instance.getCheckpoints(event.id);
          cps = cpList.length;
        } catch (_) {
          final cpList = await LocalStorageService.instance.getCachedCheckpoints(event.id);
          cps = cpList.length;
        }
      }

      if (mounted) {
        setState(() {
          _activeEvent = event;
          _participantCount = participants.length;
          _organizerCount = organizers.length;
          _totalPassages = passages;
          _checkpointCount = cps;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppColors.accent,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildActiveEventCard(),
                  const SizedBox(height: 20),
                  const SectionHeader(
                      title: 'Overview', padding: EdgeInsets.zero),
                  const SizedBox(height: 12),
                  _buildStats(),
                  const SizedBox(height: 20),
                  const SectionHeader(
                      title: 'Quick Actions', padding: EdgeInsets.zero),
                  const SizedBox(height: 12),
                  _buildQuickActions(context),
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
            child: const Icon(Icons.admin_panel_settings,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SUPER ADMIN',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    )),
                Text(user?.fullName ?? 'Administrator',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    )),
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

  Widget _buildActiveEventCard() {
    if (_activeEvent == null) {
      return GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.3),
                style: BorderStyle.solid),
          ),
          child: const Row(
            children: [
              Icon(Icons.event_busy, color: AppColors.textMuted, size: 32),
              SizedBox(width: 16),
              Text('No active event — go to Events to activate one',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 14)),
            ],
          ),
        ),
      );
    }
    final e = _activeEvent!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              const Text('ACTIVE EVENT',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('LIVE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(e.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.location_on, color: Colors.white60, size: 13),
            const SizedBox(width: 4),
            Text(e.location,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 12)),
            const SizedBox(width: 12),
            const Icon(Icons.people, color: Colors.white60, size: 13),
            const SizedBox(width: 4),
            Text('$_participantCount riders',
                style: const TextStyle(
                    color: Colors.white60, fontSize: 12)),
          ]),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        StatCard(
            label: 'Participants',
            value: '$_participantCount',
            icon: Icons.people,
            color: AppColors.info),
        StatCard(
            label: 'Organizers',
            value: '$_organizerCount',
            icon: Icons.shield,
            color: AppColors.warning),
        StatCard(
            label: 'Checkpoints',
            value: '$_checkpointCount',
            icon: Icons.flag,
            color: AppColors.success),
        StatCard(
            label: 'Passages',
            value: '$_totalPassages',
            icon: Icons.check_circle,
            color: AppColors.accent),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    // Tab indices: 0=Home, 1=Events, 2=Users, 3=Live, 4=Ranks, 5=Settings
    final actions = [
      _Action('Create Event', Icons.add_circle, AppColors.accent, () {
        widget.onTabChange(1); // → Events tab
      }),
      _Action('Add Participant', Icons.person_add, AppColors.info, () {
        widget.onTabChange(2); // → Users tab (participants)
      }),
      _Action('Add Organizer', Icons.shield, AppColors.warning, () {
        widget.onTabChange(2); // → Users tab (organizers)
      }),
      _Action('Live Dashboard', Icons.grid_view, AppColors.success, () {
        widget.onTabChange(3); // → Live tab
      }),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: actions.map((a) {
        return GestureDetector(
          onTap: a.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: a.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: a.color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(a.icon, color: a.color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(a.label,
                      style: TextStyle(
                        color: a.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      )),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Action {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _Action(this.label, this.icon, this.color, this.onTap);
}

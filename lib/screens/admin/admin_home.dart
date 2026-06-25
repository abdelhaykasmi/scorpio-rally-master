import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/app_settings_provider.dart';
import '../../services/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/sync_service.dart';
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

  // ── Schema fix dialog ─────────────────────────────────────
  static void _showSchemaDialog(BuildContext ctx, SchemaStatus status) {
    showDialog(
      context: ctx,
      builder: (_) => _SchemaFixDialog(status: status),
    );
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
          // ── Schema issues banner (highest priority, always visible) ──
          Consumer<SyncService>(
            builder: (_, sync, __) {
              if (!sync.hasSchemaIssues) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () => _showSchemaDialog(context, sync.schemaStatus!),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.14),
                    border: Border(
                      bottom: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Database schema issues detected — tap to view SQL fix',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          color: AppColors.error, size: 12),
                    ],
                  ),
                ),
              );
            },
          ),
          // ── Sync / offline status banner ──────────────────
          Consumer<SyncService>(
            builder: (_, sync, __) {
              if (sync.state == SyncState.unknown) return const SizedBox.shrink();
              if (sync.state == SyncState.online) return const SizedBox.shrink();

              final isSyncing = sync.state == SyncState.syncing;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSyncing
                      ? AppColors.info.withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.12),
                  border: Border(
                    bottom: BorderSide(
                      color: isSyncing
                          ? AppColors.info.withValues(alpha: 0.4)
                          : AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    isSyncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: AppColors.info,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.cloud_off,
                            color: AppColors.warning, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isSyncing
                            ? 'Syncing to database…'
                            : 'Database offline — data saved locally only',
                        style: TextStyle(
                          color: isSyncing ? AppColors.info : AppColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!isSyncing)
                      TextButton(
                        onPressed: () async {
                          try {
                            final result =
                                await SyncService.instance.syncAllToSupabase();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(result),
                                backgroundColor: AppColors.success,
                                duration: const Duration(seconds: 5),
                              ));
                              // Reload dashboard stats after successful sync
                              _load();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              // Show the REAL error so admin can diagnose
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: AppColors.surface,
                                  title: const Row(
                                    children: [
                                      Icon(Icons.sync_problem,
                                          color: AppColors.error),
                                      SizedBox(width: 8),
                                      Text('Sync Failed',
                                          style: TextStyle(
                                              color: AppColors.textPrimary)),
                                    ],
                                  ),
                                  content: SingleChildScrollView(
                                    child: Text(
                                      e.toString().replaceFirst(
                                          'Exception: ', ''),
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('SYNC NOW',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            )),
                      ),
                  ],
                ),
              );
            },
          ),
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

// ── Schema Fix Dialog ─────────────────────────────────────────
/// Shows a copyable SQL block the admin can paste into the Supabase SQL Editor
/// to create missing tables, columns and RLS policies.
class _SchemaFixDialog extends StatefulWidget {
  final SchemaStatus status;
  const _SchemaFixDialog({required this.status});

  @override
  State<_SchemaFixDialog> createState() => _SchemaFixDialogState();
}

class _SchemaFixDialogState extends State<_SchemaFixDialog> {
  bool _recheckLoading = false;
  String? _recheckResult;

  Future<void> _recheck() async {
    setState(() { _recheckLoading = true; _recheckResult = null; });
    try {
      final s = await SyncService.instance.recheckSchema();
      if (mounted) {
        setState(() {
          _recheckLoading = false;
          _recheckResult = s.isHealthy
              ? '✅ All schema issues resolved!'
              : '⚠️ ${s.issues.length} issue(s) still remain. Run the SQL again.';
        });
      }
    } catch (e) {
      if (mounted) setState(() { _recheckLoading = false; _recheckResult = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sql = widget.status.fixSql;
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: const Row(
        children: [
          Icon(Icons.build_circle, color: AppColors.error, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Fix Database Schema',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Issues list
              ...widget.status.issues.map((issue) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber, color: AppColors.warning, size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: Text(issue,
                        style: const TextStyle(color: AppColors.warning,
                            fontSize: 12, fontWeight: FontWeight.w600))),
                  ],
                ),
              )),
              const SizedBox(height: 12),
              const Text(
                'Paste this SQL into Supabase → SQL Editor → New Query → Run:',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              // SQL block
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: SelectableText(
                  sql,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFF79C0FF),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_recheckResult != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _recheckResult!.startsWith('✅')
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_recheckResult!,
                      style: TextStyle(
                        color: _recheckResult!.startsWith('✅')
                            ? AppColors.success
                            : AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          onPressed: _recheckLoading ? null : _recheck,
          icon: _recheckLoading
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.refresh, size: 16),
          label: const Text('Re-check Schema'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../services/local_storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AppUser> _participants = [];
  List<AppUser> _organizers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      List<AppUser> all;
      try {
        all = await SupabaseService.instance.getUsers();
        // Cache locally so offline works
        await LocalStorageService.instance.cacheUsers(all);
      } catch (_) {
        // Supabase unreachable — use local cache
        all = await LocalStorageService.instance.getCachedUsers();
      }
      if (mounted) {
        setState(() {
          _participants = all.where((u) => u.role == UserRole.participant).toList();
          _organizers = all.where((u) => u.role == UserRole.organizer).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accent,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textMuted,
              tabs: [
                Tab(text: 'PARTICIPANTS (${_participants.length})'),
                Tab(text: 'ORGANIZERS (${_organizers.length})'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _UserList(
                        users: _participants,
                        role: UserRole.participant,
                        onRefresh: _load,
                      ),
                      _UserList(
                        users: _organizers,
                        role: UserRole.organizer,
                        onRefresh: _load,
                      ),
                    ],
                  ),
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
          const Icon(Icons.people, color: AppColors.accent, size: 22),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('USER MANAGEMENT',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ))),
          IconButton(
            icon: const Icon(Icons.person_add, color: AppColors.accent),
            onPressed: () => _showUserDialog(null, UserRole.participant),
          ),
        ],
      ),
    );
  }

  void _showUserDialog(AppUser? existing, UserRole defaultRole) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _UserFormSheet(
        existing: existing,
        defaultRole: defaultRole,
        onSaved: (user) async {
          // Local cache first — UI always reflects the change
          final cached = await LocalStorageService.instance.getCachedUsers();
          final List<AppUser> updated;
          if (existing == null) {
            updated = [...cached, user];
          } else {
            updated = cached.map((u) => u.id == user.id ? user : u).toList();
          }
          await LocalStorageService.instance.cacheUsers(updated);
          // Supabase best-effort
          if (existing == null) {
            SupabaseService.instance.createUser(user).catchError((_) {});
          } else {
            SupabaseService.instance.updateUser(user).catchError((_) {});
          }
          await _load();
        },
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  final List<AppUser> users;
  final UserRole role;
  final VoidCallback onRefresh;

  const _UserList({
    required this.users,
    required this.role,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return EmptyState(
        icon: role == UserRole.participant ? Icons.directions_bike : Icons.shield,
        title: role == UserRole.participant
            ? 'No participants yet'
            : 'No organizers yet',
        action: ElevatedButton.icon(
          onPressed: () => _showCreate(context),
          icon: const Icon(Icons.add),
          label: Text(role == UserRole.participant
              ? 'Add Participant'
              : 'Add Organizer'),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => _showCreate(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(role == UserRole.participant
                    ? 'ADD PARTICIPANT'
                    : 'ADD ORGANIZER'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
            ),
          );
        }
        final user = users[i - 1];
        return _buildUserCard(context, user);
      },
    );
  }

  void _showCreate(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _UserFormSheet(
        defaultRole: role,
        onSaved: (user) async {
          // Local cache first
          final cached = await LocalStorageService.instance.getCachedUsers();
          await LocalStorageService.instance.cacheUsers([...cached, user]);
          // Supabase best-effort
          SupabaseService.instance.createUser(user).catchError((_) {});
          onRefresh();
        },
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, AppUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: user.isActive ? AppColors.cardBackground : AppColors.cardBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: user.isActive ? AppColors.border : AppColors.border.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: user.role == UserRole.participant
                  ? AppColors.info.withValues(alpha: 0.2)
                  : AppColors.warning.withValues(alpha: 0.2),
              border: Border.all(
                color: user.role == UserRole.participant
                    ? AppColors.info.withValues(alpha: 0.5)
                    : AppColors.warning.withValues(alpha: 0.5),
              ),
            ),
            child: Center(
              child: user.role == UserRole.participant
                  ? Text(
                      '#${user.bibNumber ?? '?'}',
                      style: const TextStyle(
                          color: AppColors.info,
                          fontSize: 11,
                          fontWeight: FontWeight.w900),
                    )
                  : const Icon(Icons.shield,
                      color: AppColors.warning, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(user.fullName ?? user.username,
                          style: TextStyle(
                            color: user.isActive
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          )),
                    ),
                    if (!user.isActive)
                      const StatusBadge(
                          label: 'INACTIVE', color: AppColors.textMuted),
                  ],
                ),
                Text('@${user.username}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
                if (user.role == UserRole.participant &&
                    user.bikeBrand != null)
                  Text(
                    '${user.bikeBrand} ${user.bikeModel} · ${user.nationality ?? ''}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
            color: AppColors.surface,
            onSelected: (action) async {
              if (action == 'edit') {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppColors.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (_) => _UserFormSheet(
                    existing: user,
                    defaultRole: user.role,
                    onSaved: (updated) async {
                      // Local cache first
                      final cached = await LocalStorageService.instance.getCachedUsers();
                      await LocalStorageService.instance.cacheUsers(
                          cached.map((u) => u.id == updated.id ? updated : u).toList());
                      // Supabase best-effort
                      SupabaseService.instance.updateUser(updated).catchError((_) {});
                      onRefresh();
                    },
                  ),
                );
              } else if (action == 'toggle') {
                final toggled = user.copyWith(isActive: !user.isActive);
                // Local cache first
                final c1 = await LocalStorageService.instance.getCachedUsers();
                await LocalStorageService.instance.cacheUsers(
                    c1.map((u) => u.id == toggled.id ? toggled : u).toList());
                SupabaseService.instance.updateUser(toggled).catchError((_) {});
                onRefresh();
              } else if (action == 'delete') {
                // Local cache first
                final c2 = await LocalStorageService.instance.getCachedUsers();
                await LocalStorageService.instance.cacheUsers(
                    c2.where((u) => u.id != user.id).toList());
                SupabaseService.instance.deleteUser(user.id).catchError((_) {});
                onRefresh();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                value: 'toggle',
                child: Text(user.isActive ? 'Deactivate' : 'Activate'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete',
                    style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserFormSheet extends StatefulWidget {
  final AppUser? existing;
  final UserRole defaultRole;
  final Function(AppUser) onSaved;

  const _UserFormSheet({
    required this.defaultRole,
    required this.onSaved,
    this.existing,
  });

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late UserRole _role;
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _bibCtrl = TextEditingController();
  final _bikeCtrl = TextEditingController();
  final _bikeModelCtrl = TextEditingController();
  final _engineCtrl = TextEditingController();
  final _natCtrl = TextEditingController();
  final _emgNameCtrl = TextEditingController();
  final _emgPhoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _role = widget.existing?.role ?? widget.defaultRole;
    if (widget.existing != null) {
      final u = widget.existing!;
      _usernameCtrl.text = u.username;
      _fullNameCtrl.text = u.fullName ?? '';
      _bibCtrl.text = u.bibNumber ?? '';
      _bikeCtrl.text = u.bikeBrand ?? '';
      _bikeModelCtrl.text = u.bikeModel ?? '';
      _engineCtrl.text = u.engineSize?.toString() ?? '';
      _natCtrl.text = u.nationality ?? '';
      _emgNameCtrl.text = u.emergencyContactName ?? '';
      _emgPhoneCtrl.text = u.emergencyContactPhone ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _usernameCtrl, _passwordCtrl, _fullNameCtrl, _bibCtrl,
      _bikeCtrl, _bikeModelCtrl, _engineCtrl, _natCtrl,
      _emgNameCtrl, _emgPhoneCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final password = _passwordCtrl.text.trim();
    final hash = password.isNotEmpty
        ? SupabaseService.hashPassword(password)
        : (widget.existing?.passwordHash ?? '');

    final user = AppUser(
      id: widget.existing?.id ?? const Uuid().v4(),
      username: _usernameCtrl.text.trim(),
      passwordHash: hash,
      role: _role,
      isActive: widget.existing?.isActive ?? true,
      fullName: _fullNameCtrl.text.trim().isEmpty ? null : _fullNameCtrl.text.trim(),
      bibNumber: _bibCtrl.text.trim().isEmpty ? null : _bibCtrl.text.trim(),
      bikeBrand: _bikeCtrl.text.trim().isEmpty ? null : _bikeCtrl.text.trim(),
      bikeModel: _bikeModelCtrl.text.trim().isEmpty ? null : _bikeModelCtrl.text.trim(),
      engineSize: int.tryParse(_engineCtrl.text.trim()),
      nationality: _natCtrl.text.trim().isEmpty ? null : _natCtrl.text.trim(),
      emergencyContactName: _emgNameCtrl.text.trim().isEmpty ? null : _emgNameCtrl.text.trim(),
      emergencyContactPhone: _emgPhoneCtrl.text.trim().isEmpty ? null : _emgPhoneCtrl.text.trim(),
    );
    widget.onSaved(user);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(isNew ? 'ADD USER' : 'EDIT USER',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Role selector
              Row(
                children: [
                  _roleChip(UserRole.participant, 'Participant'),
                  const SizedBox(width: 8),
                  _roleChip(UserRole.organizer, 'Organizer'),
                ],
              ),
              const SizedBox(height: 16),
              _tf('Username', _usernameCtrl, Icons.person,
                  required: true),
              const SizedBox(height: 12),
              _tf(
                isNew ? 'Password' : 'New Password (leave blank to keep)',
                _passwordCtrl,
                Icons.lock,
                required: isNew,
                obscure: true,
              ),
              const SizedBox(height: 12),
              _tf('Full Name', _fullNameCtrl, Icons.badge),
              if (_role == UserRole.participant) ...[
                const SizedBox(height: 12),
                _tf('Bib / ID Number', _bibCtrl, Icons.tag),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _tf('Bike Brand', _bikeCtrl, Icons.two_wheeler)),
                    const SizedBox(width: 10),
                    Expanded(child: _tf('Model', _bikeModelCtrl, Icons.model_training)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _tf('Engine (cc)', _engineCtrl, Icons.speed,
                        type: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: _tf('Nationality', _natCtrl, Icons.flag)),
                  ],
                ),
                const SizedBox(height: 12),
                const SectionHeader(
                    title: 'Emergency Contact',
                    padding: EdgeInsets.only(bottom: 8)),
                _tf('Contact Name', _emgNameCtrl, Icons.contact_emergency),
                const SizedBox(height: 12),
                _tf('Phone', _emgPhoneCtrl, Icons.phone,
                    type: TextInputType.phone),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(isNew ? 'CREATE USER' : 'SAVE CHANGES',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleChip(UserRole role, String label) {
    final selected = _role == role;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.accent,
      onSelected: (_) => setState(() => _role = role),
      labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontWeight: FontWeight.w700),
    );
  }

  Widget _tf(String label, TextEditingController ctrl, IconData icon,
      {bool required = false,
      bool obscure = false,
      TextInputType type = TextInputType.text}) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: required
          ? (v) => (v == null || v.isEmpty) ? '$label required' : null
          : null,
    );
  }
}

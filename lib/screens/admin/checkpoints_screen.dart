import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class CheckpointsScreen extends StatefulWidget {
  final RallyEvent event;
  const CheckpointsScreen({super.key, required this.event});

  @override
  State<CheckpointsScreen> createState() => _CheckpointsScreenState();
}

class _CheckpointsScreenState extends State<CheckpointsScreen> {
  List<Checkpoint> _checkpoints = [];
  List<AppUser> _organizers = [];
  bool _loading = true;
  String? _error;

  /// Attempts a Supabase write. On failure, marks connectivity offline.
  Future<bool> _tryWrite(Future<void> Function() write) async {
    try {
      await write();
      return true;
    } catch (_) {
      SyncService.instance.checkConnectivity();
      return false;
    }
  }

  void _showOfflineSnackBar(String entity) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$entity saved locally. Tap ••• Sync to push to database.'),
      backgroundColor: AppColors.warning,
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      // ── Load checkpoints ─────────────────────────────────
      // Rule: NEVER overwrite local cache with an empty Supabase response.
      // Supabase may return [] because of RLS, network, or nothing inserted yet —
      // that must not destroy checkpoints the user just created locally.
      final remoteCheckpoints =
          await SupabaseService.instance.getCheckpoints(widget.event.id);
      // mergeCheckpoints is a no-op when remoteCheckpoints is empty
      await LocalStorageService.instance
          .mergeCheckpoints(remoteCheckpoints, widget.event.id);
      // Always read from local cache as the single source of truth
      final cps = await LocalStorageService.instance
          .getCachedCheckpoints(widget.event.id);

      // ── Load organizers ───────────────────────────────────
      final remoteOrgs = await SupabaseService.instance.getOrganizers();
      // mergeUsers is a no-op when remoteOrgs is empty
      await LocalStorageService.instance.mergeUsers(remoteOrgs);
      // Read all users from local cache and filter organizers
      final allUsers = await LocalStorageService.instance.getCachedUsers();
      final orgs = allUsers
          .where((u) => u.role == UserRole.organizer && u.isActive)
          .toList();

      // ── Resolve organizer names on checkpoints ────────────
      final orgMap = {for (final o in orgs) o.id: o};
      final resolved = cps.map((cp) {
        if (cp.assignedOrganizerId != null &&
            cp.assignedOrganizerName == null) {
          final org = orgMap[cp.assignedOrganizerId];
          if (org != null) {
            return cp.copyWith(
                assignedOrganizerName: org.fullName ?? org.username);
          }
        }
        return cp;
      }).toList();

      if (mounted) {
        setState(() {
          _checkpoints = resolved;
          _organizers = orgs;
          _loading = false;
        });
      }
    } catch (e) {
      // Last-resort fallback: show whatever is in local cache
      try {
        final cps = await LocalStorageService.instance
            .getCachedCheckpoints(widget.event.id);
        final allUsers = await LocalStorageService.instance.getCachedUsers();
        final orgs = allUsers
            .where((u) => u.role == UserRole.organizer && u.isActive)
            .toList();
        if (mounted) {
          setState(() {
            _checkpoints = cps;
            _organizers = orgs;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Failed to load checkpoints. Please retry.';
          });
        }
      }
    }
  }

  void _addCheckpoint() => _showDialog(null);
  void _editCheckpoint(Checkpoint cp) => _showDialog(cp);

  Future<void> _deleteCheckpoint(Checkpoint cp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Checkpoint',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Delete "${cp.name}"?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // If this checkpoint had an organizer assigned, clear their assignedCheckpointId
    if (cp.assignedOrganizerId != null) {
      await _clearOrganizerCheckpointLink(cp.assignedOrganizerId!);
    }

    // Always update local cache first (instant UI feedback)
    final cached = await LocalStorageService.instance
        .getCachedCheckpoints(widget.event.id);
    await LocalStorageService.instance
        .cacheCheckpoints(cached.where((c) => c.id != cp.id).toList());

    // Then try Supabase (fire-and-forget; failure is fine — local cache is truth)
    SupabaseService.instance.deleteCheckpoint(cp.id).catchError((_) {});

    await _load();
  }

  /// Sets organizer.assignedCheckpointId = checkpointId in local cache + Supabase.
  Future<void> _setOrganizerCheckpointLink(
      String organizerId, String checkpointId) async {
    final users = await LocalStorageService.instance.getCachedUsers();
    final updated = users.map((u) {
      if (u.id == organizerId) {
        return u.copyWith(assignedCheckpointId: checkpointId);
      }
      return u;
    }).toList();
    await LocalStorageService.instance.cacheUsers(updated);
    // Best-effort Supabase sync
    SupabaseService.instance
        .updateUserCheckpointLink(organizerId, checkpointId)
        .catchError((_) {});
  }

  /// Clears organizer.assignedCheckpointId (sets to null) in local cache + Supabase.
  Future<void> _clearOrganizerCheckpointLink(String organizerId) async {
    final users = await LocalStorageService.instance.getCachedUsers();
    final updated = users.map((u) {
      if (u.id == organizerId) {
        return u.copyWith(clearCheckpointId: true);
      }
      return u;
    }).toList();
    await LocalStorageService.instance.cacheUsers(updated);
    // Best-effort Supabase sync
    SupabaseService.instance
        .clearUserCheckpointLink(organizerId)
        .catchError((_) {});
  }

  void _showDialog(Checkpoint? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CheckpointFormSheet(
        existing: existing,
        event: widget.event,
        organizers: _organizers,
        nextOrder: _checkpoints.length + 1,
        onSaved: (cp) async {
          // ── 1. Update organizer bi-directional link ───────────────────────
          // When a checkpoint is assigned/reassigned/unassigned, we must also
          // update AppUser.assignedCheckpointId so the organizer can find their
          // checkpoint in organizer_home._loadData().
          final oldOrganizerId = existing?.assignedOrganizerId;
          final newOrganizerId = cp.assignedOrganizerId;

          if (oldOrganizerId != newOrganizerId) {
            // Clear the old organizer's link (if there was one)
            if (oldOrganizerId != null) {
              await _clearOrganizerCheckpointLink(oldOrganizerId);
            }
            // Set the new organizer's link (if one is assigned)
            if (newOrganizerId != null) {
              await _setOrganizerCheckpointLink(newOrganizerId, cp.id);
            }
          } else if (newOrganizerId != null && existing == null) {
            // New checkpoint with organizer assigned from the start
            await _setOrganizerCheckpointLink(newOrganizerId, cp.id);
          }

          // ── 2. Write checkpoint to local cache first ──────────────────────
          final cached = await LocalStorageService.instance
              .getCachedCheckpoints(widget.event.id);
          final List<Checkpoint> updated;
          if (existing == null) {
            updated = [...cached, cp];
          } else {
            updated = cached.map((c) => c.id == cp.id ? cp : c).toList();
          }
          await LocalStorageService.instance.cacheCheckpoints(updated);

          // ── 3. Persist to Supabase — report offline if fails ─────────────
          final ok = await _tryWrite(
            () => SupabaseService.instance.upsertCheckpoint(cp),
          );
          if (!ok) _showOfflineSnackBar('Checkpoint');

          await _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: RaidAppBar(
        title: 'Checkpoints',
        subtitle: widget.event.name,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.accent),
            onPressed: _addCheckpoint,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 48),
                      const SizedBox(height: 16),
                      Text(_error!,
                          style: const TextStyle(color: AppColors.textMuted),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _checkpoints.isEmpty
                  ? EmptyState(
                      icon: Icons.flag,
                      title: 'No checkpoints yet',
                      subtitle: 'Add checkpoints for this event',
                      action: ElevatedButton.icon(
                        onPressed: _addCheckpoint,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Checkpoint'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.accent,
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _checkpoints.length,
                        onReorder: (oldIndex, newIndex) async {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final cp = _checkpoints.removeAt(oldIndex);
                            _checkpoints.insert(newIndex, cp);
                            for (int i = 0; i < _checkpoints.length; i++) {
                              _checkpoints[i] =
                                  _checkpoints[i].copyWith(order: i + 1);
                            }
                          });
                          // Persist new order
                          for (final cp in _checkpoints) {
                            try {
                              await SupabaseService.instance
                                  .updateCheckpoint(cp);
                            } catch (_) {}
                          }
                          await LocalStorageService.instance
                              .cacheCheckpoints(_checkpoints);
                        },
                        itemBuilder: (_, i) => _buildRow(_checkpoints[i], i),
                      ),
                    ),
    );
  }

  Widget _buildRow(Checkpoint cp, int i) {
    return Container(
      key: ValueKey(cp.id),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.drag_handle, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 10),
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
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    )),
                if (cp.assignedOrganizerName != null)
                  Row(children: [
                    const Icon(Icons.person,
                        color: AppColors.textMuted, size: 12),
                    const SizedBox(width: 4),
                    Text(cp.assignedOrganizerName!,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ])
                else if (cp.assignedOrganizerId != null)
                  Row(children: [
                    const Icon(Icons.person_outline,
                        color: AppColors.textMuted, size: 12),
                    const SizedBox(width: 4),
                    const Text('Organizer assigned',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ]),
                if (cp.latitude != null && cp.longitude != null)
                  Row(children: [
                    const Icon(Icons.location_on,
                        color: AppColors.textMuted, size: 12),
                    const SizedBox(width: 4),
                    Text(
                        '${cp.latitude!.toStringAsFixed(4)}, '
                        '${cp.longitude!.toStringAsFixed(4)}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 10)),
                  ]),
                if (cp.description != null && cp.description!.isNotEmpty)
                  Text(cp.description!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon:
                const Icon(Icons.edit, color: AppColors.textMuted, size: 18),
            onPressed: () => _editCheckpoint(cp),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppColors.error, size: 18),
            onPressed: () => _deleteCheckpoint(cp),
          ),
        ],
      ),
    );
  }
}

// ── Checkpoint Form Sheet ─────────────────────────────────────
class _CheckpointFormSheet extends StatefulWidget {
  final Checkpoint? existing;
  final RallyEvent event;
  final List<AppUser> organizers;
  final int nextOrder;
  final Function(Checkpoint) onSaved;

  const _CheckpointFormSheet({
    required this.event,
    required this.organizers,
    required this.nextOrder,
    required this.onSaved,
    this.existing,
  });

  @override
  State<_CheckpointFormSheet> createState() => _CheckpointFormSheetState();
}

class _CheckpointFormSheetState extends State<_CheckpointFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lonCtrl;
  String? _selectedOrganizerId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _descCtrl =
        TextEditingController(text: widget.existing?.description ?? '');
    _latCtrl = TextEditingController(
        text: widget.existing?.latitude?.toString() ?? '');
    _lonCtrl = TextEditingController(
        text: widget.existing?.longitude?.toString() ?? '');
    _selectedOrganizerId = widget.existing?.assignedOrganizerId;
    // Validate existing organizer ID is still in list
    if (_selectedOrganizerId != null &&
        !widget.organizers.any((o) => o.id == _selectedOrganizerId)) {
      _selectedOrganizerId = null;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    setState(() => _saving = true);

    final org = widget.organizers
        .where((o) => o.id == _selectedOrganizerId)
        .firstOrNull;

    final cp = Checkpoint(
      id: widget.existing?.id ?? const Uuid().v4(),
      eventId: widget.event.id,
      name: _nameCtrl.text.trim(),
      order: widget.existing?.order ?? widget.nextOrder,
      description: _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      latitude: double.tryParse(_latCtrl.text.trim()),
      longitude: double.tryParse(_lonCtrl.text.trim()),
      assignedOrganizerId: _selectedOrganizerId,
      assignedOrganizerName: org?.fullName ?? org?.username,
    );

    if (mounted) Navigator.of(context).pop();
    await widget.onSaved(cp);
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ───────────────────────────────────
              Row(
                children: [
                  Text(
                    isNew ? 'ADD CHECKPOINT' : 'EDIT CHECKPOINT',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Name ─────────────────────────────────────
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Checkpoint Name *',
                  prefixIcon: Icon(Icons.flag),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name required' : null,
              ),
              const SizedBox(height: 14),

              // ── Description ───────────────────────────────
              TextFormField(
                controller: _descCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 14),

              // ── Coordinates ───────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lonCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Organizer Dropdown ────────────────────────
              if (widget.organizers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber,
                          color: AppColors.warning, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No organizers found. Create organizer users first.',
                          style: TextStyle(
                              color: AppColors.warning, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedOrganizerId,
                  style: const TextStyle(color: AppColors.textPrimary),
                  dropdownColor: AppColors.surface,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Assign Organizer (optional)',
                    prefixIcon: Icon(Icons.shield),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('— None —',
                          style:
                              TextStyle(color: AppColors.textMuted)),
                    ),
                    ...widget.organizers.map((o) => DropdownMenuItem<String>(
                          value: o.id,
                          child: Text(
                            o.fullName != null && o.fullName!.isNotEmpty
                                ? '${o.fullName} (@${o.username})'
                                : '@${o.username}',
                            style: const TextStyle(
                                color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (v) =>
                      setState(() => _selectedOrganizerId = v),
                ),
              const SizedBox(height: 28),

              // ── Save Button ───────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          isNew ? 'ADD CHECKPOINT' : 'SAVE CHANGES',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cps = await SupabaseService.instance.getCheckpoints(widget.event.id);
    final orgs = await SupabaseService.instance.getOrganizers();
    setState(() {
      _checkpoints = cps;
      _organizers = orgs;
      _loading = false;
    });
  }

  void _addCheckpoint() => _showDialog(null);
  void _editCheckpoint(Checkpoint cp) => _showDialog(cp);

  Future<void> _deleteCheckpoint(Checkpoint cp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Checkpoint'),
        content: Text('Delete "${cp.name}"?'),
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
    if (confirm == true) {
      await SupabaseService.instance.deleteCheckpoint(cp.id);
      await _load();
    }
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
          if (existing == null) {
            await SupabaseService.instance.createCheckpoint(cp);
          } else {
            await SupabaseService.instance.updateCheckpoint(cp);
          }
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
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
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _checkpoints.length,
                  onReorder: (oldIndex, newIndex) async {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final cp = _checkpoints.removeAt(oldIndex);
                      _checkpoints.insert(newIndex, cp);
                      for (int i = 0; i < _checkpoints.length; i++) {
                        final updated = Checkpoint(
                          id: _checkpoints[i].id,
                          eventId: _checkpoints[i].eventId,
                          name: _checkpoints[i].name,
                          order: i + 1,
                          description: _checkpoints[i].description,
                          latitude: _checkpoints[i].latitude,
                          longitude: _checkpoints[i].longitude,
                          assignedOrganizerId: _checkpoints[i].assignedOrganizerId,
                          assignedOrganizerName: _checkpoints[i].assignedOrganizerName,
                        );
                        _checkpoints[i] = updated;
                        SupabaseService.instance.updateCheckpoint(updated);
                      }
                    });
                  },
                  itemBuilder: (_, i) => _buildRow(_checkpoints[i], i),
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
              border:
                  Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
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
                    const Icon(Icons.person, color: AppColors.textMuted, size: 12),
                    const SizedBox(width: 4),
                    Text(cp.assignedOrganizerName!,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ]),
                if (cp.latitude != null)
                  Row(children: [
                    const Icon(Icons.location_on,
                        color: AppColors.textMuted, size: 12),
                    const SizedBox(width: 4),
                    Text(
                        '${cp.latitude!.toStringAsFixed(4)}, ${cp.longitude!.toStringAsFixed(4)}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 10)),
                  ]),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.textMuted, size: 18),
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

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _latCtrl = TextEditingController(
        text: widget.existing?.latitude?.toString() ?? '');
    _lonCtrl = TextEditingController(
        text: widget.existing?.longitude?.toString() ?? '');
    _selectedOrganizerId = widget.existing?.assignedOrganizerId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final org = widget.organizers
        .where((o) => o.id == _selectedOrganizerId)
        .firstOrNull;
    final cp = Checkpoint(
      id: widget.existing?.id ?? const Uuid().v4(),
      eventId: widget.event.id,
      name: _nameCtrl.text.trim(),
      order: widget.existing?.order ?? widget.nextOrder,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      latitude: double.tryParse(_latCtrl.text),
      longitude: double.tryParse(_lonCtrl.text),
      assignedOrganizerId: _selectedOrganizerId,
      assignedOrganizerName: org?.fullName ?? org?.username,
    );
    widget.onSaved(cp);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
                  Text(
                    widget.existing == null
                        ? 'ADD CHECKPOINT'
                        : 'EDIT CHECKPOINT',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Checkpoint Name',
                  prefixIcon: Icon(Icons.flag),
                ),
                validator: (v) => v!.isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 14),
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
              DropdownButtonFormField<String>(
                value: _selectedOrganizerId,
                style: const TextStyle(color: AppColors.textPrimary),
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(
                  labelText: 'Assign Organizer (optional)',
                  prefixIcon: Icon(Icons.person),
                ),
                items: [
                  const DropdownMenuItem(
                      value: null,
                      child: Text('None',
                          style: TextStyle(color: AppColors.textMuted))),
                  ...widget.organizers.map((o) => DropdownMenuItem(
                        value: o.id,
                        child: Text(o.fullName ?? o.username,
                            style: const TextStyle(
                                color: AppColors.textPrimary)),
                      )),
                ],
                onChanged: (v) => setState(() => _selectedOrganizerId = v),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(
                    widget.existing == null ? 'ADD CHECKPOINT' : 'SAVE',
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

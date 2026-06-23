import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'checkpoints_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<RallyEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final events = await FirebaseService.instance.getEvents();
    setState(() {
      _events = events
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _loading = false;
    });
  }

  void _createEvent() {
    _showEventDialog(null);
  }

  void _editEvent(RallyEvent event) {
    _showEventDialog(event);
  }

  Future<void> _activateEvent(RallyEvent event) async {
    await FirebaseService.instance.activateEvent(event.id);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${event.name} is now the active event'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _deleteEvent(RallyEvent event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Delete "${event.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseService.instance.deleteEvent(event.id);
      await _load();
    }
  }

  void _showEventDialog(RallyEvent? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _EventFormSheet(
        existing: existing,
        onSaved: (event) async {
          if (existing == null) {
            await FirebaseService.instance.createEvent(event);
          } else {
            await FirebaseService.instance.updateEvent(event);
          }
          await _load();
        },
      ),
    );
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
                : _events.isEmpty
                    ? EmptyState(
                        icon: Icons.event,
                        title: 'No events yet',
                        action: ElevatedButton.icon(
                          onPressed: _createEvent,
                          icon: const Icon(Icons.add),
                          label: const Text('Create Event'),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.accent,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _events.length,
                          itemBuilder: (_, i) =>
                              _buildEventCard(_events[i]),
                        ),
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
          const Icon(Icons.event, color: AppColors.accent, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('EVENTS',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                )),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.accent),
            onPressed: _createEvent,
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(RallyEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: event.isActive
            ? AppColors.accent.withValues(alpha: 0.08)
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: event.isActive
              ? AppColors.accent.withValues(alpha: 0.5)
              : AppColors.border,
          width: event.isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(event.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          )),
                    ),
                    if (event.isActive)
                      const StatusBadge(
                          label: 'ACTIVE', color: AppColors.success),
                  ],
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.location_on,
                      color: AppColors.textMuted, size: 13),
                  const SizedBox(width: 4),
                  Text(event.location,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ]),
                Row(children: [
                  const Icon(Icons.calendar_today,
                      color: AppColors.textMuted, size: 13),
                  const SizedBox(width: 4),
                  Text(DateFormat('dd MMMM yyyy').format(event.date),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ]),
              ],
            ),
          ),
          Container(
            height: 1,
            color: AppColors.border,
          ),
          Row(
            children: [
              _action('CHECKPOINTS', Icons.flag, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckpointsScreen(event: event),
                  ),
                );
              }),
              _vDivider(),
              _action('EDIT', Icons.edit, () => _editEvent(event)),
              _vDivider(),
              if (!event.isActive)
                _action('ACTIVATE', Icons.play_arrow, () => _activateEvent(event),
                    color: AppColors.success)
              else
                _action('ACTIVE', Icons.check_circle, null,
                    color: AppColors.success),
              _vDivider(),
              _action('DELETE', Icons.delete_outline,
                  () => _deleteEvent(event),
                  color: AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _action(String label, IconData icon, VoidCallback? onTap,
      {Color color = AppColors.textSecondary}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: onTap != null ? color : AppColors.textMuted,
                  size: 18),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: onTap != null ? color : AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vDivider() {
    return Container(width: 1, height: 44, color: AppColors.border);
  }
}

class _EventFormSheet extends StatefulWidget {
  final RallyEvent? existing;
  final Function(RallyEvent) onSaved;

  const _EventFormSheet({required this.onSaved, this.existing});

  @override
  State<_EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<_EventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _descCtrl;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _locationCtrl =
        TextEditingController(text: widget.existing?.location ?? '');
    _descCtrl =
        TextEditingController(text: widget.existing?.description ?? '');
    _selectedDate = widget.existing?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final event = RallyEvent(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      date: _selectedDate,
      location: _locationCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      isActive: widget.existing?.isActive ?? false,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    widget.onSaved(event);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: AppTheme.darkTheme,
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
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
                    widget.existing == null ? 'CREATE EVENT' : 'EDIT EVENT',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
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
              _field('Event Name', _nameCtrl, icon: Icons.event),
              const SizedBox(height: 14),
              _field('Location', _locationCtrl, icon: Icons.location_on),
              const SizedBox(height: 14),
              _field('Description', _descCtrl,
                  icon: Icons.description, maxLines: 3),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: AppColors.textMuted, size: 18),
                      const SizedBox(width: 10),
                      Text(DateFormat('dd MMMM yyyy').format(_selectedDate),
                          style: const TextStyle(
                              color: AppColors.textPrimary)),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down,
                          color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(
                    widget.existing == null ? 'CREATE EVENT' : 'SAVE CHANGES',
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

  Widget _field(String label, TextEditingController ctrl,
      {IconData? icon, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
      validator: (v) => (v == null || v.isEmpty) ? '$label required' : null,
    );
  }
}

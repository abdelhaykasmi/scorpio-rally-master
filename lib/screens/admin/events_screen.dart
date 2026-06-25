import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../services/local_storage_service.dart';
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
    try {
      // Merge Supabase events into local cache (never overwrites with empty)
      final remote = await SupabaseService.instance.getEvents();
      await LocalStorageService.instance.mergeEvents(remote);
      // Always read from local cache as source of truth
      final events = await LocalStorageService.instance.getCachedEvents();
      if (mounted) {
        setState(() {
          _events = events..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _loading = false;
        });
      }
    } catch (_) {
      // Supabase completely unreachable — read local cache directly
      try {
        final events = await LocalStorageService.instance.getCachedEvents();
        if (mounted) {
          setState(() {
            _events = events..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  void _createEvent() {
    _showEventDialog(null);
  }

  void _editEvent(RallyEvent event) {
    _showEventDialog(event);
  }

  Future<void> _activateEvent(RallyEvent event) async {
    // Local cache first — activate this one, deactivate all others
    final cached = await LocalStorageService.instance.getCachedEvents();
    await LocalStorageService.instance.cacheEvents(
        cached.map((e) => e.copyWith(isActive: e.id == event.id)).toList());
    // Supabase best-effort
    SupabaseService.instance.activateEvent(event.id).catchError((_) {});
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

  Future<void> _deactivateEvent(RallyEvent event) async {
    // Local cache first — mark this event as inactive
    final cached = await LocalStorageService.instance.getCachedEvents();
    await LocalStorageService.instance.cacheEvents(
        cached.map((e) => e.id == event.id ? e.copyWith(isActive: false) : e).toList());
    // Supabase best-effort
    SupabaseService.instance.deactivateEvent(event.id).catchError((_) {});
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event deactivated'),
          backgroundColor: AppColors.warning,
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
      // Local cache first
      final cached = await LocalStorageService.instance.getCachedEvents();
      await LocalStorageService.instance.cacheEvents(
          cached.where((e) => e.id != event.id).toList());
      // Supabase best-effort
      SupabaseService.instance.deleteEvent(event.id).catchError((_) {});
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
          // ── Inject GPX bytes → data URI BEFORE local cache write ──
          // event.gpxFileUrl is null when a new file was picked (the form sets
          // gpxFileUrl=null and puts raw bytes in gpxBytes so the service can
          // upload them). We must convert bytes → data URI here so local cache
          // always has a downloadable URL — independently of Supabase success.
          final resolved = injectGpxBytes(event);

          // Write resolved event (with data URI) to local cache first
          final cached = await LocalStorageService.instance.getCachedEvents();
          final List<RallyEvent> updated;
          if (existing == null) {
            updated = [...cached, resolved];
          } else {
            updated = cached.map((e) => e.id == resolved.id ? resolved : e).toList();
          }
          await LocalStorageService.instance.cacheEvents(updated);

          // Persist to Supabase best-effort (injectGpxBytes called again inside)
          if (existing == null) {
            SupabaseService.instance.createEvent(event).catchError((_) {});
          } else {
            SupabaseService.instance.updateEvent(event).catchError((_) {});
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
                _action('DEACTIVATE', Icons.stop_circle, () => _deactivateEvent(event),
                    color: AppColors.warning),
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

  // GPX file state
  String? _gpxFileName;
  Uint8List? _gpxBytes;
  bool _clearGpx = false;  // set true when user removes existing GPX

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _locationCtrl =
        TextEditingController(text: widget.existing?.location ?? '');
    _descCtrl =
        TextEditingController(text: widget.existing?.description ?? '');
    _selectedDate = widget.existing?.date ?? DateTime.now();
    // Keep existing file name for display
    _gpxFileName = widget.existing?.gpxFileName;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickGpxFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gpx', 'GPX'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _gpxBytes = result.files.single.bytes;
        _gpxFileName = result.files.single.name;
        _clearGpx = false;
      });
    }
  }

  void _removeGpxFile() {
    setState(() {
      _gpxBytes = null;
      _gpxFileName = null;
      _clearGpx = true;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Determine final GPX values
    final existingUrl = _clearGpx ? null : widget.existing?.gpxFileUrl;
    final existingName = _clearGpx ? null : widget.existing?.gpxFileName;

    final event = RallyEvent(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      date: _selectedDate,
      location: _locationCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      isActive: widget.existing?.isActive ?? false,
      gpxBytes: _gpxBytes,                             // new file bytes (or null)
      gpxFileName: _gpxBytes != null ? _gpxFileName    // new pick
          : existingName,                              // keep existing
      gpxFileUrl: _gpxBytes != null ? null             // will be set by service
          : existingUrl,                               // keep or clear
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
              const SizedBox(height: 14),
              // ── GPX file picker ──────────────────────────────
              const Text('GPX Route File',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  )),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _gpxFileName != null
                      ? AppColors.accent.withValues(alpha: 0.08)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _gpxFileName != null
                        ? AppColors.accent.withValues(alpha: 0.5)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _gpxFileName != null
                          ? Icons.route
                          : Icons.upload_file,
                      color: _gpxFileName != null
                          ? AppColors.accent
                          : AppColors.textMuted,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _gpxFileName ?? 'No file selected',
                        style: TextStyle(
                          color: _gpxFileName != null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_gpxFileName != null) ...
                      [
                        GestureDetector(
                          onTap: _pickGpxFile,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('REPLACE',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                        ),
                        GestureDetector(
                          onTap: _removeGpxFile,
                          child: const Icon(Icons.close,
                              color: AppColors.error, size: 18),
                        ),
                      ]
                    else
                      GestureDetector(
                        onTap: _pickGpxFile,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('BROWSE',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                      ),
                  ],
                ),
              ),
              if (_gpxBytes != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.success, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '${(_gpxBytes!.length / 1024).toStringAsFixed(1)} KB ready to save',
                        style: const TextStyle(
                            color: AppColors.success, fontSize: 11),
                      ),
                    ],
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

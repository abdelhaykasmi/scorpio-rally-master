import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/app_settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late TextEditingController _titleCtrl;

  // local ephemeral state while the user drags
  late double _partScale;
  late double _orgScale;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppSettingsProvider>();
    _partScale = s.fontScaleParticipant;
    _orgScale  = s.fontScaleOrganizer;
    _titleCtrl = TextEditingController(text: s.appTitle);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  // ── Logo picker ───────────────────────────────────────────
  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    if (!mounted) return;
    await context.read<AppSettingsProvider>().setLogo(
          file.bytes!,
          file.name,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logo updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  // ── Color picker ──────────────────────────────────────────
  void _showColorPicker(bool isPrimary) {
    final s = context.read<AppSettingsProvider>();
    final current = isPrimary ? s.primaryColor : s.secondaryColor;
    showDialog(
      context: context,
      builder: (_) => _ColorPickerDialog(
        initial: current,
        title: isPrimary ? 'Primary / Accent Color' : 'Secondary / Gradient Color',
        onSelected: (color) {
          if (isPrimary) {
            s.setPrimaryColor(color);
          } else {
            s.setSecondaryColor(color);
          }
        },
      ),
    );
  }

  // ── Save title ────────────────────────────────────────────
  void _saveTitle() {
    context.read<AppSettingsProvider>().setAppTitle(_titleCtrl.text);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('App title updated'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettingsProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: RaidAppBar(
        title: 'App Settings',
        subtitle: 'Branding, colors & text size',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── APP TITLE ──────────────────────────────────────
          const SectionHeader(title: 'App Title', padding: EdgeInsets.only(bottom: 10)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Title shown on splash & login',
                    prefixIcon: Icon(Icons.title),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _saveTitle(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _saveTitle,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 18),
                ),
                child: const Text('SAVE'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── LOGO ──────────────────────────────────────────
          const SectionHeader(title: 'Event / App Logo', padding: EdgeInsets.only(bottom: 10)),
          CarbonCard(
            child: Column(
              children: [
                // Preview
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: s.hasLogo
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              s.logoBytes!,
                              fit: BoxFit.contain,
                              height: 110,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_outlined,
                                  color: AppColors.textMuted, size: 40),
                              const SizedBox(height: 8),
                              const Text('No logo uploaded',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                if (s.logoName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.image, color: AppColors.textMuted, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(s.logoName!,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickLogo,
                        icon: const Icon(Icons.upload, size: 18),
                        label: Text(s.hasLogo ? 'REPLACE LOGO' : 'UPLOAD LOGO'),
                      ),
                    ),
                    if (s.hasLogo) ...[
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await s.clearLogo();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Logo removed')),
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('REMOVE'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Displayed on splash screen, login screen and participant home.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── BRAND COLORS ──────────────────────────────────
          const SectionHeader(title: 'Brand Colors', padding: EdgeInsets.only(bottom: 10)),
          CarbonCard(
            child: Column(
              children: [
                _colorRow(
                  label: 'Primary / Accent Color',
                  subtitle: 'Buttons, badges, highlights',
                  color: s.primaryColor,
                  onTap: () => _showColorPicker(true),
                ),
                const Divider(height: 20),
                _colorRow(
                  label: 'Secondary / Gradient Color',
                  subtitle: 'Gradient endpoints, shadows',
                  color: s.secondaryColor,
                  onTap: () => _showColorPicker(false),
                ),
                const SizedBox(height: 12),
                // Live gradient preview
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: s.accentGradient,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Text('GRADIENT PREVIEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        )),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── FONT SIZE ─────────────────────────────────────
          const SectionHeader(title: 'Text Size', padding: EdgeInsets.only(bottom: 10)),
          CarbonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Participant
                _fontSlider(
                  label: 'Participant Text Size',
                  icon: Icons.person,
                  value: _partScale,
                  onChanged: (v) => setState(() => _partScale = v),
                  onChangeEnd: (v) {
                    context.read<AppSettingsProvider>().setFontScaleParticipant(v);
                  },
                ),
                const SizedBox(height: 8),
                _fontPreview(_partScale, 'Carlos Sainz Jr.  ·  BIB #001'),
                const Divider(height: 28),
                // Organizer
                _fontSlider(
                  label: 'Organizer / Marshal Text Size',
                  icon: Icons.shield,
                  value: _orgScale,
                  onChanged: (v) => setState(() => _orgScale = v),
                  onChangeEnd: (v) {
                    context.read<AppSettingsProvider>().setFontScaleOrganizer(v);
                  },
                ),
                const SizedBox(height: 8),
                _fontPreview(_orgScale, 'Marshal Alpha  ·  CP1 — Dune Gateway'),
                const SizedBox(height: 12),
                // Reset button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _partScale = 1.0;
                        _orgScale  = 1.0;
                      });
                      context.read<AppSettingsProvider>().setFontScaleParticipant(1.0);
                      context.read<AppSettingsProvider>().setFontScaleOrganizer(1.0);
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset to default'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── RESET ALL ─────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _confirmReset,
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('RESET ALL SETTINGS TO DEFAULT'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _colorRow({
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.edit, color: AppColors.textMuted, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fontSlider({
    required String label,
    required IconData icon,
    required double value,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    final pct = ((value - 0.8) / 0.6 * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$pct%',
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: AppColors.border,
            thumbColor: AppColors.accent,
            overlayColor: AppColors.accent.withValues(alpha: 0.15),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: 0.8,
            max: 1.4,
            divisions: 12,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Smaller', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            const Text('Normal',  style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            const Text('Larger',  style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _fontPreview(double scale, String sample) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        sample,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14 * scale,
        ),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset All Settings'),
        content: const Text(
            'This will reset logo, colors and font sizes back to defaults. Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (ok != true) return;
    final s = context.read<AppSettingsProvider>();
    await s.clearLogo();
    await s.setPrimaryColor(const Color(0xFFE53935));
    await s.setSecondaryColor(const Color(0xFFB71C1C));
    await s.setFontScaleParticipant(1.0);
    await s.setFontScaleOrganizer(1.0);
    await s.setAppTitle('RAID');
    setState(() {
      _partScale = 1.0;
      _orgScale  = 1.0;
      _titleCtrl.text = 'RAID';
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All settings reset to defaults'),
            backgroundColor: AppColors.success),
      );
    }
  }
}

// ── Inline Color Picker Dialog ────────────────────────────
class _ColorPickerDialog extends StatefulWidget {
  final Color initial;
  final String title;
  final ValueChanged<Color> onSelected;

  const _ColorPickerDialog({
    required this.initial,
    required this.title,
    required this.onSelected,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selected;
  late TextEditingController _hexCtrl;

  // Curated palette relevant to rally / adventure sports
  static const _palette = [
    // Reds
    Color(0xFFE53935), Color(0xFFB71C1C), Color(0xFFEF5350), Color(0xFFFF1744),
    // Oranges
    Color(0xFFFF6F00), Color(0xFFFF8F00), Color(0xFFFFA000), Color(0xFFFF6D00),
    // Yellows
    Color(0xFFFFD600), Color(0xFFFDD835), Color(0xFFFFFF00), Color(0xFFFFEA00),
    // Greens
    Color(0xFF2E7D32), Color(0xFF388E3C), Color(0xFF43A047), Color(0xFF00C853),
    // Blues
    Color(0xFF1565C0), Color(0xFF1976D2), Color(0xFF0288D1), Color(0xFF0097A7),
    // Purples
    Color(0xFF6A1B9A), Color(0xFF7B1FA2), Color(0xFF8E24AA), Color(0xFFAB47BC),
    // Grays / Metallics
    Color(0xFF37474F), Color(0xFF455A64), Color(0xFF546E7A), Color(0xFF78909C),
    // Whites / Creams
    Color(0xFFFFFFFF), Color(0xFFF5F5F5), Color(0xFFECEFF1), Color(0xFFCFD8DC),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _hexCtrl  = TextEditingController(text: _colorToHex(_selected));
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  void _applyHex(String hex) {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      try {
        setState(() {
          _selected = Color(int.parse('FF$clean', radix: 16));
          _hexCtrl.text = clean.toUpperCase();
        });
      } catch (_) {}
    }
  }

  static String _colorToHex(Color c) {
    return c.value.toRadixString(16).substring(2).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Live preview swatch
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: _selected,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
            ),
            const SizedBox(height: 14),
            // Hex input
            TextField(
              controller: _hexCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Hex code (e.g. E53935)',
                prefixText: '# ',
                prefixStyle: TextStyle(color: AppColors.textMuted),
              ),
              maxLength: 6,
              onSubmitted: _applyHex,
              onChanged: _applyHex,
            ),
            const SizedBox(height: 12),
            // Palette grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _palette.map((c) {
                final isSelected = c.value == _selected.value;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selected = c;
                      _hexCtrl.text = _colorToHex(c);
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : Colors.transparent,
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: c.withValues(alpha: 0.6),
                                blurRadius: 6,
                              )
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSelected(_selected);
            Navigator.pop(context);
          },
          child: const Text('APPLY'),
        ),
      ],
    );
  }
}

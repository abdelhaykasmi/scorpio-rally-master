import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/qr_helper.dart';
import '../../widgets/common_widgets.dart';

class QRScannerScreen extends StatefulWidget {
  final Checkpoint checkpoint;
  final RallyEvent event;
  final VoidCallback onPassageRecorded;

  const QRScannerScreen({
    super.key,
    required this.checkpoint,
    required this.event,
    required this.onPassageRecorded,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  bool _isScanned = false;
  Map<String, dynamic>? _scannedData;
  AppUser? _foundParticipant;
  CheckpointPassage? _duplicatePassage;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _isScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() => _isProcessing = true);

    final raw = barcode!.rawValue!;
    final data = QRHelper.parseQRData(raw);

    if (data == null) {
      setState(() {
        _error = 'Invalid QR code. Not a RAID participant code.';
        _isProcessing = false;
      });
      return;
    }

    final pid = data['pid']?.toString();
    final eid = data['eid']?.toString();

    if (pid == null || eid == null) {
      setState(() {
        _error = 'QR code missing required fields.';
        _isProcessing = false;
      });
      return;
    }

    if (eid != widget.event.id) {
      setState(() {
        _error = 'This QR code is for a different event.';
        _isProcessing = false;
      });
      return;
    }

    // Look up participant
    final participant = await FirebaseService.instance.getUserById(pid);
    if (participant == null) {
      setState(() {
        _error = 'Participant not found in system.';
        _isProcessing = false;
      });
      return;
    }

    // Check for duplicate
    final duplicate = await FirebaseService.instance.findDuplicate(
        pid, widget.checkpoint.id, widget.event.id);

    _controller.stop();

    setState(() {
      _scannedData = data;
      _foundParticipant = participant;
      _duplicatePassage = duplicate;
      _isScanned = true;
      _isProcessing = false;
      _error = null;
    });
  }

  Future<void> _confirmPassage() async {
    if (_foundParticipant == null) return;
    final now = DateTime.now();
    final passage = CheckpointPassage(
      id: const Uuid().v4(),
      eventId: widget.event.id,
      checkpointId: widget.checkpoint.id,
      checkpointName: widget.checkpoint.name,
      participantId: _foundParticipant!.id,
      participantName: _foundParticipant!.fullName ?? _foundParticipant!.username,
      bibNumber: _foundParticipant!.bibNumber ?? 'N/A',
      localTime: now,
      utcTime: now.toUtc(),
      syncStatus: SyncStatus.pending,
    );

    await FirebaseService.instance.recordPassage(passage);

    // Try to sync immediately
    await FirebaseService.instance.syncPendingPassages();

    widget.onPassageRecorded();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Passage recorded — ${_foundParticipant!.fullName ?? ''} at ${DateFormat('HH:mm:ss').format(now)}'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _resetScan() {
    setState(() {
      _isScanned = false;
      _isProcessing = false;
      _scannedData = null;
      _foundParticipant = null;
      _duplicatePassage = null;
      _error = null;
    });
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('QR SCANNER',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            Text(widget.checkpoint.name,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: _isScanned ? _buildResultView() : _buildScannerView(),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
        ),
        // Overlay frame
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(
                  color: AppColors.accent, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // Corner decorators
                _corner(Alignment.topLeft),
                _corner(Alignment.topRight),
                _corner(Alignment.bottomLeft),
                _corner(Alignment.bottomRight),
              ],
            ),
          ),
        ),
        // Instructions
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child: Column(
            children: [
              if (_error != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13))),
                      TextButton(
                        onPressed: () => setState(() => _error = null),
                        child: const Text('OK',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Align QR code within the frame',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              if (_isProcessing) ...[
                const SizedBox(height: 12),
                const CircularProgressIndicator(color: AppColors.accent),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _corner(Alignment alignment) {
    final isTop = alignment == Alignment.topLeft ||
        alignment == Alignment.topRight;
    final isLeft = alignment == Alignment.topLeft ||
        alignment == Alignment.bottomLeft;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(
            painter: _CornerPainter(isTop: isTop, isLeft: isLeft),
          ),
        ),
      ),
    );
  }

  Widget _buildResultView() {
    final p = _foundParticipant;
    if (p == null) return const SizedBox.shrink();

    final isDuplicate = _duplicatePassage != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDuplicate
                    ? AppColors.error.withValues(alpha: 0.15)
                    : AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDuplicate
                      ? AppColors.error.withValues(alpha: 0.5)
                      : AppColors.success.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isDuplicate
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle,
                    color: isDuplicate ? AppColors.error : AppColors.success,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDuplicate ? '⚠️ DUPLICATE SCAN' : '✅ SCAN SUCCESSFUL',
                          style: TextStyle(
                            color: isDuplicate
                                ? AppColors.error
                                : AppColors.success,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                        if (isDuplicate && _duplicatePassage != null)
                          Text(
                            '${p.fullName ?? p.username} was already recorded at ${DateFormat('HH:mm:ss').format(_duplicatePassage!.localTime)}',
                            style: TextStyle(
                              color: AppColors.error.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Participant card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent,
                        ),
                        child: Center(
                          child: Text(
                            '#${p.bibNumber ?? '?'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.fullName ?? p.username,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                )),
                            Text(p.nationality ?? '',
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  InfoRow(
                    label: 'Bike',
                    value: '${p.bikeBrand ?? ''} ${p.bikeModel ?? ''}',
                    icon: Icons.two_wheeler,
                  ),
                  InfoRow(
                    label: 'Engine',
                    value: '${p.engineSize ?? '—'}cc',
                    icon: Icons.speed,
                  ),
                  InfoRow(
                    label: 'Checkpoint',
                    value: widget.checkpoint.name,
                    icon: Icons.flag,
                  ),
                  InfoRow(
                    label: 'Timestamp',
                    value: DateFormat('HH:mm:ss · dd MMM yyyy')
                        .format(DateTime.now()),
                    icon: Icons.access_time,
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Action buttons
            if (!isDuplicate) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _confirmPassage,
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: const Text('CONFIRM PASSAGE',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Duplicate detected — passage not recorded again',
                        style: TextStyle(
                            color: AppColors.error.withValues(alpha: 0.9),
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _resetScan,
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                label: const Text('SCAN NEXT',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;
  const _CornerPainter({required this.isTop, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final path = Path();
    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

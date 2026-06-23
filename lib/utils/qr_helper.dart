import 'dart:convert';

class QRHelper {
  /// Generate QR data payload for a participant + event
  static String generateQRData({
    required String participantId,
    required String fullName,
    required String bibNumber,
    required String bikeBrand,
    required String bikeModel,
    required String eventId,
    required String eventName,
  }) {
    final payload = {
      'pid': participantId,
      'name': fullName,
      'bib': bibNumber,
      'bike': '$bikeBrand $bikeModel',
      'eid': eventId,
      'event': eventName,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    return base64Encode(utf8.encode(jsonEncode(payload)));
  }

  /// Parse QR data payload
  static Map<String, dynamic>? parseQRData(String data) {
    try {
      final decoded = utf8.decode(base64Decode(data));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      // Try plain JSON
      try {
        return jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
  }

  static String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }
}

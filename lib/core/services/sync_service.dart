import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../services/database_service.dart';
import '../../models/evidence_model.dart';

class SyncService {
  static String _laptopIp   = '';
  static int    _port        = 8765;
  static bool   _isSyncing   = false;

  static void configure(String ip, {int port = 8765}) {
    _laptopIp = ip;
    _port     = port;
  }

  static bool get isConfigured => _laptopIp.isNotEmpty;

  // ── AUTO SYNC ──────────────────────────────
  static Future<void> syncPending() async {
    if (_isSyncing || !isConfigured) return;
    _isSyncing = true;
    try {
      final pending = await DatabaseService.instance.getUnsyncedEvidence();
      for (final evidence in pending) {
        await _syncEvidence(evidence);
      }
    } finally {
      _isSyncing = false;
    }
  }

  static Future<bool> _syncEvidence(EvidenceModel evidence) async {
    try {
      final uri = Uri.parse('http://$_laptopIp:$_port/receive');
      final request = http.MultipartRequest('POST', uri);

      // Add metadata
      request.fields['metadata'] = jsonEncode(evidence.toMap());

      // Add photo
      if (evidence.photoPath != null &&
          File(evidence.photoPath!).existsSync()) {
        request.files.add(await http.MultipartFile.fromPath(
          'photo', evidence.photoPath!,
          filename: p.basename(evidence.photoPath!),
        ));
      }

      // Add video
      if (evidence.videoPath != null &&
          File(evidence.videoPath!).existsSync()) {
        request.files.add(await http.MultipartFile.fromPath(
          'video', evidence.videoPath!,
          filename: p.basename(evidence.videoPath!),
        ));
      }

      // Add voice note
      if (evidence.voiceNotePath != null &&
          File(evidence.voiceNotePath!).existsSync()) {
        request.files.add(await http.MultipartFile.fromPath(
          'voice', evidence.voiceNotePath!,
          filename: p.basename(evidence.voiceNotePath!),
        ));
      }

      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        await DatabaseService.instance.markEvidenceSynced(evidence.id);
        await DatabaseService.instance.log(
          'EVIDENCE SYNCED',
          details: evidence.evidenceNumber,
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

// ── PING LAPTOP ────────────────────────────
static Future<bool> pingLaptop() async {
  try {
    final client = HttpClient();

    final request = await client.getUrl(
      Uri.parse('http://$_laptopIp:$_port/ping'),
    );

    final response = await request.close();

    print("STATUS = ${response.statusCode}");

    return response.statusCode == 200;
  } catch (e) {
    print("SOCKET ERROR = $e");
    return false;
  }
}
  // Fetch full annotated scene image from laptop
static Future<Uint8List?> fetchFullImage() async {
  try {
    final response = await http.get(
      Uri.parse('http://$_laptopIp:8765/full_image'),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) return response.bodyBytes;
  } catch (_) {}
  return null;
}

// Fetch detection list
static Future<Map<String, dynamic>> fetchDetections() async {
  try {
    final response = await http.get(
      Uri.parse('http://$_laptopIp:8765/detections'),
    ).timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
  } catch (_) {}
  return {};
}

// Fetch individual crop
static Future<Uint8List?> fetchCrop(String evidenceId) async {
  try {
    final response = await http.get(
      Uri.parse('http://$_laptopIp:8765/crop/$evidenceId'),
    ).timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) return response.bodyBytes;
  } catch (_) {}
  return null;
}

// Confirm evidence
static Future<bool> confirmEvidence(String evidenceId) async {
  try {
    final response = await http.post(
      Uri.parse('http://$_laptopIp:8765/confirm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': evidenceId}),
    ).timeout(const Duration(seconds: 5));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}

// Reject evidence
static Future<bool> rejectEvidence(String evidenceId) async {
  try {
    final response = await http.post(
      Uri.parse('http://$_laptopIp:8765/reject'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': evidenceId}),
    ).timeout(const Duration(seconds: 5));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}
}
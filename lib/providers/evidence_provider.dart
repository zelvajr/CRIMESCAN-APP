import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/evidence_model.dart';
import '../core/services/database_service.dart';
import '../core/services/hash_service.dart';
import '../core/services/gps_service.dart';
import '../core/services/sync_service.dart';
import '../core/utils/evidence_numbering.dart';

class EvidenceProvider extends ChangeNotifier {
  List<EvidenceModel> _evidence = [];
  bool _loading = false;

  List<EvidenceModel> get evidence => _evidence;
  bool get loading => _loading;
  int get count => _evidence.length;

  Future<void> loadEvidence(String caseId) async {
    _loading = true;
    notifyListeners();
    _evidence = await DatabaseService.instance.getEvidenceForCase(caseId);
    _loading = false;
    notifyListeners();
  }

  Future<EvidenceModel?> addEvidence({
    required String caseId,
    required String category,
    required String collectedBy,
    String? photoPath,
    String? videoPath,
    String? voiceNotePath,
    String? notes,
  }) async {
    try {
      final position = await GpsService.getCurrentPosition();
      final filePath = photoPath ?? videoPath ?? '';
      final hash     = filePath.isNotEmpty
          ? await HashService.hashFile(filePath)
          : HashService.hashString(DateTime.now().toIso8601String());

      final evidence = EvidenceModel(
        id:             const Uuid().v4(),
        caseId:         caseId,
        evidenceNumber: EvidenceNumbering.generate(_evidence.length),
        category:       category,
        photoPath:      photoPath,
        videoPath:      videoPath,
        voiceNotePath:  voiceNotePath,
        notes:          notes,
        latitude:       position?.latitude,
        longitude:      position?.longitude,
        sha256Hash:     hash,
        collectedBy:    collectedBy,
        timestamp:      DateTime.now(),
      );

      await DatabaseService.instance.insertEvidence(evidence);
      await DatabaseService.instance.addToSyncQueue(evidence.id);
      await DatabaseService.instance.log(
        'EVIDENCE CAPTURED',
        details: '${evidence.evidenceNumber} | $category',
        officer: collectedBy,
      );

      _evidence.add(evidence);
      notifyListeners();

      // Auto sync
      SyncService.syncPending();

      return evidence;
    } catch (_) {
      return null;
    }
  }

  Future<void> attachVoiceNote(
      String evidenceId, String voiceNotePath) async {
    final idx = _evidence.indexWhere((e) => e.id == evidenceId);
    if (idx == -1) return;
    await DatabaseService.instance.log(
      'VOICE NOTE ATTACHED',
      details: _evidence[idx].evidenceNumber,
    );
    notifyListeners();
  }

  void clear() {
    _evidence = [];
    notifyListeners();
  }
}
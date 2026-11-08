import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/case_model.dart';
import '../core/services/database_service.dart';
import '../core/services/gps_service.dart';

class CaseProvider extends ChangeNotifier {
  CaseModel? _activeCase;
  List<CaseModel> _cases = [];
  bool _loading = false;

  CaseModel? get activeCase => _activeCase;
  List<CaseModel> get cases => _cases;
  bool get loading => _loading;
  bool get hasActiveCase => _activeCase != null;

  Future<void> loadCases() async {
    _loading = true;
    notifyListeners();
    _cases = await DatabaseService.instance.getCases();
    _loading = false;
    notifyListeners();
  }

  Future<bool> createCase({
    required String caseNumber,
    required String firNumber,
    required String officerName,
    required String agency,
    required String location,
    required String sceneType,
    required String notes,
  }) async {
    try {
      final position = await GpsService.getCurrentPosition();
      final newCase  = CaseModel(
        id:          const Uuid().v4(),
        caseNumber:  caseNumber,
        firNumber:   firNumber,
        officerName: officerName,
        agency:      agency,
        location:    location,
        sceneType:   sceneType,
        notes:       notes,
        latitude:    position?.latitude,
        longitude:   position?.longitude,
        createdAt:   DateTime.now(),
      );
      await DatabaseService.instance.insertCase(newCase);
      await DatabaseService.instance.log(
        'CASE CREATED',
        details:  caseNumber,
        officer:  officerName,
      );
      _activeCase = newCase;
      _cases.insert(0, newCase);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void setActiveCase(CaseModel c) {
    _activeCase = c;
    notifyListeners();
  }
}
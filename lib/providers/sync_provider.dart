import 'package:flutter/foundation.dart';
import '../core/services/sync_service.dart';

class SyncProvider extends ChangeNotifier {
  String _laptopIp  = '';
  bool   _connected = false;
  bool   _syncing   = false;
  final int    _pendingCount = 0;

  String get laptopIp   => _laptopIp;
  bool get connected    => _connected;
  bool get syncing      => _syncing;
  int  get pendingCount => _pendingCount;

  Future<void> configure(String ip) async {
  print("CONFIGURE CALLED: $ip");

  _laptopIp = ip;

  SyncService.configure(ip);

  print("PINGING LAPTOP...");

  _connected = await SyncService.pingLaptop();

  print("CONNECTED = $_connected");

  notifyListeners();
}

  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;
    notifyListeners();
    await SyncService.syncPending();
    _syncing = false;
    notifyListeners();
  }

  Future<void> checkConnection() async {
  if (_laptopIp.isEmpty) return;

  _connected = await SyncService.pingLaptop();
  notifyListeners();
}
}
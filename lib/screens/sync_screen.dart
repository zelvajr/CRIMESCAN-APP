import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../core/constants/app_colors.dart';
import '../providers/sync_provider.dart';
import '../providers/evidence_provider.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});
  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _ipCtrl = TextEditingController();
  Timer? _pingTimer;

  @override
  void initState() {
    super.initState();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      context.read<SyncProvider>().checkConnection();
    });
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _pingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync      = context.watch<SyncProvider>();
    final evidence  = context.watch<EvidenceProvider>().evidence;
    final unsynced  = evidence.where((e) => !e.synced).length;
    final synced    = evidence.where((e) => e.synced).length;

    return Scaffold(
      appBar: AppBar(title: const Text('SYNC CENTER')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection config
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LAPTOP CONNECTION',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _ipCtrl,
                        style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: '192.168.x.x',
                          labelText: 'Laptop IP Address',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () =>
                          sync.configure(_ipCtrl.text.trim()),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10)),
                      child: const Text('CONNECT',
                        style: TextStyle(fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Icon(Icons.circle,
                      size: 10,
                      color: sync.connected
                          ? AppColors.green : AppColors.amber),
                    const SizedBox(width: 8),
                    Text(
                      sync.connected
                          ? 'LAPTOP CONNECTED — Auto sync active'
                          : 'NOT CONNECTED — Configure IP above',
                      style: TextStyle(
                        color: sync.connected
                            ? AppColors.green : AppColors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stats
            Row(children: [
              _statTile('PENDING', '$unsynced', AppColors.amber),
              const SizedBox(width: 12),
              _statTile('SYNCED',  '$synced',   AppColors.green),
              const SizedBox(width: 12),
              _statTile('TOTAL',
                  '${evidence.length}', AppColors.cyan),
            ]),
            const SizedBox(height: 20),

            // Sync button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: sync.syncing || !sync.connected
                    ? null : sync.syncNow,
                icon: sync.syncing
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background))
                    : const Icon(Icons.sync, size: 20),
                label: Text(
                  sync.syncing
                      ? 'SYNCING...'
                      : 'SYNC NOW  ($unsynced pending)',
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 20),

            // Evidence sync list
            const Text('EVIDENCE SYNC STATUS',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2)),
            const SizedBox(height: 12),

            Expanded(
              child: ListView.separated(
                itemCount: evidence.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final e = evidence[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      Icon(
                        e.synced
                            ? Icons.cloud_done
                            : Icons.cloud_upload_outlined,
                        color: e.synced
                            ? AppColors.green : AppColors.amber,
                        size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.evidenceNumber,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                            Text('${e.category}  ·  '
                              '${e.timestamp.toString().substring(11,19)}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10)),
                          ],
                        ),
                      ),
                      Text(
                        e.synced ? 'SYNCED' : 'PENDING',
                        style: TextStyle(
                          color: e.synced
                              ? AppColors.green : AppColors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                    ]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) =>
    Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace')),
        ]),
      ),
    );
}
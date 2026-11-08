import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/case_provider.dart';
import '../providers/evidence_provider.dart';
import '../providers/sync_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final caseId = context.read<CaseProvider>().activeCase?.id;
      if (caseId != null) {
        context.read<EvidenceProvider>().loadEvidence(caseId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeCase = context.watch<CaseProvider>().activeCase;
    final evCount    = context.watch<EvidenceProvider>().count;
    final syncing    = context.watch<SyncProvider>().syncing;
    final connected  = context.watch<SyncProvider>().connected;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SPIDERCAM FORENSIC'),
            if (activeCase != null)
              Text(activeCase.caseNumber,
                style: const TextStyle(
                    color: AppColors.amber, fontSize: 11)),
          ],
        ),
        actions: [
          // Connection status
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: connected
                  ? AppColors.green.withValues(alpha: 0.15)
                  : AppColors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: connected ? AppColors.green : AppColors.amber),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle,
                  size: 8,
                  color: connected ? AppColors.green : AppColors.amber),
              const SizedBox(width: 5),
              Text(connected ? 'SYNCED' : 'LOCAL',
                style: TextStyle(
                  color: connected ? AppColors.green : AppColors.amber,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                )),
            ]),
          ),
        ],
      ),
      body: Column(
        children: [
          // Case banner
          if (activeCase != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              color: AppColors.surface,
              child: Row(children: [
                const Icon(Icons.folder_open,
                    color: AppColors.cyan, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activeCase.caseNumber,
                        style: const TextStyle(
                          color: AppColors.cyan,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                      Text(
                        '${activeCase.officerName}  ·  ${activeCase.location}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11)),
                    ],
                  ),
                ),
                Text('$evCount items',
                  style: const TextStyle(
                    color: AppColors.amber, fontSize: 12)),
              ]),
            ),

          // Stats row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              _statCard('EVIDENCE', '$evCount', AppColors.cyan),
              const SizedBox(width: 12),
              _statCard('STATUS',
                  connected ? 'SYNCED' : 'LOCAL',
                  connected ? AppColors.green : AppColors.amber),
              const SizedBox(width: 12),
              _statCard('CHAIN', 'ACTIVE', AppColors.green),
            ]),
          ),

          // Main navigation grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  _navCard('◉', 'LIVE FEED',
                    'Scene monitoring\nSpiderCam stream',
                    AppColors.cyan, '/live'),
                  _navCard('◎', 'CAPTURE',
                    'Photo & video\nEvidence documentation',
                    AppColors.green, '/capture'),
                  _navCard('▦', 'GALLERY',
                    'Evidence review\nGPS & metadata',
                    AppColors.amber, '/gallery'),
                  _navCard('🎙', 'VOICE NOTES',
                    'Annotate evidence\nAudio documentation',
                    AppColors.cyan, '/voice'),
                  _navCard('↗', 'SYNC',
                    'Laptop transfer\nAuto folder sync',
                    AppColors.green, '/sync'),
                  _navCard('🔍', 'EVIDENCE REVIEW',
                    'Confirm or reject\nAI detections',
                    AppColors.red, '/review'),
                  _navCard('📄', 'REPORT',
                    'Generate PDF\nChain of custody',
                    AppColors.amber, '/report'),
                ],
              ),
            ),
          ),

          // Bottom integrity bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            color: AppColors.surface,
            child: const Row(children: [
              Icon(Icons.verified_outlined,
                  color: AppColors.green, size: 14),
              SizedBox(width: 8),
              Text('SHA-256  ·  Chain of Custody Active  ·  '
                'SpiderCam Forensic Suite v2.1',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 10)),
              Spacer(),
              Text('M SELVAPRAKASH',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 10)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) =>
    Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace')),
          ],
        ),
      ),
    );

  Widget _navCard(String icon, String title, String subtitle,
      Color color, String route) =>
    InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: TextStyle(color: color, fontSize: 24)),
            const Spacer(),
            Text(title,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
}
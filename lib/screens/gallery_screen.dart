import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../core/constants/app_colors.dart';
import '../providers/evidence_provider.dart';
import '../models/evidence_model.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});
  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String _filter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final evidence = context.watch<EvidenceProvider>().evidence;
    final filtered = _filter == 'ALL'
        ? evidence
        : evidence.where((e) => e.category == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('EVIDENCE GALLERY  (${evidence.length})'),
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['ALL','WEAPON','BIOLOGICAL','TRACE',
                'SCENE OVERVIEW','OTHER'].map((f) {
                final active = f == _filter;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.cyan.withValues(alpha: 0.15)
                          : AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: active
                            ? AppColors.cyan : AppColors.border)),
                    child: Text(f,
                      style: TextStyle(
                        color: active
                            ? AppColors.cyan : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: active
                            ? FontWeight.w700 : FontWeight.normal)),
                  ),
                );
              }).toList(),
            ),
          ),

          // Grid
          Expanded(
            child: filtered.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined,
                        color: AppColors.textMuted, size: 40),
                      SizedBox(height: 12),
                      Text('NO EVIDENCE CAPTURED YET',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          letterSpacing: 1.5)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.82,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _EvidenceCard(
                    evidence: filtered[i],
                    onTap: () => _showDetail(filtered[i]),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  void _showDetail(EvidenceModel e) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2))),
            ),
            Row(children: [
              Text(e.evidenceNumber,
                style: const TextStyle(
                  color: AppColors.cyan,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
              const Spacer(),
              _catChip(e.category),
            ]),
            const SizedBox(height: 16),
            if (e.photoPath != null && File(e.photoPath!).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(e.photoPath!),
                    height: 200, fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            _detailRow('Collected by', e.collectedBy),
            _detailRow('Timestamp',
                e.timestamp.toString().substring(0,19)),
            if (e.latitude != null)
              _detailRow('GPS',
                  '${e.latitude!.toStringAsFixed(6)}, '
                  '${e.longitude!.toStringAsFixed(6)}'),
            _detailRow('SHA-256',
                '${e.sha256Hash.substring(0,16)}...'),
            _detailRow('Synced', e.synced ? 'YES ✔' : 'PENDING'),
            if (e.notes != null && e.notes!.isNotEmpty)
              _detailRow('Notes', e.notes!),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/voice',
                        arguments: e.id);
                  },
                  icon: const Icon(Icons.mic, size: 16),
                  label: const Text('ADD VOICE NOTE'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cyan,
                    side: const BorderSide(color: AppColors.cyan)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _catChip(String cat) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: (AppColors.categoryColors[cat] ?? AppColors.textMuted)
          .withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppColors.categoryColors[cat] ?? AppColors.textMuted)),
    child: Text(cat,
      style: TextStyle(
        color: AppColors.categoryColors[cat] ?? AppColors.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700)),
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label,
            style: const TextStyle(
              color: AppColors.textMuted, fontSize: 11))),
        Expanded(
          child: Text(value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontFamily: 'monospace'))),
      ],
    ),
  );
}

class _EvidenceCard extends StatelessWidget {
  final EvidenceModel evidence;
  final VoidCallback  onTap;
  const _EvidenceCard({required this.evidence, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final catColor =
        AppColors.categoryColors[evidence.category] ?? AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10)),
                child: evidence.photoPath != null &&
                        File(evidence.photoPath!).existsSync()
                    ? Image.file(File(evidence.photoPath!),
                        fit: BoxFit.cover,
                        width: double.infinity)
                    : Container(
                        color: const Color(0xFF0A1020),
                        child: Center(
                          child: Icon(
                            evidence.videoPath != null
                                ? Icons.videocam
                                : Icons.image_not_supported,
                            color: AppColors.textMuted, size: 28))),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(evidence.evidenceNumber,
                      style: TextStyle(
                        color: catColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
                    const Spacer(),
                    if (evidence.synced)
                      const Icon(Icons.cloud_done,
                          color: AppColors.green, size: 12)
                    else
                      const Icon(Icons.cloud_upload_outlined,
                          color: AppColors.amber, size: 12),
                  ]),
                  const SizedBox(height: 2),
                  Text(evidence.category,
                    style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 9)),
                  Text(
                    evidence.timestamp.toString().substring(11,19),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontFamily: 'monospace')),
                  if (evidence.voiceNotePath != null)
                    const Row(children: [
                      Icon(Icons.mic, color: AppColors.cyan, size: 10),
                      SizedBox(width: 3),
                      Text('Voice note',
                        style: TextStyle(
                          color: AppColors.cyan, fontSize: 9)),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
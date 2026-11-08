import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../core/constants/app_colors.dart';
import '../core/services/sync_service.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<Map<String, dynamic>> _detections = [];
  Uint8List? _fullImage;
  bool _loading = true;
  String _status = 'Fetching from laptop...';

  @override
  void initState() {
    super.initState();
    _fetchFromLaptop();
  }

  Future<void> _fetchFromLaptop() async {
    setState(() { _loading = true; _status = 'Connecting to laptop...'; });
    try {
      // Fetch full annotated image
      final fullImg = await SyncService.fetchFullImage();
      // Fetch detection list
      final data    = await SyncService.fetchDetections();
      final dets    = List<Map<String, dynamic>>.from(
          data['detections'] ?? []);
      final confirmed = List<String>.from(data['confirmed'] ?? []);
      final rejected  = List<String>.from(data['rejected']  ?? []);

      // Mark status on each detection
      for (final d in dets) {
        if (confirmed.contains(d['id'])) {
          d['status'] = 'CONFIRMED';
        } else if (rejected.contains(d['id'])) d['status'] = 'REJECTED';
        else                                  d['status'] = 'PENDING';
      }

      setState(() {
        _fullImage  = fullImg;
        _detections = dets;
        _loading    = false;
        _status     = '${dets.length} potential evidence items';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status  = 'ERROR: $e';
      });
    }
  }

  Future<void> _confirm(String id) async {
    await SyncService.confirmEvidence(id);
    setState(() {
      final d = _detections.firstWhere((d) => d['id'] == id,
          orElse: () => {});
      if (d.isNotEmpty) d['status'] = 'CONFIRMED';
    });
  }

  Future<void> _reject(String id) async {
    await SyncService.rejectEvidence(id);
    setState(() {
      final d = _detections.firstWhere((d) => d['id'] == id,
          orElse: () => {});
      if (d.isNotEmpty) d['status'] = 'REJECTED';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('EVIDENCE REVIEW'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _fetchFromLaptop,
        ),
      ],
    ),
    body: _loading
      ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.cyan),
              SizedBox(height: 16),
              Text('Fetching from laptop...',
                style: TextStyle(color: AppColors.textSecondary)),
            ],
          ))
      : Column(
          children: [
            // Status bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              color: AppColors.surface,
              child: Row(children: [
                const Icon(Icons.radar, color: AppColors.cyan, size: 14),
                const SizedBox(width: 8),
                Text(_status,
                  style: const TextStyle(
                    color: AppColors.cyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  '${_detections.where((d) => d["status"]=="CONFIRMED").length} confirmed  '
                  '${_detections.where((d) => d["status"]=="REJECTED").length} rejected',
                  style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 10)),
              ]),
            ),

            // Full scene image
            if (_fullImage != null)
              GestureDetector(
                onTap: () => _showFullImage(context),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(children: [
                      Image.memory(_fullImage!,
                        fit: BoxFit.cover,
                        width: double.infinity),
                      Positioned(
                        bottom: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4)),
                          child: const Text('FULL SCENE MAP — Tap to expand',
                            style: TextStyle(
                              color: AppColors.cyan,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),

            // Evidence list
            Expanded(
              child: _detections.isEmpty
                ? const Center(
                    child: Text('No detections — run AI Detection on laptop first',
                      style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                      textAlign: TextAlign.center))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: _detections.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _EvidenceReviewCard(
                          detection: _detections[i],
                          onConfirm: () => _confirm(_detections[i]['id']),
                          onReject:  () => _reject(_detections[i]['id']),
                        ),
                  ),
            ),
          ],
        ),
  );

  void _showFullImage(BuildContext context) {
    if (_fullImage == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.background,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          InteractiveViewer(
            child: Image.memory(_fullImage!)),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE',
              style: TextStyle(color: AppColors.cyan))),
        ]),
      ),
    );
  }
}

class _EvidenceReviewCard extends StatefulWidget {
  final Map<String, dynamic> detection;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  const _EvidenceReviewCard({
    required this.detection,
    required this.onConfirm,
    required this.onReject,
  });
  @override
  State<_EvidenceReviewCard> createState() => _EvidenceReviewCardState();
}

class _EvidenceReviewCardState extends State<_EvidenceReviewCard> {
  Uint8List? _cropBytes;
  bool _loadingCrop = true;

  @override
  void initState() {
    super.initState();
    _loadCrop();
  }

  Future<void> _loadCrop() async {
    final bytes = await SyncService.fetchCrop(widget.detection['id']);
    if (mounted) setState(() { _cropBytes = bytes; _loadingCrop = false; });
  }

  Color get _statusColor {
    switch (widget.detection['status']) {
      case 'CONFIRMED': return AppColors.green;
      case 'REJECTED':  return AppColors.red;
      default:          return AppColors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d      = widget.detection;
    final status = d['status'] as String? ?? 'PENDING';
    final conf   = (d['confidence'] as num?)?.toDouble() ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _statusColor.withValues(alpha: 0.4))),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10))),
          child: Row(children: [
            Text(d['id'] ?? '',
              style: TextStyle(
                color: _statusColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace')),
            const SizedBox(width: 10),
            Expanded(
              child: Text(d['label'] ?? '',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700))),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _statusColor)),
              child: Text(status,
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
            ),
          ]),
        ),

        // Content
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Crop image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 100, height: 80,
                  color: AppColors.surface,
                  child: _loadingCrop
                    ? const Center(
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.cyan)))
                    : _cropBytes != null
                        ? Image.memory(_cropBytes!,
                            fit: BoxFit.cover)
                        : const Icon(Icons.broken_image,
                            color: AppColors.textMuted),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow('Category', d['category'] ?? '—'),
                    _detailRow('Grid Ref', d['grid'] ?? '—'),
                    _detailRow('Confidence',
                        '${(conf * 100).toStringAsFixed(0)}%'),
                    const SizedBox(height: 8),

                    // Action buttons — only show if pending
                    if (status == 'PENDING')
                      Row(children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: widget.onConfirm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8),
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                            child: const Text('✔ CONFIRM'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: widget.onReject,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8),
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                            child: const Text('✕ REJECT'),
                          ),
                        ),
                      ])
                    else
                      // Already decided — show change option
                      TextButton(
                        onPressed: () {
                          if (status == 'CONFIRMED') {
                            widget.onReject();
                          } else {
                            widget.onConfirm();
                          }
                        },
                        child: Text(
                          status == 'CONFIRMED'
                              ? '↺ Mark as Rejected'
                              : '↺ Mark as Confirmed',
                          style: TextStyle(
                            color: _statusColor,
                            fontSize: 11)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      SizedBox(
        width: 80,
        child: Text(label,
          style: const TextStyle(
            color: AppColors.textMuted, fontSize: 10))),
      Text(value,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600)),
    ]),
  );
}
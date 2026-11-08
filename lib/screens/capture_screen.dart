import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../core/constants/app_colors.dart';
import '../providers/case_provider.dart';
import '../providers/evidence_provider.dart';
import '../models/evidence_model.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});
  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _picker        = ImagePicker();
  String _category     = 'SCENE OVERVIEW';
  File?  _lastCapture;
  bool   _capturing    = false;

  final List<String> _categories = [
    'WEAPON', 'BIOLOGICAL', 'TRACE', 'IMPRESSION',
    'DIGITAL', 'DOCUMENT', 'FIRE DEBRIS', 'TOOLMARK',
    'CONTROLLED SUBSTANCE', 'SCENE OVERVIEW', 'OTHER',
  ];

  Future<void> _capturePhoto() async {
    setState(() => _capturing = true);
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (xfile == null) return;
      _lastCapture = File(xfile.path);
      await _saveEvidence(photoPath: xfile.path);
    } finally {
      setState(() => _capturing = false);
    }
  }

  Future<void> _captureVideo() async {
    setState(() => _capturing = true);
    try {
      final xfile = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 10),
      );
      if (xfile == null) return;
      await _saveEvidence(videoPath: xfile.path);
    } finally {
      setState(() => _capturing = false);
    }
  }

  Future<void> _saveEvidence({
    String? photoPath, String? videoPath}) async {
    final caseProvider = context.read<CaseProvider>();
    final activeCase   = caseProvider.activeCase;
    if (activeCase == null) return;

    final evidence = await context.read<EvidenceProvider>().addEvidence(
      caseId:      activeCase.id,
      category:    _category,
      collectedBy: activeCase.officerName,
      photoPath:   photoPath,
      videoPath:   videoPath,
    );

    if (evidence != null && mounted) {
      _showCaptureSuccess(evidence);
    }
  }

  void _showCaptureSuccess(EvidenceModel evidence) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.green)),
        content: Row(children: [
          const Icon(Icons.check_circle_outline,
              color: AppColors.green, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(evidence.evidenceNumber,
                style: const TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
              Text('${evidence.category}  ·  SHA-256 verified',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11)),
            ],
          )),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              Navigator.pushNamed(context, '/voice',
                  arguments: evidence.id);
            },
            child: const Text('ADD VOICE',
              style: TextStyle(
                  color: AppColors.cyan, fontSize: 11)),
          ),
        ]),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final evCount = context.watch<EvidenceProvider>().count;
    return Scaffold(
      appBar: AppBar(title: const Text('EVIDENCE CAPTURE')),
      body: Column(
        children: [
          // Stats
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Row(children: [
              _badge('NEXT', 'E-${(evCount+1).toString().padLeft(3,"0")}',
                  AppColors.cyan),
              const SizedBox(width: 12),
              _badge('CAPTURED', '$evCount', AppColors.green),
              const SizedBox(width: 12),
              _badge('CATEGORY', _category.length > 8
                  ? _category.substring(0,8) : _category,
                  AppColors.amber),
            ]),
          ),

          // Preview
          Expanded(
            child: _lastCapture != null
              ? Stack(
                  children: [
                    Image.file(_lastCapture!,
                      fit: BoxFit.contain,
                      width: double.infinity),
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          'E-${(evCount).toString().padLeft(3,"0")}  ·  $_category',
                          style: const TextStyle(
                            color: AppColors.cyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                )
              : Container(
                  color: const Color(0xFF040710),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined,
                          color: Color(0xFF1A3858), size: 48),
                        SizedBox(height: 12),
                        Text('TAP CAPTURE TO BEGIN',
                          style: TextStyle(
                            color: Color(0xFF1A3858),
                            letterSpacing: 2,
                            fontSize: 12)),
                      ],
                    ),
                  ),
                ),
          ),

          // Category selector
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = cat == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.cyan.withValues(alpha: 0.15)
                          : AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.cyan : AppColors.border),
                    ),
                    child: Text(cat,
                      style: TextStyle(
                        color: selected
                            ? AppColors.cyan : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w700 : FontWeight.normal)),
                  ),
                );
              },
            ),
          ),

          // Capture buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _capturing ? null : _capturePhoto,
                  icon: _capturing
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background))
                      : const Icon(Icons.camera_alt, size: 20),
                  label: const Text('CAPTURE PHOTO'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _capturing ? null : _captureVideo,
                  icon: const Icon(Icons.videocam, size: 20),
                  label: const Text('CAPTURE VIDEO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
        const SizedBox(height: 2),
        Text(value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace')),
      ]),
    ),
  );
}
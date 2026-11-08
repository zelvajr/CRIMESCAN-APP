import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/case_provider.dart';
import '../models/case_model.dart';

class CaseInitScreen extends StatefulWidget {
  const CaseInitScreen({super.key});
  @override
  State<CaseInitScreen> createState() => _CaseInitScreenState();
}

class _CaseInitScreenState extends State<CaseInitScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _caseNoCtrl   = TextEditingController();
  final _firCtrl      = TextEditingController();
  final _officerCtrl  = TextEditingController();
  final _agencyCtrl   = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  String _sceneType   = 'INDOOR';
  bool _loading       = false;

  final List<String> _sceneTypes = [
    'INDOOR', 'OUTDOOR', 'VEHICLE', 'UNDERWATER',
    'ELEVATED', 'CONFINED SPACE', 'OTHER'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CaseProvider>().loadCases();
    });
  }

  @override
  void dispose() {
    _caseNoCtrl.dispose(); _firCtrl.dispose();
    _officerCtrl.dispose(); _agencyCtrl.dispose();
    _locationCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _createCase() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final success = await context.read<CaseProvider>().createCase(
      caseNumber:  _caseNoCtrl.text.trim(),
      firNumber:   _firCtrl.text.trim(),
      officerName: _officerCtrl.text.trim(),
      agency:      _agencyCtrl.text.trim(),
      location:    _locationCtrl.text.trim(),
      sceneType:   _sceneType,
      notes:       _notesCtrl.text.trim(),
    );
    setState(() => _loading = false);
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CaseProvider>().cases;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CASE INITIALISATION'),
        actions: [
          if (cases.isNotEmpty)
            TextButton(
              onPressed: () => _showExistingCases(cases),
              child: const Text('LOAD EXISTING',
                style: TextStyle(color: AppColors.amber, fontSize: 12)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('CASE INFORMATION'),
              const SizedBox(height: 12),
              _field(_caseNoCtrl,  'Case Number *',   'CS-2026-001'),
              const SizedBox(height: 12),
              _field(_firCtrl,     'FIR Number',      'FIR-2026-001'),
              const SizedBox(height: 12),
              _field(_officerCtrl, 'Officer Name *',  'M SELVAPRAKASH'),
              const SizedBox(height: 12),
              _field(_agencyCtrl,  'Agency / Unit',   'TN Police FSL'),
              const SizedBox(height: 20),
              _sectionLabel('SCENE INFORMATION'),
              const SizedBox(height: 12),
              _field(_locationCtrl,'Scene Location *','Address / Landmark'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _sceneType,
                decoration: const InputDecoration(labelText: 'Scene Type'),
                dropdownColor: AppColors.surfaceCard,
                style: const TextStyle(color: AppColors.textPrimary),
                items: _sceneTypes.map((t) => DropdownMenuItem(
                    value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _sceneType = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Initial Notes',
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _createCase,
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.background))
                      : const Text('INITIALISE CASE  ▶',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(children: [
                  Icon(Icons.shield_outlined,
                      color: AppColors.green, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SHA-256 chain of custody active from first capture',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
    style: const TextStyle(
      color: AppColors.textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
    ),
  );

  Widget _field(TextEditingController ctrl, String label,
      String hint) =>
    TextFormField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label, hintText: hint),
      style: const TextStyle(color: AppColors.textPrimary),
      validator: label.contains('*')
          ? (v) => v == null || v.isEmpty ? 'Required' : null
          : null,
    );

  void _showExistingCases(List<CaseModel> cases) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('EXISTING CASES',
              style: TextStyle(
                color: AppColors.cyan,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2)),
          ),
          ...cases.take(5).map((c) => ListTile(
            title: Text(c.caseNumber,
              style: const TextStyle(color: AppColors.textPrimary)),
            subtitle: Text('${c.officerName}  ·  ${c.location}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
            trailing: const Icon(Icons.arrow_forward_ios,
                color: AppColors.cyan, size: 14),
            onTap: () {
              context.read<CaseProvider>().setActiveCase(c);
              Navigator.of(context)
                ..pop()
                ..pushReplacementNamed('/home');
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
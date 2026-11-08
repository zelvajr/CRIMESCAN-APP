import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import '../core/constants/app_colors.dart';
import '../providers/evidence_provider.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});
  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  final _recorder     = AudioRecorder();
  final _player       = AudioPlayer();
  bool  _recording    = false;
  bool  _hasRecording = false;
  bool  _playing      = false;
  String? _recordPath;
  int   _seconds      = 0;
  Timer? _timer;
  final SpeechToText _speech = SpeechToText();

  String _transcript = '';

  bool _listening = false;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;
    final dir  = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    _recordPath = path;
    _seconds    = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });
    setState(() { _recording = true; _hasRecording = false; });
  }

  Future<void> _stopRecording() async {
    await _recorder.stop();
    _timer?.cancel();
    setState(() { _recording = false; _hasRecording = true; });
  }

  Future<void> _playRecording() async {
    if (_recordPath == null) return;
    setState(() => _playing = true);
    await _player.play(DeviceFileSource(_recordPath!));
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  Future<void> _startSpeechRecognition() async {

  bool available = await _speech.initialize();

  if (!available) return;

  setState(() {
    _listening = true;
    _transcript = '';
  });

  await _speech.listen(
    localeId: 'ta_IN',
    onResult: (result) {
      setState(() {
        _transcript = result.recognizedWords;
      });
    },
  );
}

Future<void> _stopSpeechRecognition() async {

  await _speech.stop();

  setState(() {
    _listening = false;
  });
}

  Future<void> _saveToEvidence() async {
    final evidenceId =
        ModalRoute.of(context)?.settings.arguments as String?;
    if (evidenceId == null || _recordPath == null) return;
    await context.read<EvidenceProvider>()
        .attachVoiceNote(evidenceId, _recordPath!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✔ Voice note saved to evidence'),
          backgroundColor: AppColors.surface),
      );
      Navigator.pop(context);
    }
  }

  String get _timeDisplay {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('VOICE ANNOTATION')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Timer display
            Text(_timeDisplay,
              style: TextStyle(
                color: _recording ? AppColors.red : AppColors.textMuted,
                fontSize: 48,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w300)),
            const SizedBox(height: 8),
            Text(
              _recording
                  ? '● RECORDING IN PROGRESS'
                  : _hasRecording
                      ? '✔ RECORDING COMPLETE'
                      : 'TAP TO BEGIN VOICE ANNOTATION',
              style: TextStyle(
                color: _recording
                    ? AppColors.red
                    : _hasRecording
                        ? AppColors.green : AppColors.textMuted,
                fontSize: 12,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 48),

            // Main record button
            GestureDetector(
              onTap: _recording ? _stopRecording : _startRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _recording
                      ? AppColors.red.withValues(alpha: 0.15)
                      : AppColors.cyan.withValues(alpha: 0.1),
                  border: Border.all(
                    color: _recording ? AppColors.red : AppColors.cyan,
                    width: 2.5)),
                child: Icon(
                  _recording ? Icons.stop : Icons.mic,
                  color: _recording ? AppColors.red : AppColors.cyan,
                  size: 40),
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _listening
                      ? _stopSpeechRecognition
                      : _startSpeechRecognition,
                  icon: Icon(
                    _listening ? Icons.stop : Icons.mic,
                  ),
                  label: Text(
                    _listening
                        ? 'STOP DICTATION'
                        : 'DICTATE NOTE',
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  _transcript.isEmpty
                      ? 'Speech transcript will appear here...'
                      : _transcript,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),

              const SizedBox(height: 20),
            // Playback and save
            if (_hasRecording) ...[
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                OutlinedButton.icon(
                  onPressed: _playing ? null : _playRecording,
                  icon: Icon(_playing ? Icons.stop : Icons.play_arrow,
                      size: 18),
                  label: Text(_playing ? 'PLAYING...' : 'PLAYBACK'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cyan,
                    side: const BorderSide(color: AppColors.cyan)),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _startRecording,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('RE-RECORD'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.amber,
                    side: const BorderSide(color: AppColors.amber)),
                ),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saveToEvidence,
                  child: const Text('SAVE TO EVIDENCE',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
                ),
              ),
            ],

            const SizedBox(height: 32),
            const Text(
              'Voice note will be attached to the selected\nevidence item and included in the report',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    ),
  );
}
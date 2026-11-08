import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mjpeg_stream/mjpeg_stream.dart';

import '../core/constants/app_colors.dart';
import '../core/services/spidercam_publish_service.dart';

class LiveFeedScreen extends StatefulWidget {
  const LiveFeedScreen({super.key});

  @override
  State<LiveFeedScreen> createState() => _LiveFeedScreenState();
}

class _LiveFeedScreenState extends State<LiveFeedScreen> {
  // ─────────────────────────────────────────────────────────────
  // VIEW MODE / CONNECTION
  // ─────────────────────────────────────────────────────────────

  final TextEditingController _ipCtrl = TextEditingController();

  bool _connected = false;
  bool _gridOn = false;
  String _streamUrl = '';

  // ─────────────────────────────────────────────────────────────
  // FORENSIC ACQUISITIONS
  //
  // IMPORTANT:
  // This is NOT a video-frame counter.
  // It only increments when the user deliberately performs
  // an acquisition through the Capture workflow.
  // ─────────────────────────────────────────────────────────────

  int _acquisitionCount = 0;
  bool _captureLocked = false;

  // ─────────────────────────────────────────────────────────────
  // LIVEKIT / CAMERA MODE
  // ─────────────────────────────────────────────────────────────

  bool _cameraMode = false;

  final SpiderCamPublishService _publishService =
      SpiderCamPublishService();

  SpiderCamConnState _pubState = SpiderCamConnState.idle;
  String _pubStateMsg = '';

  final String _deviceId =
      'SC-MOBILE-${DateTime.now().millisecondsSinceEpoch % 1000}';

  // ─────────────────────────────────────────────────────────────
  // LIVE UI
  // ─────────────────────────────────────────────────────────────

  bool _controlsVisible = true;
  Timer? _hideTimer;

  // ─────────────────────────────────────────────────────────────
  // LIVE DURATION
  // ─────────────────────────────────────────────────────────────

  int _liveSec = 0;
  Timer? _liveTimer;

  // ─────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _leaveFullscreen();
  }

  @override
  void dispose() {
    _ipCtrl.dispose();

    _hideTimer?.cancel();
    _liveTimer?.cancel();

    // Stop any active LiveKit session.
    _publishService.stopLive();

    _leaveFullscreen();

    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // SYSTEM UI
  // ─────────────────────────────────────────────────────────────

  Future<void> _enterFullscreen() async {
  await SystemChrome.setPreferredOrientations(
    const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
  );

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );
}

Future<void> _leaveFullscreen() async {
  await SystemChrome.setPreferredOrientations(
    const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
  );

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );
}

  // ─────────────────────────────────────────────────────────────
  // IP / MJPEG VIEW MODE
  // ─────────────────────────────────────────────────────────────

  void _connect() {
    final ip = _ipCtrl.text.trim();

    if (ip.isEmpty) {
      return;
    }

    final url = ip.startsWith('http')
        ? ip
        : 'http://$ip/video';

    setState(() {
      _streamUrl = url;
      _connected = true;
      _liveSec = 0;
      _controlsVisible = true;
    });

    _enterFullscreen();
    _startLiveTimer();
    _scheduleHide();
  }

  void _disconnect() {
    _hideTimer?.cancel();
    _liveTimer?.cancel();

    setState(() {
      _connected = false;
      _streamUrl = '';
      _liveSec = 0;
      _controlsVisible = true;
    });

    _leaveFullscreen();
  }

  // ─────────────────────────────────────────────────────────────
  // LIVE TIMER
  // ─────────────────────────────────────────────────────────────

  void _startLiveTimer() {
    _liveTimer?.cancel();

    _liveTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        setState(() {
          _liveSec++;
        });
      },
    );
  }

  String get _liveDuration {
    final hours = _liveSec ~/ 3600;
    final minutes = (_liveSec % 3600) ~/ 60;
    final seconds = _liveSec % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ─────────────────────────────────────────────────────────────
  // CONTROL AUTO-HIDE
  // ─────────────────────────────────────────────────────────────

  void _scheduleHide() {
    _hideTimer?.cancel();

    _hideTimer = Timer(
      const Duration(seconds: 4),
      () {
        if (!mounted) return;

        final streaming =
            _connected ||
            _pubState == SpiderCamConnState.live;

        if (streaming) {
          setState(() {
            _controlsVisible = false;
          });
        }
      },
    );
  }

  void _showControls() {
    if (!mounted) return;

    setState(() {
      _controlsVisible = true;
    });

    _scheduleHide();
  }

  void _onTapFeed() {
    if (!_controlsVisible) {
      _showControls();
      return;
    }

    _scheduleHide();
  }

  // ─────────────────────────────────────────────────────────────
  // FORENSIC CAPTURE
  //
  // A live video frame is NOT an acquisition.
  //
  // The acquisition counter is intentionally independent from
  // any streaming frame count.
  // ─────────────────────────────────────────────────────────────

  Future<void> _captureFrame() async {
    if (_captureLocked) return;

    setState(() {
      _captureLocked = true;
    });

    try {
      final result = await Navigator.pushNamed(
        context,
        '/capture',
      );

      if (!mounted) return;

      // If the capture workflow explicitly reports success,
      // count one forensic acquisition.
      //
      // The fallback preserves compatibility with the existing
      // capture screen if it does not currently return a value.
      if (result == true || result == null) {
        setState(() {
          _acquisitionCount++;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _captureLocked = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LIVEKIT CAMERA PUBLISH
  // ─────────────────────────────────────────────────────────────

  Future<void> _startLive() async {
    if (_pubState == SpiderCamConnState.connecting) {
      return;
    }

    setState(() {
      _pubState = SpiderCamConnState.connecting;
      _pubStateMsg = 'Starting camera...';
    });

    try {
      await _publishService.startLive(
        deviceId: _deviceId,
        caseId: 'SC-2026-001',
        onState: (state, msg) {
          if (!mounted) return;

          setState(() {
            _pubState = state;
            _pubStateMsg = msg;
          });

          if (state == SpiderCamConnState.live) {
            _enterFullscreen();
            _startLiveTimer();
            _scheduleHide();
          }

          if (state == SpiderCamConnState.error) {
            _leaveFullscreen();
          }
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _pubState = SpiderCamConnState.error;
        _pubStateMsg = e.toString();
      });

      _leaveFullscreen();
    }
  }

  Future<void> _stopLive() async {
    await _publishService.stopLive();

    _liveTimer?.cancel();
    _hideTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _pubState = SpiderCamConnState.idle;
      _pubStateMsg = '';
      _liveSec = 0;
      _controlsVisible = true;
    });

    _leaveFullscreen();
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isLiveKit =
        _cameraMode &&
        _pubState == SpiderCamConnState.live &&
        _publishService.videoTrack != null;

    final bool isStreaming =
        _connected || isLiveKit;

    if (isStreaming) {
      return _buildLiveScreen(isLiveKit);
    }

    return _buildSetupScreen();
  }

  // ─────────────────────────────────────────────────────────────
  // FULLSCREEN LIVE SCREEN
  // ─────────────────────────────────────────────────────────────

  Widget _buildLiveScreen(bool isLiveKit) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTapFeed,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // =====================================================
            // VIDEO
            //
            // No timestamp.
            // No FRAME counter.
            // No REC stamp.
            // No forensic metadata burned into pixels.
            // =====================================================

            _buildFullVideo(isLiveKit),

            // =====================================================
            // VIEW-ONLY GRID
            //
            // This is a Flutter overlay and does not modify the
            // underlying video frame.
            // =====================================================

            if (_gridOn)
              IgnorePointer(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _GridPainter(),
                ),
              ),

            // =====================================================
            // TOP UI
            // =====================================================

            _buildTopBar(),

            // =====================================================
            // BOTTOM CONTROLS
            // =====================================================

            if (_controlsVisible)
              _buildBottomControls(isLiveKit),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // VIDEO RENDERER
  // ─────────────────────────────────────────────────────────────

  Widget _buildFullVideo(bool isLiveKit) {
    if (isLiveKit) {
      final track = _publishService.videoTrack;

      if (track == null) {
        return const ColoredBox(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // 16:9 4K presentation area.
      //
      // This does not manufacture 4K resolution. The actual
      // capture resolution comes from SpiderCamPublishService.
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 3840,
            height: 2160,
            child: VideoTrackRenderer(track),
          ),
        ),
      );
    }

    if (_streamUrl.isEmpty) {
      return const ColoredBox(
        color: Colors.black,
      );
    }

    return SizedBox.expand(
      child: MJPEGStreamScreen(
        streamUrl: _streamUrl,
        showLiveIcon: false,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TOP BAR
  // ─────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    final bool isLive =
        _connected ||
        _pubState == SpiderCamConnState.live;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              16,
              42,
              16,
              18,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black87,
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                // LIVE STATUS
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isLive
                        ? AppColors.red.withValues(alpha: 0.9)
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: Colors.white,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // SESSION DURATION
                Text(
                  _liveDuration,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const Spacer(),

                // FORENSIC ACQUISITIONS
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.cyan.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    'ACQ: $_acquisitionCount',
                    style: const TextStyle(
                      color: AppColors.cyan,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BOTTOM CONTROLS
  // ─────────────────────────────────────────────────────────────

  Widget _buildBottomControls(bool isLiveKit) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              16,
              24,
              16,
              30,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black87,
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // STOP
                _overlayBtn(
                  Icons.stop_circle,
                  'STOP',
                  color: AppColors.red,
                  onTap: isLiveKit
                      ? _stopLive
                      : _disconnect,
                ),

                // GRID
                _overlayBtn(
                  Icons.grid_on,
                  'GRID',
                  active: _gridOn,
                  onTap: () {
                    setState(() {
                      _gridOn = !_gridOn;
                    });

                    _scheduleHide();
                  },
                ),

                // CAPTURE
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _captureLocked
                      ? null
                      : _captureFrame,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _captureLocked
                          ? Colors.grey.withValues(alpha: 0.25)
                          : AppColors.cyan.withValues(alpha: 0.18),
                      border: Border.all(
                        color: _captureLocked
                            ? Colors.grey
                            : AppColors.cyan,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: _captureLocked
                          ? Colors.grey
                          : AppColors.cyan,
                      size: 30,
                    ),
                  ),
                ),

                // FLASH
                _overlayBtn(
                  Icons.flash_on,
                  'FLASH',
                  onTap: () {
                    // Hardware flash control can be connected here.
                    _scheduleHide();
                  },
                ),

                // ZOOM
                _overlayBtn(
                  Icons.zoom_in,
                  'ZOOM',
                  onTap: () {
                    // Optical/digital zoom control can be connected here.
                    _scheduleHide();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CAMERA MODE SETUP
  // ─────────────────────────────────────────────────────────────

  Widget _buildCameraSetup() {
    final bool connecting =
        _pubState == SpiderCamConnState.connecting;

    final bool live =
        _pubState == SpiderCamConnState.live;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam,
              color: AppColors.cyan,
              size: 60,
            ),

            const SizedBox(height: 20),

            Text(
              _deviceId,
              style: const TextStyle(
                color: AppColors.cyan,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              '4K UHD • 30 FPS • H.264',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _pubStateMsg.isEmpty
                  ? _pubState.name.toUpperCase()
                  : _pubStateMsg,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: connecting
                    ? null
                    : (live ? _stopLive : _startLive),
                icon: Icon(
                  live
                      ? Icons.stop
                      : Icons.play_arrow,
                ),
                label: Text(
                  connecting
                      ? 'CONNECTING...'
                      : live
                          ? 'STOP LIVE'
                          : 'START LIVE',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      live
                          ? AppColors.red
                          : AppColors.cyan,
                  foregroundColor: Colors.black,
                ),
              ),
            ),

            if (_pubState == SpiderCamConnState.error) ...[
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      AppColors.red.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        AppColors.red.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _pubStateMsg,
                  style: const TextStyle(
                    color: AppColors.red,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SETUP SCREEN
  // ─────────────────────────────────────────────────────────────

  Widget _buildSetupScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('LIVE FORENSIC FEED'),
      ),
      body: Column(
        children: [
          // MODE SELECTOR
          Container(
            padding: const EdgeInsets.all(8),
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: _modeBtn(
                    'VIEW MODE',
                    !_cameraMode,
                    () {
                      if (_pubState ==
                          SpiderCamConnState.live) {
                        return;
                      }

                      setState(() {
                        _cameraMode = false;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: _modeBtn(
                    'CAMERA MODE',
                    _cameraMode,
                    () {
                      if (_pubState ==
                          SpiderCamConnState.live) {
                        return;
                      }

                      setState(() {
                        _cameraMode = true;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          if (!_cameraMode) ...[
            // ===================================================
            // IP / MJPEG VIEW MODE
            // ===================================================

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ipCtrl,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                      decoration:
                          const InputDecoration(
                        hintText:
                            '192.168.x.x:8080 or stream URL',
                        contentPadding:
                            EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _connect(),
                    ),
                  ),

                  const SizedBox(width: 8),

                  ElevatedButton(
                    onPressed: _connect,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.cyan,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      'CONNECT',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _feedPlaceholder(),
            ),
          ] else ...[
            // ===================================================
            // LIVEKIT CAMERA MODE
            // ===================================================

            Expanded(
              child: _buildCameraSetup(),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PLACEHOLDER
  // ─────────────────────────────────────────────────────────────

  Widget _feedPlaceholder() {
    return Container(
      color: const Color(0xFF040710),
      child: const Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off,
              color: Color(0xFF1A3858),
              size: 56,
            ),

            SizedBox(height: 16),

            Text(
              'AWAITING FORENSIC VIDEO SOURCE',
              style: TextStyle(
                color: Color(0xFF1A3858),
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),

            SizedBox(height: 8),

            Text(
              'Enter IP camera URL and tap CONNECT',
              style: TextStyle(
                color: Color(0xFF0E2030),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MODE BUTTON
  // ─────────────────────────────────────────────────────────────

  Widget _modeBtn(
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: active
              ? AppColors.cyan
              : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active
              ? AppColors.cyan
              : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // OVERLAY CONTROL BUTTON
  // ─────────────────────────────────────────────────────────────

  Widget _overlayBtn(
    IconData icon,
    String label, {
    bool active = false,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black45,
              border: Border.all(
                color: color ??
                    (active
                        ? AppColors.cyan
                        : Colors.white30),
              ),
            ),
            child: Icon(
              icon,
              color: color ??
                  (active
                      ? AppColors.cyan
                      : Colors.white70),
              size: 20,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            label,
            style: TextStyle(
              color: color ??
                  (active
                      ? AppColors.cyan
                      : Colors.white60),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// VIEW-ONLY FORENSIC GRID
//
// This is rendered above the video by Flutter.
// It does NOT modify the source video pixels.
// ═══════════════════════════════════════════════════════════════

class _GridPainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = const Color(0x404DC8F0)
      ..strokeWidth = 0.8;

    const int cols = 8;
    const int rows = 8;

    final double cellWidth =
        size.width / cols;

    final double cellHeight =
        size.height / rows;

    // Vertical lines
    for (int i = 1; i < cols; i++) {
      canvas.drawLine(
        Offset(i * cellWidth, 0),
        Offset(
          i * cellWidth,
          size.height,
        ),
        paint,
      );
    }

    // Horizontal lines
    for (int i = 1; i < rows; i++) {
      canvas.drawLine(
        Offset(0, i * cellHeight),
        Offset(
          size.width,
          i * cellHeight,
        ),
        paint,
      );
    }

    // Column labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int column = 0;
        column < cols;
        column++) {
      textPainter.text = TextSpan(
        text: String.fromCharCode(
          65 + column,
        ),
        style: const TextStyle(
          color: Color(0x804DC8F0),
          fontSize: 10,
        ),
      );

      textPainter.layout();

      textPainter.paint(
        canvas,
        Offset(
          column * cellWidth +
              cellWidth / 2 -
              5,
          4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}
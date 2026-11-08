import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:livekit_client/livekit_client.dart';

/// Connection state for the SpiderCam live camera publisher.
enum SpiderCamConnState {
  idle,
  connecting,
  live,
  reconnecting,
  error,
}

/// Low-latency LiveKit camera publisher.
///
/// Design goals:
/// - minimum practical glass-to-glass latency
/// - hardware H.264 where the platform supports it
/// - 30 FPS priority
/// - no simulcast
/// - no application-level frame queue
/// - fast room/publisher setup
/// - automatic recovery from temporary network loss
///
/// IMPORTANT:
/// This is the LIVE PREVIEW profile.
///
/// It intentionally does NOT represent the maximum forensic acquisition
/// resolution of the physical camera. Evidence acquisition should be handled
/// separately from the real-time operator preview.
class SpiderCamPublishConfig {
  final String apiBaseUrl;
  final String sharedKey;

  const SpiderCamPublishConfig({
    required this.apiBaseUrl,
    required this.sharedKey,
  });

  factory SpiderCamPublishConfig.fromEnvironment() {
    return const SpiderCamPublishConfig(
      apiBaseUrl: String.fromEnvironment('SPIDERCAM_API_BASE_URL'),
      sharedKey: String.fromEnvironment('SPIDERCAM_SHARED_KEY'),
    );
  }

  void validate() {
    if (apiBaseUrl.trim().isEmpty) {
      throw StateError(
        'SpiderCam backend URL is not configured. '
        'Set SPIDERCAM_API_BASE_URL when building the app.',
      );
    }

    if (sharedKey.trim().isEmpty) {
      throw StateError(
        'SpiderCam backend shared key is not configured. '
        'Set SPIDERCAM_SHARED_KEY through a secure build-time secret store.',
      );
    }
  }
}

class SpiderCamPublishService {
  // ===========================================================================
  // BACKEND CONFIGURATION
  // ===========================================================================

  final SpiderCamPublishConfig _config;

  SpiderCamPublishService({
    SpiderCamPublishConfig? config,
  }) : _config = config ?? SpiderCamPublishConfig.fromEnvironment();

  // ===========================================================================
  // LOW-LATENCY LIVE VIDEO PROFILE
  // ===========================================================================

  /// Live operator preview:
  ///
  /// 1920 × 1080
  /// 30 FPS
  ///
  /// We deliberately don't push 4K through the realtime path.
  ///
  /// 4K remains appropriate for forensic acquisition, but the live operator
  /// path should prioritize capture/encode/network/decode latency.
  static const VideoParameters _kLiveCameraParams = VideoParameters(
    dimensions: VideoDimensionsPresets.h1080_169,
    encoding: VideoEncoding(
      maxBitrate: 4 * 1000 * 1000,
      maxFramerate: 30,
    ),
  );

  /// Explicit sender encoding.
  ///
  /// This prevents the publisher from silently choosing an unnecessarily
  /// aggressive bitrate for the realtime stream.
  static const VideoEncoding _kLiveVideoEncoding = VideoEncoding(
    maxBitrate: 4 * 1000 * 1000,
    maxFramerate: 30,
  );

  static const String _kVideoCodec = 'h264';

  // ===========================================================================
  // INTERNAL STATE
  // ===========================================================================

  Room? _room;
  LocalVideoTrack? _videoTrack;
  EventsListener<RoomEvent>? _listener;

  bool _busy = false;
  bool _stoppingIntentionally = false;

  // Used to prevent an old asynchronous start operation from becoming
  // authoritative after a stop/restart.
  int _sessionGeneration = 0;

  // ===========================================================================
  // PUBLIC ACCESSORS
  // ===========================================================================

  /// Current local camera track.
  LocalVideoTrack? get videoTrack => _videoTrack;

  /// Current LiveKit room.
  Room? get room => _room;

  /// Whether a publishing session currently exists.
  bool get isLive => _room != null && _videoTrack != null;

  /// Live preview width.
  int get requestedWidth => _kLiveCameraParams.dimensions.width;

  /// Live preview height.
  int get requestedHeight => _kLiveCameraParams.dimensions.height;

  /// Live preview FPS.
  int get requestedFps => _kLiveCameraParams.encoding?.maxFramerate ?? 30;

  /// Live preview bitrate.
  int get requestedBitrate =>
      _kLiveCameraParams.encoding?.maxBitrate ?? 4000000;

  /// Codec used by the live publisher.
  String get videoCodec => _kVideoCodec;

  // ===========================================================================
  // START
  // ===========================================================================

  Future<void> startLive({
    required String deviceId,
    required String caseId,
    required void Function(
      SpiderCamConnState state,
      String msg,
    ) onState,
  }) async {
    if (_busy || _room != null) {
      return;
    }

    _busy = true;
    _stoppingIntentionally = false;

    final int generation = ++_sessionGeneration;

    try {
      // -----------------------------------------------------------------------
      // 1. TOKEN
      // -----------------------------------------------------------------------

      onState(
        SpiderCamConnState.connecting,
        'Requesting live access…',
      );

      final identity = '$deviceId-${DateTime.now().millisecondsSinceEpoch}';

      final tokenResponse = await _fetchToken(
        deviceId: deviceId,
        caseId: caseId,
        identity: identity,
      );

      _assertSessionIsCurrent(generation);

      // -----------------------------------------------------------------------
      // 2. CREATE ROOM
      // -----------------------------------------------------------------------

      onState(
        SpiderCamConnState.connecting,
        'Preparing low-latency connection…',
      );

      final room = Room(
        roomOptions: const RoomOptions(
          // We have one primary operator stream.
          adaptiveStream: false,

          // No simulcast layers.
          dynacast: false,

          // Optimize publication setup.
          fastPublish: true,
        ),
      );

      _room = room;

      _listener = room.createListener();

      _registerRoomEvents(
        room: room,
        onState: onState,
      );

      // -----------------------------------------------------------------------
      // 3. PREPARE CONNECTION
      // -----------------------------------------------------------------------
      //
      // LiveKit exposes prepareConnection() to reduce connection setup time.
      //
      // It doesn't reduce steady-state glass-to-glass latency, but it reduces
      // the time between START and the stream becoming usable.

      try {
        await room.prepareConnection(
          tokenResponse.url,
          tokenResponse.token,
        );
      } catch (_) {
        // Preparation is an optimization, not a requirement.
        //
        // If it fails, normal connect() is still attempted.
      }

      _assertSessionIsCurrent(generation);

      // -----------------------------------------------------------------------
      // 4. CONNECT
      // -----------------------------------------------------------------------

      onState(
        SpiderCamConnState.connecting,
        'Connecting to LiveKit…',
      );

      await room.connect(
        tokenResponse.url,
        tokenResponse.token,
      );

      _assertSessionIsCurrent(generation);

      // -----------------------------------------------------------------------
      // 5. CREATE CAMERA
      // -----------------------------------------------------------------------

      onState(
        SpiderCamConnState.connecting,
        'Starting camera…',
      );

      final track = await LocalVideoTrack.createCameraTrack(
        const CameraCaptureOptions(
          cameraPosition: CameraPosition.back,

          // Never intentionally capture above our realtime target.
          maxFrameRate: 30,

          params: _kLiveCameraParams,
        ),
      );

      _assertSessionIsCurrent(generation);

      // -----------------------------------------------------------------------
      // 6. LOCAL PARTICIPANT
      // -----------------------------------------------------------------------

      final participant = room.localParticipant;

      if (participant == null) {
        await _disposeTrack(track);

        throw StateError(
          'LiveKit local participant is unavailable.',
        );
      }

      // -----------------------------------------------------------------------
      // 7. PUBLISH
      // -----------------------------------------------------------------------

      onState(
        SpiderCamConnState.connecting,
        'Starting H.264 live stream…',
      );

      await participant.publishVideoTrack(
        track,
        publishOptions: const VideoPublishOptions(
          // H.264 is preferred for the cross-device realtime baseline.
          videoCodec: _kVideoCodec,

          // One stream only.
          //
          // We do not want the encoder producing multiple quality layers
          // while establishing the lowest-latency baseline.
          simulcast: false,

          // Explicit realtime sender budget.
          videoEncoding: _kLiveVideoEncoding,

          // If bandwidth becomes constrained, preserve temporal smoothness
          // rather than sacrificing FPS first.
          degradationPreference: DegradationPreference.maintainFramerate,
        ),
      );

      _assertSessionIsCurrent(generation);

      // Only expose the track to the UI after publication succeeds.
      _videoTrack = track;

      // -----------------------------------------------------------------------
      // 8. LIVE
      // -----------------------------------------------------------------------

      onState(
        SpiderCamConnState.live,
        'LIVE • $requestedWidth×$requestedHeight • '
        '$requestedFps FPS • H.264',
      );
    } catch (error) {
      await _teardown();

      if (!_stoppingIntentionally) {
        onState(
          SpiderCamConnState.error,
          _cleanErrorMessage(error),
        );
      }
    } finally {
      _busy = false;
    }
  }

  // ===========================================================================
  // ROOM EVENTS
  // ===========================================================================

  void _registerRoomEvents({
    required Room room,
    required void Function(
      SpiderCamConnState state,
      String msg,
    ) onState,
  }) {
    final listener = _listener;

    if (listener == null) {
      return;
    }

    listener
      ..on<RoomReconnectingEvent>((_) {
        if (_stoppingIntentionally) {
          return;
        }

        onState(
          SpiderCamConnState.reconnecting,
          'Network interruption — reconnecting…',
        );
      })
      ..on<RoomReconnectedEvent>((_) {
        if (_stoppingIntentionally) {
          return;
        }

        onState(
          SpiderCamConnState.live,
          'LIVE • connection restored',
        );
      })
      ..on<RoomDisconnectedEvent>((event) {
        if (_stoppingIntentionally) {
          return;
        }

        onState(
          SpiderCamConnState.error,
          'Live connection ended: ${event.reason}',
        );
      });
  }

  // ===========================================================================
  // STOP
  // ===========================================================================

  Future<void> stopLive() async {
    _stoppingIntentionally = true;

    // Invalidate all asynchronous work belonging to the old session.
    ++_sessionGeneration;

    await _teardown();
  }

  // ===========================================================================
  // TOKEN
  // ===========================================================================

  Future<_TokenResponse> _fetchToken({
    required String deviceId,
    required String caseId,
    required String identity,
  }) async {
    _config.validate();

    final baseUrl = _config.apiBaseUrl.trim().replaceFirst(
          RegExp(r'/+$'),
          '',
        );

    final uri = Uri.parse('$baseUrl/token');

    final client = HttpClient();

    try {
      final request = await client.postUrl(uri);

      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json',
      );

      request.headers.set(
        'Accept',
        'application/json',
      );

      request.headers.set(
        'X-API-Key',
        _config.sharedKey,
      );

      final payload = <String, dynamic>{
        'identity': identity,
        'room': caseId,

        // Camera publisher.
        'can_publish': true,
        'can_subscribe': false,

        'device_type': 'MOBILE_CAMERA',

        // These describe the LIVE profile, not forensic acquisition.
        'resolution': '${_kLiveCameraParams.dimensions.width}x'
            '${_kLiveCameraParams.dimensions.height}',

        'fps': '${_kLiveCameraParams.encoding?.maxFramerate ?? 30}',

        'codec': _kVideoCodec,
      };

      request.write(jsonEncode(payload));

      final response = await request.close();

      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Token request failed '
          '(${response.statusCode}): $body',
          uri: uri,
        );
      }

      dynamic decoded;

      try {
        decoded = jsonDecode(body);
      } catch (_) {
        throw const FormatException(
          'Backend returned invalid JSON.',
        );
      }

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Backend returned an unexpected token response.',
        );
      }

      final token = decoded['token'] as String?;
      final url = decoded['url'] as String?;

      final room = (decoded['room'] as String?) ?? caseId;

      if (token == null || token.trim().isEmpty) {
        throw StateError(
          'Backend token response did not contain a valid token.',
        );
      }

      if (url == null || url.trim().isEmpty) {
        throw StateError(
          'Backend token response did not contain a LiveKit URL.',
        );
      }

      return _TokenResponse(
        token: token,
        url: url,
        room: room,
      );
    } finally {
      client.close(force: true);
    }
  }

  // ===========================================================================
  // SESSION VALIDATION
  // ===========================================================================

  void _assertSessionIsCurrent(int generation) {
    if (_stoppingIntentionally || generation != _sessionGeneration) {
      throw const _SessionCancelledException();
    }
  }

  // ===========================================================================
  // TEARDOWN
  // ===========================================================================

  Future<void> _teardown() async {
    final track = _videoTrack;
    final listener = _listener;
    final room = _room;

    _videoTrack = null;
    _listener = null;
    _room = null;

    // Stop camera first.
    if (track != null) {
      await _disposeTrack(track);
    }

    // Remove event listeners.
    if (listener != null) {
      try {
        await listener.dispose();
      } catch (_) {}
    }

    // Disconnect LiveKit.
    if (room != null) {
      try {
        await room.disconnect();
      } catch (_) {}

      try {
        await room.dispose();
      } catch (_) {}
    }
  }

  Future<void> _disposeTrack(
    LocalVideoTrack track,
  ) async {
    try {
      await track.stop();
    } catch (_) {}

    try {
      await track.dispose();
    } catch (_) {}
  }

  // ===========================================================================
  // ERROR HANDLING
  // ===========================================================================

  String _cleanErrorMessage(Object error) {
    if (error is _SessionCancelledException) {
      return 'Live session cancelled.';
    }

    final message = error.toString().trim();

    if (message.isEmpty) {
      return 'Unable to start SpiderCam LIVE.';
    }

    return message;
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  void dispose() {
    _stoppingIntentionally = true;
    ++_sessionGeneration;

    unawaited(_teardown());
  }
}

// =============================================================================
// TOKEN RESPONSE
// =============================================================================

class _TokenResponse {
  final String token;
  final String url;
  final String room;

  const _TokenResponse({
    required this.token,
    required this.url,
    required this.room,
  });
}

// =============================================================================
// INTERNAL CANCELLATION
// =============================================================================

class _SessionCancelledException implements Exception {
  const _SessionCancelledException();
}

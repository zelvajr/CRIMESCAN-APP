import 'package:flutter_test/flutter_test.dart';
import 'package:forensic_spidercam/core/services/spidercam_publish_service.dart';

void main() {
  group('SpiderCamPublishConfig', () {
    test('accepts a valid secure configuration', () {
      const config = SpiderCamPublishConfig(
        apiBaseUrl: 'https://demo.example.com',
        sharedKey: 'secure-token',
      );

      expect(() => config.validate(), returnsNormally);
    });

    test('rejects a missing API base URL', () {
      const config = SpiderCamPublishConfig(
        apiBaseUrl: '   ',
        sharedKey: 'secure-token',
      );

      expect(() => config.validate(), throwsA(isA<StateError>()));
    });

    test('rejects a missing shared key', () {
      const config = SpiderCamPublishConfig(
        apiBaseUrl: 'https://demo.example.com',
        sharedKey: '   ',
      );

      expect(() => config.validate(), throwsA(isA<StateError>()));
    });
  });

  test('service accepts an injected secure config', () {
    final service = SpiderCamPublishService(
      config: const SpiderCamPublishConfig(
        apiBaseUrl: 'https://demo.example.com',
        sharedKey: 'secure-token',
      ),
    );

    expect(service.room, isNull);
    expect(service.videoTrack, isNull);
  });
}

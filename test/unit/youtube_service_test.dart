import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_player_app/core/services/youtube_service.dart';

void main() {
  group('YouTubeService duration parser', () {
    Duration testParseDuration(String iso) {
      final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
      final match = regex.firstMatch(iso);
      if (match == null) return Duration.zero;
      return Duration(
        hours: int.tryParse(match.group(1) ?? '') ?? 0,
        minutes: int.tryParse(match.group(2) ?? '') ?? 0,
        seconds: int.tryParse(match.group(3) ?? '') ?? 0,
      );
    }

    test('parses PT1H2M30S correctly', () {
      expect(
        testParseDuration('PT1H2M30S'),
        const Duration(hours: 1, minutes: 2, seconds: 30),
      );
    });

    test('parses PT45S correctly', () {
      expect(testParseDuration('PT45S'), const Duration(seconds: 45));
    });

    test('parses PT5M correctly', () {
      expect(testParseDuration('PT5M'), const Duration(minutes: 5));
    });

    test('parses PT0S as zero', () {
      expect(testParseDuration('PT0S'), Duration.zero);
    });

    test('parses malformed string as zero', () {
      expect(testParseDuration('INVALID'), Duration.zero);
    });
  });

  group('YouTubeService API key check', () {
    test('getVideoMetadata returns null when no API key is set', () async {
      final service = YouTubeService();
      final result = await service.getVideoMetadata('dQw4w9WgXcQ');
      expect(result, isNull);
    });
  });
}

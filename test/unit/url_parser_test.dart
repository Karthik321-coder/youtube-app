import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_player_app/core/utils/url_parser.dart';

void main() {
  group('UrlParser.extractVideoId', () {
    const id = 'dQw4w9WgXcQ';

    test('bare 11-char ID passes through unchanged', () {
      expect(UrlParser.extractVideoId(id), id);
    });

    test('extracts from standard watch URL', () {
      expect(
        UrlParser.extractVideoId('https://www.youtube.com/watch?v=$id'),
        id,
      );
    });

    test('extracts from short youtu.be URL', () {
      expect(UrlParser.extractVideoId('https://youtu.be/$id'), id);
    });

    test('extracts from /shorts/ URL', () {
      expect(
        UrlParser.extractVideoId('https://www.youtube.com/shorts/$id'),
        id,
      );
    });

    test('extracts from /embed/ URL', () {
      expect(
        UrlParser.extractVideoId('https://www.youtube.com/embed/$id'),
        id,
      );
    });

    test('extracts from URL with extra query params', () {
      expect(
        UrlParser.extractVideoId(
          'https://www.youtube.com/watch?v=$id&t=30s&feature=share',
        ),
        id,
      );
    });

    test('returns null for non-YouTube URL', () {
      expect(UrlParser.extractVideoId('https://google.com'), null);
    });

    test('returns null for empty string', () {
      expect(UrlParser.extractVideoId(''), null);
    });

    test('returns null for short-but-wrong-length string', () {
      expect(UrlParser.extractVideoId('abc'), null);
    });
  });

  group('UrlParser.isShortUrl', () {
    test('returns true for /shorts/ URL', () {
      expect(
        UrlParser.isShortUrl('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
        isTrue,
      );
    });

    test('returns false for standard watch URL', () {
      expect(
        UrlParser.isShortUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        isFalse,
      );
    });
  });
}

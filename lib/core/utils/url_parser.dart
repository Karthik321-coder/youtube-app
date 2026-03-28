class UrlParser {
  UrlParser._();

  static String? extractVideoId(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;

    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(s)) return s;

    final patterns = [
      RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/v/([a-zA-Z0-9_-]{11})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(s);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static bool isShortUrl(String url) => url.contains('youtube.com/shorts/');
}

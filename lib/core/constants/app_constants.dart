class AppConstants {
  AppConstants._();

  static const String youtubeApiKey =
      String.fromEnvironment('YOUTUBE_API_KEY', defaultValue: '');
  static const String youtubeApiBase = 'https://www.googleapis.com/youtube/v3';
  static const int searchPageSize = 15;
  static const int shortsMaxDurationSeconds = 60;
  static const int shortsMaxAliveControllers = 3;
  static const Duration apiTimeout = Duration(seconds: 10);
}

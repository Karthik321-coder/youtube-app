import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/youtube_service.dart';

final youtubeServiceProvider = Provider<YouTubeService>(
  (ref) => YouTubeService(),
);

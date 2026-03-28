import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../models/video_item.dart';
import '../constants/app_constants.dart';

class YouTubeService {
  final Dio _dio;
  final YoutubeExplode _yt;
  final Map<String, VideoSearchList> _fallbackPageCache = {};
  int _fallbackTokenCounter = 0;

  YouTubeService({Dio? dio, YoutubeExplode? yt})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.youtubeApiBase,
                connectTimeout: AppConstants.apiTimeout,
                receiveTimeout: AppConstants.apiTimeout,
              ),
            ),
        _yt = yt ?? YoutubeExplode();

  Future<VideoItem?> getVideoMetadata(String videoId) async {
    if (AppConstants.youtubeApiKey.isEmpty) {
      return _getVideoMetadataFallback(videoId);
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/videos',
        queryParameters: {
          'part': 'snippet,contentDetails',
          'id': videoId,
          'key': AppConstants.youtubeApiKey,
        },
      );

      final items = response.data?['items'] as List?;
      if (items == null || items.isEmpty) return null;

      final item = items.first as Map<String, dynamic>;
      final snippet = item['snippet'] as Map<String, dynamic>;
      final contentDetails = item['contentDetails'] as Map<String, dynamic>;
      final duration = _parseIsoDuration(
        contentDetails['duration'] as String? ?? 'PT0S',
      );
      final isShort = duration.inSeconds > 0 &&
          duration.inSeconds <= AppConstants.shortsMaxDurationSeconds;

      final thumbnails = (snippet['thumbnails'] as Map<String, dynamic>?) ?? {};
      final thumbUrl =
          (thumbnails['medium'] as Map<String, dynamic>?)?['url'] as String? ??
              'https://img.youtube.com/vi/$videoId/mqdefault.jpg';

      return VideoItem(
        id: videoId,
        title: snippet['title'] as String? ?? 'Untitled',
        channelTitle: snippet['channelTitle'] as String?,
        thumbnailUrl: thumbUrl,
        duration: duration,
        isShort: isShort,
      );
    } on DioException catch (e) {
      final fallback = await _getVideoMetadataFallback(videoId);
      if (fallback != null) return fallback;
      throw YouTubeServiceException(
        'Network error: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw YouTubeServiceException('Unexpected error: $e');
    }
  }

  Future<VideoSearchPage?> searchVideos({
    required String query,
    String? pageToken,
    bool shortsOnly = false,
    SearchOrder order = SearchOrder.relevance,
    SearchDuration duration = SearchDuration.any,
    bool liveOnly = false,
    int? publishedWithinDays,
  }) async {
    if (AppConstants.youtubeApiKey.isEmpty) {
      return _searchVideosFallback(
        query: query,
        pageToken: pageToken,
        shortsOnly: shortsOnly,
      );
    }

    try {
      return _searchVideosApi(
        query: query,
        pageToken: pageToken,
        shortsOnly: shortsOnly,
        order: order,
        duration: duration,
        liveOnly: liveOnly,
        publishedWithinDays: publishedWithinDays,
      );
    } on DioException catch (e) {
      final fallback = await _searchVideosFallback(
        query: query,
        pageToken: pageToken,
        shortsOnly: shortsOnly,
      );
      if (fallback != null) return fallback;

      throw YouTubeServiceException(
        'Search failed: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw YouTubeServiceException('Unexpected error: $e');
    }
  }

  Future<VideoSearchPage?> _searchVideosApi({
    required String query,
    String? pageToken,
    required bool shortsOnly,
    required SearchOrder order,
    required SearchDuration duration,
    required bool liveOnly,
    required int? publishedWithinDays,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/search',
      queryParameters: {
        'part': 'snippet',
        'q': query,
        'type': 'video',
        'maxResults': AppConstants.searchPageSize,
        'order': _orderParam(order),
        'videoEmbeddable': 'true',
        if (liveOnly) 'eventType': 'live',
        if (_durationParam(shortsOnly: shortsOnly, duration: duration)
            case final videoDuration?)
          'videoDuration': videoDuration,
        if (publishedWithinDays != null)
          'publishedAfter': DateTime.now()
              .toUtc()
              .subtract(Duration(days: publishedWithinDays))
              .toIso8601String(),
        if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
        'key': AppConstants.youtubeApiKey,
      },
    );

    final items = response.data?['items'] as List? ?? const [];
    if (items.isEmpty) {
      return const VideoSearchPage(items: [], nextPageToken: null);
    }

    final ids = <String>[];
    final byId = <String, Map<String, dynamic>>{};
    for (final raw in items) {
      final item = raw as Map<String, dynamic>;
      final idObj = item['id'] as Map<String, dynamic>?;
      final videoId = idObj?['videoId'] as String?;
      if (videoId != null && videoId.isNotEmpty) {
        ids.add(videoId);
        byId[videoId] = item;
      }
    }

    final durations = await _fetchDurations(ids);

    final videos = <VideoItem>[];
    for (final id in ids) {
      final item = byId[id];
      if (item == null) continue;
      final snippet = item['snippet'] as Map<String, dynamic>? ?? {};
      final thumbnails = snippet['thumbnails'] as Map<String, dynamic>? ?? {};
      final thumbUrl =
          (thumbnails['medium'] as Map<String, dynamic>?)?['url'] as String? ??
              'https://img.youtube.com/vi/$id/mqdefault.jpg';

      final itemDuration = durations[id];
      final isShort = itemDuration != null &&
          itemDuration.inSeconds > 0 &&
          itemDuration.inSeconds <= AppConstants.shortsMaxDurationSeconds;

      videos.add(
        VideoItem(
          id: id,
          title: snippet['title'] as String? ?? 'Untitled',
          channelTitle: snippet['channelTitle'] as String?,
          thumbnailUrl: thumbUrl,
          duration: itemDuration,
          isShort: isShort,
        ),
      );
    }

    return VideoSearchPage(
      items: videos,
      nextPageToken: response.data?['nextPageToken'] as String?,
    );
  }

  Future<VideoSearchPage?> _searchVideosFallback({
    required String query,
    String? pageToken,
    required bool shortsOnly,
  }) async {
    VideoSearchList? page;
    if (pageToken != null && pageToken.isNotEmpty) {
      page = _fallbackPageCache.remove(pageToken);
      if (page == null) {
        return const VideoSearchPage(items: [], nextPageToken: null);
      }
    } else {
      page = await _yt.search.search(query, filter: TypeFilters.video);
    }

    var current = page.toList(growable: false);
    if (shortsOnly) {
      current = current.where((video) {
        final d = video.duration;
        return d != null &&
            d.inSeconds > 0 &&
            d.inSeconds <= AppConstants.shortsMaxDurationSeconds;
      }).toList(growable: false);
    }

    String? nextToken;
    final next = await page.nextPage();
    if (next != null) {
      nextToken = _storeFallbackPage(next);
    }

    final mapped = current
        .take(AppConstants.searchPageSize)
        .map(_mapYtVideoToVideoItem)
        .toList(growable: false);

    return VideoSearchPage(items: mapped, nextPageToken: nextToken);
  }

  Future<VideoItem?> _getVideoMetadataFallback(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId);
      return _mapYtVideoToVideoItem(video);
    } catch (_) {
      return null;
    }
  }

  String _storeFallbackPage(VideoSearchList page) {
    _fallbackTokenCounter += 1;
    final token = 'fallback_$_fallbackTokenCounter';
    _fallbackPageCache[token] = page;
    return token;
  }

  VideoItem _mapYtVideoToVideoItem(Video video) {
    final itemDuration = video.duration;
    final isShort = itemDuration != null &&
        itemDuration.inSeconds > 0 &&
        itemDuration.inSeconds <= AppConstants.shortsMaxDurationSeconds;

    return VideoItem(
      id: video.id.value,
      title: video.title,
      channelTitle: video.author,
      thumbnailUrl: video.thumbnails.highResUrl,
      duration: itemDuration,
      isShort: isShort,
    );
  }

  void dispose() {
    _yt.close();
  }

  Future<Map<String, Duration>> _fetchDurations(List<String> ids) async {
    if (ids.isEmpty) return {};

    final response = await _dio.get<Map<String, dynamic>>(
      '/videos',
      queryParameters: {
        'part': 'contentDetails',
        'id': ids.join(','),
        'key': AppConstants.youtubeApiKey,
      },
    );

    final result = <String, Duration>{};
    final items = response.data?['items'] as List? ?? const [];
    for (final raw in items) {
      final item = raw as Map<String, dynamic>;
      final id = item['id'] as String?;
      if (id == null || id.isEmpty) continue;
      final contentDetails = item['contentDetails'] as Map<String, dynamic>?;
      final iso = contentDetails?['duration'] as String? ?? 'PT0S';
      result[id] = _parseIsoDuration(iso);
    }
    return result;
  }

  static Duration _parseIsoDuration(String iso) {
    final r = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final m = r.firstMatch(iso);
    if (m == null) return Duration.zero;
    return Duration(
      hours: int.tryParse(m.group(1) ?? '') ?? 0,
      minutes: int.tryParse(m.group(2) ?? '') ?? 0,
      seconds: int.tryParse(m.group(3) ?? '') ?? 0,
    );
  }

  static String _orderParam(SearchOrder order) {
    switch (order) {
      case SearchOrder.date:
        return 'date';
      case SearchOrder.viewCount:
        return 'viewCount';
      case SearchOrder.rating:
        return 'rating';
      case SearchOrder.relevance:
        return 'relevance';
    }
  }

  static String? _durationParam({
    required bool shortsOnly,
    required SearchDuration duration,
  }) {
    if (shortsOnly) return 'short';

    switch (duration) {
      case SearchDuration.any:
        return null;
      case SearchDuration.short:
        return 'short';
      case SearchDuration.medium:
        return 'medium';
      case SearchDuration.long:
        return 'long';
    }
  }
}

class YouTubeServiceException implements Exception {
  final String message;
  final int? statusCode;

  const YouTubeServiceException(this.message, {this.statusCode});

  @override
  String toString() =>
      'YouTubeServiceException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

class VideoSearchPage {
  final List<VideoItem> items;
  final String? nextPageToken;

  const VideoSearchPage({required this.items, this.nextPageToken});
}

enum SearchOrder { relevance, date, viewCount, rating }

enum SearchDuration { any, short, medium, long }

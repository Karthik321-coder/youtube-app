import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/connectivity_service.dart';
import '../../core/services/youtube_service.dart';
import '../../models/stream_quality_option.dart';
import '../../models/video_item.dart';
import '../../shared/widgets/offline_banner.dart';
import '../downloads/downloads_notifier.dart';
import '../player/player_screen.dart';
import '../shorts/shorts_feed_screen.dart';
import 'widgets/video_list_tile.dart';

const String _defaultHomeQuery = 'latest trending videos';
const String _defaultShortsQuery = 'latest trending shorts';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final YouTubeService _youTubeService = YouTubeService();

  bool _searching = false;
  bool _loadingMore = false;
  bool _liveOnly = false;
  bool _initialized = false;

  int _tabIndex = 0;

  String _homeNextPageToken = '';
  String _shortsNextPageToken = '';
  String _lastQuery = '';
  String _searchError = '';
  String _shortsError = '';

  List<VideoItem> _homeResults = const [];
  List<VideoItem> _shortsResults = const [];
  final Set<String> _favoriteIds = <String>{};

  List<VideoItem> get _favoriteVideos => _homeResults
      .where((video) => _favoriteIds.contains(video.id))
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.text = _defaultHomeQuery;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _primeHome();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _youTubeService.dispose();
    super.dispose();
  }

  Future<void> _primeHome() async {
    await _loadHomeVideos(queryOverride: _defaultHomeQuery);
    await _loadShortVideos(queryOverride: _defaultShortsQuery);
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  Future<bool> _ensureConnected() async {
    final connected = await ref.read(connectivityServiceProvider).isConnected;
    if (!connected && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Connect and try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    return connected;
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || _tabIndex == 3) {
      return;
    }

    final nextToken =
        _tabIndex == 1 ? _shortsNextPageToken : _homeNextPageToken;
    if (nextToken.isEmpty) return;

    final threshold = _scrollController.position.maxScrollExtent - 280;
    if (_scrollController.position.pixels >= threshold) {
      if (_tabIndex == 1) {
        _loadShortVideos(loadMore: true);
      } else {
        _loadHomeVideos(loadMore: true);
      }
    }
  }

  Future<void> _loadHomeVideos({
    bool loadMore = false,
    String? queryOverride,
  }) async {
    final query = (queryOverride ?? _searchController.text).trim().isEmpty
        ? _defaultHomeQuery
        : (queryOverride ?? _searchController.text).trim();

    if (!await _ensureConnected()) return;
    if (loadMore && (_homeNextPageToken.isEmpty || _loadingMore)) return;

    setState(() {
      _searchError = '';
      _loadingMore = loadMore;
      if (!loadMore) _searching = true;
    });

    try {
      final page = await _youTubeService.searchVideos(
        query: query,
        pageToken: loadMore ? _homeNextPageToken : null,
        liveOnly: _liveOnly,
        order: SearchOrder.relevance,
        duration: SearchDuration.any,
      );

      if (!mounted) return;

      setState(() {
        _lastQuery = query;
        _homeNextPageToken = page?.nextPageToken ?? '';
        if (loadMore) {
          _homeResults = _mergeUnique(_homeResults, page?.items ?? const []);
        } else {
          _homeResults = page?.items ?? const [];
        }
      });
    } on YouTubeServiceException catch (e) {
      if (!mounted) return;
      setState(() => _searchError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _searchError = 'Search failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadShortVideos({
    bool loadMore = false,
    String? queryOverride,
  }) async {
    final query = (queryOverride ?? _searchController.text).trim().isEmpty
        ? _defaultShortsQuery
        : (queryOverride ?? _searchController.text).trim();

    if (!await _ensureConnected()) return;
    if (loadMore && (_shortsNextPageToken.isEmpty || _loadingMore)) return;

    setState(() {
      _shortsError = '';
      _loadingMore = loadMore;
      if (!loadMore) _searching = true;
    });

    try {
      final page = await _youTubeService.searchVideos(
        query: query,
        pageToken: loadMore ? _shortsNextPageToken : null,
        shortsOnly: true,
      );

      if (!mounted) return;

      setState(() {
        _shortsNextPageToken = page?.nextPageToken ?? '';
        if (loadMore) {
          _shortsResults =
              _mergeUnique(_shortsResults, page?.items ?? const []);
        } else {
          _shortsResults = page?.items ?? const [];
        }
      });
    } on YouTubeServiceException catch (e) {
      if (!mounted) return;
      setState(() => _shortsError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _shortsError = 'Shorts load failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
          _loadingMore = false;
        });
      }
    }
  }

  List<VideoItem> _mergeUnique(List<VideoItem> a, List<VideoItem> b) {
    final seen = <String>{};
    final merged = <VideoItem>[];
    for (final item in [...a, ...b]) {
      if (seen.add(item.id)) {
        merged.add(item);
      }
    }
    return merged;
  }

  void _openVideo(VideoItem video) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(video: video)),
    );
  }

  void _toggleFavorite(VideoItem video) {
    setState(() {
      if (_favoriteIds.contains(video.id)) {
        _favoriteIds.remove(video.id);
      } else {
        _favoriteIds.add(video.id);
      }
    });
  }

  Future<void> _openShortsFeed() async {
    var shorts = _shortsResults;

    if (shorts.isEmpty) {
      await _loadShortVideos(queryOverride: _defaultShortsQuery);
      shorts = _shortsResults;
    }

    if (!mounted) return;

    if (shorts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No playable Shorts found right now.')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShortsFeedScreen(
          shorts: shorts,
          seedQuery: _searchController.text.trim().isEmpty
              ? _defaultShortsQuery
              : _searchController.text.trim(),
        ),
      ),
    );
  }

  Future<void> _showDownloadOptions(VideoItem video) async {
    if (!await _ensureConnected() || !mounted) return;

    List<StreamQualityOption> qualities = const [];

    try {
      qualities =
          await ref.read(downloadsProvider.notifier).loadQualities(video.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load download qualities: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!mounted) return;

    if (qualities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No downloadable qualities available for this video.'),
        ),
      );
      return;
    }

    int selectedIndex = 0;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Download Quality',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: qualities.length,
                        itemBuilder: (context, index) {
                          final quality = qualities[index];
                          final selected = selectedIndex == index;
                          return RadioListTile<int>(
                            activeColor: Colors.red,
                            value: index,
                            groupValue: selectedIndex,
                            onChanged: (value) {
                              if (value != null) {
                                setSheetState(() => selectedIndex = value);
                              }
                            },
                            title: Text(
                              quality.displayLabel,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final selected = qualities[selectedIndex];
                          await ref
                              .read(downloadsProvider.notifier)
                              .enqueueDownload(video: video, quality: selected);
                          if (!sheetContext.mounted || !mounted) return;
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Download queued at ${selected.qualityLabel}. Check Downloads tab.',
                              ),
                            ),
                          );
                          setState(() => _tabIndex = 3);
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Download'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloads = ref.watch(downloadsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.play_circle_fill, color: Colors.red, size: 26),
            SizedBox(width: 8),
            Text('YouTube Live'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Live filter',
            onPressed: () {
              setState(() => _liveOnly = !_liveOnly);
              _loadHomeVideos();
            },
            icon: Icon(
              _liveOnly ? Icons.live_tv : Icons.live_tv_outlined,
              color: _liveOnly ? Colors.red : Colors.white70,
            ),
          ),
          IconButton(
            tooltip: 'Open Shorts Feed',
            onPressed: _openShortsFeed,
            icon: const Icon(Icons.smart_display_outlined),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(66),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      if (_tabIndex == 1) {
                        _loadShortVideos();
                      } else {
                        _loadHomeVideos();
                      }
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search videos, live and shorts...',
                      hintStyle:
                          const TextStyle(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF212121),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _searching
                      ? null
                      : () {
                          if (_tabIndex == 1) {
                            _loadShortVideos();
                          } else {
                            _loadHomeVideos();
                          }
                        },
                  icon: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.search),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) {
          setState(() => _tabIndex = index);
          if (index == 1 && _shortsResults.isEmpty) {
            _loadShortVideos(queryOverride: _defaultShortsQuery);
          }
        },
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          const NavigationDestination(
              icon: Icon(Icons.ondemand_video), label: 'Shorts'),
          const NavigationDestination(
              icon: Icon(Icons.favorite_outline), label: 'Favorites'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: downloads.isNotEmpty,
              label: Text('${downloads.length}'),
              child: const Icon(Icons.download_outlined),
            ),
            label: 'Downloads',
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          if (_searchError.isNotEmpty && _tabIndex != 1)
            _errorBanner(_searchError, Colors.redAccent),
          if (_shortsError.isNotEmpty && _tabIndex == 1)
            _errorBanner(_shortsError, Colors.orangeAccent),
          if (_lastQuery.isNotEmpty && _tabIndex != 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Results for "$_lastQuery"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                  Text(
                    _liveOnly ? 'Live only' : 'All results',
                    style: TextStyle(
                      color: _liveOnly ? Colors.redAccent : Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildTabBody(downloads)),
        ],
      ),
    );
  }

  Widget _errorBanner(String message, Color color) {
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        message,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  Widget _buildTabBody(List<DownloadTaskItem> downloads) {
    switch (_tabIndex) {
      case 0:
        return _buildVideoList(
          videos: _homeResults,
          emptyMessage: 'Loading latest and trending videos...',
          allowLoadMore: true,
        );
      case 1:
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_shortsResults.length} shorts available',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openShortsFeed,
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Open Feed'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildVideoList(
                videos: _shortsResults,
                emptyMessage: 'Loading latest shorts...',
                allowLoadMore: true,
              ),
            ),
          ],
        );
      case 2:
        return _buildVideoList(
          videos: _favoriteVideos,
          emptyMessage: 'No favorites yet. Tap heart on a video to save it.',
          allowLoadMore: false,
        );
      case 3:
        return _DownloadsTab(
          tasks: downloads,
          onRemove: (id) => ref.read(downloadsProvider.notifier).removeTask(id),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildVideoList({
    required List<VideoItem> videos,
    required String emptyMessage,
    bool allowLoadMore = true,
  }) {
    if (videos.isEmpty) {
      if (_searching || !_initialized) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final hasMore = _tabIndex == 1
        ? _shortsNextPageToken.isNotEmpty
        : _homeNextPageToken.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () => _tabIndex == 1 ? _loadShortVideos() : _loadHomeVideos(),
      child: ListView.separated(
        controller: _scrollController,
        itemCount: videos.length + (allowLoadMore && hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(
          height: 0.5,
          color: Colors.white10,
          indent: 16,
          endIndent: 16,
        ),
        itemBuilder: (context, index) {
          if (index >= videos.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : OutlinedButton.icon(
                        onPressed: () => _tabIndex == 1
                            ? _loadShortVideos(loadMore: true)
                            : _loadHomeVideos(loadMore: true),
                        icon: const Icon(Icons.expand_more),
                        label: const Text('Load more'),
                      ),
              ),
            );
          }

          final video = videos[index];
          return VideoListTile(
            video: video,
            onTap: () => _openVideo(video),
            isFavorite: _favoriteIds.contains(video.id),
            onFavoriteTap: () => _toggleFavorite(video),
            onDownloadTap: () => _showDownloadOptions(video),
          );
        },
      ),
    );
  }
}

class _DownloadsTab extends StatelessWidget {
  final List<DownloadTaskItem> tasks;
  final ValueChanged<String> onRemove;

  const _DownloadsTab({required this.tasks, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No downloads yet. Tap the download button on any video.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: tasks.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 0.5, color: Colors.white10),
      itemBuilder: (context, index) {
        final task = tasks[index];
        final statusText = switch (task.status) {
          DownloadStatus.queued => 'Queued',
          DownloadStatus.downloading =>
            'Downloading ${(task.progress * 100).toStringAsFixed(0)}%',
          DownloadStatus.completed => 'Completed',
          DownloadStatus.failed => 'Failed',
        };

        final statusColor = switch (task.status) {
          DownloadStatus.completed => Colors.greenAccent,
          DownloadStatus.failed => Colors.redAccent,
          DownloadStatus.downloading => Colors.orangeAccent,
          DownloadStatus.queued => Colors.white54,
        };

        return ListTile(
          title: Text(
            task.video.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              Text(
                '${task.quality} • $statusText',
                style: TextStyle(color: statusColor, fontSize: 11),
              ),
              if (task.status == DownloadStatus.downloading) ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: task.progress,
                  minHeight: 3,
                  color: Colors.red,
                  backgroundColor: Colors.white12,
                ),
              ],
              if (task.status == DownloadStatus.failed && task.error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    task.error,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
            ],
          ),
          trailing: IconButton(
            onPressed: () => onRemove(task.id),
            icon: const Icon(Icons.delete_outline, color: Colors.white54),
          ),
        );
      },
    );
  }
}

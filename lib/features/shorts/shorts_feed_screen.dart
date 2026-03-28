import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/youtube_service.dart';
import '../../models/video_item.dart';

class ShortsFeedScreen extends StatefulWidget {
  final List<VideoItem> shorts;
  final String seedQuery;

  const ShortsFeedScreen({
    super.key,
    required this.shorts,
    this.seedQuery = 'latest shorts',
  });

  @override
  State<ShortsFeedScreen> createState() => _ShortsFeedScreenState();
}

class _ShortsFeedScreenState extends State<ShortsFeedScreen>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final Map<int, YoutubePlayerController> _controllers = {};
  final YouTubeService _youTubeService = YouTubeService();
  final Connectivity _connectivity = Connectivity();

  late final List<VideoItem> _shorts;
  late final List<String> _queryCandidates;
  int _currentPage = 0;
  int _queryIndex = 0;
  bool _loadingMore = false;
  bool _isConnected = true;
  String _nextPageToken = '';
  String _errorMessage = '';
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shorts = [...widget.shorts];
    _queryCandidates = {
      'trending shorts',
      'viral shorts',
      'latest shorts',
      widget.seedQuery.trim(),
      'music shorts',
      'gaming shorts',
      'sports highlights shorts',
    }.where((query) => query.isNotEmpty).toList();
    _bootstrapConnectivity();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshFeed(useExistingSeed: false);
      }
    });
  }

  Future<void> _bootstrapConnectivity() async {
    final current = await _connectivity.checkConnectivity();
    final connected =
        current.any((result) => result != ConnectivityResult.none);
    if (!mounted) return;
    setState(() => _isConnected = connected);

    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final nowConnected =
          results.any((result) => result != ConnectivityResult.none);
      if (!mounted) return;

      final justRestored = !_isConnected && nowConnected;
      setState(() => _isConnected = nowConnected);

      if (justRestored && _shorts.length < 3) {
        _fetchMoreShorts();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controllers[_currentPage]?.pause();
    }
  }

  YoutubePlayerController _controllerFor(int index) {
    if (!_controllers.containsKey(index)) {
      _controllers[index] = YoutubePlayerController(
        initialVideoId: _shorts[index].id,
        flags: YoutubePlayerFlags(
          autoPlay: index == _currentPage,
          mute: false,
          loop: true,
          enableCaption: false,
        ),
      );
    }
    return _controllers[index]!;
  }

  void _onPageChanged(int page) {
    _controllers[_currentPage]?.pause();
    setState(() => _currentPage = page);

    _controllerFor(page).play();

    if (page + 1 < _shorts.length) _controllerFor(page + 1);
    if (page - 1 >= 0) _controllerFor(page - 1);

    if (page >= _shorts.length - 2) {
      _fetchMoreShorts();
    }

    final toPrune = _controllers.keys
        .where((key) =>
            (key - page).abs() > AppConstants.shortsMaxAliveControllers)
        .toList();
    for (final key in toPrune) {
      _controllers[key]?.dispose();
      _controllers.remove(key);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _pageController.dispose();
    _youTubeService.dispose();
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }

  Future<void> _refreshFeed({required bool useExistingSeed}) async {
    if (_loadingMore) return;
    setState(() {
      _loadingMore = false;
      _errorMessage = '';
      _queryIndex = 0;
      _nextPageToken = '';
      _currentPage = 0;
      if (!useExistingSeed) {
        _shorts.clear();
      }
    });

    _disposeControllers();
    await _fetchMoreShorts();
    if (!mounted) return;
    if (_shorts.isNotEmpty) {
      _controllerFor(0).play();
    }
  }

  Future<void> _skipBlockedVideo(int index) async {
    if (!mounted || index != _currentPage) return;

    if (index + 1 < _shorts.length) {
      await _pageController.animateToPage(
        index + 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }

    await _fetchMoreShorts();

    if (!mounted) return;
    if (index + 1 < _shorts.length) {
      await _pageController.animateToPage(
        index + 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _fetchMoreShorts() async {
    if (_loadingMore) return;
    if (_queryIndex >= _queryCandidates.length) return;

    setState(() {
      _loadingMore = true;
      _errorMessage = '';
    });

    try {
      final existing = _shorts.map((video) => video.id).toSet();
      List<VideoItem> incoming = const [];
      var fetched = false;

      while (_queryIndex < _queryCandidates.length) {
        fetched = true;
        final page = await _youTubeService.searchVideos(
          query: _queryCandidates[_queryIndex],
          pageToken: _nextPageToken.isEmpty ? null : _nextPageToken,
          shortsOnly: true,
        );

        if (!mounted) return;

        incoming = (page?.items ?? const [])
            .where((video) => !existing.contains(video.id))
            .toList();
        _nextPageToken = page?.nextPageToken ?? '';

        if (incoming.isNotEmpty) {
          break;
        }

        if (_nextPageToken.isNotEmpty) {
          break;
        }

        _queryIndex += 1;
        _nextPageToken = '';
      }

      if (!mounted) return;

      setState(() {
        _shorts.addAll(incoming);
        if (incoming.isEmpty &&
            _queryIndex >= _queryCandidates.length &&
            fetched) {
          _errorMessage = _isConnected
              ? 'No more Shorts available right now.'
              : 'No internet. Reconnect and pull to refresh.';
        }
      });
    } on YouTubeServiceException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to load more Shorts: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const PageScrollPhysics(),
            itemCount: _shorts.length + 1,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              if (index >= _shorts.length) {
                return _ShortsLoadingPage(
                  loading: _loadingMore,
                  hasMore: _nextPageToken.isNotEmpty || _shorts.isEmpty,
                  errorMessage: _errorMessage,
                  onRetry: () => _refreshFeed(useExistingSeed: false),
                );
              }

              return _ShortsPage(
                video: _shorts[index],
                controller: _controllerFor(index),
                isActive: index == _currentPage,
                index: index,
                total: _shorts.length,
                onBlockedVideo: _skipBlockedVideo,
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Icon(Icons.bolt, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'Shorts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _refreshFeed(useExistingSeed: false),
                    icon: const Icon(Icons.search, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.photo_camera_outlined,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          if (!_isConnected)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 56),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Offline - shorts loading paused',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShortsPage extends StatefulWidget {
  final VideoItem video;
  final YoutubePlayerController controller;
  final bool isActive;
  final int index;
  final int total;
  final ValueChanged<int> onBlockedVideo;

  const _ShortsPage({
    required this.video,
    required this.controller,
    required this.isActive,
    required this.index,
    required this.total,
    required this.onBlockedVideo,
  });

  @override
  State<_ShortsPage> createState() => _ShortsPageState();
}

class _ShortsLoadingPage extends StatelessWidget {
  final bool loading;
  final bool hasMore;
  final String errorMessage;
  final VoidCallback onRetry;

  const _ShortsLoadingPage({
    required this.loading,
    required this.hasMore,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CircularProgressIndicator(
                    color: Colors.red, strokeWidth: 2)
              else if (errorMessage.isNotEmpty) ...[
                const Icon(Icons.error_outline, color: Colors.redAccent),
                const SizedBox(height: 10),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
              ] else if (!hasMore)
                const Text(
                  'No more Shorts right now.',
                  style: TextStyle(color: Colors.white54),
                )
              else
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Load Shorts'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortsPageState extends State<_ShortsPage> {
  bool _ready = false;
  bool _handledBlock = false;
  bool _liked = false;
  bool _disliked = false;
  bool _subscribed = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted || _handledBlock) return;
    final code = widget.controller.value.errorCode;
    if (code == 101 || code == 150 || code == 100 || code == 5) {
      _handledBlock = true;
      widget.onBlockedVideo(widget.index);
    }
  }

  int _seededCount(int min, int max) {
    final span = max - min;
    final value = widget.video.id.hashCode.abs() % (span + 1);
    return min + value;
  }

  String _compactCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  Future<void> _openInYoutube() async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=${widget.video.id}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openComments() async {
    final uri = Uri.parse(
      'https://www.youtube.com/watch?v=${widget.video.id}&lc=1',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openChannel() async {
    final query = (widget.video.channelTitle ?? 'youtube').trim();
    final uri = Uri.parse(
      'https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      onExitFullScreen: widget.controller.play,
      player: YoutubePlayer(
        controller: widget.controller,
        showVideoProgressIndicator: false,
        onReady: () {
          if (mounted) setState(() => _ready = true);
          if (widget.isActive) widget.controller.play();
        },
        onEnded: (YoutubeMetaData _) {},
      ),
      builder: (context, player) {
        final likeCount = _compactCount(_seededCount(400, 980000));
        final commentCount = _compactCount(_seededCount(20, 48000));

        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            LayoutBuilder(
              builder: (context, constraints) {
                final videoWidth = constraints.maxHeight * (9 / 16);
                return ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.center,
                    minWidth: constraints.maxWidth,
                    maxWidth: videoWidth,
                    minHeight: constraints.maxHeight,
                    maxHeight: constraints.maxHeight,
                    child: SizedBox(
                      width: videoWidth,
                      height: constraints.maxHeight,
                      child: GestureDetector(
                        onTap: () {
                          if (widget.controller.value.isPlaying) {
                            widget.controller.pause();
                          } else {
                            widget.controller.play();
                          }
                          setState(() {});
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            player,
                            if (!_ready)
                              const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white54,
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              right: 8,
              bottom: 104,
              child: Column(
                children: [
                  _ShortActionButton(
                    icon: _liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    label: likeCount,
                    onTap: () {
                      setState(() {
                        _liked = !_liked;
                        if (_liked) _disliked = false;
                      });
                    },
                    active: _liked,
                  ),
                  const SizedBox(height: 14),
                  _ShortActionButton(
                    icon: _disliked
                        ? Icons.thumb_down
                        : Icons.thumb_down_outlined,
                    label: 'Dislike',
                    onTap: () {
                      setState(() {
                        _disliked = !_disliked;
                        if (_disliked) _liked = false;
                      });
                    },
                    active: _disliked,
                  ),
                  const SizedBox(height: 14),
                  _ShortActionButton(
                    icon: Icons.comment_outlined,
                    label: commentCount,
                    onTap: _openComments,
                  ),
                  const SizedBox(height: 14),
                  _ShortActionButton(
                    icon: Icons.reply_outlined,
                    label: 'Share',
                    onTap: _openInYoutube,
                  ),
                  const SizedBox(height: 14),
                  _ShortActionButton(
                    icon: Icons.auto_awesome,
                    label: 'Remix',
                    onTap: _openInYoutube,
                  ),
                  const SizedBox(height: 14),
                  _ShortActionButton(
                    icon: widget.controller.value.volume == 0
                        ? Icons.volume_off
                        : Icons.volume_up,
                    label: 'Sound',
                    onTap: () {
                      if (widget.controller.value.volume == 0) {
                        widget.controller.unMute();
                      } else {
                        widget.controller.mute();
                      }
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.86),
                      Colors.transparent,
                    ],
                    stops: const [0, 1],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 80, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 15,
                                  backgroundColor: Colors.white,
                                  child: Text(
                                    (widget.video.channelTitle ?? 'C')
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '@${(widget.video.channelTitle ?? 'channel').replaceAll(' ', '').toLowerCase()}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                TextButton(
                                  onPressed: _openChannel,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('View'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => setState(
                                    () => _subscribed = !_subscribed,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _subscribed
                                        ? Colors.black
                                        : Colors.white,
                                    backgroundColor: _subscribed
                                        ? Colors.white
                                        : Colors.transparent,
                                    side: BorderSide(
                                      color: _subscribed
                                          ? Colors.white
                                          : Colors.white54,
                                      width: 0.8,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: Text(
                                    _subscribed ? 'Subscribed' : 'Subscribe',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.video.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.graphic_eq,
                                  color: Colors.white70,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${widget.video.channelTitle ?? 'Original audio'}  •  Original audio',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${widget.index + 1}/${widget.total}',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShortActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _ShortActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Icon(
            icon,
            color: active ? Colors.redAccent : Colors.white,
            size: 29,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.redAccent : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

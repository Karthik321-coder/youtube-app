import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../models/video_item.dart';
import '../player/widgets/loading_placeholder.dart';
import '../player/widgets/player_controls.dart';

class PlaylistPlayerScreen extends StatefulWidget {
  final List<VideoItem> playlist;
  final int initialIndex;

  const PlaylistPlayerScreen({
    super.key,
    required this.playlist,
    this.initialIndex = 0,
  });

  @override
  State<PlaylistPlayerScreen> createState() => _PlaylistPlayerScreenState();
}

class _PlaylistPlayerScreenState extends State<PlaylistPlayerScreen>
    with WidgetsBindingObserver {
  late YoutubePlayerController _controller;
  late int _currentIndex;
  bool _isReady = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex.clamp(0, widget.playlist.length - 1);
    _buildController(_currentIndex);
  }

  void _buildController(int index) {
    setState(() {
      _isReady = false;
      _errorMessage = '';
    });
    _controller = YoutubePlayerController(
      initialVideoId: widget.playlist[index].id,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: false,
      ),
    );
    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final code = _controller.value.errorCode;
    if (code != 0 && _errorMessage.isEmpty) {
      setState(() => _errorMessage = 'Playback error (code $code).');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _controller.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _playAt(int index) {
    if (index < 0 || index >= widget.playlist.length) return;
    setState(() {
      _currentIndex = index;
      _isReady = false;
      _errorMessage = '';
    });
    _controller.load(widget.playlist[index].id);
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.playlist[_currentIndex];

    return YoutubePlayerBuilder(
      onExitFullScreen: _controller.play,
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: false,
        onReady: () {
          setState(() => _isReady = true);
          _controller.play();
        },
        onEnded: (YoutubeMetaData _) {
          if (_currentIndex < widget.playlist.length - 1) {
            _playAt(_currentIndex + 1);
          }
        },
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(
              current.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: Column(
            children: [
              Stack(
                children: [
                  player,
                  if (!_isReady)
                    const Positioned.fill(child: LoadingPlaceholder()),
                ],
              ),
              if (_isReady) PlayerControls(controller: _controller),
              if (_errorMessage.isNotEmpty)
                Container(
                  color: Colors.black,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_currentIndex + 1} / ${widget.playlist.length}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.skip_previous, color: Colors.white),
                      onPressed: _currentIndex > 0
                          ? () => _playAt(_currentIndex - 1)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next, color: Colors.white),
                      onPressed: _currentIndex < widget.playlist.length - 1
                          ? () => _playAt(_currentIndex + 1)
                          : null,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: widget.playlist.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 0.5, color: Colors.white10),
                  itemBuilder: (context, index) {
                    final video = widget.playlist[index];
                    final active = index == _currentIndex;
                    return ListTile(
                      selected: active,
                      selectedTileColor: Colors.red.withValues(alpha: 0.12),
                      dense: true,
                      leading: SizedBox(
                        width: 24,
                        child: active
                            ? const Icon(Icons.play_arrow,
                                color: Colors.red, size: 18)
                            : Text(
                                '${index + 1}',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                      ),
                      title: Text(
                        video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? Colors.red : Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      trailing: video.isShort
                          ? const Text(
                              'SHORT',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                      onTap: () => _playAt(index),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

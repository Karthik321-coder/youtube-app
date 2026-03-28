import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'widgets/player_controls.dart';

class FullscreenPlayerPage extends StatefulWidget {
  final YoutubePlayerController controller;
  final String title;

  const FullscreenPlayerPage({
    super.key,
    required this.controller,
    this.title = '',
  });

  @override
  State<FullscreenPlayerPage> createState() => _FullscreenPlayerPageState();
}

class _FullscreenPlayerPageState extends State<FullscreenPlayerPage> {
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleControls() =>
      setState(() => _controlsVisible = !_controlsVisible);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: YoutubePlayer(
                controller: widget.controller,
                showVideoProgressIndicator: false,
              ),
            ),
            if (_controlsVisible) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.72),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.fullscreen_exit,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          if (widget.title.isNotEmpty)
                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.72),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: PlayerControls(controller: widget.controller),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

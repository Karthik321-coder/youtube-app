import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../models/video_item.dart';
import 'loading_placeholder.dart';
import 'player_controls.dart';

class VideoPlayerWidget extends StatelessWidget {
  final YoutubePlayerController controller;
  final VideoItem video;
  final bool isLoading;
  final VoidCallback? onReady;
  final VoidCallback? onEnded;
  final VoidCallback? onFullscreen;
  final String selectedQuality;
  final ValueChanged<String>? onQualityChanged;
  final VoidCallback? onDownload;

  const VideoPlayerWidget({
    super.key,
    required this.controller,
    required this.video,
    this.isLoading = false,
    this.onReady,
    this.onEnded,
    this.onFullscreen,
    this.selectedQuality = 'Auto',
    this.onQualityChanged,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      onExitFullScreen: controller.play,
      player: YoutubePlayer(
        controller: controller,
        showVideoProgressIndicator: false,
        onReady: () {
          controller.play();
          onReady?.call();
        },
        onEnded: (YoutubeMetaData _) => onEnded?.call(),
      ),
      builder: (context, player) {
        final sizedPlayer = video.isShort
            ? AspectRatio(aspectRatio: 9 / 16, child: player)
            : player;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                sizedPlayer,
                if (isLoading)
                  Positioned.fill(
                    child: LoadingPlaceholder(isShort: video.isShort),
                  ),
              ],
            ),
            if (!isLoading)
              PlayerControls(
                controller: controller,
                onFullscreen: onFullscreen,
                selectedQuality: selectedQuality,
                onQualityChanged: onQualityChanged,
                onDownload: onDownload,
              ),
          ],
        );
      },
    );
  }
}

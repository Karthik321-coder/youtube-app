import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class PlayerControls extends StatelessWidget {
  final YoutubePlayerController controller;
  final VoidCallback? onFullscreen;
  final String selectedQuality;
  final ValueChanged<String>? onQualityChanged;
  final VoidCallback? onDownload;

  const PlayerControls({
    super.key,
    required this.controller,
    this.onFullscreen,
    this.selectedQuality = 'Auto',
    this.onQualityChanged,
    this.onDownload,
  });

  Future<void> _openSettings(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
        final qualities = <String>[
          'Auto',
          '360p',
          '720p',
          '1080p',
          '1440p',
          '2160p'
        ];
        return ValueListenableBuilder<YoutubePlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final currentSpeed = value.playbackRate;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Player Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Playback speed',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: speeds.map((speed) {
                        final selected = (currentSpeed - speed).abs() < 0.001;
                        return ChoiceChip(
                          label: Text('${speed}x'),
                          selected: selected,
                          onSelected: (_) {
                            controller.setPlaybackRate(speed);
                          },
                          selectedColor: Colors.red.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: selected ? Colors.redAccent : Colors.white70,
                          ),
                          side: BorderSide(
                            color: selected
                                ? Colors.red.withValues(alpha: 0.6)
                                : Colors.white24,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Quality',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: qualities.map((quality) {
                        final selected = quality == selectedQuality;
                        return ChoiceChip(
                          label: Text(quality),
                          selected: selected,
                          onSelected: (_) => onQualityChanged?.call(quality),
                          selectedColor: Colors.red.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: selected ? Colors.redAccent : Colors.white70,
                          ),
                          side: BorderSide(
                            color: selected
                                ? Colors.red.withValues(alpha: 0.6)
                                : Colors.white24,
                          ),
                        );
                      }).toList(),
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

  String _formatDuration(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: ValueListenableBuilder<YoutubePlayerValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final position = value.position;
          final duration = value.metaData.duration;
          final isPlaying = value.playerState == PlayerState.playing;
          final isBuffering = value.playerState == PlayerState.buffering;
          final isMuted = value.volume == 0;

          final progress = duration.inMilliseconds > 0
              ? (position.inMilliseconds / duration.inMilliseconds)
                  .clamp(0.0, 1.0)
                  .toDouble()
              : 0.0;

          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 8, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10,
                    ),
                    activeTrackColor: Colors.red,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.red,
                    overlayColor: Colors.red.withValues(alpha: 0.18),
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: (value) {
                      final ms = (value * duration.inMilliseconds).round();
                      controller.seekTo(Duration(milliseconds: ms));
                    },
                  ),
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: isBuffering
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                color: Colors.white54,
                                strokeWidth: 2,
                              ),
                            )
                          : IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 26,
                              ),
                              onPressed: () => isPlaying
                                  ? controller.pause()
                                  : controller.play(),
                            ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${_formatDuration(position)}  /  ${_formatDuration(duration)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      icon: Icon(
                        isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: () =>
                          isMuted ? controller.unMute() : controller.mute(),
                    ),
                    if (onFullscreen != null)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        icon: const Icon(
                          Icons.fullscreen,
                          color: Colors.white70,
                          size: 22,
                        ),
                        onPressed: onFullscreen,
                      ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      icon: const Icon(
                        Icons.download,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: onDownload,
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      icon: const Icon(
                        Icons.settings,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: () => _openSettings(context),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

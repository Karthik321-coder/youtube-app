import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../models/stream_quality_option.dart';
import '../../models/video_item.dart';
import '../../shared/widgets/offline_banner.dart';
import '../downloads/downloads_notifier.dart';
import 'fullscreen_player_page.dart';
import 'player_notifier.dart';
import 'player_state_model.dart';
import 'widgets/video_player_widget.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final VideoItem video;

  const PlayerScreen({super.key, required this.video});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playerProvider.notifier).loadVideo(widget.video);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(playerProvider.notifier).pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  void _enterFullscreen(BuildContext context) {
    final state = ref.read(playerProvider);
    if (state.controller == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenPlayerPage(
          controller: state.controller!,
          title: state.currentVideo?.title ?? '',
        ),
      ),
    );
  }

  Future<void> _openDownloadSheet(VideoItem video) async {
    List<StreamQualityOption> qualities;

    try {
      qualities =
          await ref.read(downloadsProvider.notifier).loadQualities(video.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load qualities: $e')),
      );
      return;
    }

    if (!mounted || qualities.isEmpty) return;

    int selected = 0;

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
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: qualities.length,
                        itemBuilder: (context, index) {
                          final quality = qualities[index];
                          return RadioListTile<int>(
                            value: index,
                            groupValue: selected,
                            activeColor: Colors.red,
                            onChanged: (value) {
                              if (value != null) {
                                setSheetState(() => selected = value);
                              }
                            },
                            title: Text(
                              quality.displayLabel,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          await ref
                              .read(downloadsProvider.notifier)
                              .enqueueDownload(
                                video: video,
                                quality: qualities[selected],
                              );
                          if (!sheetContext.mounted || !mounted) return;
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('Download queued.')),
                          );
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
    final state = ref.watch(playerProvider);
    final video = state.currentVideo ?? widget.video;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          video.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPlayerArea(context, state, video),
                  _buildVideoInfo(video),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerArea(
    BuildContext context,
    PlayerStateModel state,
    VideoItem video,
  ) {
    if (state.controller == null && !state.hasError) {
      return AspectRatio(
        aspectRatio: video.isShort ? 9 / 16 : 16 / 9,
        child: const ColoredBox(
          color: Colors.black,
          child: Center(
            child:
                CircularProgressIndicator(color: Colors.red, strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (state.hasError) {
      return AspectRatio(
        aspectRatio: video.isShort ? 9 / 16 : 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white38, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    state.errorMessage,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.55,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 0.5),
                    ),
                    onPressed: () =>
                        ref.read(playerProvider.notifier).retryLoad(),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (state.controller != null) {
      return VideoPlayerWidget(
        controller: state.controller!,
        video: video,
        isLoading: state.isLoading,
        onReady: () => ref.read(playerProvider.notifier).onPlayerReady(),
        onEnded: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video ended'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        },
        onFullscreen: () => _enterFullscreen(context),
        selectedQuality: state.selectedQuality,
        onQualityChanged: (quality) =>
            ref.read(playerProvider.notifier).setPreferredQuality(quality),
        onDownload: () => _openDownloadSheet(video),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildVideoInfo(VideoItem video) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            video.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          if (video.channelTitle != null) ...[
            const SizedBox(height: 5),
            Text(
              video.channelTitle!,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Badge(
                  label: video.isShort ? 'Short' : 'Video',
                  accent: video.isShort),
              if (video.duration != null)
                _Badge(label: _formatDuration(video.duration!)),
              _Badge(label: video.id, mono: true),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return duration.inHours > 0 ? '${duration.inHours}:$m:$s' : '$m:$s';
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final bool accent;
  final bool mono;

  const _Badge({required this.label, this.accent = false, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final color = accent ? Colors.red : Colors.white30;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent ? Colors.red : Colors.white54,
          fontSize: 11,
          fontFamily: mono ? 'monospace' : null,
        ),
      ),
    );
  }
}

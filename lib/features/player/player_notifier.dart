import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/youtube_service.dart';
import '../../models/video_item.dart';
import 'player_state_model.dart';

class PlayerNotifier extends StateNotifier<PlayerStateModel> {
  final YouTubeService _service;
  bool _isDisposed = false;

  PlayerNotifier(this._service) : super(const PlayerStateModel());

  Future<void> loadVideo(VideoItem video) async {
    if (_isDisposed) return;

    state.controller?.dispose();
    state = PlayerStateModel(
      loadState: PlayerLoadState.loading,
      currentVideo: video,
    );

    VideoItem enriched = video;

    try {
      final meta = await _service.getVideoMetadata(video.id);
      if (meta != null) enriched = meta;
    } catch (_) {
      // Keep existing video data when metadata fetch fails.
    }

    if (_isDisposed) return;

    final controller = YoutubePlayerController(
      initialVideoId: enriched.id,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: false,
        hideThumbnail: false,
        loop: false,
      ),
    );

    controller.addListener(() => _onControllerUpdate(controller));

    if (_isDisposed) {
      controller.dispose();
      return;
    }

    state = PlayerStateModel(
      controller: controller,
      currentVideo: enriched,
      loadState: PlayerLoadState.loading,
    );
  }

  void onPlayerReady() {
    if (_isDisposed) return;
    state.controller?.play();
    if (!state.isReady) {
      state = state.copyWith(loadState: PlayerLoadState.ready);
    }
  }

  void swapVideo(VideoItem video) {
    if (_isDisposed) return;
    if (state.controller == null) {
      loadVideo(video);
      return;
    }
    state.controller!.load(video.id);
    state = state.copyWith(
      currentVideo: video,
      loadState: PlayerLoadState.loading,
    );
  }

  void retryLoad() {
    if (_isDisposed || state.currentVideo == null) return;
    loadVideo(state.currentVideo!);
  }

  void play() => state.controller?.play();
  void pause() => state.controller?.pause();
  void seekTo(Duration position) => state.controller?.seekTo(position);
  void mute() => state.controller?.mute();
  void unMute() => state.controller?.unMute();

  void setPreferredQuality(String qualityLabel) {
    if (_isDisposed) return;
    state = state.copyWith(selectedQuality: qualityLabel);

    final controller = state.controller;
    if (controller == null) return;

    final ytQuality = _youtubeQualityLabel(qualityLabel);
    try {
      if (ytQuality != null) {
        // Dynamic call keeps compatibility if the plugin API differs by version.
        (controller as dynamic).setPlaybackQuality(ytQuality);
      }
    } catch (_) {
      // Keep playback running even if quality hints are not supported.
    }
  }

  void _onControllerUpdate(YoutubePlayerController controller) {
    if (_isDisposed) return;
    final code = controller.value.errorCode;
    if (code != 0 && !state.hasError) {
      state = state.copyWith(
        loadState: PlayerLoadState.error,
        errorMessage: _errorCodeToMessage(code),
      );
    }
  }

  String _errorCodeToMessage(int code) {
    switch (code) {
      case 2:
        return 'Invalid video ID.\nPlease check the URL.';
      case 5:
        return 'This video cannot be played\nin an embedded player.';
      case 100:
        return 'Video not found.\nIt may be private or deleted.';
      case 101:
      case 150:
        return 'The video owner has disabled\nembedding for this video.';
      default:
        return 'Playback error (code $code).\nCheck your internet connection and try again.';
    }
  }

  String? _youtubeQualityLabel(String qualityLabel) {
    switch (qualityLabel) {
      case 'Auto':
        return 'auto';
      case '360p':
        return 'medium';
      case '720p':
        return 'hd720';
      case '1080p':
        return 'hd1080';
      case '1440p':
        return 'hd1440';
      case '2160p':
        return 'highres';
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    state.controller?.dispose();
    super.dispose();
  }
}

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerStateModel>((ref) {
  return PlayerNotifier(ref.watch(youtubeServiceProvider));
});

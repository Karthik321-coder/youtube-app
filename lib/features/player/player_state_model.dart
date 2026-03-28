import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../models/video_item.dart';

enum PlayerLoadState { idle, loading, ready, error }

class PlayerStateModel {
  final YoutubePlayerController? controller;
  final VideoItem? currentVideo;
  final PlayerLoadState loadState;
  final String errorMessage;
  final String selectedQuality;

  const PlayerStateModel({
    this.controller,
    this.currentVideo,
    this.loadState = PlayerLoadState.idle,
    this.errorMessage = '',
    this.selectedQuality = 'Auto',
  });

  bool get isIdle => loadState == PlayerLoadState.idle;
  bool get isLoading => loadState == PlayerLoadState.loading;
  bool get isReady => loadState == PlayerLoadState.ready;
  bool get hasError => loadState == PlayerLoadState.error;

  PlayerStateModel copyWith({
    YoutubePlayerController? controller,
    VideoItem? currentVideo,
    PlayerLoadState? loadState,
    String? errorMessage,
    String? selectedQuality,
  }) {
    return PlayerStateModel(
      controller: controller ?? this.controller,
      currentVideo: currentVideo ?? this.currentVideo,
      loadState: loadState ?? this.loadState,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedQuality: selectedQuality ?? this.selectedQuality,
    );
  }
}

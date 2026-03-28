import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/download_service.dart';
import '../../models/stream_quality_option.dart';
import '../../models/video_item.dart';

enum DownloadStatus { queued, downloading, completed, failed }

class DownloadTaskItem {
  final String id;
  final VideoItem video;
  final String quality;
  final DownloadStatus status;
  final double progress;
  final String? filePath;
  final String error;

  const DownloadTaskItem({
    required this.id,
    required this.video,
    required this.quality,
    required this.status,
    this.progress = 0,
    this.filePath,
    this.error = '',
  });

  DownloadTaskItem copyWith({
    DownloadStatus? status,
    double? progress,
    String? filePath,
    String? error,
  }) {
    return DownloadTaskItem(
      id: id,
      video: video,
      quality: quality,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      filePath: filePath ?? this.filePath,
      error: error ?? this.error,
    );
  }
}

class DownloadsNotifier extends StateNotifier<List<DownloadTaskItem>> {
  final DownloadService _downloadService;

  DownloadsNotifier(this._downloadService) : super(const []);

  Future<List<StreamQualityOption>> loadQualities(String videoId) {
    return _downloadService.fetchQualityOptions(videoId);
  }

  Future<void> enqueueDownload({
    required VideoItem video,
    required StreamQualityOption quality,
  }) async {
    final taskId =
        '${video.id}_${quality.itag}_${DateTime.now().millisecondsSinceEpoch}';
    final task = DownloadTaskItem(
      id: taskId,
      video: video,
      quality: quality.qualityLabel,
      status: DownloadStatus.queued,
    );

    state = [task, ...state];

    _updateTask(
        taskId, (old) => old.copyWith(status: DownloadStatus.downloading));

    try {
      final file = await _downloadService.downloadVideo(
        video: video,
        option: quality,
        onProgress: (progress) {
          _updateTask(
            taskId,
            (old) => old.copyWith(
                progress: progress, status: DownloadStatus.downloading),
          );
        },
      );

      _updateTask(
        taskId,
        (old) => old.copyWith(
          status: DownloadStatus.completed,
          progress: 1,
          filePath: file.path,
        ),
      );
    } on DownloadServiceException catch (e) {
      _updateTask(
        taskId,
        (old) => old.copyWith(status: DownloadStatus.failed, error: e.message),
      );
    } catch (e) {
      _updateTask(
        taskId,
        (old) => old.copyWith(status: DownloadStatus.failed, error: '$e'),
      );
    }
  }

  Future<void> removeTask(String id, {bool deleteFile = false}) async {
    DownloadTaskItem? task;
    for (final item in state) {
      if (item.id == id) {
        task = item;
        break;
      }
    }
    if (deleteFile && task?.filePath != null) {
      final file = File(task!.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    state = state.where((item) => item.id != id).toList(growable: false);
  }

  void _updateTask(
      String id, DownloadTaskItem Function(DownloadTaskItem old) update) {
    state = state
        .map((task) => task.id == id ? update(task) : task)
        .toList(growable: false);
  }
}

final downloadServiceProvider = Provider<DownloadService>((ref) {
  final service = DownloadService();
  ref.onDispose(service.dispose);
  return service;
});

final downloadsProvider =
    StateNotifierProvider<DownloadsNotifier, List<DownloadTaskItem>>((ref) {
  return DownloadsNotifier(ref.watch(downloadServiceProvider));
});

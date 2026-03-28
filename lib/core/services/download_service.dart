import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../models/stream_quality_option.dart';
import '../../models/video_item.dart';

class DownloadService {
  final YoutubeExplode _yt;

  DownloadService({YoutubeExplode? yt}) : _yt = yt ?? YoutubeExplode();

  Future<List<StreamQualityOption>> fetchQualityOptions(String videoId) async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    final options = <StreamQualityOption>[];

    for (final stream in manifest.muxed) {
      options.add(
        StreamQualityOption(
          itag: stream.tag,
          qualityLabel: stream.qualityLabel,
          container: stream.container.name,
          hasAudio: true,
          bitrateKbps: (stream.bitrate.bitsPerSecond / 1000).round(),
          sizeBytes: stream.size.totalBytes,
        ),
      );
    }

    options.sort((a, b) => _qualityScore(b.qualityLabel).compareTo(
          _qualityScore(a.qualityLabel),
        ));

    final unique = <int, StreamQualityOption>{};
    for (final option in options) {
      unique[option.itag] = option;
    }

    return unique.values.toList(growable: false);
  }

  Future<File> downloadVideo({
    required VideoItem video,
    required StreamQualityOption option,
    required void Function(double progress) onProgress,
  }) async {
    final manifest = await _yt.videos.streamsClient.getManifest(video.id);
    final muxed = manifest.muxed.firstWhere(
      (stream) => stream.tag == option.itag,
      orElse: () => throw const DownloadServiceException(
        'Selected quality is no longer available. Please refresh qualities.',
      ),
    );

    final outputDir = await _downloadsDirectory();
    if (!outputDir.existsSync()) {
      await outputDir.create(recursive: true);
    }

    final fileName = _safeFileName(
      '${video.title}_${option.qualityLabel}.${muxed.container.name}',
    );

    final outputFile =
        File('${outputDir.path}${Platform.pathSeparator}$fileName');

    final stream = _yt.videos.streamsClient.get(muxed);
    final sink = outputFile.openWrite(mode: FileMode.writeOnly);

    var received = 0;
    final total = muxed.size.totalBytes;

    try {
      await for (final chunk in stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) {
          onProgress((received / total).clamp(0.0, 1.0));
        }
      }
      await sink.flush();
      await sink.close();
      onProgress(1.0);
      return outputFile;
    } catch (e) {
      await sink.close();
      if (outputFile.existsSync()) {
        await outputFile.delete();
      }
      throw DownloadServiceException('Download failed: $e');
    }
  }

  Future<Directory> _downloadsDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}${Platform.pathSeparator}downloads');
  }

  int _qualityScore(String label) {
    final digits = RegExp(r'\d+').firstMatch(label)?.group(0);
    return int.tryParse(digits ?? '') ?? 0;
  }

  String _safeFileName(String input) {
    return input
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void dispose() {
    _yt.close();
  }
}

class DownloadServiceException implements Exception {
  final String message;

  const DownloadServiceException(this.message);

  @override
  String toString() => 'DownloadServiceException: $message';
}

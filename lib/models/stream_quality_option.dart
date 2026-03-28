class StreamQualityOption {
  final int itag;
  final String qualityLabel;
  final String container;
  final bool hasAudio;
  final int? bitrateKbps;
  final int? sizeBytes;

  const StreamQualityOption({
    required this.itag,
    required this.qualityLabel,
    required this.container,
    required this.hasAudio,
    this.bitrateKbps,
    this.sizeBytes,
  });

  String get displayLabel {
    final audio = hasAudio ? 'video+audio' : 'video-only';
    return '$qualityLabel ($audio, $container)';
  }
}

class VideoItem {
  final String id;
  final String title;
  final String? channelTitle;
  final String? thumbnailUrl;
  final Duration? duration;
  final bool isShort;

  const VideoItem({
    required this.id,
    required this.title,
    this.channelTitle,
    this.thumbnailUrl,
    this.duration,
    this.isShort = false,
  });

  String get mqThumbnailUrl =>
      thumbnailUrl ?? 'https://img.youtube.com/vi/$id/mqdefault.jpg';

  VideoItem copyWith({
    String? id,
    String? title,
    String? channelTitle,
    String? thumbnailUrl,
    Duration? duration,
    bool? isShort,
  }) {
    return VideoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      channelTitle: channelTitle ?? this.channelTitle,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      isShort: isShort ?? this.isShort,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is VideoItem && id == other.id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VideoItem(id: $id, title: $title, isShort: $isShort)';
}

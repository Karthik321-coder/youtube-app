import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../models/video_item.dart';

class VideoListTile extends StatelessWidget {
  final VideoItem video;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onDownloadTap;

  const VideoListTile({
    super.key,
    required this.video,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoriteTap,
    this.onDownloadTap,
  });

  String _formatDuration(Duration? duration) {
    if (duration == null) return '';
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Thumbnail(video: video),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (video.channelTitle != null) ...[
                        Flexible(
                          child: Text(
                            video.channelTitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const Text(
                          ' . ',
                          style: TextStyle(color: Colors.white24, fontSize: 11),
                        ),
                      ],
                      Text(
                        video.isShort ? 'Short' : 'Video',
                        style: TextStyle(
                          color: video.isShort ? Colors.red : Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                      if (video.duration != null) ...[
                        const Text(
                          ' . ',
                          style: TextStyle(color: Colors.white24, fontSize: 11),
                        ),
                        Text(
                          _formatDuration(video.duration),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (onFavoriteTap != null)
              IconButton(
                onPressed: onFavoriteTap,
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.redAccent : Colors.white38,
                  size: 18,
                ),
              ),
            if (onDownloadTap != null)
              IconButton(
                onPressed: onDownloadTap,
                icon: const Icon(
                  Icons.download_for_offline_outlined,
                  color: Colors.white54,
                  size: 18,
                ),
              ),
            const Icon(Icons.chevron_right, color: Colors.white12, size: 16),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final VideoItem video;

  const _Thumbnail({required this.video});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CachedNetworkImage(
            imageUrl: video.mqThumbnailUrl,
            width: 120,
            height: 68,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 120,
              height: 68,
              color: const Color(0xFF1E1E1E),
              child: const Icon(Icons.image_outlined,
                  color: Colors.white12, size: 24),
            ),
            errorWidget: (_, __, ___) => Container(
              width: 120,
              height: 68,
              color: const Color(0xFF1E1E1E),
              child: const Icon(
                Icons.broken_image_outlined,
                color: Colors.white12,
                size: 24,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.play_arrow, color: Colors.white, size: 18),
            ),
          ),
        ),
        if (video.isShort)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'SHORT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

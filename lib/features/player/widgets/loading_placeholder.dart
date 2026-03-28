import 'package:flutter/material.dart';

class LoadingPlaceholder extends StatefulWidget {
  final bool isShort;

  const LoadingPlaceholder({super.key, this.isShort = false});

  @override
  State<LoadingPlaceholder> createState() => _LoadingPlaceholderState();
}

class _LoadingPlaceholderState extends State<LoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => ColoredBox(
        color: Color.lerp(
          const Color(0xFF1C1C1C),
          const Color(0xFF2E2E2E),
          _animation.value,
        )!,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Colors.red,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Loading video...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.28),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

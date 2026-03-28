import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/connectivity_service.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(isConnectedProvider);

    return connectivity.when(
      data: (connected) {
        if (connected) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: const Color(0xFF1A1A1A),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white54, size: 16),
              SizedBox(width: 8),
              Text(
                'No internet connection',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

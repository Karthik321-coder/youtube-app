import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Stream<bool> get onChanged => _connectivity.onConnectivityChanged.map(
        (results) => results.any((result) => result != ConnectivityResult.none),
      );

  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService(),
);

final isConnectedProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).onChanged;
});

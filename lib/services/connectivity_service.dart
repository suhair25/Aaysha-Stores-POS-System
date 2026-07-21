import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:aaysha_stores/utils/logger.dart';

/// Network connectivity service
/// Manages internet connection detection
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal();

  /// Check initial connection status
  Future<bool> initializeConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = result != ConnectivityResult.none;
      AppLogger.info('Initial connectivity check: $_isOnline');
      _startListening();
      return _isOnline;
    } catch (e) {
      AppLogger.error('Error checking connectivity', e);
      return false;
    }
  }

  /// Listen to connectivity changes
  void _startListening() {
    _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;

      if (wasOnline != _isOnline) {
        if (_isOnline) {
          AppLogger.success('Internet connection established');
          _onConnectionRestored();
        } else {
          AppLogger.warning('Internet connection lost - switching to offline mode');
          _onConnectionLost();
        }
      }
    });
  }

  /// Called when connection is restored
  void _onConnectionRestored() {
    // Trigger sync operations
    // This will be connected to SyncService
  }

  /// Called when connection is lost
  void _onConnectionLost() {
    // Switch to offline mode
    // Disable cloud operations, queue for later
  }

  /// Get current connection status
  bool get isOnline => _isOnline;

  /// Get current connection status as stream
  Stream<bool> get connectionStatusStream {
    return _connectivity.onConnectivityChanged.map((result) {
      final online = result != ConnectivityResult.none;
      return online;
    });
  }

  /// Force check connectivity
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = result != ConnectivityResult.none;
      AppLogger.debug('Connectivity check: $_isOnline');
      return _isOnline;
    } catch (e) {
      AppLogger.error('Error checking connectivity', e);
      return false;
    }
  }

  /// Get connection type
  Future<String> getConnectionType() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return _connectionResultToString(result);
    } catch (e) {
      AppLogger.error('Error getting connection type', e);
      return 'Unknown';
    }
  }

  /// Convert ConnectivityResult to readable string
  String _connectionResultToString(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.mobile:
        return 'Mobile Network';
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.none:
        return 'No Connection';
      default:
        return 'Unknown';
    }
  }

  /// Wait for connection
  Future<void> waitForConnection() async {
    if (_isOnline) return;

    AppLogger.info('Waiting for internet connection...');
    await connectionStatusStream.firstWhere((online) => online);
    AppLogger.success('Internet connection is available');
  }
}

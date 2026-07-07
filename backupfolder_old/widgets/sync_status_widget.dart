import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/persistent_sync_service.dart';
import 'package:intl/intl.dart';

/// Widget to display sync status and provide manual sync trigger
class SyncStatusWidget extends StatefulWidget {
  final String? classID;
  final VoidCallback? onSyncComplete;

  const SyncStatusWidget({
    super.key,
    this.classID,
    this.onSyncComplete,
  });

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  final _syncService = PersistentSyncService();
  bool _isOnline = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _updateSyncStatus();

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() {
          _isOnline = result != ConnectivityResult.none;
        });
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
    }
  }

  void _updateSyncStatus() {
    if (mounted) {
      setState(() {
        _isSyncing = _syncService.isSyncing();
        _lastSyncTime = _syncService.getLastSyncTime();
      });
    }
  }

  Future<void> _triggerManualSync() async {
    if (_isSyncing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync already in progress'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await _syncService.syncAllData();

      if (mounted) {
        setState(() {
          _isSyncing = false;
          _lastSyncTime = DateTime.now();
        });

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sync completed: ${result.learnersSynced} learners, ${result.clockingRecordsSynced} clocking records',
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Notify parent
          widget.onSyncComplete?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sync failed: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatLastSyncTime() {
    if (_lastSyncTime == null) {
      return 'Never synced';
    }

    final now = DateTime.now();
    final difference = now.difference(_lastSyncTime!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, HH:mm').format(_lastSyncTime!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _isOnline ? Colors.green.shade50 : Colors.orange.shade50,
        border: Border(
          bottom: BorderSide(
            color: _isOnline ? Colors.green.shade200 : Colors.orange.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Status indicator
          Icon(
            _isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: _isOnline ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),

          // Status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isOnline ? 'Online' : 'Offline Mode',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isOnline
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Last sync: ${_formatLastSyncTime()}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Sync button
          if (_isOnline)
            _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.sync),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _triggerManualSync,
                    tooltip: 'Sync now',
                  ),
        ],
      ),
    );
  }
}

/// Compact version for app bar
class CompactSyncStatusWidget extends StatefulWidget {
  final VoidCallback? onTap;

  const CompactSyncStatusWidget({
    super.key,
    this.onTap,
  });

  @override
  State<CompactSyncStatusWidget> createState() =>
      _CompactSyncStatusWidgetState();
}

class _CompactSyncStatusWidgetState extends State<CompactSyncStatusWidget> {
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();

    Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() {
          _isOnline = result != ConnectivityResult.none;
        });
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _isOnline ? Colors.green.shade100 : Colors.orange.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isOnline ? Icons.cloud_done : Icons.cloud_off,
              color: _isOnline ? Colors.green.shade700 : Colors.orange.shade700,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              _isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color:
                    _isOnline ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Query Queue Service
/// 
/// Manages API request queuing with:
/// - Controlled concurrency (max 3 simultaneous requests)
/// - Request prioritization (high, normal, low)
/// - Automatic retry with exponential backoff
/// - Request deduplication
/// - Cancellation support
/// 
/// Usage:
/// ```dart
/// final result = await QueryQueueService.instance.enqueue(
///   () => http.get(Uri.parse('...')),
///   priority: Priority.high,
/// );
/// ```
class QueryQueueService {
  static final QueryQueueService instance = QueryQueueService._();
  QueryQueueService._();

  // Configuration
  static const int maxConcurrentRequests = 3;
  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(seconds: 1);

  // Queue management
  final Queue<_QueuedRequest> _queue = Queue();
  final Set<String> _runningRequestIds = {};
  final Map<String, dynamic> _cachedResults = {};
  int _activeRequests = 0;

  /// Enqueue a request
  Future<T> enqueue<T>(
    Future<T> Function() request, {
    Priority priority = Priority.normal,
    String? cacheKey,
    Duration? cacheFor,
    bool deduplicateBy,
  }) async {
    // Check cache first
    if (cacheKey != null && _cachedResults.containsKey(cacheKey)) {
      final cached = _cachedResults[cacheKey];
      if (cached is _CachedResult && !cached.isExpired) {
        debugPrint('✅ QueryQueue: Cache hit for $cacheKey');
        return cached.data as T;
      }
    }

    final completer = Completer<T>();
    final requestId = cacheKey ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Deduplicate if already running
    if (deduplicateBy && _runningRequestIds.contains(requestId)) {
      debugPrint('⏳ QueryQueue: Deduplicating request $requestId');
      return _waitForRunningRequest<T>(requestId);
    }

    final queuedRequest = _QueuedRequest<T>(
      id: requestId,
      request: request,
      priority: priority,
      completer: completer,
      retries: 0,
      cacheKey: cacheKey,
      cacheFor: cacheFor,
    );

    _addToQueue(queuedRequest);
    _processQueue();

    return completer.future;
  }

  /// Add request to queue based on priority
  void _addToQueue(_QueuedRequest request) {
    if (_queue.isEmpty) {
      _queue.add(request);
      return;
    }

    // Insert based on priority
    final list = _queue.toList();
    int insertIndex = list.length;

    for (int i = 0; i < list.length; i++) {
      if (request.priority.value > list[i].priority.value) {
        insertIndex = i;
        break;
      }
    }

    if (insertIndex == list.length) {
      _queue.add(request);
    } else {
      list.insert(insertIndex, request);
      _queue.clear();
      _queue.addAll(list);
    }

    debugPrint('📥 QueryQueue: Added ${request.id} (priority: ${request.priority.name}, queue size: ${_queue.length})');
  }

  /// Process queue
  void _processQueue() {
    while (_activeRequests < maxConcurrentRequests && _queue.isNotEmpty) {
      final request = _queue.removeFirst();
      _executeRequest(request);
    }
  }

  /// Execute a single request
  Future<void> _executeRequest(_QueuedRequest request) async {
    _activeRequests++;
    _runningRequestIds.add(request.id);

    debugPrint('🚀 QueryQueue: Executing ${request.id} (active: $_activeRequests/${maxConcurrentRequests})');

    try {
      final result = await request.request();

      // Cache result if requested
      if (request.cacheKey != null && request.cacheFor != null) {
        _cachedResults[request.cacheKey!] = _CachedResult(
          data: result,
          expiresAt: DateTime.now().add(request.cacheFor!),
        );
        debugPrint('💾 QueryQueue: Cached ${request.cacheKey} for ${request.cacheFor!.inSeconds}s');
      }

      request.completer.complete(result);
      debugPrint('✅ QueryQueue: Completed ${request.id}');
    } catch (error) {
      debugPrint('❌ QueryQueue: Error in ${request.id}: $error');

      // Retry logic
      if (request.retries < maxRetries) {
        request.retries++;
        final delay = initialRetryDelay * (1 << (request.retries - 1)); // Exponential backoff

        debugPrint('🔄 QueryQueue: Retrying ${request.id} (attempt ${request.retries}/$maxRetries) in ${delay.inSeconds}s');

        await Future.delayed(delay);
        _addToQueue(request);
      } else {
        request.completer.completeError(error);
        debugPrint('💀 QueryQueue: Failed ${request.id} after $maxRetries retries');
      }
    } finally {
      _activeRequests--;
      _runningRequestIds.remove(request.id);
      _processQueue();
    }
  }

  /// Wait for a running request to complete
  Future<T> _waitForRunningRequest<T>(String requestId) async {
    // Poll until request completes
    while (_runningRequestIds.contains(requestId)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Check if result is cached
    if (_cachedResults.containsKey(requestId)) {
      return (_cachedResults[requestId] as _CachedResult).data as T;
    }

    throw Exception('Deduplicated request completed but no result found');
  }

  /// Clear queue (for emergency situations)
  void clearQueue() {
    for (final request in _queue) {
      request.completer.completeError(Exception('Queue cleared'));
    }
    _queue.clear();
    debugPrint('🗑️ QueryQueue: Cleared');
  }

  /// Get queue status
  QueueStatus get status => QueueStatus(
        queueSize: _queue.length,
        activeRequests: _activeRequests,
        cachedResults: _cachedResults.length,
      );

  /// Clear expired cache
  void clearExpiredCache() {
    final now = DateTime.now();
    _cachedResults.removeWhere((key, value) {
      if (value is _CachedResult && value.isExpired) {
        debugPrint('🧹 QueryQueue: Cleared expired cache: $key');
        return true;
      }
      return false;
    });
  }
}

/// Request priority levels
enum Priority {
  high(3),
  normal(2),
  low(1);

  final int value;
  const Priority(this.value);
}

/// Internal queued request
class _QueuedRequest<T> {
  final String id;
  final Future<T> Function() request;
  final Priority priority;
  final Completer<T> completer;
  int retries;
  final String? cacheKey;
  final Duration? cacheFor;

  _QueuedRequest({
    required this.id,
    required this.request,
    required this.priority,
    required this.completer,
    required this.retries,
    this.cacheKey,
    this.cacheFor,
  });
}

/// Cached result with expiration
class _CachedResult {
  final dynamic data;
  final DateTime expiresAt;

  _CachedResult({required this.data, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Queue status info
class QueueStatus {
  final int queueSize;
  final int activeRequests;
  final int cachedResults;

  QueueStatus({
    required this.queueSize,
    required this.activeRequests,
    required this.cachedResults,
  });

  @override
  String toString() =>
      'QueueStatus(queue: $queueSize, active: $activeRequests, cached: $cachedResults)';
}

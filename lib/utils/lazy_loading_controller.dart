import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../services/query_queue_service.dart';

/// Lazy Loading Controller
/// 
/// Manages pagination and infinite scroll for large datasets.
/// 
/// Features:
/// - Automatic page loading on scroll
/// - Pull-to-refresh support
/// - Loading state management
/// - Error handling with retry
/// - Integrates with QueryQueueService
/// 
/// Usage:
/// ```dart
/// final controller = LazyLoadingController<Learner>(
///   fetchPage: (page, pageSize) async {
///     return await fetchLearners(page: page, pageSize: pageSize);
///   },
///   pageSize: 30,
/// );
/// ```
class LazyLoadingController<T> extends ChangeNotifier {
  // Configuration
  final Future<List<T>> Function(int page, int pageSize) fetchPage;
  final int pageSize;
  final ScrollController? scrollController;
  final bool useQueryQueue;
  final Priority queuePriority;

  // State
  final List<T> _items = [];
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  bool _isRefreshing = false;

  LazyLoadingController({
    required this.fetchPage,
    this.pageSize = 30,
    this.scrollController,
    this.useQueryQueue = true,
    this.queuePriority = Priority.normal,
  }) {
    _setupScrollListener();
  }

  // Getters
  List<T> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  bool get isRefreshing => _isRefreshing;
  bool get isEmpty => _items.isEmpty && !_isLoading;
  int get totalItems => _items.length;

  /// Initialize - load first page
  Future<void> initialize() async {
    if (_items.isEmpty && !_isLoading) {
      await loadNextPage();
    }
  }

  /// Load next page
  Future<void> loadNextPage() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('📄 LazyLoading: Loading page ${_currentPage + 1} (size: $pageSize)');

      final List<T> newItems;
      
      if (useQueryQueue) {
        // Use query queue for controlled concurrency
        newItems = await QueryQueueService.instance.enqueue(
          () => fetchPage(_currentPage + 1, pageSize),
          priority: queuePriority,
          cacheKey: 'page_${_currentPage + 1}_$pageSize',
          cacheFor: const Duration(minutes: 5),
          deduplicateBy: true,
        );
      } else {
        newItems = await fetchPage(_currentPage + 1, pageSize);
      }

      _items.addAll(newItems);
      _currentPage++;
      _hasMore = newItems.length >= pageSize;

      debugPrint('✅ LazyLoading: Loaded ${newItems.length} items (total: ${_items.length}, hasMore: $_hasMore)');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ LazyLoading: Error loading page: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh - clear and reload
  Future<void> refresh() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🔄 LazyLoading: Refreshing...');

      _items.clear();
      _currentPage = 0;
      _hasMore = true;

      await loadNextPage();
      
      debugPrint('✅ LazyLoading: Refresh complete');
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Retry after error
  Future<void> retry() async {
    if (_error != null) {
      await loadNextPage();
    }
  }

  /// Setup scroll listener for infinite scroll
  void _setupScrollListener() {
    scrollController?.addListener(_onScroll);
  }

  /// Handle scroll events
  void _onScroll() {
    if (scrollController == null) return;

    final threshold = scrollController!.position.maxScrollExtent * 0.8;
    
    if (scrollController!.position.pixels >= threshold) {
      loadNextPage();
    }
  }

  /// Add item (for optimistic updates)
  void addItem(T item) {
    _items.add(item);
    notifyListeners();
  }

  /// Remove item (for optimistic updates)
  void removeItem(T item) {
    _items.remove(item);
    notifyListeners();
  }

  /// Update item (for optimistic updates)
  void updateItem(int index, T item) {
    if (index >= 0 && index < _items.length) {
      _items[index] = item;
      notifyListeners();
    }
  }

  /// Clear all items
  void clear() {
    _items.clear();
    _currentPage = 0;
    _hasMore = true;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    scrollController?.removeListener(_onScroll);
    super.dispose();
  }
}

/// Extension for easier ListView.builder integration
extension LazyLoadingListView<T> on LazyLoadingController<T> {
  /// Build list item with loading indicator
  Widget buildItem(
    BuildContext context,
    int index,
    Widget Function(BuildContext, T) itemBuilder,
    Widget Function(BuildContext)? loadingBuilder,
  ) {
    // Show loading indicator at the end
    if (index == items.length) {
      if (isLoading) {
        return loadingBuilder?.call(context) ??
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
      }
      return const SizedBox.shrink();
    }

    return itemBuilder(context, items[index]);
  }

  /// Get item count for ListView.builder
  int get itemCount => items.length + (hasMore ? 1 : 0);
}

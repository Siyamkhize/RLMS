import 'package:flutter/material.dart';
import '../utils/lazy_loading_controller.dart';

/// Reusable Paginated List Widget
/// 
/// Drop-in replacement for ListView with automatic pagination.
/// 
/// Features:
/// - Infinite scroll
/// - Pull-to-refresh
/// - Loading indicators
/// - Error handling with retry
/// - Empty state
/// 
/// Usage:
/// ```dart
/// PaginatedListWidget<Learner>(
///   controller: lazyController,
///   itemBuilder: (context, learner) => LearnerTile(learner),
/// )
/// ```
class PaginatedListWidget<T> extends StatefulWidget {
  final LazyLoadingController<T> controller;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget Function(BuildContext)? loadingBuilder;
  final Widget Function(BuildContext, String)? errorBuilder;
  final Widget Function(BuildContext)? emptyBuilder;
  final Widget Function(BuildContext)? separatorBuilder;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool enableRefresh;

  const PaginatedListWidget({
    Key? key,
    required this.controller,
    required this.itemBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.separatorBuilder,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.enableRefresh = true,
  }) : super(key: key);

  @override
  State<PaginatedListWidget<T>> createState() => _PaginatedListWidgetState<T>();
}

class _PaginatedListWidgetState<T> extends State<PaginatedListWidget<T>> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
    widget.controller.initialize();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Show error state
    if (widget.controller.error != null && widget.controller.items.isEmpty) {
      return _buildError(context, widget.controller.error!);
    }

    // Show empty state
    if (widget.controller.isEmpty) {
      return widget.emptyBuilder?.call(context) ?? _buildDefaultEmpty(context);
    }

    // Show list
    final listView = ListView.separated(
      controller: widget.controller.scrollController,
      padding: widget.padding ?? const EdgeInsets.all(8.0),
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: widget.controller.itemCount,
      separatorBuilder: (context, index) =>
          widget.separatorBuilder?.call(context) ?? const Divider(height: 1),
      itemBuilder: (context, index) {
        return widget.controller.buildItem(
          context,
          index,
          widget.itemBuilder,
          widget.loadingBuilder,
        );
      },
    );

    // Wrap with RefreshIndicator if enabled
    if (widget.enableRefresh) {
      return RefreshIndicator(
        onRefresh: widget.controller.refresh,
        child: listView,
      );
    }

    return listView;
  }

  Widget _buildError(BuildContext context, String error) {
    return widget.errorBuilder?.call(context, error) ??
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading data',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: widget.controller.retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
  }

  Widget _buildDefaultEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No items found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search-enabled paginated list with debouncing
class SearchablePaginatedList<T> extends StatefulWidget {
  final Future<List<T>> Function(String query, int page, int pageSize) searchFetch;
  final Widget Function(BuildContext, T) itemBuilder;
  final String hintText;
  final int pageSize;
  final Duration debounceDuration;

  const SearchablePaginatedList({
    Key? key,
    required this.searchFetch,
    required this.itemBuilder,
    this.hintText = 'Search...',
    this.pageSize = 30,
    this.debounceDuration = const Duration(milliseconds: 500),
  }) : super(key: key);

  @override
  State<SearchablePaginatedList<T>> createState() => _SearchablePaginatedListState<T>();
}

class _SearchablePaginatedListState<T> extends State<SearchablePaginatedList<T>> {
  late LazyLoadingController<T> _controller;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _initController('');
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _initController(String query) {
    _controller = LazyLoadingController<T>(
      fetchPage: (page, pageSize) => widget.searchFetch(query, page, pageSize),
      pageSize: widget.pageSize,
      useQueryQueue: true,
      queuePriority: Priority.high,
    );
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      if (_currentQuery != _searchController.text) {
        _currentQuery = _searchController.text;
        setState(() {
          _controller.dispose();
          _initController(_currentQuery);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
        ),
        Expanded(
          child: PaginatedListWidget<T>(
            controller: _controller,
            itemBuilder: widget.itemBuilder,
          ),
        ),
      ],
    );
  }
}

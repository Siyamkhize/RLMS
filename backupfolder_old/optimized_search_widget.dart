import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class OptimizedSearchWidget extends StatefulWidget {
  final String? classID;
  final Function(Map<String, dynamic>) onLearnerSelected;
  final String hintText;
  final bool showAutocomplete;
  
  const OptimizedSearchWidget({
    super.key,
    this.classID,
    required this.onLearnerSelected,
    this.hintText = 'Search learner...',
    this.showAutocomplete = true,
  });

  @override
  _OptimizedSearchWidgetState createState() => _OptimizedSearchWidgetState();
}

class _OptimizedSearchWidgetState extends State<OptimizedSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    if (query.length < 2) {
      setState(() {
        _suggestions.clear();
        _showSuggestions = false;
      });
      _removeOverlay();
      return;
    }

    // Debounce search requests
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (widget.showAutocomplete) {
        _fetchSuggestions(query);
      } else {
        _performDirectSearch(query);
      }
    });
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // Delay hiding suggestions to allow for selection
      Timer(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _showSuggestions = false;
          });
          _removeOverlay();
        }
      });
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final url = AppConfig.buildUrl('search_autocomplete.php', queryParams: {
        'q': query,
        if (widget.classID != null) 'classID': widget.classID!,
        'limit': '8',
      });

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _suggestions = List<Map<String, dynamic>>.from(data['suggestions'] ?? []);
            _showSuggestions = _suggestions.isNotEmpty;
          });
          
          if (_showSuggestions) {
            _showOverlay();
          } else {
            _removeOverlay();
          }
        }
      }
    } catch (e) {
      print('Autocomplete error: $e');
      if (mounted) {
        setState(() {
          _suggestions.clear();
          _showSuggestions = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _performDirectSearch(String query) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final url = AppConfig.buildUrl('search_learner_optimized.php', queryParams: {
        'search': query,
        if (widget.classID != null) 'classID': widget.classID!,
        'type': 'all',
        'limit': '1',
      });

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'].isNotEmpty) {
          final learner = data['data'][0];
          widget.onLearnerSelected(learner);
        } else {
          _showNoResultsMessage();
        }
      }
    } catch (e) {
      print('Search error: $e');
      _showErrorMessage('Search failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showOverlay() {
    _removeOverlay();
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: LayerLink(),
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      suggestion['text'] ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                    onTap: () {
                      _selectSuggestion(suggestion);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    _searchController.text = suggestion['text'] ?? '';
    setState(() {
      _showSuggestions = false;
    });
    _removeOverlay();
    
    // Convert suggestion to learner format
    final learner = {
      'learner_id': suggestion['id'],
      'name': suggestion['name'],
      'surname': suggestion['surname'],
      'id_number': suggestion['id_number'],
    };
    
    widget.onLearnerSelected(learner);
  }

  void _showNoResultsMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No learner found with that search term'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    prefixIcon: const Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (value) {
                    if (!widget.showAutocomplete && value.trim().isNotEmpty) {
                      _performDirectSearch(value.trim());
                    }
                  },
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _suggestions.clear();
                      _showSuggestions = false;
                    });
                    _removeOverlay();
                  },
                ),
            ],
          ),
        ),
        // Show suggestions inline if overlay is not used
        if (!widget.showAutocomplete && _showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  title: Text(suggestion['text'] ?? ''),
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}

// Usage example widget
class SearchExample extends StatelessWidget {
  const SearchExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Optimized Search')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            OptimizedSearchWidget(
              classID: '123',
              showAutocomplete: true,
              hintText: 'Search learner by name or ID...',
              onLearnerSelected: (learner) {
                print('Selected learner: $learner');
                // Handle learner selection
              },
            ),
            const SizedBox(height: 20),
            const Text('Search results will appear here...'),
          ],
        ),
      ),
    );
  }
}
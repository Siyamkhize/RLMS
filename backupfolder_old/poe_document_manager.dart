import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

/// Manages POE documents including viewing, merging, and downloading
class PoeDocumentManager extends StatefulWidget {
  final int learnerId;
  final String learnerName;

  const PoeDocumentManager({
    super.key,
    required this.learnerId,
    required this.learnerName,
  });

  @override
  State<PoeDocumentManager> createState() => _PoeDocumentManagerState();
}

class _PoeDocumentManagerState extends State<PoeDocumentManager> {
  List<Map<String, dynamic>> _documents = [];
  final Set<int> _selectedDocuments = {};
  bool _isLoading = false;
  bool _isMerging = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/get_poe_documents.php?learner_id=${widget.learnerId}',
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _documents = List<Map<String, dynamic>>.from(data['documents'] ?? []);
          });
        }
      }
    } catch (e) {
      _showError('Failed to load documents: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _mergeSelectedDocuments() async {
    if (_selectedDocuments.length < 2) {
      _showError('Please select at least 2 documents to merge');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge Documents'),
        content: Text(
          'Merge ${_selectedDocuments.length} documents into one PDF?\n\n'
          'The original documents will be marked as merged but not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Merge'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isMerging = true;
    });

    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/merge_poe_documents.php');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'document_ids': _selectedDocuments.toList(),
          'learner_id': widget.learnerId.toString(),
          'mark_originals_as_merged': true,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _showSuccess('Documents merged successfully!');
          setState(() {
            _selectedDocuments.clear();
          });
          await _loadDocuments();
        } else {
          _showError(data['message'] ?? 'Merge failed');
        }
      } else {
        _showError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Failed to merge documents: $e');
    } finally {
      setState(() {
        _isMerging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POE Documents'),
        backgroundColor: Colors.green,
        actions: [
          if (_selectedDocuments.length >= 2)
            IconButton(
              icon: const Icon(Icons.merge_type),
              tooltip: 'Merge Selected',
              onPressed: _isMerging ? null : _mergeSelectedDocuments,
            ),
        ],
      ),
      body: Column(
        children: [
          // Learner info
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.learnerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('Learner ID: ${widget.learnerId}'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Selection info
          if (_selectedDocuments.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_selectedDocuments.length} document(s) selected',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedDocuments.clear();
                      });
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),

          // Merge instructions
          if (_documents.length >= 2 && _selectedDocuments.isEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Tip: Select multiple documents to merge them into one PDF',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Documents list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _documents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No POE documents found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadDocuments,
                        child: ListView.builder(
                          itemCount: _documents.length,
                          itemBuilder: (context, index) {
                            final doc = _documents[index];
                            final docId = doc['id'] as int;
                            final isSelected = _selectedDocuments.contains(docId);
                            final isMerged = doc['status'] == 'merged';

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              elevation: isSelected ? 4 : 1,
                              color: isSelected
                                  ? Colors.blue.shade50
                                  : isMerged
                                      ? Colors.grey.shade100
                                      : null,
                              child: ListTile(
                                leading: Checkbox(
                                  value: isSelected,
                                  onChanged: isMerged
                                      ? null
                                      : (value) {
                                          setState(() {
                                            if (value == true) {
                                              _selectedDocuments.add(docId);
                                            } else {
                                              _selectedDocuments.remove(docId);
                                            }
                                          });
                                        },
                                ),
                                title: Text(
                                  doc['file_name'] ?? 'Unknown',
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    decoration: isMerged
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.picture_as_pdf,
                                            size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_formatFileSize(doc['file_size'])} • ${doc['page_count'] ?? 0} pages',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDate(doc['upload_date']),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                    if (isMerged)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Merged into another document',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.orange.shade700,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    if (doc['document_type'] == 'POE_MERGED')
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'MERGED DOCUMENT',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.green.shade800,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'download') {
                                      _downloadDocument(doc);
                                    } else if (value == 'view') {
                                      _viewDocument(doc);
                                    } else if (value == 'delete') {
                                      _deleteDocument(doc);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'view',
                                      child: Row(
                                        children: [
                                          Icon(Icons.visibility, size: 20),
                                          SizedBox(width: 8),
                                          Text('View'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'download',
                                      child: Row(
                                        children: [
                                          Icon(Icons.download, size: 20),
                                          SizedBox(width: 8),
                                          Text('Download'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 20, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),

          // Merge button
          if (_selectedDocuments.length >= 2)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _isMerging ? null : _mergeSelectedDocuments,
                icon: _isMerging
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.merge_type),
                label: Text(
                  _isMerging
                      ? 'Merging...'
                      : 'Merge ${_selectedDocuments.length} Documents',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatFileSize(dynamic size) {
    if (size == null) return 'Unknown';
    final bytes = size is int ? size : int.tryParse(size.toString()) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown date';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return date.toString();
    }
  }

  void _downloadDocument(Map<String, dynamic> doc) {
    // TODO: Implement download functionality
    _showInfo('Download: ${doc['file_name']}');
  }

  void _viewDocument(Map<String, dynamic> doc) {
    // TODO: Implement PDF viewer
    _showInfo('View: ${doc['file_name']}');
  }

  Future<void> _deleteDocument(Map<String, dynamic> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Delete ${doc['file_name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Implement delete
      _showInfo('Delete: ${doc['file_name']}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

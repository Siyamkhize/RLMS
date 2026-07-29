import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/clocking_logger.dart';

class DebugLogViewer extends StatefulWidget {
  const DebugLogViewer({super.key});

  @override
  State<DebugLogViewer> createState() => _DebugLogViewerState();
}

class _DebugLogViewerState extends State<DebugLogViewer> {
  String _logContent = 'Loading logs...';
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await ClockingLogger.instance.getRecentLogs(maxLines: 500);
      setState(() {
        _logContent = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _logContent = 'Error loading logs: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    try {
      await ClockingLogger.instance.clearOldLogs();
      await _loadLogs();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs cleared successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing logs: $e')),
      );
    }
  }

  Future<void> _copyLogs() async {
    await Clipboard.setData(ClipboardData(text: _logContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }

  Future<void> _generateReport() async {
    try {
      await ClockingLogger.instance.generateSummaryReport();
      await _loadLogs();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summary report generated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadLogs();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'copy':
                  _copyLogs();
                  break;
                case 'clear':
                  _clearLogs();
                  break;
                case 'report':
                  _generateReport();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 8),
                    Text('Copy Logs'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.summarize),
                    SizedBox(width: 8),
                    Text('Generate Report'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear Logs'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔍 Debugging Clocking Issues',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Watch for "SERVER DATA CHANGE" entries showing unexpected clock-outs\n'
                          '• Look for HTTP requests to clockout.php you didn\'t initiate\n'
                          '• Check timing patterns for automatic behaviors\n'
                          '• Monitor sync operations that might overwrite data',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Scrollbar(
                        controller: _scrollController,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: SelectableText(
                            _logContent,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        },
        tooltip: 'Scroll to bottom',
        child: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

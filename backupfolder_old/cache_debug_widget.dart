import 'package:flutter/material.dart';
import 'database_helper.dart';

/// Debug widget to check offline cache status
/// Add this to your POE tab to see cache information
class CacheDebugWidget extends StatefulWidget {
  final int learnerID;
  
  const CacheDebugWidget({super.key, required this.learnerID});

  @override
  State<CacheDebugWidget> createState() => _CacheDebugWidgetState();
}

class _CacheDebugWidgetState extends State<CacheDebugWidget> {
  String cacheStatus = 'Checking...';
  bool isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  Future<void> _checkCache() async {
    setState(() {
      isChecking = true;
      cacheStatus = 'Checking cache...';
    });

    try {
      final dbHelper = DatabaseHelper();
      
      // Check if table exists
      final db = await dbHelper.database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='learner_pathways_cache'"
      );
      
      if (tables.isEmpty) {
        setState(() {
          cacheStatus = '❌ Cache table does not exist\nDatabase needs upgrade';
          isChecking = false;
        });
        return;
      }

      // Check if cache exists for this learner
      final cache = await dbHelper.getLearnerPathwaysCache(widget.learnerID);
      
      if (cache == null) {
        setState(() {
          cacheStatus = '⚠️ No cache for learner ${widget.learnerID}\nLoad POE tab while online to cache';
          isChecking = false;
        });
        return;
      }

      // Cache exists, get details
      final results = await db.query(
        'learner_pathways_cache',
        where: 'learnerID = ?',
        whereArgs: [widget.learnerID],
      );
      
      if (results.isNotEmpty) {
        final row = results.first;
        final updatedAt = row['updated_at'] as String?;
        final jsonLength = (row['pathways_json'] as String?)?.length ?? 0;
        
        setState(() {
          cacheStatus = '✅ Cache exists for learner ${widget.learnerID}\n'
              'Data size: ${(jsonLength / 1024).toStringAsFixed(2)} KB\n'
              'Updated: ${updatedAt ?? 'Unknown'}';
          isChecking = false;
        });
      }
    } catch (e) {
      setState(() {
        cacheStatus = '❌ Error checking cache: $e';
        isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'Offline Cache Status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const Spacer(),
              if (!isChecking)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _checkCache,
                  tooltip: 'Refresh',
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (isChecking)
            const Center(
              child: CircularProgressIndicator(),
            )
          else
            Text(
              cacheStatus,
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }
}

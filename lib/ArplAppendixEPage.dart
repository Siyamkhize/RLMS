import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class ArplAppendixEPage extends StatefulWidget {
  final int learnerID;
  final String learnerName;
  final String ofoNumber;
  final int facilitatorId;

  const ArplAppendixEPage({
    Key? key,
    required this.learnerID,
    required this.learnerName,
    required this.ofoNumber,
    required this.facilitatorId,
  }) : super(key: key);

  @override
  _ArplAppendixEPageState createState() => _ArplAppendixEPageState();
}

class _ArplAppendixEPageState extends State<ArplAppendixEPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _activities = [];
  Map<int, int> _ratings = {}; // activity_id => rating (1-5)
  Map<int, String> _comments = {}; // activity_id => comment
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadActivitiesAndRatings();
  }

  Future<void> _loadActivitiesAndRatings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/mobile/get_arpl_appendix_e.php'),
        body: {
          'learnerID': widget.learnerID.toString(),
          'ofo_number': widget.ofoNumber,
          'facilitator_id': widget.facilitatorId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          setState(() {
            _activities =
                List<Map<String, dynamic>>.from(data['activities'] ?? []);

            // Load existing ratings
            Map<String, dynamic> existingRatings =
                data['existing_ratings'] ?? {};
            existingRatings.forEach((activityIdStr, ratingData) {
              int activityId = int.parse(activityIdStr);
              _ratings[activityId] = int.tryParse(
                      ratingData['competency_scale_id']?.toString() ?? '0') ??
                  0;
              _comments[activityId] = ratingData['comments']?.toString() ?? '';
            });
          });
        } else {
          _showError(data['message'] ?? 'Failed to load activities');
        }
      }
    } catch (e) {
      _showError('Error loading activities: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveRatings() async {
    // Validate: at least one rating must be provided
    if (_ratings.isEmpty) {
      _showError('Please rate at least one activity before saving');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      List<Map<String, dynamic>> ratingsPayload = [];

      _ratings.forEach((activityId, rating) {
        if (rating >= 1 && rating <= 5) {
          // Find activity name
          String activityName = '';
          for (var activity in _activities) {
            if (activity['activity_id'].toString() == activityId.toString()) {
              activityName = activity['activity_name'] ?? '';
              break;
            }
          }

          ratingsPayload.add({
            'activity_id': activityId,
            'activity_name': activityName,
            'competency_scale_id': rating,
            'comments': _comments[activityId] ?? '',
          });
        }
      });

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/mobile/save_arpl_appendix_e.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'learnerID': widget.learnerID,
          'ofo_number': widget.ofoNumber,
          'facilitator_id': widget.facilitatorId,
          'ratings': ratingsPayload,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Ratings saved successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Reload to show updated data
          await _loadActivitiesAndRatings();
        } else {
          _showError(data['message'] ?? 'Failed to save ratings');
        }
      }
    } catch (e) {
      _showError('Error saving ratings: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appendix E - Activity Ratings'),
            Text(
              widget.learnerName,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        actions: [
          if (!_isLoading && _activities.isNotEmpty)
            IconButton(
              icon: Icon(Icons.info_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Rating Scale'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('1 = Not Competent',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('2 = Needs Improvement'),
                        Text('3 = Competent'),
                        Text('4 = Highly Competent'),
                        Text('5 = Expert',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No activities found for this qualification'),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadActivitiesAndRatings,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Summary header
                    Container(
                      padding: EdgeInsets.all(16),
                      color: Colors.deepPurple.shade50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Activities: ${_activities.length}',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Rated: ${_ratings.length}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _ratings.length == _activities.length
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Activities list
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.all(8),
                        itemCount: _activities.length,
                        itemBuilder: (context, index) {
                          final activity = _activities[index];
                          final activityId = int.tryParse(
                                  activity['activity_id']?.toString() ?? '0') ??
                              0;
                          final currentRating = _ratings[activityId] ?? 0;
                          final currentComment = _comments[activityId] ?? '';

                          return Card(
                            elevation: 3,
                            margin: EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Activity name
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.deepPurple,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          activity['activity_name'] ??
                                              'Unknown Activity',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Activity description (if available)
                                  if (activity['activity_description'] !=
                                          null &&
                                      activity['activity_description']
                                          .toString()
                                          .isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        activity['activity_description'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),

                                  SizedBox(height: 16),

                                  // Rating label
                                  Text(
                                    'Rating: ${currentRating > 0 ? currentRating : "Not Rated"}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: currentRating > 0
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                  ),

                                  SizedBox(height: 8),

                                  // Rating buttons (1-5)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: List.generate(5, (ratingIndex) {
                                      int ratingValue = ratingIndex + 1;
                                      bool isSelected =
                                          currentRating == ratingValue;

                                      return Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 4),
                                          child: ElevatedButton(
                                            onPressed: () {
                                              setState(() {
                                                _ratings[activityId] =
                                                    ratingValue;
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isSelected
                                                  ? _getRatingColor(ratingValue)
                                                  : Colors.grey[300],
                                              foregroundColor: isSelected
                                                  ? Colors.white
                                                  : Colors.black,
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text(
                                              '$ratingValue',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),

                                  SizedBox(height: 12),

                                  // Comments field
                                  TextField(
                                    decoration: InputDecoration(
                                      labelText: 'Comments (optional)',
                                      border: OutlineInputBorder(),
                                      hintText:
                                          'Add notes about this activity...',
                                      isDense: true,
                                    ),
                                    maxLines: 2,
                                    controller: TextEditingController(
                                        text: currentComment)
                                      ..selection = TextSelection.fromPosition(
                                        TextPosition(
                                            offset: currentComment.length),
                                      ),
                                    onChanged: (value) {
                                      _comments[activityId] = value;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Save button
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveRatings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSaving
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Saving...'),
                                  ],
                                )
                              : Text(
                                  'Save Ratings',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.amber;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

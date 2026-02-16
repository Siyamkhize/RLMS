import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

class WorkExperienceForm extends StatefulWidget {
  final String learnerID;

  const WorkExperienceForm({super.key, required this.learnerID});

  @override
  _WorkExperienceFormState createState() => _WorkExperienceFormState();
}

class _WorkExperienceFormState extends State<WorkExperienceForm> {
  List<Map<String, dynamic>> _workExperiences = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkExperiences();
  }

  Future<void> _loadWorkExperiences() async {
    setState(() => _isLoading = true);
    try {
      final experiences = await DatabaseHelper().getWorkExperiences(widget.learnerID);
      setState(() {
        _workExperiences = experiences;
        _isLoading = false;
      });
    } catch (e) {
      print('[WORK_EXP] Error loading work experiences: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addNewExperience() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkExperienceEditPage(
          learnerID: widget.learnerID,
        ),
      ),
    );

    if (result == true) {
      _loadWorkExperiences();
    }
  }

  Future<void> _editExperience(Map<String, dynamic> experience) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkExperienceEditPage(
          learnerID: widget.learnerID,
          experience: experience,
        ),
      ),
    );

    if (result == true) {
      _loadWorkExperiences();
    }
  }

  Future<void> _deleteExperience(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Work Experience'),
        content: const Text('Are you sure you want to delete this work experience?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseHelper().deleteWorkExperience(id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Work experience deleted')),
        );
        _loadWorkExperiences();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workExperiences.isEmpty
          ? _buildEmptyState()
          : _buildExperienceList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewExperience,
        icon: const Icon(Icons.add),
        label: const Text('Add Experience'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Work Experience Added',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button below to add work experience',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _workExperiences.length,
      itemBuilder: (context, index) {
        final exp = _workExperiences[index];
        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16.0),
          child: InkWell(
            onTap: () => _editExperience(exp),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          exp['employer_name'] ?? 'Unknown Employer',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteExperience(exp['id']),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.work, exp['position_held'] ?? 'N/A'),
                  const SizedBox(height: 4),
                  _buildInfoRow(
                    Icons.calendar_today,
                    '${_formatDate(exp['period_from'])} - ${_formatDate(exp['period_to'])}',
                  ),
                  if (exp['responsibilities'] != null && exp['responsibilities'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Responsibilities:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exp['responsibilities'],
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        exp['synced'] == 1 ? Icons.cloud_done : Icons.cloud_off,
                        size: 16,
                        color: exp['synced'] == 1 ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        exp['synced'] == 1 ? 'Synced' : 'Not synced',
                        style: TextStyle(
                          fontSize: 12,
                          color: exp['synced'] == 1 ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(date.toString());
      return DateFormat('MMM yyyy').format(dateTime);
    } catch (e) {
      return date.toString();
    }
  }
}

class WorkExperienceEditPage extends StatefulWidget {
  final String learnerID;
  final Map<String, dynamic>? experience;

  const WorkExperienceEditPage({
    super.key,
    required this.learnerID,
    this.experience,
  });

  @override
  _WorkExperienceEditPageState createState() => _WorkExperienceEditPageState();
}

class _WorkExperienceEditPageState extends State<WorkExperienceEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _employerNameController = TextEditingController();
  final _positionController = TextEditingController();
  final _responsibilitiesController = TextEditingController();
  DateTime? _periodFrom;
  DateTime? _periodTo;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.experience != null) {
      _employerNameController.text = widget.experience!['employer_name'] ?? '';
      _positionController.text = widget.experience!['position_held'] ?? '';
      _responsibilitiesController.text = widget.experience!['responsibilities'] ?? '';
      
      if (widget.experience!['period_from'] != null) {
        _periodFrom = DateTime.parse(widget.experience!['period_from']);
      }
      if (widget.experience!['period_to'] != null) {
        _periodTo = DateTime.parse(widget.experience!['period_to']);
      }
    }
  }

  @override
  void dispose() {
    _employerNameController.dispose();
    _positionController.dispose();
    _responsibilitiesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_periodFrom ?? DateTime.now()) : (_periodTo ?? DateTime.now()),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _periodFrom = picked;
        } else {
          _periodTo = picked;
        }
      });
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _saveExperience() async {
    if (!_formKey.currentState!.validate()) return;

    if (_periodFrom == null || _periodTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both start and end dates')),
      );
      return;
    }

    if (_periodTo!.isBefore(_periodFrom!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after start date')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final experienceData = {
        'learner_id': widget.learnerID,
        'employer_name': _employerNameController.text.trim(),
        'position_held': _positionController.text.trim(),
        'period_from': _periodFrom!.toIso8601String().split('T')[0],
        'period_to': _periodTo!.toIso8601String().split('T')[0],
        'responsibilities': _responsibilitiesController.text.trim(),
        'synced': 0,
      };

      // Save to local database first
      int id;
      if (widget.experience != null) {
        experienceData['id'] = widget.experience!['id'];
        await DatabaseHelper().updateWorkExperience(experienceData);
        id = widget.experience!['id'];
      } else {
        id = await DatabaseHelper().insertWorkExperience(experienceData);
      }

      // Try to sync to server if online
      bool isOnline = await _checkConnectivity();
      print('[WORK_EXP] Connectivity check: $isOnline');
      
      if (isOnline) {
        try {
          final url = '${AppConfig.baseUrl}/save_work_experience.php';
          print('[WORK_EXP] Syncing to: $url');
          print('[WORK_EXP] Data: ${jsonEncode(experienceData)}');
          
          final response = await http.post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(experienceData),
          ).timeout(const Duration(seconds: 30));

          print('[WORK_EXP] Response status: ${response.statusCode}');
          print('[WORK_EXP] Response body: ${response.body}');

          if (response.statusCode == 200) {
            final jsonResponse = jsonDecode(response.body);
            if (jsonResponse['success'] == true) {
              // Mark as synced
              await DatabaseHelper().markWorkExperienceSynced(id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Work experience saved and synced'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              print('[WORK_EXP] Server returned success=false: ${jsonResponse['message']}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Saved locally. Server: ${jsonResponse['message']}'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } else {
            print('[WORK_EXP] HTTP error: ${response.statusCode}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Saved locally. Server error: ${response.statusCode}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } catch (e) {
          print('[WORK_EXP] Error syncing to server: $e');
          print('[WORK_EXP] Error type: ${e.runtimeType}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved locally. Sync error: ${e.toString().substring(0, 50)}...'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        print('[WORK_EXP] Device is offline');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved locally, will sync when online'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
      print('[WORK_EXP] Error saving work experience: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.experience != null ? 'Edit Work Experience' : 'Add Work Experience'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveExperience,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Last Employer',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _employerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Name of Employer *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter employer name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _positionController,
                      decoration: const InputDecoration(
                        labelText: 'Position Held *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.work),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter position held';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, true),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Period From *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                _periodFrom != null
                                    ? DateFormat('dd MMM yyyy').format(_periodFrom!)
                                    : 'Select date',
                                style: TextStyle(
                                  color: _periodFrom != null ? Colors.black : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, false),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Period To *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                _periodTo != null
                                    ? DateFormat('dd MMM yyyy').format(_periodTo!)
                                    : 'Select date',
                                style: TextStyle(
                                  color: _periodTo != null ? Colors.black : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _responsibilitiesController,
                      decoration: const InputDecoration(
                        labelText: 'Responsibilities',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.list),
                        hintText: 'Describe your key responsibilities...',
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter responsibilities';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveExperience,
              icon: const Icon(Icons.save),
              label: Text(widget.experience != null ? 'Update Experience' : 'Save Experience'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

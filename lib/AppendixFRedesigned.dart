library appendix_f_redesigned;

import 'dart:convert';
import 'package:flutter/material.dart';

class AppendixFKnowledgeQuestion {
  int questionNumber;
  TextEditingController questionController;
  TextEditingController scoreController;
  TextEditingController percentageController;

  AppendixFKnowledgeQuestion({
    required this.questionNumber,
    String? questionText,
    int? score,
    double? percentage,
  })  : questionController = TextEditingController(text: questionText ?? ''),
        scoreController = TextEditingController(text: score?.toString() ?? ''),
        percentageController =
            TextEditingController(text: percentage?.toString() ?? '');

  void dispose() {
    questionController.dispose();
    scoreController.dispose();
    percentageController.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'question_number': questionNumber,
      'question_text': questionController.text,
      'candidate_score': int.tryParse(scoreController.text) ?? 0,
      'percentage': double.tryParse(percentageController.text) ?? 0.0,
    };
  }

  factory AppendixFKnowledgeQuestion.fromJson(Map<String, dynamic> json) {
    return AppendixFKnowledgeQuestion(
      questionNumber: json['question_number'] as int? ?? 0,
      questionText: json['question_text'] as String?,
      score: json['candidate_score'] as int?,
      percentage: (json['percentage'] as num?)?.toDouble(),
    );
  }
}

class AppendixFPracticalTask {
  int taskNumber;
  TextEditingController taskNameController;
  TextEditingController scoreController;
  TextEditingController percentageController;

  AppendixFPracticalTask({
    required this.taskNumber,
    String? taskName,
    int? score,
    double? percentage,
  })  : taskNameController = TextEditingController(text: taskName ?? ''),
        scoreController = TextEditingController(text: score?.toString() ?? ''),
        percentageController =
            TextEditingController(text: percentage?.toString() ?? '');

  void dispose() {
    taskNameController.dispose();
    scoreController.dispose();
    percentageController.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'task_number': taskNumber,
      'task_name': taskNameController.text,
      'candidate_score': int.tryParse(scoreController.text) ?? 0,
      'percentage': double.tryParse(percentageController.text) ?? 0.0,
    };
  }

  factory AppendixFPracticalTask.fromJson(Map<String, dynamic> json) {
    return AppendixFPracticalTask(
      taskNumber: json['task_number'] as int? ?? 0,
      taskName: json['task_name'] as String?,
      score: json['candidate_score'] as int?,
      percentage: (json['percentage'] as num?)?.toDouble(),
    );
  }
}

class AppendixFWorkplaceObservation {
  int activityId;
  String taskObserved;
  int technicalKnowledge;
  int interpretationOfInstructions;
  int teamWorkAttitude;

  AppendixFWorkplaceObservation({
    required this.activityId,
    required this.taskObserved,
    this.technicalKnowledge = 1,
    this.interpretationOfInstructions = 1,
    this.teamWorkAttitude = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'activity_id': activityId,
      'task_observed': taskObserved,
      'technical_knowledge': technicalKnowledge,
      'interpretation_of_instructions': interpretationOfInstructions,
      'team_work_attitude': teamWorkAttitude,
    };
  }

  factory AppendixFWorkplaceObservation.fromJson(Map<String, dynamic> json) {
    return AppendixFWorkplaceObservation(
      activityId: json['activity_id'] as int? ?? 0,
      taskObserved: json['task_observed'] as String? ?? '',
      technicalKnowledge: json['technical_knowledge'] as int? ?? 1,
      interpretationOfInstructions:
          json['interpretation_of_instructions'] as int? ?? 1,
      teamWorkAttitude: json['team_work_attitude'] as int? ?? 1,
    );
  }
}

String appendixFRatingText(int rating) {
  switch (rating) {
    case 1:
      return '1 - Fair';
    case 2:
      return '2 - Good';
    case 3:
      return '3 - Excellent';
    default:
      return '-';
  }
}

const List<DropdownMenuItem<int>> appendixFRatingDropdownItems = [
  DropdownMenuItem(value: 1, child: Text('1 - Fair')),
  DropdownMenuItem(value: 2, child: Text('2 - Good')),
  DropdownMenuItem(value: 3, child: Text('3 - Excellent')),
];

class ArplToolkitData {
  final LearnerDetails? learner;
  final FacilitatorDetails? facilitator;
  final ClassInfo? classInfo;
  final AppendixAData? appendixA;
  final List<AppendixBRating> appendixB;
  final AppendixCData? appendixC;
  final Map<String, String> appendixD;
  final List<AppendixERating> appendixE;
  final AppendixFData? appendixF;
  final AppendixGData? appendixG;
  final AppendixHData appendixH;
  final AppendixIData? appendixI;
  final AppendixJData? appendixJ;
  final String ofoNumber;
  final int learnerID;

  ArplToolkitData({
    this.learner,
    this.facilitator,
    this.classInfo,
    this.appendixA,
    this.appendixB = const [],
    this.appendixC,
    this.appendixD = const {},
    this.appendixE = const [],
    this.appendixF,
    this.appendixG,
    required this.appendixH,
    this.appendixI,
    this.appendixJ,
    required this.ofoNumber,
    required this.learnerID,
  });

  factory ArplToolkitData.fromJson(Map<String, dynamic> json) {
    print('[ArplToolkitData.fromJson] ═══ STARTING ═══');
    try {
      print('[ArplToolkitData.fromJson] Parsing learner...');
      final learner = json['learner'] != null
          ? LearnerDetails.fromJson(json['learner'])
          : null;
      print('[ArplToolkitData.fromJson] ✓ Learner parsed');

      print('[ArplToolkitData.fromJson] Parsing facilitator...');
      final facilitator = json['facilitator'] != null
          ? FacilitatorDetails.fromJson(json['facilitator'])
          : null;
      print('[ArplToolkitData.fromJson] ✓ Facilitator parsed');

      print('[ArplToolkitData.fromJson] Parsing classInfo...');
      final classInfo = json['class_info'] != null
          ? ClassInfo.fromJson(json['class_info'])
          : null;
      print('[ArplToolkitData.fromJson] ✓ ClassInfo parsed');

      print('[ArplToolkitData.fromJson] Parsing appendixA...');
      final appendixA = json['appendixA'] != null
          ? AppendixAData.fromJson(json['appendixA'])
          : null;
      print('[ArplToolkitData.fromJson] ✓ AppendixA parsed');

      print('[ArplToolkitData.fromJson] Parsing appendixB...');
      final appendixB = (json['appendixB'] as List<dynamic>?)
              ?.map((item) => AppendixBRating.fromJson(item))
              .toList() ??
          [];
      print(
          '[ArplToolkitData.fromJson] ✓ AppendixB parsed (${appendixB.length} items)');

      print('[ArplToolkitData.fromJson] Parsing appendixC...');
      final appendixC = json['appendixC'] != null
          ? AppendixCData.fromJson(json['appendixC'])
          : null;
      print('[ArplToolkitData.fromJson] ✓ AppendixC parsed');

      print('[ArplToolkitData.fromJson] Parsing appendixD...');
      final appendixD = Map<String, String>.from(json['appendixD'] ?? {});
      print('[ArplToolkitData.fromJson] ✓ AppendixD parsed');

      print('[ArplToolkitData.fromJson] Parsing appendixE...');
      final appendixE = (json['appendixE'] as List<dynamic>?)
              ?.map((item) => AppendixERating.fromJson(item))
              .toList() ??
          [];
      print(
          '[ArplToolkitData.fromJson] ✓ AppendixE parsed (${appendixE.length} items)');

      print('[ArplToolkitData.fromJson] Parsing appendixF...');
      final appendixF = json['appendixF'] != null
          ? AppendixFData.fromJson(json['appendixF'])
          : null;
      print('[ArplToolkitData.fromJson] ✓ AppendixF parsed');

      print('[ArplToolkitData.fromJson] Parsing appendixG...');
      final appendixG = json['appendixG'] != null
          ? AppendixGData.fromJson(json['appendixG'])
          : null;
      print('[ArplToolkitData.fromJson] ✓ AppendixG parsed');

      print('[ArplToolkitData.fromJson] Parsing appendixH...');
      print(
          '[ArplToolkitData.fromJson] appendixH raw value: ${json['appendixH']}');
      print(
          '[ArplToolkitData.fromJson] appendixH type: ${json['appendixH']?.runtimeType}');
      final appendixH = AppendixHData.fromJson(json['appendixH'] ?? {});
      print('[ArplToolkitData.fromJson] ✓ AppendixH parsed');

      print('[ArplToolkitData.fromJson] Parsing appendixI...');
      final appendixI = json['appendixI'] != null
          ? AppendixIData.fromJson(json['appendixI'])
          : null;
      print('[ArplToolkitData.fromJson] ✓ AppendixI parsed');

      print('[ArplToolkitData.fromJson] Parsing appendixJ...');
      final appendixJ = json['appendixJ'] != null
          ? AppendixJData.fromJson(json['appendixJ'])
          : null;
      print('[ArplToolkitData.fromJson] ✓ AppendixJ parsed');

      print('[ArplToolkitData.fromJson] ✅ ALL APPENDICES PARSED SUCCESSFULLY');
      print('[ArplToolkitData.fromJson] ═══ COMPLETE ═══');

      return ArplToolkitData(
        learner: learner,
        facilitator: facilitator,
        classInfo: classInfo,
        appendixA: appendixA,
        appendixB: appendixB,
        appendixC: appendixC,
        appendixD: appendixD,
        appendixE: appendixE,
        appendixF: appendixF,
        appendixG: appendixG,
        appendixH: appendixH,
        appendixI: appendixI,
        appendixJ: appendixJ,
        ofoNumber: json['ofo_number'] ?? '671101',
        learnerID: json['learnerID'] ?? 0,
      );
    } catch (e, stackTrace) {
      print('[ArplToolkitData.fromJson] ═══ FATAL ERROR ═══');
      print('[ArplToolkitData.fromJson] Error: $e');
      print('[ArplToolkitData.fromJson] Stack Trace:');
      print(stackTrace);
      print('[ArplToolkitData.fromJson] ═══ END ERROR ═══');
      rethrow;
    }
  }
}

class LearnerDetails {
  final int learnerID;
  final String? title;
  final String name;
  final String surname;
  final String idNumber;
  final String? dateOfBirth;
  final String? phoneNumber;
  final String? email;
  final String? gender;
  final String? race;
  final String? language;
  final String? addressLine1;
  final String? addressLine2;
  final String? addressLine3;
  final String? postalCode;

  LearnerDetails({
    required this.learnerID,
    this.title,
    required this.name,
    required this.surname,
    required this.idNumber,
    this.dateOfBirth,
    this.phoneNumber,
    this.email,
    this.gender,
    this.race,
    this.language,
    this.addressLine1,
    this.addressLine2,
    this.addressLine3,
    this.postalCode,
  });

  String get fullName => '$name $surname';

  String get fullAddress {
    final parts = [addressLine1, addressLine2, addressLine3, postalCode]
        .where((p) => p != null && p.isNotEmpty)
        .join(', ');
    return parts.isEmpty ? 'No address' : parts;
  }

  factory LearnerDetails.fromJson(Map<String, dynamic> json) {
    return LearnerDetails(
      learnerID: int.tryParse(json['LearnerID']?.toString() ?? '0') ?? 0,
      title: json['Title'],
      name: json['Name'] ?? '',
      surname: json['Surname'] ?? '',
      idNumber: json['IDNumber'] ?? '',
      dateOfBirth: json['DateOfBirth'],
      phoneNumber: json['PhoneNumber'],
      email: json['Email'],
      gender: json['Gender'],
      race: json['Race'],
      language: json['Language'],
      addressLine1: json['AddressLine1'],
      addressLine2: json['AddressLine2'],
      addressLine3: json['AddressLine3'],
      postalCode: json['PostalCode'],
    );
  }
}

class FacilitatorDetails {
  final String firstName;
  final String lastName;
  final String? assessorNo;
  final String? phoneNumber;
  final String? email;

  FacilitatorDetails({
    required this.firstName,
    required this.lastName,
    this.assessorNo,
    this.phoneNumber,
    this.email,
  });

  String get fullName => '$firstName $lastName';

  factory FacilitatorDetails.fromJson(Map<String, dynamic> json) {
    return FacilitatorDetails(
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      assessorNo: json['assessorNo'],
      phoneNumber: json['PhoneNumber'],
      email: json['Email'],
    );
  }
}

class ClassInfo {
  final String? className;
  final String? siteName;
  final String? province;
  final String? district;
  final String? projectName;
  final String? providerName;
  final String? accreditationN;

  ClassInfo({
    this.className,
    this.siteName,
    this.province,
    this.district,
    this.projectName,
    this.providerName,
    this.accreditationN,
  });

  factory ClassInfo.fromJson(Map<String, dynamic> json) {
    return ClassInfo(
      className: json['className'],
      siteName: json['siteName'],
      province: json['Province'],
      district: json['District'],
      projectName: json['Project_name'],
      providerName: json['provider_name'],
      accreditationN: json['accreditation_n'],
    );
  }
}

class AppendixBRating {
  final int activityId;
  final String activityNumber;
  final String activityName;
  final int competencyScaleId;
  final String comments;
  final String ratingDate;
  final bool hasRating;

  AppendixBRating({
    required this.activityId,
    required this.activityNumber,
    required this.activityName,
    required this.competencyScaleId,
    required this.comments,
    required this.ratingDate,
    required this.hasRating,
  });

  factory AppendixBRating.fromJson(Map<String, dynamic> json) {
    final rating = json['rating'] as Map<String, dynamic>?;

    return AppendixBRating(
      activityId: int.tryParse(json['activity_id']?.toString() ?? '0') ?? 0,
      activityNumber: json['activity_number']?.toString() ?? '',
      activityName: json['activity_name'] ?? '',
      competencyScaleId: rating != null
          ? (int.tryParse(rating['rating_score']?.toString() ?? '0') ?? 0)
          : 0,
      comments: rating?['comments'] ?? '',
      ratingDate: rating?['rating_date'] ?? '',
      hasRating: json['has_rating'] == true,
    );
  }
}

class AppendixERating {
  final int activityId;
  final String activityNumber;
  final String activityName;
  final int competencyScaleId;
  final String comments;
  final String ratingDate;
  final bool hasRating;

  AppendixERating({
    required this.activityId,
    required this.activityNumber,
    required this.activityName,
    required this.competencyScaleId,
    required this.comments,
    required this.ratingDate,
    required this.hasRating,
  });

  factory AppendixERating.fromJson(Map<String, dynamic> json) {
    final rating = json['rating'] as Map<String, dynamic>?;

    return AppendixERating(
      activityId: int.tryParse(json['activity_id']?.toString() ?? '0') ?? 0,
      activityNumber: json['activity_number']?.toString() ?? '',
      activityName: json['activity_name'] ?? '',
      competencyScaleId: rating != null
          ? (int.tryParse(rating['rating_score']?.toString() ?? '0') ?? 0)
          : 0,
      comments: rating?['comments'] ?? '',
      ratingDate: rating?['rating_date'] ?? '',
      hasRating: json['has_rating'] == true,
    );
  }
}

class AppendixHData {
  final List<AcrItem> items;
  final List<AccessRecommendation> recommendations;
  final List<GapStandard> gapStandards;

  AppendixHData({
    this.items = const [],
    this.recommendations = const [],
    this.gapStandards = const [],
  });

  factory AppendixHData.fromJson(Map<String, dynamic> json) {
    try {
      print('[AppendixHData.fromJson] ═══ ENTERING ═══');
      print('[AppendixHData.fromJson] Input JSON: $json');
      print('[AppendixHData.fromJson] JSON type: ${json.runtimeType}');
      print('[AppendixHData.fromJson] JSON keys: ${json.keys.toList()}');

      List<AcrItem> itemsList = [];
      if (json['items'] != null) {
        print('[AppendixHData.fromJson] Processing items...');
        print(
            '[AppendixHData.fromJson] items type: ${json['items'].runtimeType}');
        print(
            '[AppendixHData.fromJson] items is List: ${json['items'] is List}');
        print('[AppendixHData.fromJson] items value: ${json['items']}');

        if (json['items'] is List) {
          itemsList = (json['items'] as List<dynamic>).map((item) {
            print(
                '[AppendixHData.fromJson] Processing item: $item (type: ${item.runtimeType})');
            return AcrItem.fromJson(item as Map<String, dynamic>);
          }).toList();
          print(
              '[AppendixHData.fromJson] Successfully parsed ${itemsList.length} items');
        } else {
          print(
              '[AppendixHData.fromJson] ERROR: items is not a List, it is ${json['items'].runtimeType}');
          throw Exception(
              'items should be a List, got ${json['items'].runtimeType}');
        }
      }

      List<AccessRecommendation> recommendationsList = [];
      if (json['recommendations'] != null) {
        print('[AppendixHData.fromJson] Processing recommendations...');
        print(
            '[AppendixHData.fromJson] recommendations type: ${json['recommendations'].runtimeType}');
        print(
            '[AppendixHData.fromJson] recommendations is List: ${json['recommendations'] is List}');
        print(
            '[AppendixHData.fromJson] recommendations value: ${json['recommendations']}');

        if (json['recommendations'] is List) {
          recommendationsList =
              (json['recommendations'] as List<dynamic>).map((item) {
            print(
                '[AppendixHData.fromJson] Processing recommendation: $item (type: ${item.runtimeType})');
            return AccessRecommendation.fromJson(item as Map<String, dynamic>);
          }).toList();
          print(
              '[AppendixHData.fromJson] Successfully parsed ${recommendationsList.length} recommendations');
        } else {
          print(
              '[AppendixHData.fromJson] ERROR: recommendations is not a List, it is ${json['recommendations'].runtimeType}');
          throw Exception(
              'recommendations should be a List, got ${json['recommendations'].runtimeType}');
        }
      }

      List<GapStandard> gapStandardsList = [];
      if (json['gap_standards'] != null) {
        print('[AppendixHData.fromJson] Processing gap_standards...');
        print(
            '[AppendixHData.fromJson] gap_standards type: ${json['gap_standards'].runtimeType}');
        print(
            '[AppendixHData.fromJson] gap_standards is List: ${json['gap_standards'] is List}');

        if (json['gap_standards'] is List) {
          gapStandardsList = (json['gap_standards'] as List<dynamic>)
              .map((item) => GapStandard.fromJson(item as Map<String, dynamic>))
              .toList();
          print(
              '[AppendixHData.fromJson] Successfully parsed ${gapStandardsList.length} gap standards');
        }
      }

      print('[AppendixHData.fromJson] ✅ Creation successful');
      print('[AppendixHData.fromJson] ═══ EXITING ═══');

      return AppendixHData(
        items: itemsList,
        recommendations: recommendationsList,
        gapStandards: gapStandardsList,
      );
    } catch (e, stackTrace) {
      print('[AppendixHData.fromJson] ═══ EXCEPTION ═══');
      print('[AppendixHData.fromJson] Error: $e');
      print('[AppendixHData.fromJson] Stack Trace:');
      print(stackTrace);
      print('[AppendixHData.fromJson] Input JSON was: $json');
      print('[AppendixHData.fromJson] ═══ END EXCEPTION ═══');
      rethrow;
    }
  }
}

class AcrItem {
  final int acrId;
  final String assessmentType;

  AcrItem({
    required this.acrId,
    required this.assessmentType,
  });

  factory AcrItem.fromJson(Map<String, dynamic> json) {
    try {
      return AcrItem(
        acrId: int.tryParse(json['acrId']?.toString() ?? '0') ?? 0,
        assessmentType: json['assessmentType']?.toString() ?? '',
      );
    } catch (e, stackTrace) {
      print('[AcrItem.fromJson] Error: $e');
      print('[AcrItem.fromJson] Stack: $stackTrace');
      print('[AcrItem.fromJson] JSON: $json');
      rethrow;
    }
  }
}

class AccessRecommendation {
  final int recommendationId;
  final int learnerId;
  final int acrId;
  final String trade;
  final String ofoCode;
  final String status;
  final String remarks;
  final String createdAt;
  final String updatedAt;

  AccessRecommendation({
    required this.recommendationId,
    required this.learnerId,
    required this.acrId,
    required this.trade,
    required this.ofoCode,
    required this.status,
    required this.remarks,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AccessRecommendation.fromJson(Map<String, dynamic> json) {
    try {
      return AccessRecommendation(
        recommendationId:
            int.tryParse(json['recommendationId']?.toString() ?? '0') ?? 0,
        learnerId: int.tryParse(json['learnerId']?.toString() ?? '0') ?? 0,
        acrId: int.tryParse(json['acrId']?.toString() ?? '0') ?? 0,
        trade: json['trade']?.toString() ?? '',
        ofoCode: json['ofoCode']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        remarks: json['remarks']?.toString() ?? '',
        createdAt: json['createdAt']?.toString() ?? '',
        updatedAt: json['updatedAt']?.toString() ?? '',
      );
    } catch (e, stackTrace) {
      print('[AccessRecommendation.fromJson] Error: $e');
      print('[AccessRecommendation.fromJson] Stack: $stackTrace');
      print('[AccessRecommendation.fromJson] JSON: $json');
      rethrow;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GAP CLOSURE: UNIT STANDARD FOR LEARNER TO ATTEND
// ══════════════════════════════════════════════════════════════════════════════
class GapUnitStandard {
  final int id;
  final int learnerId;
  final int? recommendationId;
  final String unitStandardId;
  final String? unitStandardName;
  final int qualificationId;
  final String ofoCode;
  final String? assignedDate;
  final String status;
  final String createdAt;

  GapUnitStandard({
    required this.id,
    required this.learnerId,
    this.recommendationId,
    required this.unitStandardId,
    this.unitStandardName,
    required this.qualificationId,
    required this.ofoCode,
    this.assignedDate,
    required this.status,
    required this.createdAt,
  });

  factory GapUnitStandard.fromJson(Map<String, dynamic> json) {
    return GapUnitStandard(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      learnerId: int.tryParse(json['learner_id']?.toString() ?? '0') ?? 0,
      recommendationId: json['recommendation_id'] != null
          ? int.tryParse(json['recommendation_id'].toString())
          : null,
      unitStandardId: json['unit_standard_id']?.toString() ?? '',
      unitStandardName: json['unit_standard_name'],
      qualificationId:
          int.tryParse(json['qualification_id']?.toString() ?? '0') ?? 0,
      ofoCode: json['ofo_code']?.toString() ?? '',
      assignedDate: json['assigned_date'],
      status: json['status']?.toString() ?? 'Pending',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'learner_id': learnerId,
      'recommendation_id': recommendationId,
      'unit_standard_id': unitStandardId,
      'unit_standard_name': unitStandardName,
      'qualification_id': qualificationId,
      'ofo_code': ofoCode,
      'assigned_date': assignedDate,
      'status': status,
      'created_at': createdAt,
    };
  }
}

class GapStandard {
  final String unitStandardId;
  final String? unitStandardName;
  final String assignedDate;

  GapStandard({
    required this.unitStandardId,
    this.unitStandardName,
    required this.assignedDate,
  });

  factory GapStandard.fromJson(Map<String, dynamic> json) {
    return GapStandard(
      unitStandardId: json['unit_standard_id']?.toString() ?? '',
      unitStandardName: json['unit_standard_name'],
      assignedDate: json['assigned_date'] ?? '',
    );
  }
}

// ══════════════════════════════════════════════════════════
// APPENDIX A: APPLICATION FORM DATA
// ══════════════════════════════════════════════════════════
class AppendixAData {
  final String? specialization;
  final String? postalAddress1;
  final String? postalAddress2;
  final String? postalCode;
  final String? faxNumber;
  final bool? currentlyEmployed;
  final bool? selfEmployed;
  final String? currentEmployer;
  final String? positionJobTitle;
  final String? employerAddress;
  final String? reference;
  final String? employerTel;
  final String? employerFax;
  final String? employerCell;
  final String? employerEmail;
  final List<EmploymentHistory> employmentHistory;
  final String? candidateSignature;
  final String? signatureDate;

  AppendixAData({
    this.specialization,
    this.postalAddress1,
    this.postalAddress2,
    this.postalCode,
    this.faxNumber,
    this.currentlyEmployed,
    this.selfEmployed,
    this.currentEmployer,
    this.positionJobTitle,
    this.employerAddress,
    this.reference,
    this.employerTel,
    this.employerFax,
    this.employerCell,
    this.employerEmail,
    this.employmentHistory = const [],
    this.candidateSignature,
    this.signatureDate,
  });

  factory AppendixAData.fromJson(Map<String, dynamic> json) {
    return AppendixAData(
      specialization: json['specialization'],
      postalAddress1: json['postal_address1'],
      postalAddress2: json['postal_address2'],
      postalCode: json['postal_code'],
      faxNumber: json['fax_number'],
      currentlyEmployed: json['currently_employed'] == true ||
          json['currently_employed'] == 'yes',
      selfEmployed:
          json['self_employed'] == true || json['self_employed'] == 'yes',
      currentEmployer: json['current_employer'],
      positionJobTitle: json['position_job_title'],
      employerAddress: json['employer_address'],
      reference: json['reference'],
      employerTel: json['employer_tel'],
      employerFax: json['employer_fax'],
      employerCell: json['employer_cell'],
      employerEmail: json['employer_email'],
      employmentHistory: (json['employment_history'] as List<dynamic>?)
              ?.map((item) => EmploymentHistory.fromJson(item))
              .toList() ??
          [],
      candidateSignature: json['candidate_signature'],
      signatureDate: json['signature_date'],
    );
  }
}

class EmploymentHistory {
  final String company;
  final String position;
  final String period;
  final String contact;

  EmploymentHistory({
    required this.company,
    required this.position,
    required this.period,
    required this.contact,
  });

  factory EmploymentHistory.fromJson(Map<String, dynamic> json) {
    return EmploymentHistory(
      company: json['company'] ?? '',
      position: json['position'] ?? '',
      period: json['period'] ?? '',
      contact: json['contact'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company': company,
      'position': position,
      'period': period,
      'contact': contact,
    };
  }
}

// ══════════════════════════════════════════════════════════
// APPENDIX C: TRADE CURRICULUM CONTENT SUMMARY DATA
// ══════════════════════════════════════════════════════════
class AppendixCData {
  final String? curriculumOverview;
  final String? moduleSummary;
  final String? learningOutcomes;
  final String? additionalNotes;

  AppendixCData({
    this.curriculumOverview,
    this.moduleSummary,
    this.learningOutcomes,
    this.additionalNotes,
  });

  factory AppendixCData.fromJson(Map<String, dynamic> json) {
    return AppendixCData(
      curriculumOverview: json['curriculum_overview'],
      moduleSummary: json['module_summary'],
      learningOutcomes: json['learning_outcomes'],
      additionalNotes: json['additional_notes'],
    );
  }
}

// ══════════════════════════════════════════════════════════
// APPENDIX F: PRACTICAL ASSESSMENT EVALUATION FORM DATA
// ══════════════════════════════════════════════════════════
class AppendixFData {
  final List<PracticalTask> practicalTasks;
  final List<WorkplaceObservation> workplaceObservations;
  final String? assessorName;
  final String? candidateName;
  final String? witnessName;
  final String? assessorSignature;
  final String? candidateSignature;
  final String? witnessSignature;
  final String? assessmentDate;
  final String? authorizedDate;

  AppendixFData({
    this.practicalTasks = const [],
    this.workplaceObservations = const [],
    this.assessorName,
    this.candidateName,
    this.witnessName,
    this.assessorSignature,
    this.candidateSignature,
    this.witnessSignature,
    this.assessmentDate,
    this.authorizedDate,
  });

  factory AppendixFData.fromJson(Map<String, dynamic> json) {
    return AppendixFData(
      // PHP sends camelCase keys: practicalTasks, workplaceObservations
      practicalTasks: (json['practicalTasks'] as List<dynamic>?)
              ?.map((item) => PracticalTask.fromJson(item))
              .toList() ??
          [],
      workplaceObservations: (json['workplaceObservations'] as List<dynamic>?)
              ?.map((item) => WorkplaceObservation.fromJson(item))
              .toList() ??
          [],
      assessorName: json['assessorName'],
      candidateName: json['candidateName'],
      witnessName: json['witnessName'],
      assessorSignature: json['assessorSignature'],
      candidateSignature: json['candidateSignature'],
      witnessSignature: json['witnessSignature'],
      assessmentDate: json['assessmentDate'],
      authorizedDate: json['authorizedDate'],
    );
  }
}

class PracticalTask {
  final int taskNumber;
  final String taskName;
  final int score;
  final double percentage;

  PracticalTask({
    required this.taskNumber,
    required this.taskName,
    required this.score,
    required this.percentage,
  });

  factory PracticalTask.fromJson(Map<String, dynamic> json) {
    return PracticalTask(
      taskNumber: int.tryParse(json['task_number']?.toString() ?? '0') ?? 0,
      taskName: json['task_name'] ?? '',
      score: int.tryParse(json['score']?.toString() ?? '0') ?? 0,
      percentage: double.tryParse(json['percentage']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_number': taskNumber,
      'task_name': taskName,
      'score': score,
      'percentage': percentage,
    };
  }
}

class WorkplaceObservation {
  final int observationNumber;
  final String taskObserved;
  final String technicalKnowledge;
  final String interpretation;
  final String teamWork;

  WorkplaceObservation({
    required this.observationNumber,
    required this.taskObserved,
    required this.technicalKnowledge,
    required this.interpretation,
    required this.teamWork,
  });

  factory WorkplaceObservation.fromJson(Map<String, dynamic> json) {
    return WorkplaceObservation(
      observationNumber:
          int.tryParse(json['observation_number']?.toString() ?? '0') ?? 0,
      taskObserved: json['task_observed'] ?? '',
      technicalKnowledge: json['technical_knowledge'] ?? '',
      interpretation: json['interpretation'] ?? '',
      teamWork: json['team_work'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'observation_number': observationNumber,
      'task_observed': taskObserved,
      'technical_knowledge': technicalKnowledge,
      'interpretation': interpretation,
      'team_work': teamWork,
    };
  }
}

// ══════════════════════════════════════════════════════════
// APPENDIX G: APPEALS FORM DATA
// ══════════════════════════════════════════════════════════
class AppendixGData {
  final String? appealSubject;
  final String? groundsForAppeal;
  final String? moderatorName;
  final String? appealStatus;
  final String? assessorFindings;
  final String? candidateSignature;
  final String? assessorSignature;
  final String? candidateSignedAt;
  final String? assessorSignedAt;
  final String? candidateDate;
  final String? assessorDate;

  AppendixGData({
    this.appealSubject,
    this.groundsForAppeal,
    this.moderatorName,
    this.appealStatus,
    this.assessorFindings,
    this.candidateSignature,
    this.assessorSignature,
    this.candidateSignedAt,
    this.assessorSignedAt,
    this.candidateDate,
    this.assessorDate,
  });

  factory AppendixGData.fromJson(Map<String, dynamic> json) {
    return AppendixGData(
      appealSubject: json['appeal_subject'],
      groundsForAppeal: json['grounds_for_appeal'],
      moderatorName: json['moderator_name'],
      appealStatus: json['appeal_status'],
      assessorFindings: json['assessor_findings'],
      candidateSignature: json['candidate_signature'],
      assessorSignature: json['assessor_signature'],
      candidateSignedAt: json['candidate_signed_at'],
      assessorSignedAt: json['assessor_signed_at'],
      candidateDate: json['candidate_date'],
      assessorDate: json['assessor_date'],
    );
  }
}

// ══════════════════════════════════════════════════════════
// APPENDIX I: STATEMENT OF RESULTS DATA
// ══════════════════════════════════════════════════════════
class AppendixIData {
  final String? providerType;
  final String? knowledgeResult;
  final String? practicalResult;
  final String? workplaceResult;
  final int? overallCompetencyRating;
  final String? assessorName;
  final String? assessorRegNumber;
  final String? certificationDate;
  final String? additionalNotes;

  AppendixIData({
    this.providerType,
    this.knowledgeResult,
    this.practicalResult,
    this.workplaceResult,
    this.overallCompetencyRating,
    this.assessorName,
    this.assessorRegNumber,
    this.certificationDate,
    this.additionalNotes,
  });

  factory AppendixIData.fromJson(Map<String, dynamic> json) {
    return AppendixIData(
      providerType: json['provider_type'],
      knowledgeResult: json['knowledge_result'],
      practicalResult: json['practical_result'],
      workplaceResult: json['workplace_result'],
      overallCompetencyRating: json['overall_competency_rating'] != null
          ? int.tryParse(json['overall_competency_rating'].toString())
          : null,
      assessorName: json['assessor_name'],
      assessorRegNumber: json['assessor_reg_number'],
      certificationDate: json['certification_date'],
      additionalNotes: json['additional_notes'],
    );
  }
}

// ══════════════════════════════════════════════════════════
// APPENDIX J: PRE-ASSESSMENT AGREEMENT DATA
// ══════════════════════════════════════════════════════════
class AppendixJData {
  final bool? understandsProcess;
  final bool? consentsToAssessment;
  final bool? understandsRights;
  final bool? confirmsAccuracy;
  final bool? understandsCriteria;
  final bool? agreesToTerms;
  final String? candidateSignature;
  final String? witnessName;
  final String? witnessSignature;
  final String? agreementDate;

  AppendixJData({
    this.understandsProcess,
    this.consentsToAssessment,
    this.understandsRights,
    this.confirmsAccuracy,
    this.understandsCriteria,
    this.agreesToTerms,
    this.candidateSignature,
    this.witnessName,
    this.witnessSignature,
    this.agreementDate,
  });

  factory AppendixJData.fromJson(Map<String, dynamic> json) {
    return AppendixJData(
      understandsProcess: json['understands_process'] == true ||
          json['understands_process'] == 'yes',
      consentsToAssessment: json['consents_to_assessment'] == true ||
          json['consents_to_assessment'] == 'yes',
      understandsRights: json['understands_rights'] == true ||
          json['understands_rights'] == 'yes',
      confirmsAccuracy: json['confirms_accuracy'] == true ||
          json['confirms_accuracy'] == 'yes',
      understandsCriteria: json['understands_criteria'] == true ||
          json['understands_criteria'] == 'yes',
      agreesToTerms:
          json['agrees_to_terms'] == true || json['agrees_to_terms'] == 'yes',
      candidateSignature: json['candidate_signature'],
      witnessName: json['witness_name'],
      witnessSignature: json['witness_signature'],
      agreementDate: json['agreement_date'],
    );
  }
}

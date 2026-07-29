# PHASE 4: FORM STATE MANAGEMENT & SAVING ROADMAP

**Objective:** Add form controllers and extend save logic to handle all 6 new appendices

**Files to Modify:**
- `lib/ArplToolkitViewerPage.dart` (main work - ~200 lines of additions)

---

## CHANGES NEEDED IN ArplToolkitViewerPage.dart

### 1. Add Form Controllers to State Class (Lines 30-70)

**Add after existing B, D, E controllers:**

```dart
// Cover page controllers
final TextEditingController _coverNotesController = TextEditingController();

// ════ APPENDIX A CONTROLLERS ════
final TextEditingController _appendixASpecializationController = TextEditingController();
final TextEditingController _appendixAPostalAddress1Controller = TextEditingController();
final TextEditingController _appendixAPostalAddress2Controller = TextEditingController();
final TextEditingController _appendixAPostalCodeController = TextEditingController();
final TextEditingController _appendixAFaxController = TextEditingController();
final TextEditingController _appendixAEmployerController = TextEditingController();
final TextEditingController _appendixAPositionController = TextEditingController();
final TextEditingController _appendixAEmployerAddressController = TextEditingController();
final TextEditingController _appendixAEmployerTelController = TextEditingController();
final TextEditingController _appendixAEmployerFaxController = TextEditingController();
final TextEditingController _appendixAEmployerCellController = TextEditingController();
final TextEditingController _appendixAEmployerEmailController = TextEditingController();
String _appendixACurrentlyEmployed = 'no';
String _appendixASelfEmployed = 'no';

// ════ APPENDIX C CONTROLLERS ════
final TextEditingController _appendixCCurriculumOverviewController = TextEditingController();
final TextEditingController _appendixCModuleSummaryController = TextEditingController();
final TextEditingController _appendixCLearningOutcomesController = TextEditingController();
final TextEditingController _appendixCAdditionalNotesController = TextEditingController();

// ════ APPENDIX F CONTROLLERS ════
bool _appendixFKnowledgeAcknowledged = false;
bool _appendixFPracticalAcknowledged = false;
bool _appendixFWorkplaceAcknowledged = false;
bool _appendixFAssessorAcknowledged = false;

// ════ APPENDIX G CONTROLLERS ════
final TextEditingController _appendixGAppealSubjectController = TextEditingController();
final TextEditingController _appendixGGroundsForAppealController = TextEditingController();
final TextEditingController _appendixGModeratorNameController = TextEditingController();
final TextEditingController _appendixGAssessorFindingsController = TextEditingController();
String _appendixGAppealStatus = 'Submitted';
final TextEditingController _appendixGCandidatePlaceController = TextEditingController();
final TextEditingController _appendixGAssessorPlaceController = TextEditingController();

// ════ APPENDIX I CONTROLLERS ════
final TextEditingController _appendixIAssessorNameController = TextEditingController();
final TextEditingController _appendixIAssessorRegController = TextEditingController();
final TextEditingController _appendixIAdditionalNotesController = TextEditingController();
String _appendixIProviderType = 'Skills Development Provider';
String _appendixIKnowledgeResult = '';
String _appendixIPracticalResult = '';
String _appendixIWorkplaceResult = '';
int _appendixIOverallRating = 0;

// ════ APPENDIX J CONTROLLERS ════
bool _appendixJUnderstandsProcess = false;
bool _appendixJConsentsToAssessment = false;
bool _appendixJUnderstandsRights = false;
bool _appendixJConfirmsAccuracy = false;
bool _appendixJUnderstandsCriteria = false;
bool _appendixJAgreesToTerms = false;
final TextEditingController _appendixJWitnessNameController = TextEditingController();
```

### 2. Update dispose() Method

**Add disposals for new controllers (after line ~60):**

```dart
@override
void dispose() {
    _tabController?.dispose();
    _tradeSpecializationController.dispose();
    
    // Dispose existing B, D, E controllers
    _appendixBComments.forEach((key, controller) => controller.dispose());
    _appendixEComments.forEach((key, controller) => controller.dispose());
    
    // Dispose new appendix controllers
    _coverNotesController.dispose();
    _appendixASpecializationController.dispose();
    _appendixAPostalAddress1Controller.dispose();
    _appendixAPostalAddress2Controller.dispose();
    _appendixAPostalCodeController.dispose();
    _appendixAFaxController.dispose();
    _appendixAEmployerController.dispose();
    _appendixAPositionController.dispose();
    _appendixAEmployerAddressController.dispose();
    _appendixAEmployerTelController.dispose();
    _appendixAEmployerFaxController.dispose();
    _appendixAEmployerCellController.dispose();
    _appendixAEmployerEmailController.dispose();
    
    _appendixCCurriculumOverviewController.dispose();
    _appendixCModuleSummaryController.dispose();
    _appendixCLearningOutcomesController.dispose();
    _appendixCAdditionalNotesController.dispose();
    
    _appendixGAppealSubjectController.dispose();
    _appendixGGroundsForAppealController.dispose();
    _appendixGModeratorNameController.dispose();
    _appendixGAssessorFindingsController.dispose();
    _appendixGCandidatePlaceController.dispose();
    _appendixGAssessorPlaceController.dispose();
    
    _appendixIAssessorNameController.dispose();
    _appendixIAssessorRegController.dispose();
    _appendixIAdditionalNotesController.dispose();
    
    _appendixJWitnessNameController.dispose();
    
    super.dispose();
}
```

### 3. Update _populateControllers() Method

**Extend existing method to populate new data (lines ~130-160):**

```dart
void _populateControllers() {
    if (_toolkitData == null) return;

    // ... existing B, D, E code ...

    // ════ POPULATE APPENDIX A ════
    if (_toolkitData!.appendixA != null) {
        final a = _toolkitData!.appendixA!;
        _appendixASpecializationController.text = a.specialization ?? '';
        _appendixAPostalAddress1Controller.text = a.postalAddress1 ?? '';
        _appendixAPostalAddress2Controller.text = a.postalAddress2 ?? '';
        _appendixAPostalCodeController.text = a.postalCode ?? '';
        _appendixAFaxController.text = a.faxNumber ?? '';
        _appendixAEmployerController.text = a.currentEmployer ?? '';
        _appendixAPositionController.text = a.positionJobTitle ?? '';
        _appendixAEmployerAddressController.text = a.employerAddress ?? '';
        _appendixAEmployerTelController.text = a.employerTel ?? '';
        _appendixAEmployerFaxController.text = a.employerFax ?? '';
        _appendixAEmployerCellController.text = a.employerCell ?? '';
        _appendixAEmployerEmailController.text = a.employerEmail ?? '';
        _appendixACurrentlyEmployed = (a.currentlyEmployed ?? false) ? 'yes' : 'no';
        _appendixASelfEmployed = (a.selfEmployed ?? false) ? 'yes' : 'no';
    }

    // ════ POPULATE APPENDIX C ════
    if (_toolkitData!.appendixC != null) {
        final c = _toolkitData!.appendixC!;
        _appendixCCurriculumOverviewController.text = c.curriculumOverview ?? '';
        _appendixCModuleSummaryController.text = c.moduleSummary ?? '';
        _appendixCLearningOutcomesController.text = c.learningOutcomes ?? '';
        _appendixCAdditionalNotesController.text = c.additionalNotes ?? '';
    }

    // ════ POPULATE APPENDIX F ════
    if (_toolkitData!.appendixF != null) {
        final f = _toolkitData!.appendixF!;
        _appendixFKnowledgeAcknowledged = f.knowledgeAcknowledged ?? false;
        _appendixFPracticalAcknowledged = f.practicalAcknowledged ?? false;
        _appendixFWorkplaceAcknowledged = f.workplaceAcknowledged ?? false;
        _appendixFAssessorAcknowledged = f.assessorAcknowledged ?? false;
    }

    // ════ POPULATE APPENDIX G ════
    if (_toolkitData!.appendixG != null) {
        final g = _toolkitData!.appendixG!;
        _appendixGAppealSubjectController.text = g.appealSubject ?? '';
        _appendixGGroundsForAppealController.text = g.groundsForAppeal ?? '';
        _appendixGModeratorNameController.text = g.moderatorName ?? '';
        _appendixGAssessorFindingsController.text = g.assessorFindings ?? '';
        _appendixGAppealStatus = g.appealStatus ?? 'Submitted';
        _appendixGCandidatePlaceController.text = g.candidateSignedAt ?? '';
        _appendixGAssessorPlaceController.text = g.assessorSignedAt ?? '';
    }

    // ════ POPULATE APPENDIX I ════
    if (_toolkitData!.appendixI != null) {
        final i = _toolkitData!.appendixI!;
        _appendixIProviderType = i.providerType ?? 'Skills Development Provider';
        _appendixIKnowledgeResult = i.knowledgeResult ?? '';
        _appendixIPracticalResult = i.practicalResult ?? '';
        _appendixIWorkplaceResult = i.workplaceResult ?? '';
        _appendixIOverallRating = i.overallCompetencyRating ?? 0;
        _appendixIAssessorNameController.text = i.assessorName ?? '';
        _appendixIAssessorRegController.text = i.assessorRegNumber ?? '';
        _appendixIAdditionalNotesController.text = i.additionalNotes ?? '';
    }

    // ════ POPULATE APPENDIX J ════
    if (_toolkitData!.appendixJ != null) {
        final j = _toolkitData!.appendixJ!;
        _appendixJUnderstandsProcess = j.understandsProcess ?? false;
        _appendixJConsentsToAssessment = j.consentsToAssessment ?? false;
        _appendixJUnderstandsRights = j.understandsRights ?? false;
        _appendixJConfirmsAccuracy = j.confirmsAccuracy ?? false;
        _appendixJUnderstandsCriteria = j.understandsCriteria ?? false;
        _appendixJAgreesToTerms = j.agreesToTerms ?? false;
        _appendixJWitnessNameController.text = j.witnessName ?? '';
    }
}
```

### 4. Update _saveAllChanges() Method

**Extend save logic to include all 6 new appendices (lines ~160-220):**

```dart
Future<void> _saveAllChanges() async {
    if (_toolkitData == null) return;

    setState(() {
        _isSaving = true;
    });

    try {
        // ... existing B, D, E save code ...

        // ════ PREPARE APPENDIX A DATA ════
        final appendixAData = {
            'learnerID': widget.learnerID,
            'ofoNumber': widget.ofoNumber,
            'specialization': _appendixASpecializationController.text,
            'postal_address1': _appendixAPostalAddress1Controller.text,
            'postal_address2': _appendixAPostalAddress2Controller.text,
            'postal_code': _appendixAPostalCodeController.text,
            'fax_number': _appendixAFaxController.text,
            'currently_employed': _appendixACurrentlyEmployed,
            'self_employed': _appendixASelfEmployed,
            'current_employer': _appendixAEmployerController.text,
            'position_job_title': _appendixAPositionController.text,
            'employer_address': _appendixAEmployerAddressController.text,
            'employer_tel': _appendixAEmployerTelController.text,
            'employer_fax': _appendixAEmployerFaxController.text,
            'employer_cell': _appendixAEmployerCellController.text,
            'employer_email': _appendixAEmployerEmailController.text,
            'employment_history': [], // TODO: Add employment history logic
        };

        // ════ PREPARE APPENDIX C DATA ════
        final appendixCData = {
            'learnerID': widget.learnerID,
            'ofoNumber': widget.ofoNumber,
            'curriculum_overview': _appendixCCurriculumOverviewController.text,
            'module_summary': _appendixCModuleSummaryController.text,
            'learning_outcomes': _appendixCLearningOutcomesController.text,
            'additional_notes': _appendixCAdditionalNotesController.text,
        };

        // ════ PREPARE APPENDIX F DATA ════
        final appendixFData = {
            'learnerID': widget.learnerID,
            'ofoNumber': widget.ofoNumber,
            'knowledge_acknowledged': _appendixFKnowledgeAcknowledged,
            'practical_acknowledged': _appendixFPracticalAcknowledged,
            'workplace_acknowledged': _appendixFWorkplaceAcknowledged,
            'assessor_acknowledged': _appendixFAssessorAcknowledged,
        };

        // ════ PREPARE APPENDIX G DATA ════
        final appendixGData = {
            'learnerID': widget.learnerID,
            'ofoNumber': widget.ofoNumber,
            'appeal_subject': _appendixGAppealSubjectController.text,
            'grounds_for_appeal': _appendixGGroundsForAppealController.text,
            'moderator_name': _appendixGModeratorNameController.text,
            'assessor_findings': _appendixGAssessorFindingsController.text,
            'appeal_status': _appendixGAppealStatus,
            'candidate_signed_at': _appendixGCandidatePlaceController.text,
            'assessor_signed_at': _appendixGAssessorPlaceController.text,
        };

        // ════ PREPARE APPENDIX I DATA ════
        final appendixIData = {
            'learnerID': widget.learnerID,
            'ofoNumber': widget.ofoNumber,
            'provider_type': _appendixIProviderType,
            'knowledge_result': _appendixIKnowledgeResult,
            'practical_result': _appendixIPracticalResult,
            'workplace_result': _appendixIWorkplaceResult,
            'overall_competency_rating': _appendixIOverallRating,
            'assessor_name': _appendixIAssessorNameController.text,
            'assessor_reg_number': _appendixIAssessorRegController.text,
            'additional_notes': _appendixIAdditionalNotesController.text,
        };

        // ════ PREPARE APPENDIX J DATA ════
        final appendixJData = {
            'learnerID': widget.learnerID,
            'ofoNumber': widget.ofoNumber,
            'understands_process': _appendixJUnderstandsProcess,
            'consents_to_assessment': _appendixJConsentsToAssessment,
            'understands_rights': _appendixJUnderstandsRights,
            'confirms_accuracy': _appendixJConfirmsAccuracy,
            'understands_criteria': _appendixJUnderstandsCriteria,
            'agrees_to_terms': _appendixJAgreesToTerms,
            'witness_name': _appendixJWitnessNameController.text,
        };

        // ════ SAVE EACH APPENDIX ════
        List<String> savedAppendices = [];
        List<String> failedAppendices = [];

        // Save Appendix A
        try {
            final response = await http.post(
                Uri.parse('${AppConfig.baseUrl}/mobile/save_arpl_appendix_a.php'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(appendixAData),
            );
            if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                if (data['status'] == 'success') {
                    savedAppendices.add('A');
                } else {
                    failedAppendices.add('A: ${data['message']}');
                }
            }
        } catch (e) {
            failedAppendices.add('A: $e');
        }

        // Save Appendix C
        try {
            final response = await http.post(
                Uri.parse('${AppConfig.baseUrl}/mobile/save_arpl_appendix_c.php'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(appendixCData),
            );
            if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                if (data['status'] == 'success') {
                    savedAppendices.add('C');
                } else {
                    failedAppendices.add('C: ${data['message']}');
                }
            }
        } catch (e) {
            failedAppendices.add('C: $e');
        }

        // Save Appendix F
        try {
            final response = await http.post(
                Uri.parse('${AppConfig.baseUrl}/mobile/save_arpl_appendix_f.php'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(appendixFData),
            );
            if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                if (data['status'] == 'success') {
                    savedAppendices.add('F');
                } else {
                    failedAppendices.add('F: ${data['message']}');
                }
            }
        } catch (e) {
            failedAppendices.add('F: $e');
        }

        // Save Appendix G
        try {
            final response = await http.post(
                Uri.parse('${AppConfig.baseUrl}/mobile/save_arpl_appendix_g.php'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(appendixGData),
            );
            if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                if (data['status'] == 'success') {
                    savedAppendices.add('G');
                } else {
                    failedAppendices.add('G: ${data['message']}');
                }
            }
        } catch (e) {
            failedAppendices.add('G: $e');
        }

        // Save Appendix I
        try {
            final response = await http.post(
                Uri.parse('${AppConfig.baseUrl}/mobile/save_arpl_appendix_i.php'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(appendixIData),
            );
            if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                if (data['status'] == 'success') {
                    savedAppendices.add('I');
                } else {
                    failedAppendices.add('I: ${data['message']}');
                }
            }
        } catch (e) {
            failedAppendices.add('I: $e');
        }

        // Save Appendix J
        try {
            final response = await http.post(
                Uri.parse('${AppConfig.baseUrl}/mobile/save_arpl_appendix_j.php'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(appendixJData),
            );
            if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                if (data['status'] == 'success') {
                    savedAppendices.add('J');
                } else {
                    failedAppendices.add('J: ${data['message']}');
                }
            }
        } catch (e) {
            failedAppendices.add('J: $e');
        }

        // ════ HANDLE SAVE RESULTS ════
        setState(() {
            _isSaving = false;
            _isEditing = false;
        });

        if (failedAppendices.isEmpty) {
            // All saved successfully
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('✓ All changes saved (A, B, C, D, E, F, G, I, J)'),
                    backgroundColor: const Color(0xFF006341),
                    duration: const Duration(seconds: 2),
                ),
            );
            await _loadToolkitData();
        } else {
            // Some failed
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Saved: ${savedAppendices.join(', ')}\nFailed: ${failedAppendices.join(', ')}'),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 4),
                ),
            );
            await _loadToolkitData();
        }
    } catch (e) {
        setState(() {
            _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error saving: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
            ),
        );
    }
}
```

---

## IMPLEMENTATION CHECKLIST

- [ ] Add all TextEditingControllers and state variables
- [ ] Update dispose() method with all new controllers
- [ ] Update _populateControllers() to populate new data
- [ ] Update _saveAllChanges() to save all 6 new appendices
- [ ] Handle employment history JSON array for Appendix A
- [ ] Test data loading with populated controllers
- [ ] Test save functionality with all 6 appendices
- [ ] Verify data persists after reload
- [ ] Build APK and install
- [ ] Device testing with test learner ID 20286

---

## ESTIMATED EFFORT

- Adding controllers: 20 minutes
- Updating methods: 20 minutes
- Testing & debugging: 15 minutes
- **Total:** ~55 minutes

---

**Next: Run this after Phase 3 backend completion**

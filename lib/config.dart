import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  // Local dev (phone must be on same Wi-Fi as the PC running the server)
  // static const String serverHost = '192.168.0.57'; // Local dev IP
  // static const int serverPort = 8080; // Local dev port
  // static const String serverProtocol = 'http'; // Local dev uses HTTP
  // static const String basePath = '/assessorReport2/mobile';

  // Live server configuration - ONLINE
  static const String serverHost = 'rlms.rlms.co.za'; // Live server domain
  static const int serverPort = 443; // HTTPS port
  static const String serverProtocol = 'https'; // Live server uses HTTPS
  static const String basePath = '/mobile';

  // Base URL for all API calls
  // Result: http://192.168.68.106/assessorReport2/mobile
  static String get baseUrl {
    // Don't include port for standard HTTPS (443) or HTTP (80)
    final includePort = (serverProtocol == 'https' && serverPort != 443) ||
        (serverProtocol == 'http' && serverPort != 80);
    final url = includePort
        ? '$serverProtocol://$serverHost:$serverPort$basePath'
        : '$serverProtocol://$serverHost$basePath';
    print('[CONFIG] Base URL: $url');
    return url;
  }

  // Common endpoints
  static String get loginUrl => '$baseUrl/login.php';
  static String get syncUrl => '$baseUrl/sync_data';
  // static String get clockinUrl => '$baseUrl/clockin.php';
  // static String get clockoutUrl => '$baseUrl/clockout.php';
  static String get clockinUrl => '$baseUrl/clocking/clockin.php';
  static String get clockoutUrl => '$baseUrl/clocking/clockout.php';
  static String get facilitatorClockinUrl => '$baseUrl/facilitator_clockin.php';
  static String get facilitatorClockoutUrl =>
      '$baseUrl/facilitator_clockout.php';
  static String get getLearnersUrl => '$baseUrl/get_learners.php';
  static String get syncLearnersByClassUrl =>
      '$baseUrl/sync_learners_by_class.php';
  static String get syncLearnerUrl => '$baseUrl/sync_learner.php';
  static String get uploadSickNoteUrl => '$baseUrl/upload_sick_note.php';
  static String get syncSickNotesUrl => '$baseUrl/sync_sick_notes.php';
  static String get syncUsersUrl => '$baseUrl/sync_users.php';
  static String get syncLearnerDetailsUrl => '$baseUrl/sync_learnerdetails.php';
  static String get syncLearnerDocumentsUrl =>
      '$baseUrl/sync_learner_documents.php';
  static String get syncBankLocalUrl => '$baseUrl/sync_bank_local.php';
  static String get syncFacilitatorUrl => '$baseUrl/sync_facilitator.php';
  static String get syncLearnerClockingUrl =>
      '$baseUrl/clocking/sync_learner_clocking.php';
  static String get syncClockingUrl => '$baseUrl/clocking/sync_clocking.php';
  // static String get syncLearnerClockingUrl => '$baseUrl/sync_learner_clocking.php';
  // static String get syncClockingUrl => '$baseUrl/sync_clocking.php';
  static String get syncUnsyncedDataUrl => '$baseUrl/sync_unsynced_data.php';
  static String get getFacilitatorDataUrl => '$baseUrl/get_facilitator_data';
  static String get syncDataUrl => '$baseUrl/sync_data';
  static String get poeUrl => '$baseUrl/poe.php';
  static String get learnerDetailsUrl => '$baseUrl/learner_details.php';
  static String get updateLearnerUrl => '$baseUrl/update_learner.php';
  static String get saveImageUrl => '$baseUrl/save_image.php';
  static String get saveSignatureUrl => '$baseUrl/save_signature.php';
  static String get saveInitialsUrl => '$baseUrl/save_initials.php';
  static String get newAgreementUrl => '$baseUrl/new_aggrement.php';
  static String get uploadImageUrl => '$baseUrl/upload_image.php';
  static String get learnerImagesUrl => '$baseUrl/learnerImages';
  static String get signaturesUrl => '$baseUrl/signatures';
  static String get getSdpUrl => '$baseUrl/get_sdp.php';
  static String get getSdpProjectsUrl => '$baseUrl/get_sdp_projects.php';
  static String get getSdpSitesUrl => '$baseUrl/get_sdp_sites.php';
  static String get getSdpAllDataUrl => '$baseUrl/get_sdp_all_data.php';
  static String get searchLearnerByIdSdpUrl =>
      '$baseUrl/search_learner_by_id_sdp.php';
  static String get syncSitesUrl => '$baseUrl/sync_sites.php';
  static String get syncClassUrl => '$baseUrl/sync_class.php';
  static String get syncLearningPathwayUrl =>
      '$baseUrl/syncLearningpathway.php';
  static String get syncPathwaySelectionUrl =>
      '$baseUrl/syncPathwaySelection.php';
  static String get syncQualificationUrl => '$baseUrl/syncQualification.php';
  static String get syncQualificationSelectionUrl =>
      '$baseUrl/syncQualification_selection.php';
  static String get syncQualificationPathwayUrl =>
      '$baseUrl/syncQualification_pathway.php';
  static String get syncQualificationUnitStandardUrl =>
      '$baseUrl/syncQualificationunitstandard.php';
  static String get syncUnitStandardUrl => '$baseUrl/syncUnitstandard.php';
  static String get syncUnitStandardSelectionUrl =>
      '$baseUrl/syncUnit_standard_selection.php';
  static String get syncAssessmentUrl => '$baseUrl/syncAssessment.php';
  static String get syncPoeUrl => '$baseUrl/syncPoe.php';
  static String get syncAcknowledgmentDataUrl =>
      '$baseUrl/sync_acknowlegdementData.php';
  static String get syncMaterialFormsUrl => '$baseUrl/syncMaterialForms.php';
  static String get uploadSaveMaterialFormUrl =>
      '$baseUrl/uploadsaveMaterialForm.php';
  static String get saveReceiptFormUrl => '$baseUrl/save_receipt_form.php';
  static String get saveMaterialsReceivedUrl =>
      '$baseUrl/save_materials_received.php';

  // ARPL Endpoints
  static String get saveArplAppendixBUrl => '$baseUrl/save_arpl_appendix_b.php';
  static String get saveArplAppendixDUrl => '$baseUrl/save_arpl_appendix_d.php';
  static String get getArplAppendixDUrl => '$baseUrl/get_arpl_appendix_d.php';
  static String get saveArplAppendixEUrl => '$baseUrl/save_arpl_appendix_e.php';
  static String get getArplAppendixEUrl => '$baseUrl/get_arpl_appendix_e.php';
  static String get saveArplAppendixFUrl => '$baseUrl/save_arpl_appendix_f.php';
  static String get saveAppendixFDataUrl =>
      '$baseUrl/save_appendix_f_data.php'; // NEW REDESIGNED ENDPOINT
  static String get saveArplToolkitEditsUrl =>
      '$baseUrl/save_arpl_toolkit_edits.php'; // B/D/E save endpoint
  static String get saveArplCriteriaUrl => '$baseUrl/save_arpl_criteria.php';
  static String get getArplDataUrl => '$baseUrl/get_arpl_data.php';
  static String get verifyFingerprintSignatureUrl =>
      '$baseUrl/verify_fingerprint_and_get_signature.php'; // Fingerprint-verified signature
  // ARPL Toolkit Data - All trades use unified endpoint
  static String get getArplToolkitDataUrl =>
      '$baseUrl/get_arpl_toolkit_data.php';
  static String get getBricklayerToolkitDataUrl =>
      '$baseUrl/get_bricklayer_toolkit_data.php'; // Separate endpoint for bricklayer
  static String get getPlumberToolkitDataUrl =>
      '$baseUrl/get_arpl_toolkit_data.php'; // Use unified endpoint for plumber
  static String get getArplSaveToolkitDataUrl =>
      '$baseUrl/save_arpl_appendix_f_assessment.php';

  // Bricklayer Gap Closure Endpoints
  static String get getBricklayerGapUnitStandardsUrl =>
      '$baseUrl/get_bricklayer_gap_unit_standards.php';
  static String get saveBricklayerGapClosureUrl =>
      '$baseUrl/save_bricklayer_gap_closure.php';

  // Electrician Gap Closure Endpoints
  static String get getElectricianGapUnitStandardsUrl =>
      '$baseUrl/get_electrician_gap_unit_standards.php';
  static String get saveElectricianGapClosureUrl =>
      '$baseUrl/save_electrician_gap_closure.php';

  // Plumber Gap Closure Endpoints
  static String get getPlumberGapUnitStandardsUrl =>
      '$baseUrl/get_plumber_gap_unit_standards.php';
  static String get savePlumberGapClosureUrl =>
      '$baseUrl/save_plumber_gap_closure.php';

  // Sick Note Endpoints
  static String get getSickNoteEligibleDatesUrl =>
      '$baseUrl/get_sick_note_eligible_dates.php?v=2';
  static String get submitSickNoteUrl => '$baseUrl/submit_sick_note.php?v=2';

  static String get syncProjectUrl => '$baseUrl/sync_project.php';
  static String get syncPoeOnlineUrl => '$baseUrl/sync_PoeOnline.php';
  static String get syncOnlineDetailsUrl => '$baseUrl/sync_online_details.php';
  static String get syncInductionUrl => '$baseUrl/sync_induction.php';
  static String get syncInductionClockingUrl =>
      '$baseUrl/syncInductionClocking.php';
  static String get ppeSizesUrl => '$baseUrl/ppe_sizes.php';
  static String get addLearnerUrl => '$baseUrl/add_learner.php';
  static String get getAttendanceUrl => '$baseUrl/get_attendance.php';
  static String get checkBankDetailsUrl => '$baseUrl/check_bank_details.php';

  // Logistics Management Endpoints
  static String get getLogisticsSitesUrl => '$baseUrl/get_logistics_sites.php';
  static String get getLogisticsClassesUrl =>
      '$baseUrl/get_logistics_classes.php';
  static String get getLogisticsLearnersUrl =>
      '$baseUrl/get_logistics_learners.php';
  static String get getMaterialInventoryUrl =>
      '$baseUrl/get_material_inventory.php';
  static String get getMaterialIssuancesUrl =>
      '$baseUrl/get_material_issuances.php';
  static String get saveMaterialIssuanceUrl =>
      '$baseUrl/save_material_issuance.php';

  //new endpoints
  static String get saveMetadataUrl => '$baseUrl/save_metadata.php';
  static String get saveMonitoringRecordsUrl =>
      '$baseUrl/save_monitoring_records.php';
  static String get syncMonitoringRecordsUrl =>
      '$baseUrl/sync_monitoring_records.php';
  static String get saveMonitoringClockinUrl =>
      '$baseUrl/save_monitoring_clockin.php';
  static String get syncMonitoringClockinUrl =>
      '$baseUrl/sync_monitoring_clockin.php';

  // Helper method to build URLs with query parameters
  static String buildUrl(String endpoint, {Map<String, String>? queryParams}) {
    String url = '$baseUrl/$endpoint';
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      url += '?$queryString';
    }
    return url;
  }

  // Helper function to get auth token
  static Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      debugPrint('[AUTH] Error getting auth token: $e');
      return null;
    }
  }

  // Helper function to build serve_file.php URL with token
  static Future<String> buildServeFileUrl(String filePath) async {
    final token = await getAuthToken();
    debugPrint('[CONFIG] buildServeFileUrl called with filePath: $filePath');
    debugPrint('[CONFIG] Retrieved token: $token');
    final params = {'file': filePath};
    if (token != null) {
      params['token'] = token;
    }
    final url = buildUrl('serve_file.php', queryParams: params);
    debugPrint('[CONFIG] Generated serve URL: $url');
    return url;
  }
}

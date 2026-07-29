class AppConfig {
  // ========================================
  // LIVE SERVER CONFIGURATION
  // ========================================
  // static const String serverHost = 'tesing.mtltechnical.co.za';
  // static const String serverHost = 'rlms.rlms.co.za'; // Live server domain
  // static const int serverPort = 443; // HTTPS port
  // static const String serverProtocol = 'https';
  // // Live server uses HTTPS
  // static const String basePath = '/mobile';

  static const String serverHost =
      '192.168.68.102'; // Updated production hostname
  static const int serverPort = 8080; // HTTP poj   ``rt 8080
  static const String serverProtocol = 'http'; // Local server uses HTTP
  static const String basePath = '/assessorReport2/mobile';

  // Base URL for all API calls
  // Result: https://rlms.rlms.co.za/mobile
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
}

import 'package:flutter_test/flutter_test.dart';
import 'package:rlmss/utils/document_scanner_manager.dart';

void main() {
  group('Document Scanner Manager Tests', () {
    late DocumentScannerManager scannerManager;

    setUp(() {
      scannerManager = DocumentScannerManager();
    });

    test('Scanner manager should be singleton', () {
      final manager1 = DocumentScannerManager();
      final manager2 = DocumentScannerManager();
      expect(identical(manager1, manager2), true);
    });

    test('Initial state should not be scanning', () {
      expect(scannerManager.isScanning, false);
      expect(scannerManager.timeSinceLastScan, null);
    });

    test('Reset should clear scanning state', () {
      scannerManager.reset();
      expect(scannerManager.isScanning, false);
      expect(scannerManager.timeSinceLastScan, null);
    });

    test('Force reset should set last scan time', () {
      scannerManager.forceReset();
      expect(scannerManager.isScanning, false);
      expect(scannerManager.timeSinceLastScan, isNotNull);
    });
  });
}

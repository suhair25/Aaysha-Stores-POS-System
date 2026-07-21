import 'package:aaysha_stores/utils/barcode_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BarcodeUtils', () {
    test('normalizes EAN-13 values with prefixes and whitespace', () {
      expect(
        BarcodeUtils.normalizeScannedBarcode('EAN-13: 8901234567001'),
        '8901234567001',
      );
      expect(
        BarcodeUtils.normalizeScannedBarcode('  8901234567001  '),
        '8901234567001',
      );
      expect(
        BarcodeUtils.normalizeScannedBarcode('EAN13:8901234567001'),
        '8901234567001',
      );
    });

    test('returns null for empty or invalid scan values', () {
      expect(BarcodeUtils.normalizeScannedBarcode(null), isNull);
      expect(BarcodeUtils.normalizeScannedBarcode('   '), isNull);
      expect(BarcodeUtils.normalizeScannedBarcode('abc'), isNull);
    });
  });
}

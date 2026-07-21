import 'package:aaysha_stores/config/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('billing uses file-backed storage mode', () {
    expect(AppConstants.forceFileOnlyBilling, isTrue);
  });
}

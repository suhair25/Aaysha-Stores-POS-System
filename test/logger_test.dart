import 'package:aaysha_stores/utils/logger.dart';
import 'package:flutter_test/flutter_test.dart';

class ThrowingToString {
  @override
  String toString() => throw UnsupportedError('Unsupported operation: _Namespace');
}

void main() {
  test('AppLogger.error handles errors whose toString throws', () {
    expect(
      () => AppLogger.error('Sync queue read failed', ThrowingToString()),
      returnsNormally,
    );
  });
}

import 'package:aaysha_stores/utils/storage_path.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('falls back to a writable directory when path provider throws', () async {
    final dir = await StoragePathHelper.resolveDocumentsDirectory(
      provider: () async {
        throw MissingPluginException('No implementation found');
      },
    );

    expect(dir.existsSync(), isTrue);
    expect(dir.path, isNotEmpty);
  });
}

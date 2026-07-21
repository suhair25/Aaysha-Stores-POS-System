import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoragePathHelper {
  static Future<Directory> resolveDocumentsDirectory({
    Future<Directory> Function()? provider,
  }) async {
    final getDirectory = provider ?? getApplicationDocumentsDirectory;

    try {
      final directory = await getDirectory();
      if (directory.path.isNotEmpty) {
        return Directory(directory.path);
      }
    } on MissingPluginException catch (_) {
      // Fall back below when path_provider isn't available.
    } on PlatformException catch (_) {
      // Fall back below when path_provider isn't available.
    } catch (_) {
      // Fall back below for any unexpected path-provider error.
    }

    // Accessing Platform.environment is not supported on all Flutter platforms
    // (e.g., some embeddings throw UnsupportedError). Wrap access in a safe helper.
    String? safeEnv(String key) {
      try {
        return Platform.environment[key];
      } catch (_) {
        return null;
      }
    }

    final candidates = <String?>[
      safeEnv('LOCALAPPDATA'),
      safeEnv('APPDATA'),
      safeEnv('HOME'),
      safeEnv('USERPROFILE'),
      Directory.systemTemp.path,
    ];

    for (final candidate in candidates) {
      if (candidate == null || candidate.isEmpty) continue;
      final directory = Directory(p.join(candidate, 'AayshaStoresData'));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    }

    final fallback = await Directory.systemTemp.createTemp('aaysha_stores');
    return fallback;
  }

  /// Prefer external storage when available, otherwise fall back to documents.
  static Future<Directory> resolveExportDirectory() async {
    try {
      final external = await getExternalStorageDirectory();
      if (external != null && external.path.isNotEmpty) {
        return Directory(external.path);
      }
    } catch (_) {
      // ignore and fall back to documents directory
    }

    return resolveDocumentsDirectory();
  }
}

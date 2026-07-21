import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:aaysha_stores/utils/logger.dart';
import 'package:aaysha_stores/utils/storage_path.dart';

class FileSyncQueueService {
  static final FileSyncQueueService _instance =
      FileSyncQueueService._internal();
  factory FileSyncQueueService() => _instance;
  FileSyncQueueService._internal();

  Future<File> _getQueueFile() async {
    final doc = await StoragePathHelper.resolveDocumentsDirectory();
    final dir = Directory(p.join(doc.path, 'AayshaExports', 'sync_queue'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'queue.json'));
    if (!await file.exists()) await file.writeAsString(jsonEncode([]));
    return file;
  }

  Future<List<Map<String, dynamic>>> _readAll() async {
    try {
      final f = await _getQueueFile();
      final content = await f.readAsString();
      final arr = jsonDecode(content) as List<dynamic>;
      return arr.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      AppLogger.error('Failed to read sync queue file', e);
      return [];
    }
  }

  Future<void> _writeAll(List<Map<String, dynamic>> list) async {
    final f = await _getQueueFile();
    await f.writeAsString(jsonEncode(list));
  }

  Future<void> enqueue(
    String operation,
    String tableName,
    Map<String, dynamic> data,
  ) async {
    try {
      final list = await _readAll();
      final id = const Uuid().v4();
      final entry = {
        'id': id,
        'operation': operation,
        'tableName': tableName,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'isProcessed': false,
      };
      list.add(entry);
      await _writeAll(list);
      AppLogger.debug('Enqueued file sync op: $operation $tableName ($id)');
    } catch (e) {
      AppLogger.error('Failed to enqueue file sync op', e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPending() async {
    final all = await _readAll();
    return all.where((e) => e['isProcessed'] == false).toList();
  }

  Future<void> removeByIds(List<String> ids) async {
    final all = await _readAll();
    final remaining = all
        .where((e) => !ids.contains(e['id']?.toString()))
        .toList();
    await _writeAll(remaining);
  }
}

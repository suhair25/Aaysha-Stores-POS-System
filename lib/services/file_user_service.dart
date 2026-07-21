import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:aaysha_stores/models/user_model.dart';
import 'package:aaysha_stores/utils/logger.dart';

/// Simple file-backed user storage using a JSON array file.
class FileUserService {
  static final FileUserService _instance = FileUserService._internal();
  factory FileUserService() => _instance;
  FileUserService._internal();

  Future<File> _getUsersFile() async {
    final doc = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(doc.path, 'AayshaExports', 'users'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'users.json'));
    if (!await file.exists()) await file.writeAsString(jsonEncode([]));
    return file;
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final f = await _getUsersFile();
      final content = await f.readAsString();
      final arr = jsonDecode(content) as List<dynamic>;
      return arr.map((e) => UserModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      AppLogger.error('Failed to read users file', e);
      return [];
    }
  }

  Future<UserModel?> getUserByUid(String uid) async {
    final list = await getAllUsers();
    try {
      return list.firstWhere((u) => u.uid == uid);
    } catch (_) {
      return null;
    }
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final list = await getAllUsers();
    try {
      return list.firstWhere((u) => u.email.toLowerCase() == email.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(UserModel user) async {
    try {
      final list = await getAllUsers();
      final idx = list.indexWhere((u) => u.uid == user.uid);
      if (idx >= 0) {
        list[idx] = user;
      } else {
        list.add(user);
      }
      final f = await _getUsersFile();
      await f.writeAsString(jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (e) {
      AppLogger.error('Failed to save user to file', e);
      rethrow;
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      final list = await getAllUsers();
      final newList = list.where((u) => u.uid != uid).map((u) => u.toJson()).toList();
      final f = await _getUsersFile();
      await f.writeAsString(jsonEncode(newList));
    } catch (e) {
      AppLogger.error('Failed to delete user from file', e);
      rethrow;
    }
  }
}

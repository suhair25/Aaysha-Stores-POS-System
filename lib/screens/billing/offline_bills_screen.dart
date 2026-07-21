import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:aaysha_stores/services/file_storage_service.dart';
import 'package:aaysha_stores/services/sync_service.dart';

class OfflineBillsScreen extends StatefulWidget {
  const OfflineBillsScreen({super.key});

  @override
  State<OfflineBillsScreen> createState() => _OfflineBillsScreenState();
}

class _OfflineBillsScreenState extends State<OfflineBillsScreen> {
  final FileStorageService _fileSvc = FileStorageService();
  List<File> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    final files = await _fileSvc.listUnsyncedJsonFiles();
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  Future<void> _showFileContent(File f) async {
    final content = await f.readAsString();
    final pretty = const JsonEncoder.withIndent('  ').convert(jsonDecode(content));
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sale ${f.uri.pathSegments.last}'),
        content: SingleChildScrollView(child: Text(pretty)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _deleteFile(File f) async {
    final saleId = f.uri.pathSegments.last.replaceAll('.json', '');
    try {
      await _fileSvc.deleteSaleFiles(saleId);
      await _loadFiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete files: $e')));
    }
  }

  Future<void> _uploadAll() async {
    setState(() => _loading = true);
    await SyncService().uploadSavedSales();
    await _loadFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Bills')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? const Center(child: Text('No unsynced offline bills'))
                : ListView.separated(
                  itemCount: _files.length,
                  separatorBuilder: (_, separatorIndex) => const Divider(),
                  itemBuilder: (context, index) {
                    final f = _files[index];
                    final id = f.uri.pathSegments.last.replaceAll('.json', '');
                    return ListTile(
                      title: Text('Sale $id'),
                      subtitle: Text(f.path),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.remove_red_eye), onPressed: () => _showFileContent(f)),
                          IconButton(icon: const Icon(Icons.cloud_upload), onPressed: () async { await SyncService().uploadSavedSales(); await _loadFiles(); }),
                          IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteFile(f)),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadAll,
        icon: const Icon(Icons.cloud_upload),
        label: const Text('Upload all'),
      ),
    );
  }
}

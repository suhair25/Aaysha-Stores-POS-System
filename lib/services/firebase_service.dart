import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:aaysha_stores/utils/logger.dart';

/// Firebase Firestore service
/// Handles all cloud database operations
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  late final FirebaseFirestore _firestore;

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal() {
    _firestore = FirebaseFirestore.instance;
  }

  /// Get Firestore instance
  FirebaseFirestore get firestore => _firestore;

  /// ADD document to collection
  Future<String> addDocument(String collection, Map<String, dynamic> data) async {
    try {
      final docRef = await _firestore.collection(collection).add(data);
      AppLogger.success('Added document to $collection: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      AppLogger.error('Error adding document to $collection', e);
      rethrow;
    }
  }

  /// SET document with custom ID
  Future<void> setDocument(String collection, String docId, Map<String, dynamic> data,
      {bool merge = false}) async {
    try {
      await _firestore.collection(collection).doc(docId).set(data, SetOptions(merge: merge));
      AppLogger.success('Set document in $collection: $docId');
    } catch (e) {
      AppLogger.error('Error setting document in $collection', e);
      rethrow;
    }
  }

  /// UPDATE document
  Future<void> updateDocument(String collection, String docId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collection).doc(docId).update(data);
      AppLogger.success('Updated document in $collection: $docId');
    } catch (e) {
      AppLogger.error('Error updating document in $collection', e);
      rethrow;
    }
  }

  /// DELETE document
  Future<void> deleteDocument(String collection, String docId) async {
    try {
      await _firestore.collection(collection).doc(docId).delete();
      AppLogger.success('Deleted document from $collection: $docId');
    } catch (e) {
      AppLogger.error('Error deleting document from $collection', e);
      rethrow;
    }
  }

  /// GET single document
  Future<DocumentSnapshot> getDocument(String collection, String docId) async {
    try {
      final doc = await _firestore.collection(collection).doc(docId).get();
      AppLogger.debug('Retrieved document from $collection: $docId');
      return doc;
    } catch (e) {
      AppLogger.error('Error getting document from $collection', e);
      rethrow;
    }
  }

  /// QUERY documents
  Future<QuerySnapshot> queryDocuments(
    String collection, {
    String? whereField,
    dynamic isEqualTo,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    try {
      Query query = _firestore.collection(collection);

      if (whereField != null) {
        query = query.where(whereField, isEqualTo: isEqualTo);
      }

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      AppLogger.debug('Queried $collection: found ${snapshot.docs.length} documents');
      return snapshot;
    } catch (e) {
      AppLogger.error('Error querying $collection', e);
      rethrow;
    }
  }

  /// BATCH operations
  Future<List<dynamic>> batchWrite(
      List<Map<String, dynamic>> operations) async {
    try {
      final batch = _firestore.batch();

      for (final op in operations) {
        final collection = op['collection'] as String;
        final docId = op['docId'] as String;
        final data = op['data'] as Map<String, dynamic>;
        final type = op['type'] as String; // 'set', 'update', 'delete'

        if (type == 'set') {
          batch.set(_firestore.collection(collection).doc(docId), data);
        } else if (type == 'update') {
          batch.update(_firestore.collection(collection).doc(docId), data);
        } else if (type == 'delete') {
          batch.delete(_firestore.collection(collection).doc(docId));
        }
      }

      await batch.commit();
      AppLogger.success('Batch write completed: ${operations.length} operations');
      return [];
    } catch (e) {
      AppLogger.error('Batch write error', e);
      rethrow;
    }
  }

  /// LISTEN to real-time updates (use sparingly on free plan)
  Stream<QuerySnapshot> listenToCollection(String collection) {
    AppLogger.warning('Starting real-time listener on $collection (free plan: use sparingly)');
    return _firestore.collection(collection).snapshots();
  }

  /// LISTEN to single document (use sparingly on free plan)
  Stream<DocumentSnapshot> listenToDocument(String collection, String docId) {
    AppLogger.warning('Starting real-time listener on $collection/$docId (free plan: use sparingly)');
    return _firestore.collection(collection).doc(docId).snapshots();
  }

  /// Upload a file to Firebase Storage and return download URL
  Future<String> uploadFile(String path, File file, {SettableMetadata? metadata}) async {
    try {
      final storageRef = FirebaseStorage.instance.ref(path);
      final uploadTask = storageRef.putFile(file, metadata);
      final snapshot = await uploadTask.whenComplete(() {});
      final url = await snapshot.ref.getDownloadURL();
      AppLogger.success('Uploaded file to Storage: $path');
      return url;
    } catch (e) {
      AppLogger.error('Error uploading file to Storage', e);
      rethrow;
    }
  }

  /// Delete a file from Firebase Storage
  Future<void> deleteFile(String path) async {
    try {
      final storageRef = FirebaseStorage.instance.ref(path);
      await storageRef.delete();
      AppLogger.info('Deleted storage file: $path');
    } catch (e) {
      AppLogger.error('Error deleting storage file: $path', e);
    }
  }

  /// Count documents in collection
  Future<int> getDocumentCount(String collection) async {
    try {
      final snapshot = await _firestore.collection(collection).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      AppLogger.warning('Error counting documents in $collection', e);
      return 0;
    }
  }

  /// Search documents (case-insensitive prefix search)
  Future<QuerySnapshot> searchDocuments(
    String collection,
    String field,
    String searchTerm,
  ) async {
    try {
      final query = await _firestore
          .collection(collection)
          .where(field, isGreaterThanOrEqualTo: searchTerm)
          .where(field, isLessThan: '${searchTerm}z')
          .get();

      AppLogger.debug('Searched $collection for "$searchTerm": found ${query.docs.length} results');
      return query;
    } catch (e) {
      AppLogger.error('Search error in $collection', e);
      rethrow;
    }
  }

  /// Pagination helper
  Future<QuerySnapshot> getDocumentsWithPagination(
    String collection, {
    int pageSize = 20,
    DocumentSnapshot? lastDocument,
    String? orderBy,
  }) async {
    try {
      Query query = _firestore.collection(collection);

      if (orderBy != null) {
        query = query.orderBy(orderBy);
      }

      query = query.limit(pageSize + 1);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      AppLogger.debug('Pagination query: got ${snapshot.docs.length} documents');
      return snapshot;
    } catch (e) {
      AppLogger.error('Pagination error', e);
      rethrow;
    }
  }

  /// Check if document exists
  Future<bool> documentExists(String collection, String docId) async {
    try {
      final doc = await _firestore.collection(collection).doc(docId).get();
      return doc.exists;
    } catch (e) {
      AppLogger.error('Error checking document existence', e);
      return false;
    }
  }

  /// Get collection statistics
  Future<Map<String, dynamic>> getCollectionStats(String collection) async {
    try {
      final snapshot = await _firestore.collection(collection).get();
      return {
        'documentCount': snapshot.docs.length,
        'sizeBytes': 0,
      };
    } catch (e) {
      AppLogger.warning('Error getting collection stats', e);
      return {'documentCount': 0, 'sizeBytes': 0};
    }
  }
}

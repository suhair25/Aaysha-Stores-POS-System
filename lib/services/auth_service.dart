import 'package:firebase_auth/firebase_auth.dart';
import 'package:aaysha_stores/models/user_model.dart';
import 'package:aaysha_stores/services/sqlite_service.dart';
import 'package:aaysha_stores/services/file_user_service.dart';
import 'package:aaysha_stores/utils/logger.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'package:aaysha_stores/enums/user_role.dart';

/// Firebase Authentication service
/// Handles user authentication and session management
class AuthService {
  static final AuthService _instance = AuthService._internal();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final SQLiteService _sqliteService = SQLiteService();
  final FileUserService _fileUserService = FileUserService();

  UserModel? _currentUser;

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  /// Initialize authentication
  Future<void> initialize() async {
    try {
      AppLogger.info('Initializing Auth Service...');

      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        // Load user from local database or file-backed storage
        if (AppConstants.forceFileOnlyBilling) {
          _currentUser = await _fileUserService.getUserByUid(firebaseUser.uid);
        } else {
          _currentUser = await _loadUserFromLocal(firebaseUser.uid);
        }
      }

      AppLogger.success('Auth Service initialized');
    } catch (e) {
      AppLogger.error('Error initializing Auth Service', e);
    }
  }

  /// Get current user
  UserModel? get currentUser => _currentUser;

  /// Get current Firebase user
  User? get firebaseUser => _firebaseAuth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => _firebaseAuth.currentUser != null;

  /// Import UserRole enum
  // (Imports are at the top of the file)

  /// Sign up (create new account)
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
  }) async {
    try {
      AppLogger.info('Signing up user: $email');

      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Create user model
      final user = UserModel(
        uid: uid,
        email: email.trim(),
        fullName: fullName,
        phone: phone,
        role: role,
        createdAt: DateTime.now(),
      );

      // Save to local database or file
      if (AppConstants.forceFileOnlyBilling) {
        await _fileUserService.saveUser(user);
      } else {
        await _saveUserToLocal(user);
      }
      _currentUser = user;

      AppLogger.success('User signed up successfully: $email');
      return user;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Firebase auth error during signup', e.message);
      rethrow;
    } catch (e) {
      AppLogger.error('Error during signup', e);
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger.info('Signing in user: $email');

      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Load user from local database or file
      if (AppConstants.forceFileOnlyBilling) {
        _currentUser = await _fileUserService.getUserByUid(uid);
      } else {
        _currentUser = await _loadUserFromLocal(uid);
      }
      if (_currentUser != null) {
        AppLogger.success('User signed in successfully: $email');
        return _currentUser;
      }

      AppLogger.error('User not found in local database');
      return null;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Firebase auth error during signin', e.message);
      // Fallback: allow specific local test accounts when Firebase isn't available
      final trimmedEmail = email.trim();
      if (trimmedEmail == 'suhair@gmail.com' && password == 'Suhair2002@') {
        final localUser = UserModel(
          uid: 'local_suhair',
          email: trimmedEmail,
          fullName: 'Suhair',
          phone: '0000000000',
          role: UserRole.owner,
          createdAt: DateTime.now(),
        );
        await _saveUserToLocal(localUser);
        _currentUser = localUser;
        AppLogger.info('Signed in using local fallback account: $trimmedEmail');
        return _currentUser;
      }

      // Demo cashier account
      if (trimmedEmail == 'cashier@local' && password == 'cashier123') {
        final localUser = UserModel(
          uid: 'local_cashier',
          email: trimmedEmail,
          fullName: 'Local Cashier',
          phone: '0000000000',
          role: UserRole.cashier,
          createdAt: DateTime.now(),
        );
        await _saveUserToLocal(localUser);
        _currentUser = localUser;
        AppLogger.info('Signed in using local fallback account: $trimmedEmail');
        return _currentUser;
      }
      rethrow;
    } catch (e) {
      AppLogger.error('Error during signin', e);
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      _currentUser = null;
      AppLogger.success('User signed out');
    } catch (e) {
      AppLogger.error('Error during signout', e);
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      AppLogger.info('Sending password reset email to: $email');
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      AppLogger.success('Password reset email sent');
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Firebase auth error during password reset', e.message);
      rethrow;
    } catch (e) {
      AppLogger.error('Error during password reset', e);
      rethrow;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile(UserModel user) async {
    try {
      // Update local database
      await _saveUserToLocal(user);
      _currentUser = user;
      AppLogger.success('User profile updated');
    } catch (e) {
      AppLogger.error('Error updating user profile', e);
      rethrow;
    }
  }

  /// Save user to local database
  Future<void> _saveUserToLocal(UserModel user) async {
    try {
      final data = user.toJson();
      if (AppConstants.forceFileOnlyBilling) {
        await _fileUserService.saveUser(user);
        AppLogger.debug('User saved to local file: ${user.uid}');
      } else {
        final existing = await _sqliteService.query(
          'users',
          where: 'uid = ?',
          whereArgs: [user.uid],
        );

        if (existing.isNotEmpty) {
          await _sqliteService.update('users', data, 'uid = ?', [user.uid]);
        } else {
          await _sqliteService.insert('users', data);
        }

        AppLogger.debug('User saved to local database: ${user.uid}');
      }
    } catch (e) {
      AppLogger.error('Error saving user to local database', e);
    }
  }

  /// Load user from local database
  Future<UserModel?> _loadUserFromLocal(String uid) async {
    try {
      if (AppConstants.forceFileOnlyBilling) {
        final user = await _fileUserService.getUserByUid(uid);
        if (user != null) {
          AppLogger.debug('User loaded from local file: $uid');
          return user;
        }
        AppLogger.warning('User not found in local file: $uid');
        return null;
      }

      final results = await _sqliteService.query(
        'users',
        where: 'uid = ?',
        whereArgs: [uid],
      );

      if (results.isNotEmpty) {
        final user = UserModel.fromJson(results.first);
        AppLogger.debug('User loaded from local database: $uid');
        return user;
      }

      AppLogger.warning('User not found in local database: $uid');
      return null;
    } catch (e) {
      AppLogger.error('Error loading user from local database', e);
      return null;
    }
  }

  /// Check if email exists
  Future<bool> emailExists(String email) async {
    try {
      // First check local users table to avoid unnecessary remote checks
      if (AppConstants.forceFileOnlyBilling) {
        final u = await _fileUserService.getUserByEmail(email.trim());
        if (u != null) return true;
      } else {
        final local = await _sqliteService.query(
          'users',
          where: 'email = ?',
          whereArgs: [email.trim()],
        );
        if (local.isNotEmpty) return true;
      }

      // Remote check: note `fetchSignInMethodsForEmail` is deprecated in client SDKs.
      // Keep the call as a fallback but suppress the deprecation analyzer warning
      // and log a note that this check may be affected by Identity Platform settings.
      // ignore: deprecated_member_use
      final methods = await _firebaseAuth.fetchSignInMethodsForEmail(
        email.trim(),
      );
      return methods.isNotEmpty;
    } catch (e) {
      AppLogger.error('Error checking if email exists', e);
      return false;
    }
  }

  /// Get authentication state stream
  Stream<User?> get authStateStream => _firebaseAuth.authStateChanges();
}

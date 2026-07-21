import 'package:flutter/material.dart';
import 'package:aaysha_stores/models/user_model.dart';
import 'package:aaysha_stores/services/auth_service.dart';
import 'package:aaysha_stores/utils/logger.dart';
import 'package:aaysha_stores/enums/user_role.dart';

/// Auth provider for managing sign-in, sign-up, and user state.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _authService.initialize();
      _user = _authService.currentUser;
    } catch (e) {
      AppLogger.error('AuthProvider initialization failed', e);
      _errorMessage = 'Unable to initialize authentication.';
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final result = await _authService.signIn(email: email, password: password);
      if (result != null) {
        _user = result;
        AppLogger.success('User signed in: ${result.email}');
        return true;
      }
      _errorMessage = 'Invalid credentials.';
      return false;
    } catch (e) {
      AppLogger.error('Sign in failed', e);
      _errorMessage = 'Failed to sign in. Please check your credentials.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final result = await _authService.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        role: role,
      );
      if (result != null) {
        _user = result;
        AppLogger.success('User signed up: ${result.email}');
        return true;
      }
      _errorMessage = 'Unable to create account.';
      return false;
    } catch (e) {
      AppLogger.error('Sign up failed', e);
      _errorMessage = 'Failed to create account. Please try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _user = null;
      AppLogger.info('User signed out');
    } catch (e) {
      AppLogger.error('Sign out failed', e);
      _errorMessage = 'Failed to sign out.';
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

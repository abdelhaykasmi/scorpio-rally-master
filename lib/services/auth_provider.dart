import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'supabase_service.dart';
import 'local_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;
  bool get isParticipant => _currentUser?.role == UserRole.participant;
  bool get isOrganizer => _currentUser?.role == UserRole.organizer;
  bool get isSuperAdmin => _currentUser?.role == UserRole.superAdmin;

  Future<void> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();
    final user = await LocalStorageService.instance.getCurrentUser();
    if (user != null) {
      _currentUser = user;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> signIn(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    AppUser? user;

    // Try Supabase first, fall back to local demo data
    try {
      user = await SupabaseService.instance.signIn(
          username.trim(), password.trim());
    } catch (_) {
      // Supabase unavailable — try local cache (seeded demo data)
      user = null;
    }

    // Fallback: check locally cached users (works offline / if Supabase unreachable)
    if (user == null) {
      final localUsers = await LocalStorageService.instance.getCachedUsers();
      if (localUsers.isNotEmpty) {
        final hash = SupabaseService.hashPassword(password.trim());
        try {
          user = localUsers.firstWhere(
            (u) => u.username == username.trim() &&
                u.passwordHash == hash &&
                u.isActive,
          );
        } catch (_) {
          user = null;
        }
      }
    }

    if (user != null) {
      _currentUser = user;
      await LocalStorageService.instance.saveCurrentUser(user);
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Invalid username or password';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _currentUser = null;
    await LocalStorageService.instance.clearCurrentUser();
    notifyListeners();
  }

  void updateCurrentUser(AppUser user) {
    _currentUser = user;
    LocalStorageService.instance.saveCurrentUser(user);
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

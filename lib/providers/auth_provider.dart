import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _role = 'customer'; // 'customer' | 'worker' | 'admin'
  AppUser? _profile;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get role => _role;
  AppUser? get profile => _profile;

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getString('auth_token') != null;
    _role = prefs.getString('role') ?? 'customer';
    if (_isLoggedIn) {
      // Refresh full profile (verification status, availability, etc.)
      try {
        _profile = await _api.getProfile();
        _role = _profile!.role;
      } catch (_) {
        // token might be stale; leave role as cached
      }
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.login(username, password);
      _isLoggedIn = true;
      _role = data['role'] ?? 'customer';
      _profile = await _api.getProfile();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      _isLoggedIn = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String role,
    String phone = '',
    String category = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.register(
        username: username,
        email: email,
        password: password,
        role: role,
        phone: phone,
        category: category,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }


  Future<void> refreshProfile() async {
    try {
      _profile = await _api.getProfile();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    await _api.logout();
    _isLoggedIn = false;
    _profile = null;
    notifyListeners();
  }

  void forceMockLogin(String roleName) {
    _isLoggedIn = true;
    _role = roleName;
    _profile = AppUser(
      id: 1,
      username: 'Demo User',
      email: 'demo@smartfix.com',
      role: roleName,
      phone: '1234567890',
    );
    notifyListeners();
  }
}
  

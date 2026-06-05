import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class UserProvider extends ChangeNotifier {
  String _name = 'Unknown';
  String _age = '18';
  String _email = '';
  bool _isAdmin = false;
  String _verificationStatus = 'none';

  String get name => _name;
  String get age => _age;
  String get email => _email;
  bool get isAdmin => _isAdmin;
  String get verificationStatus => _verificationStatus;

  void setUser({
    required String name,
    required String age,
    required String email,
    required bool isAdmin,
    required String verificationStatus,
  }) {
    _name = name;
    _age = age;
    _email = email;
    _isAdmin = isAdmin;
    _verificationStatus = verificationStatus;
    notifyListeners();
  }

  void updateVerificationStatus(String status) {
    _verificationStatus = status;
    notifyListeners();
  }

  Future<void> fetchProfile() async {
    if (_email.isEmpty) return;
    try {
      final data = await AuthService.getProfile(_email);
      _name = data['name'] ?? _name;
      _age = data['age'] ?? _age;
      _verificationStatus = data['verificationStatus'] ?? 'none';
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', _name);
      await prefs.setString('user_age', _age);
      await prefs.setString('verification_status', _verificationStatus);
      
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to fetch profile in UserProvider: $e");
    }
  }
}

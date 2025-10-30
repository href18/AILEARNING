import 'dart:async';

import 'package:flutter/foundation.dart';

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({
    String demoEmail = 'admin@example.com',
    String demoPassword = 'TrainMe123!',
  })  : _demoEmail = demoEmail.toLowerCase(),
        _demoPassword = demoPassword;

  final ValueNotifier<bool> _isSignedInNotifier = ValueNotifier<bool>(false);
  final Map<String, String> _users = {};
  final String _demoEmail;
  final String _demoPassword;
  String? _currentEmail;

  ValueListenable<bool> get authState => _isSignedInNotifier;

  bool get isSignedIn => _isSignedInNotifier.value;

  String? get currentEmail => _currentEmail;

  Future<void> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final normalizedEmail = email.toLowerCase();

    if (!_users.containsKey(normalizedEmail)) {
      throw AuthException('Brukeren er ikke registrert ennå.');
    }
    if (_users[normalizedEmail] != password) {
      throw AuthException('Feil passord. Prøv igjen.');
    }

    _currentEmail = normalizedEmail;
    _isSignedInNotifier.value = true;
  }

  Future<void> signUp(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final normalizedEmail = email.toLowerCase();

    if (_users.containsKey(normalizedEmail)) {
      throw AuthException('Denne e-posten er allerede registrert.');
    }

    _users[normalizedEmail] = password;
    _currentEmail = normalizedEmail;
    _isSignedInNotifier.value = true;
  }

  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _currentEmail = null;
    _isSignedInNotifier.value = false;
  }

  void seedDemoUser() {
    _users.putIfAbsent(_demoEmail, () => _demoPassword);
  }
}

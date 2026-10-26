import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/services.dart';

/// Firebase oturum durumunu GoRouter'ın dinleyebileceği bir
/// [ChangeNotifier]'a çevirir. `isReady`, ilk auth cevabı gelene kadar
/// splash ekranında beklemek için kullanılır.
class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    _subscription = authServiceInstance.authStateChanges.listen((user) {
      _user = user;
      _isReady = true;
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _subscription;
  User? _user;
  bool _isReady = false;

  bool get isReady => _isReady;
  bool get isAuthenticated => _user != null;
  User? get user => _user;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

import 'dart:async';

import 'package:common/api/supabase_client.dart';
import 'package:common/models/profile.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthNotifier extends ChangeNotifier {
  SupabaseAuthNotifier() {
    _session = Supabase.instance.client.auth.currentSession;
    if (_session != null) {
      _loadProfile();
    }
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _session = data.session;
      if (_session == null) {
        _profile = null;
      } else {
        _loadProfile();
      }
      notifyListeners();
    });
  }

  Session? _session;
  Profile? _profile;
  bool _loadingProfile = false;
  late final StreamSubscription<AuthState> _subscription;

  Session? get session => _session;
  Profile? get profile => _profile;
  bool get loadingProfile => _loadingProfile;

  bool get isAuthenticated => _session != null;

  bool get isCreator => _profile?.role == 'creator' || _profile?.role == 'admin';

  Future<void> signIn(String email, String password) async {
    final response = await SupabaseManager.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    _session = response.session;
    await _loadProfile();
    notifyListeners();
  }

  Future<void> signOut() async {
    await SupabaseManager.client.auth.signOut();
    _profile = null;
    _session = null;
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    final userId = _session?.user.id;
    if (userId == null) {
      return;
    }
    _loadingProfile = true;
    notifyListeners();
    final response = await SupabaseManager.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    _loadingProfile = false;
    if (response != null) {
      _profile = Profile.fromJson(response as Map<String, dynamic>);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

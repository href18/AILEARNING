import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_state.dart';

final authNotifierProvider = ChangeNotifierProvider<SupabaseAuthNotifier>((ref) {
  final notifier = SupabaseAuthNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

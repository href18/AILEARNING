import 'package:common/api/supabase_client.dart';
import 'package:common/models/certificate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

final certificatesProvider = FutureProvider<List<Certificate>>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  final userId = auth.profile?.id;
  if (userId == null) {
    return const [];
  }
  final response = await SupabaseManager.client
      .from('certificates')
      .select()
      .eq('user_id', userId)
      .order('issued_at', ascending: false);
  return (response as List<dynamic>)
      .map((json) => Certificate.fromJson(json as Map<String, dynamic>))
      .toList();
});

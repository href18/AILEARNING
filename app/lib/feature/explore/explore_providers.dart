import 'package:common/api/supabase_client.dart';
import 'package:common/models/course.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final exploreSearchProvider = StateProvider<String>((ref) => '');

final catalogProvider = FutureProvider<List<Course>>((ref) async {
  final query = ref.watch(exploreSearchProvider);
  final response = await SupabaseManager.client
      .from('courses')
      .select()
      .eq('is_published', true)
      .order('title');
  final courses = (response as List<dynamic>)
      .map((json) => Course.fromJson(json as Map<String, dynamic>))
      .toList();
  if (query.isEmpty) {
    return courses;
  }
  final lowercase = query.toLowerCase();
  return courses
      .where((course) => course.title.toLowerCase().contains(lowercase))
      .toList();
});

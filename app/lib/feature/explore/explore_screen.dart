import 'package:common/api/supabase_client.dart';
import 'package:common/models/course.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_providers.dart';
import '../learning/learning_providers.dart';
import 'explore_providers.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(catalogProvider);
    final enrollmentsAsync = ref.watch(enrollmentsProvider);
    final enrollments = enrollmentsAsync.maybeWhen(data: (data) => data, orElse: () => const []);
    final enrolledCourseIds = enrollments.map((e) => e.courseId).toSet();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search courses',
                    ),
                    onChanged: (value) =>
                        ref.read(exploreSearchProvider.notifier).state = value,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Filters coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: coursesAsync.when(
              data: (courses) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(catalogProvider);
                },
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 3 / 2,
                  ),
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    final course = courses[index];
                    final enrolled = enrolledCourseIds.contains(course.id);
                    return _CourseCard(course: course, enrolled: enrolled);
                  },
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error loading courses: $error')),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends ConsumerWidget {
  const _CourseCard({required this.course, required this.enrolled});

  final Course course;
  final bool enrolled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    course.description ?? 'No description provided',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(_formatPrice(course.priceCents, course.currency)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: enrolled ? null : () => _startCheckout(context, ref, course),
                child: Text(enrolled ? 'Enrolled' : 'Buy'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(int cents, String currency) {
    final value = cents / 100;
    return '${currency.toUpperCase()} ${value.toStringAsFixed(2)}';
  }

  Future<void> _startCheckout(BuildContext context, WidgetRef ref, Course course) async {
    final auth = ref.read(authNotifierProvider);
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to purchase courses.')),
      );
      return;
    }

    final response = await SupabaseManager.client.functions.invoke('create-checkout-session', body: {
      'course_id': course.id,
      'success_url': 'app://success',
      'cancel_url': 'app://cancel',
    });

    final data = response.data as Map<String, dynamic>?;
    final url = data?['url'] as String?;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start checkout.')), 
      );
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open checkout URL: $url')),
      );
    }
  }
}

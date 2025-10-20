import 'package:common/models/certificate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'certificates_providers.dart';

class CertificatesScreen extends ConsumerWidget {
  const CertificatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certificatesAsync = ref.watch(certificatesProvider);
    return SafeArea(
      child: certificatesAsync.when(
        data: (certificates) {
          if (certificates.isEmpty) {
            return const Center(child: Text('Complete courses to earn certificates.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final certificate = certificates[index];
              return _CertificateTile(certificate: certificate);
            },
            separatorBuilder: (_, __) => const Divider(),
            itemCount: certificates.length,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load certificates: $error')),
      ),
    );
  }
}

class _CertificateTile extends StatelessWidget {
  const _CertificateTile({required this.certificate});

  final Certificate certificate;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('Course ${certificate.courseId}'),
      subtitle: Text('Issued ${certificate.issuedAt.toLocal()}'),
      trailing: certificate.pdfUrl == null
          ? const Text('Pending PDF')
          : FilledButton.icon(
              onPressed: () => _openPdf(context, certificate.pdfUrl!),
              icon: const Icon(Icons.download),
              label: const Text('Download'),
            ),
    );
  }

  Future<void> _openPdf(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open certificate URL: $url')),
        );
      }
    }
  }
}

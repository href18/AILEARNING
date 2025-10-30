import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:compliance_training_app/localization/app_localizations.dart';

class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key, this.showLabel = true, this.compact = false});

  final bool showLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final isNorwegian = locale.languageCode != 'en';

    final toggle = SegmentedButton<bool>(
      style: ButtonStyle(
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 8)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: WidgetStateProperty.all(const Size(0, 36)),
      ),
      segments: const <ButtonSegment<bool>>[
        ButtonSegment<bool>(
          value: true,
          label: Text('Norsk'),
        ),
        ButtonSegment<bool>(
          value: false,
          label: Text('English'),
        ),
      ],
      selected: <bool>{isNorwegian},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) {
          return;
        }
        final targetCode = selection.first ? 'nb' : 'en';
        Intl.defaultLocale = targetCode;
        AppLocalizationsDelegateHolder
            .updateLocale(Locale(targetCode));
      },
    );

    if (!showLabel) {
      return toggle;
    }

    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Text(
          l10n.translate('catalog_language_toggle'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(width: 8),
        toggle,
      ],
    );
  }
}

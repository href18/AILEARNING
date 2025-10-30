import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:compliance_training_app/localization/app_localizations.dart';
import 'package:compliance_training_app/services/auth_service.dart';
import 'package:compliance_training_app/widgets/language_toggle_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _isRegistering = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _infoMessage = null;
      _loading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    await Future.delayed(const Duration(milliseconds: 150));

    if (_isRegistering) {
      await _signUp(email, password);
    } else {
      await _signIn(email, password);
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _signIn(String email, String password) async {
    try {
      await widget.authService.signIn(email, password);
      if (!mounted) {
        return;
      }
      context.go('/');
    } on AuthException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = AppLocalizations.of(context)
            .translate('login_error_unexpected', params: {'error': '$error'});
      });
    }
  }

  Future<void> _signUp(String email, String password) async {
    try {
      await widget.authService.signUp(email, password);
      if (!mounted) {
        return;
      }
      context.go('/');
    } on AuthException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = AppLocalizations.of(context)
            .translate('login_error_unexpected', params: {'error': '$error'});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final isWide = media.size.width >= 960;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff0f172a), Color(0xff1f2937)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 48 : 24,
                      vertical: isWide ? 40 : 28,
                    ),
                    child: isWide
                        ? Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child:
                                    _MarketingPanel(theme: theme, l10n: l10n),
                              ),
                              const SizedBox(width: 48),
                              Expanded(
                                flex: 2,
                                child: _AuthCard(
                                  formKey: _formKey,
                                  emailController: _emailController,
                                  passwordController: _passwordController,
                                  isRegistering: _isRegistering,
                                  loading: _loading,
                                  errorMessage: _errorMessage,
                                  infoMessage: _infoMessage,
                                  onSubmit: _submit,
                                  onToggleMode: _toggleMode,
                                ),
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _MarketingPanel(theme: theme, l10n: l10n),
                                const SizedBox(height: 28),
                                _AuthCard(
                                  formKey: _formKey,
                                  emailController: _emailController,
                                  passwordController: _passwordController,
                                  isRegistering: _isRegistering,
                                  loading: _loading,
                                  errorMessage: _errorMessage,
                                  infoMessage: _infoMessage,
                                  onSubmit: _submit,
                                  onToggleMode: _toggleMode,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleMode() {
    if (_loading) {
      return;
    }
    setState(() {
      _isRegistering = !_isRegistering;
      _errorMessage = null;
      _infoMessage = null;
    });
  }
}

class _MarketingPanel extends StatelessWidget {
  const _MarketingPanel({required this.theme, required this.l10n});

  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final headline = theme.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_moon_outlined,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                'Compliance Academy',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(l10n.translate('login_intro_title'), style: headline),
        const SizedBox(height: 16),
        Text(
          l10n.translate('login_intro_body'),
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _FeatureBulletRow(text: l10n.translate('login_intro_points')),
        const SizedBox(height: 32),
        Text(
          l10n.translate('login_partner_blurb'),
          style: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 18,
          runSpacing: 12,
          children: List.generate(
            4,
            (index) => Container(
              height: 42,
              width: 110,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                'LOGO ${index + 1}',
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 0.6,
                  color: theme.hintColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureBulletRow extends StatelessWidget {
  const _FeatureBulletRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = text.split('·');
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: parts.where((part) => part.trim().isNotEmpty).map((part) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle,
                  color: theme.colorScheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                part.trim(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isRegistering,
    required this.loading,
    required this.errorMessage,
    required this.infoMessage,
    required this.onSubmit,
    required this.onToggleMode,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isRegistering;
  final bool loading;
  final String? errorMessage;
  final String? infoMessage;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isRegistering
                          ? l10n.translate('login_title_register')
                          : l10n.translate('login_title_sign_in'),
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const LanguageToggleButton(showLabel: false, compact: true),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isRegistering
                    ? l10n.translate('login_subtitle_register')
                    : l10n.translate('login_subtitle_sign_in'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: l10n.translate('login_email_label'),
                  hintText: l10n.translate('login_email_hint'),
                  prefixIcon: const Icon(Icons.alternate_email),
                ),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.translate('login_email_error_empty');
                  }
                  if (!value.contains('@')) {
                    return l10n.translate('login_email_error_invalid');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: l10n.translate('login_password_label'),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.translate('login_password_error_empty');
                  }
                  if (value.length < 6) {
                    return l10n.translate('login_password_error_short');
                  }
                  return null;
                },
              ),
              if (isRegistering)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    l10n.translate('login_register_notice'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ),
              const SizedBox(height: 20),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    errorMessage!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              if (infoMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    infoMessage!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                ),
              FilledButton.icon(
                onPressed: loading ? null : onSubmit,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(isRegistering ? Icons.arrow_forward : Icons.login),
                label: Text(
                  isRegistering
                      ? l10n.translate('login_button_register')
                      : l10n.translate('login_button_sign_in'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: loading ? null : onToggleMode,
                child: Text(
                  isRegistering
                      ? l10n.translate('login_switch_to_sign_in')
                      : l10n.translate('login_switch_to_register'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

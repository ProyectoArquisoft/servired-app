import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import 'package:servired_app/features/auth/data/auth_repository.dart';
import 'package:servired_app/l10n/app_localizations.dart';

/// Ingreso y registro con correo y contraseña (Supabase Auth). Al iniciar
/// sesión, reemplaza esta pantalla por la que el ciudadano quería abrir.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.redirectTo});

  /// Ruta a la que se va después de ingresar; `null` vuelve atrás.
  final String? redirectTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final auth = ref.read(authRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final signedIn = _registering
          ? await auth.signUp(email: _email.text, password: _password.text)
          : await auth
                .signIn(email: _email.text, password: _password.text)
                .then((_) => true);
      if (!mounted) return;
      if (signedIn) {
        _leave();
      } else {
        setState(() {
          _info = l10n.confirmEmailSent;
          _registering = false;
        });
      }
    } on AuthException catch (e) {
      final code = e.code ?? '';
      setState(
        () => _error = switch (code) {
          'email_not_confirmed' => l10n.emailNotConfirmed,
          _ when _registering => l10n.registerFailed,
          _ => l10n.loginFailed,
        },
      );
    } on Exception {
      setState(() => _error = l10n.authNetworkError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _leave() {
    if (widget.redirectTo case final target?) {
      context.pushReplacement(target);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.login)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  _registering ? l10n.registerTitle : l10n.loginTitle,
                  style: textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(l10n.loginWhy),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.emailLabel,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (v) =>
                      RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(v?.trim() ?? '')
                      ? null
                      : l10n.emailInvalid,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: _obscure,
                  autofillHints: [
                    _registering
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: l10n.passwordLabel,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: l10n.passwordLabel,
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      (v ?? '').length >= 6 ? null : l10n.passwordTooShort,
                ),
                if (_error != null || _info != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Card(
                      color: _error != null
                          ? Theme.of(context).colorScheme.errorContainer
                          : Theme.of(context).colorScheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error ?? _info!),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _registering ? l10n.registerButton : l10n.loginButton,
                        ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _registering = !_registering;
                          _error = null;
                        }),
                  child: Text(
                    _registering ? l10n.switchToLogin : l10n.switchToRegister,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

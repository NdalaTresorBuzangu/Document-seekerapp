import 'package:flutter/material.dart';

import 'api_service.dart';
import 'auth_validators.dart';
import 'auth_widgets.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';
import 'seeker_dashboard_page.dart';
import 'session_store.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = await ApiService.login(
        email: _email.text.trim(),
        password: _password.text,
      );
      final data = body['data'] as Map<String, dynamic>?;
      final token = data?['token']?.toString();
      final user = data?['user'] as Map<String, dynamic>?;
      if (token == null || user == null) {
        throw Exception('Unexpected login response');
      }
      final id = user['userID'] as int? ?? int.tryParse(user['userID'].toString()) ?? 0;
      await SessionStore.saveSession(
        token: token,
        userId: id,
        userName: user['userName']?.toString() ?? '',
        userEmail: user['userEmail']?.toString() ?? '',
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const SeekerDashboardPage()),
        (r) => false,
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Sign in'),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.45),
              scheme.surfaceContainerLowest,
              scheme.secondaryContainer.withValues(alpha: 0.2),
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: AuthShell(
              title: 'Welcome back',
              subtitle:
                  'Use the same email and password as the Tshijuka RDP website. You can reset your password here or on the website.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: AuthValidators.validateEmail,
                  ),
                  const SizedBox(height: 18),
                  ObscuredPasswordField(
                    controller: _password,
                    label: 'Password',
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    validator: AuthValidators.validatePasswordLogin,
                    onFieldSubmitted: (_) => _busy ? null : _submit(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(builder: (_) => const ForgotPasswordPage()),
                              );
                            },
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Material(
                      color: scheme.errorContainer.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline_rounded, color: scheme.error, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: scheme.onErrorContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'New here?',
                        style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
                                );
                              },
                        child: const Text('Create an account'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

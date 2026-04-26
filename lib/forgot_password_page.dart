import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_service.dart';
import 'auth_validators.dart';
import 'auth_widgets.dart';

/// Same steps as the website: request code by email, then OTP + new password.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  int _step = 0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validateOtp(String? v) {
    final s = v?.trim() ?? '';
    if (s.length != 6) return 'Enter the 6-digit code from your email';
    if (!RegExp(r'^\d{6}$').hasMatch(s)) return 'Use digits only (000000)';
    return null;
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiService.requestPasswordReset(email: _email.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If this email is registered, a code was sent. Check your inbox and spam folder.',
          ),
        ),
      );
      setState(() => _step = 1);
      _otp.clear();
      _password.clear();
      _confirm.clear();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setNewPassword() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiService.confirmPasswordReset(
        email: _email.text.trim(),
        otp: _otp.text.trim(),
        newPassword: _password.text,
        confirmPassword: _confirm.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. You can sign in now.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Reset password'),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.4),
              scheme.surfaceContainerLowest,
              scheme.secondaryContainer.withValues(alpha: 0.22),
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: AuthShell(
              title: _step == 0 ? 'Forgot your password?' : 'Enter code & new password',
              subtitle: _step == 0
                  ? 'If an account exists for this email, a 6-digit code will be sent (valid 15 minutes). Check your inbox and spam folder.'
                  : 'Enter the 6-digit code from your email, then choose a new password.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_step == 0) ...[
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      validator: AuthValidators.validateEmail,
                      onFieldSubmitted: (_) => _busy ? null : _sendCode(),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _email,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _otp,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                      decoration: const InputDecoration(
                        labelText: 'Verification code',
                        hintText: '000000',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                      validator: _validateOtp,
                    ),
                    const SizedBox(height: 14),
                    ObscuredPasswordField(
                      controller: _password,
                      label: 'New password',
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: AuthValidators.validatePasswordRegister,
                    ),
                    const SizedBox(height: 10),
                    PasswordRuleChecklist(password: _password.text),
                    const SizedBox(height: 14),
                    ObscuredPasswordField(
                      controller: _confirm,
                      label: 'Confirm new password',
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) {
                        if (v != _password.text) return 'Passwords do not match';
                        return AuthValidators.validatePasswordRegister(v);
                      },
                      onFieldSubmitted: (_) => _busy ? null : _setNewPassword(),
                    ),
                  ],
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
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                    onPressed: _busy
                        ? null
                        : (_step == 0 ? _sendCode : _setNewPassword),
                    child: _busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_step == 0 ? 'Send code' : 'Set new password'),
                  ),
                  if (_step == 1) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() {
                                _step = 0;
                                _error = null;
                              });
                            },
                      child: const Text('Request a new code'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

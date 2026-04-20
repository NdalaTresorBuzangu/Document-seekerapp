import 'package:flutter/material.dart';

import 'api_service.dart';
import 'auth_validators.dart';
import 'auth_widgets.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _contact = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _terms = false;
  bool _privacy = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _contact.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_terms || !_privacy) {
      setState(() => _error = 'Please accept the Terms and Privacy Policy to continue.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiService.register(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        confirmPassword: _confirm.text,
        contact: _contact.text.trim(),
        acceptTerms: _terms,
        acceptPrivacy: _privacy,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. You can sign in now.')),
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
        title: const Text('Create account'),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.secondaryContainer.withValues(alpha: 0.35),
              scheme.surfaceContainerLowest,
              scheme.primaryContainer.withValues(alpha: 0.25),
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: AuthShell(
              title: 'Create your account',
              subtitle:
                  'Choose a strong password: at least ${AuthValidators.minPasswordLength} characters including upper and lower case, a number, and a symbol. You can use this account on the website too.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: AuthValidators.validateName,
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contact,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      prefixIcon: Icon(Icons.phone_outlined),
                      helperText: 'Leave blank if you prefer not to share a number',
                    ),
                    validator: (v) => AuthValidators.validateOptionalContact(v),
                  ),
                  const SizedBox(height: 16),
                  ObscuredPasswordField(
                    controller: _password,
                    label: 'Password',
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: AuthValidators.validatePasswordRegister,
                  ),
                  const SizedBox(height: 14),
                  PasswordRuleChecklist(password: _password.text),
                  const SizedBox(height: 16),
                  ObscuredPasswordField(
                    controller: _confirm,
                    label: 'Confirm password',
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (v) {
                      if (v != _password.text) return 'Passwords do not match';
                      return AuthValidators.validatePasswordRegister(v);
                    },
                  ),
                  const SizedBox(height: 18),
                  CheckboxListTile(
                    value: _terms,
                    onChanged: (v) => setState(() => _terms = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('I accept the Terms of Service'),
                  ),
                  CheckboxListTile(
                    value: _privacy,
                    onChanged: (v) => setState(() => _privacy = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('I accept the Privacy Policy'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
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
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create account'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                                );
                              },
                        child: const Text('Sign in'),
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

/// Client-side validation only (Flutter). Does not change API or database rules.
/// Registration uses a professional-style password policy; login stays permissive
/// so existing web accounts with older passwords can still sign in.
class AuthValidators {
  AuthValidators._();

  static const int minPasswordLength = 8;

  static final RegExp _email = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );

  /// Letters, numbers, spaces, hyphen, apostrophe (reasonable display names).
  static final RegExp _nameChars = RegExp(r"^[\p{L}\p{M}\s'.-]+$", unicode: true);

  static String? validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter your email address';
    if (s.length > 254) return 'Email is too long';
    if (!_email.hasMatch(s)) return 'Enter a valid email address';
    return null;
  }

  /// Login: only ensure password was typed (server accepts existing passwords).
  static String? validatePasswordLogin(String? v) {
    if (v == null || v.isEmpty) return 'Enter your password';
    return null;
  }

  /// Registration: min 8 chars, upper, lower, digit, special (common enterprise pattern).
  static String? validatePasswordRegister(String? v) {
    if (v == null || v.isEmpty) return 'Choose a password';
    if (v.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(v)) {
      return 'Include at least one uppercase letter (A–Z)';
    }
    if (!RegExp(r'[a-z]').hasMatch(v)) {
      return 'Include at least one lowercase letter (a–z)';
    }
    if (!RegExp(r'[0-9]').hasMatch(v)) {
      return 'Include at least one number (0–9)';
    }
    if (!RegExp(r'''[!@#$%^&*()_+\-=\[\]{}|\\;:'",.<>/?`~]''').hasMatch(v)) {
      return 'Include at least one symbol (e.g. ! @ # \$ % & * …)';
    }
    if (v.length > 128) return 'Password is too long';
    return null;
  }

  static String? validateName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter your full name';
    if (s.length < 2) return 'Use at least 2 characters';
    if (s.length > 120) return 'Name is too long';
    if (!_nameChars.hasMatch(s)) {
      return 'Use letters, spaces, hyphens, or apostrophes only';
    }
    return null;
  }

  /// Optional contact: empty OK, else simple international-friendly check.
  static String? validateOptionalContact(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    final digits = RegExp(r'\d').allMatches(s).length;
    if (digits < 7) return 'Enter a valid phone number or leave blank';
    if (s.length > 40) return 'Contact is too long';
    return null;
  }

  /// Live rule checklist for the registration UI (not sent to server).
  static Map<String, bool> passwordRuleState(String password) {
    return <String, bool>{
      'len': password.length >= minPasswordLength,
      'upper': RegExp(r'[A-Z]').hasMatch(password),
      'lower': RegExp(r'[a-z]').hasMatch(password),
      'digit': RegExp(r'[0-9]').hasMatch(password),
      'symbol': RegExp(r'''[!@#$%^&*()_+\-=\[\]{}|\\;:'",.<>/?`~]''').hasMatch(password),
    };
  }
}

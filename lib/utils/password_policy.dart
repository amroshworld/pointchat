/// Client-side password rules (stricter than Appwrite minimum when possible).
class PasswordPolicy {
  PasswordPolicy._();

  static const int minLength = 10;

  /// Returns null if valid, otherwise a short user-facing message.
  static String? validate(String password) {
    if (password.length < minLength) {
      return 'Use at least $minLength characters.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Add at least one uppercase letter.';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Add at least one lowercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Add at least one number.';
    }
    if (!RegExp(r'[!@#$%^&*()_+\-=\[\]{};:\\|,.<>\/?]').hasMatch(password)) {
      return 'Add at least one symbol (e.g. ! @ #).';
    }
    return null;
  }
}

/// Client checks that mirror the server's, so most mistakes show before a
/// round trip; the server stays the authority (fe-guide auth module).
final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

bool looksLikeEmail(String value) => _email.hasMatch(value.trim());

/// BR-02, the regex `PasswordPolicy` uses: 8–64 characters with a lowercase
/// letter, an uppercase letter and a digit.
class PasswordRules {
  const PasswordRules(this.password);

  final String password;

  bool get length => password.length >= 8 && password.length <= 64;
  bool get lowercase => RegExp('[a-z]').hasMatch(password);
  bool get uppercase => RegExp('[A-Z]').hasMatch(password);
  bool get digit => RegExp(r'\d').hasMatch(password);
  bool get all => length && lowercase && uppercase && digit;
}

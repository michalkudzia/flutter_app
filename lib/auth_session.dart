class AuthSession {
  const AuthSession({
    required this.subject,
    required this.name,
    required this.email,
  });

  final String subject;
  final String name;
  final String? email;
}

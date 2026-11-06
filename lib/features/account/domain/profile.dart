import '../../../core/json/json_read.dart';

class Profile {
  const Profile({
    required this.email,
    required this.displayName,
    required this.notifyEmail,
    required this.notifyPush,
  });

  final String email;
  final String displayName;
  final bool notifyEmail;
  final bool notifyPush;

  Profile copyWith({bool? notifyEmail, bool? notifyPush}) => Profile(
    email: email,
    displayName: displayName,
    notifyEmail: notifyEmail ?? this.notifyEmail,
    notifyPush: notifyPush ?? this.notifyPush,
  );
}

Profile decodeProfile(Object? body) {
  final json = asJsonObject(body, 'profile');
  return Profile(
    email: readString(json, 'email'),
    displayName: readString(json, 'displayName'),
    notifyEmail: readBool(json, 'notifyEmail'),
    notifyPush: readBool(json, 'notifyPush'),
  );
}

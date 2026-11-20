import '../../../core/json/json_read.dart';

/// The trading style of the profile; the AI assistant explains things for
/// it (T-074). Null on a profile until the Trader chooses one.
enum TradingStyle {
  scalping('SCALPING'),
  day('DAY'),
  swing('SWING'),
  position('POSITION');

  const TradingStyle(this.wire);

  final String wire;
}

/// The risk profile of the profile (CONSERVATIVE until changed).
enum RiskProfile {
  conservative('CONSERVATIVE'),
  balanced('BALANCED'),
  aggressive('AGGRESSIVE');

  const RiskProfile(this.wire);

  final String wire;
}

class Profile {
  const Profile({
    required this.email,
    required this.displayName,
    required this.notifyEmail,
    required this.notifyPush,
    required this.riskProfile,
    this.tradingStyle,
  });

  final String email;
  final String displayName;
  final bool notifyEmail;
  final bool notifyPush;
  final TradingStyle? tradingStyle;
  final RiskProfile riskProfile;

  Profile copyWith({bool? notifyEmail, bool? notifyPush}) => Profile(
    email: email,
    displayName: displayName,
    notifyEmail: notifyEmail ?? this.notifyEmail,
    notifyPush: notifyPush ?? this.notifyPush,
    tradingStyle: tradingStyle,
    riskProfile: riskProfile,
  );
}

T _enum<T extends Enum>(List<T> values, String wire, String Function(T) of) {
  for (final value in values) {
    if (of(value) == wire) return value;
  }
  throw DecodeException('unknown value $wire');
}

Profile decodeProfile(Object? body) {
  final json = asJsonObject(body, 'profile');
  final style = readOptionalString(json, 'tradingStyle');
  return Profile(
    email: readString(json, 'email'),
    displayName: readString(json, 'displayName'),
    notifyEmail: readBool(json, 'notifyEmail'),
    notifyPush: readBool(json, 'notifyPush'),
    tradingStyle: style == null
        ? null
        : _enum(TradingStyle.values, style, (s) => s.wire),
    riskProfile: _enum(
      RiskProfile.values,
      readString(json, 'riskProfile'),
      (r) => r.wire,
    ),
  );
}

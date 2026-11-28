import 'package:intl/intl.dart';

import '../i18n/app_localizations.dart';
import 'api_failure.dart';

/// The text of an SRS 5.3 message code (D-25: the backend sends codes, the
/// client owns the words). [field] fills MSG01; [args] are `messageArgs`;
/// [extensions] are the other members of the body (MSG63).
String messageText(
  AppLocalizations l,
  String code, {
  List<String> args = const [],
  String? field,
  String? traceId,
  Map<String, String> extensions = const {},
}) {
  String arg(int i) => i < args.length ? args[i] : '';
  switch (code) {
    case 'MSG01':
      return l.msg01(field ?? '');
    case 'MSG02':
      return l.msg02;
    case 'MSG03':
      return l.msg03;
    case 'MSG07':
      return l.msg07;
    case 'MSG08':
      return l.msg08;
    case 'MSG09':
      return l.msg09(arg(0));
    case 'MSG10':
      return l.msg10(_status(l, arg(0)));
    case 'MSG11':
      return l.msg11;
    case 'MSG12':
      return l.msg12;
    case 'MSG13':
      return l.msg13;
    case 'MSG14':
      return l.msg14;
    case 'MSG15':
      return l.msg15(field ?? '', arg(0), arg(1));
    case 'MSG16':
      return l.msg16(arg(0), arg(1));
    case 'MSG18':
      return l.msg18;
    case 'MSG19':
      return l.msg19;
    case 'MSG20':
      return l.msg20;
    case 'MSG21':
      return l.msg21(arg(0), arg(1));
    case 'MSG25':
      return l.msg25(arg(0));
    case 'MSG26':
      return l.msg26(arg(0), arg(1));
    case 'MSG27':
      return l.msg27(arg(0), arg(1), arg(2));
    case 'MSG29':
      return l.msg29(arg(0));
    case 'MSG32':
      return l.msg32(arg(0));
    case 'MSG30':
      return l.msg30(arg(0));
    case 'MSG31':
      return l.msg31;
    case 'MSG51':
      return l.msg51(arg(0), arg(1), arg(2));
    case 'MSG52':
      return l.msg52(arg(0), arg(1));
    case 'MSG45':
      return l.msg45(arg(0));
    case 'MSG41':
      return l.msg41;
    case 'MSG44':
      return l.msg44;
    case 'MSG50':
      return l.msg50(arg(0));
    case 'MSG61':
      return l.msg61(arg(0));
    case 'MSG62':
      return l.msg62;
    // TRADING_PAUSED (D-159): 503 on every paper and plan write while the
    // market is not live.
    case 'MSG63':
      return l.msg63(
        extensions['market'] ?? arg(0),
        _since(l, extensions['since']),
        _state(l, extensions['state']),
      );
    case 'MSG64':
      return l.msg64;
    default:
      return l.msg43(traceId ?? l.errorUnknownReference);
  }
}

String _since(AppLocalizations l, String? since) {
  final at = since == null ? null : DateTime.tryParse(since);
  if (at == null) return l.errorUnknownReference;
  return DateFormat('d MMM HH:mm', 'en_US').format(at.toLocal());
}

String _state(AppLocalizations l, String? state) =>
    state == null || state.isEmpty
    ? l.errorUnknownReference
    : state.toLowerCase().replaceAll('_', ' ');

String _status(AppLocalizations l, String status) => switch (status) {
  'LOCKED' => l.statusLocked,
  'BANNED' => l.statusBanned,
  _ => status.toLowerCase(),
};

/// One line for a failed call, used where no field can carry it.
String failureText(AppLocalizations l, ApiFailure failure) {
  return switch (failure) {
    ProblemFailure(:final problem) => messageText(
      l,
      problem.messageCode,
      args: problem.messageArgs,
      traceId: problem.traceId,
      extensions: problem.extensions,
    ),
    NetworkFailure(:final timeout) => timeout ? l.errorTimeout : l.errorNetwork,
    SessionExpiredFailure() => l.msg44,
    UnexpectedFailure(:final traceId) => l.msg43(
      traceId ?? l.errorUnknownReference,
    ),
  };
}

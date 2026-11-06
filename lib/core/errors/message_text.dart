import '../i18n/app_localizations.dart';
import 'api_failure.dart';

/// The text of an SRS 5.3 message code (D-25: the backend sends codes, the
/// client owns the words). [field] fills MSG01; [args] are `messageArgs`.
String messageText(
  AppLocalizations l,
  String code, {
  List<String> args = const [],
  String? field,
  String? traceId,
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
    case 'MSG25':
      return l.msg25(arg(0));
    case 'MSG26':
      return l.msg26(arg(0), arg(1));
    case 'MSG27':
      return l.msg27(arg(0), arg(1), arg(2));
    case 'MSG29':
      return l.msg29(arg(0));
    case 'MSG45':
      return l.msg45(arg(0));
    case 'MSG41':
      return l.msg41;
    case 'MSG44':
      return l.msg44;
    case 'MSG50':
      return l.msg50(arg(0));
    default:
      return l.msg43(traceId ?? l.errorUnknownReference);
  }
}

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
    ),
    NetworkFailure(:final timeout) => timeout ? l.errorTimeout : l.errorNetwork,
    SessionExpiredFailure() => l.msg44,
    UnexpectedFailure(:final traceId) => l.msg43(
      traceId ?? l.errorUnknownReference,
    ),
  };
}

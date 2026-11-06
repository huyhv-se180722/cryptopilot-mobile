# CryptoPilot mobile

Flutter client of CryptoPilot (Android 8.0+, iOS 14+). Decision support and simulated
trading only: no real orders, no exchange keys, no funds.

## Run

```
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1   --dart-define=WS_URL=ws://10.0.2.2:8080/ws   --dart-define=WEB_BASE_URL=http://10.0.2.2:5173
```

The defaults above suit the Android emulator against a local backend and web client.
`WEB_BASE_URL` is where screens that exist only on the website open (register, profile,
subscription, the administration console). Release builds must pass
HTTPS / WSS addresses; plain HTTP is allowed in debug builds only.

## Check

```
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Copy lives in `lib/core/i18n/app_en.arb`; `flutter gen-l10n` (or any build) regenerates
`app_localizations*.dart`.

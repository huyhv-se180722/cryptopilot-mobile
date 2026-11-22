# CryptoPilot Mobile

Flutter client of **CryptoPilot**, a crypto decision-support and paper-trading app for Android
(8.0+, API 26) and iOS (13+).

> **Product boundary.** CryptoPilot never places real orders. There are no exchange API keys,
> no wallets, no deposits and no real funds, and nothing in the app is investment advice.
> Paper trading uses virtual funds only, and every paper screen says so ("Demo · virtual funds").

## Features

| Area | What the app does |
|---|---|
| Markets | Spot, Futures and Coins lists with live prices, market overview (dominance, Fear & Greed, altcoin season) |
| Watchlist and alerts | Grouped watchlists, price and indicator alerts, notifications |
| Analysis and chart | Candlestick chart (TradingView Lightweight Charts in a WebView), indicators, analysis score |
| Plans and journal | Trading plans with positions, journal entries, performance |
| Paper trading | Spot and Futures demo accounts: orders, positions, history, PnL, assets |
| AI assistant | Chat with market and portfolio context |
| Community | Posts, comments, member pages, follow and block |
| Academy | Lessons, beginner path, glossary |

Some screens (plan creation and editing, billing, administration) live only on the web client;
the app opens them in the browser.

## Tech stack

Flutter · Dart 3 · [Riverpod](https://riverpod.dev) (state) · [dio](https://pub.dev/packages/dio) (REST) ·
[go_router](https://pub.dev/packages/go_router) (navigation) ·
[stomp_dart_client](https://pub.dev/packages/stomp_dart_client) (realtime over WebSocket) ·
[decimal](https://pub.dev/packages/decimal) (money and prices) ·
[flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) (refresh token) ·
`webview_flutter` (chart) · `intl` / ARB (copy).

## Getting started

### Requirements

- Flutter **3.44.6** (stable), Dart **3.12+**
- Android Studio with the Android SDK and an emulator (or a device), JDK 17
- Xcode for iOS builds (macOS only)
- A running CryptoPilot backend (see [Backend](#backend))

### Install and run

```bash
git clone https://github.com/huyhv-se180722/cryptopilot-mobile.git
cd cryptopilot-mobile
git switch develop
flutter pub get
flutter run
```

`flutter run` (or any build) also generates `lib/core/i18n/app_localizations*.dart` from the ARB file.

### Configuration

Addresses are read at build time from `--dart-define`. The defaults suit a debug build on the
Android emulator, where the host machine is `10.0.2.2`.

| Key | Default | Purpose |
|---|---|---|
| `API_BASE_URL` | `http://10.0.2.2:8080/api/v1` | REST root, no trailing slash |
| `WS_URL` | `ws://10.0.2.2:8080/ws` | STOMP endpoint |
| `WEB_BASE_URL` | `http://10.0.2.2:5173` | Web client, for screens that exist only there |

```bash
flutter run \
  --dart-define=API_BASE_URL=http://192.168.1.10:8080/api/v1 \
  --dart-define=WS_URL=ws://192.168.1.10:8080/ws \
  --dart-define=WEB_BASE_URL=http://192.168.1.10:5173
```

Plain HTTP is allowed in debug builds only; **release builds must use HTTPS and WSS**.
Never put credentials in the code; pass them with `--dart-define` when a test needs them.

### Backend

The app talks to the CryptoPilot backend (Spring Boot, PostgreSQL, Redis). Run it locally from the
backend repository (`develop` branch) with its Docker Compose setup, then start the app against it.
Ask the team lead for a test account.

## Project structure

```
lib/
  main.dart, app.dart        entry point, app widget, cross-feature wiring
  core/                      shared code used by every feature
    auth/  http/  realtime/  session, dio client and interceptors, STOMP hub
    router/                  go_router routes and the bottom navigation
    theme/  widgets/         design tokens (light and dark) and shared widgets
    i18n/                    app_en.arb (all UI copy) and generated localizations
    format/  json/  errors/  number formats, JSON reading helpers, API failures
    config/  settings/  state/  media/  web/
  features/<feature>/        one folder per feature
    domain/                  plain Dart types and value objects
    data/                    API port (interface) + dio / STOMP adapter + repository
    application/             Riverpod controllers
    presentation/            screens and widgets
test/
  core/  features/           unit and widget tests, mirroring lib/
  support/                   fakes of the API ports and the realtime hub
  fixtures/                  reference data (TA-Lib indicator values)
integration_test/            runs on an emulator against a real backend
assets/                      brand images, chart page (Lightweight Charts)
```

## Architecture rules

- **Data flow:** Widget → Riverpod controller → API port (interface) → dio / STOMP adapter.
  Widgets and controllers never import dio or STOMP.
- **Decoding by hand:** adapters read `Object?` JSON and reject unexpected shapes; no code generation.
- **Money and prices are decimals** (`Decimal` or decimal strings), never `double`.
  Whole numbers are sent as `int`.
- **Features stay independent:** a feature may read another one way through its domain types,
  API port or controller (Market is the base the others read). Never use another feature's dio
  class; actions across features meet in `main.dart` or the router.
- **Only real contracts:** no invented endpoint, field or status; the backend `develop` branch is the reference.
- **Session:** access token in memory, refresh token in secure storage, one shared refresh.
- **UI:** every user-facing string goes in `lib/core/i18n/app_en.arb` (English); dates and chart
  axes use the app locale, not the device's; up is green and down is red, always with a sign;
  every screen works at **360 dp** wide, in light and dark themes.
- **New libraries** need the team's agreement before they are added.

## Checks

Run before every commit; all must pass:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test -j 2
```

`-j 2` keeps the test run within the memory of an 8 GB machine.

Integration tests run on an emulator against a running backend (not part of `flutter test`):

```bash
flutter test integration_test/real_backend_test.dart -d emulator-5554 \
  --dart-define=LOGIN_EMAIL=<test account> --dart-define=LOGIN_PASSWORD=<password>
```

Tests use the fakes in `test/support`; a new feature adds its fakes there.

## Contributing

### Branches

- `main`: releases · `develop`: integration branch, always green.
- Work on `feature/T-xxx-short-name`, `fix/T-xxx-short-name` or `chore/T-xxx-short-name`,
  branched from `develop` (`T-xxx` is the task id).
- Merge into `develop` with `git merge --no-ff`. Do not rebase or force-push shared branches;
  fix mistakes with a follow-up commit.

### Commits

[Conventional Commits](https://www.conventionalcommits.org), one logical change per commit,
each commit green on its own:

```
fix(paper): Spot confirm sheet hides the last order's snack bar

Why the change was needed and what it does, wrapped at 72 characters.

Refs: T-128 (D-142, TR-26)
```

Types: `feat`, `fix`, `refactor`, `test`, `perf`, `style`, `build`, `chore`, `revert`.
Scope: the feature (`market`, `paper`, `plans`, `auth`, `ui`, …).
Inside a feature, commit in layer order: domain → API port and adapter → controller → widgets →
screen and route → tests.

### Never commit

`.env`, keystores (`*.jks`, `*.keystore`), `android/key.properties`, `google-services.json`,
`local.properties`, `build/`, APK or AAB files, or any credential. Markdown files other than this
README stay local.

### Before asking for a merge

- The three checks above pass.
- New behaviour has unit or widget tests.
- The screen was checked at 360 dp in light and dark themes.
- Loading, empty, error and success states are handled.

## License

Proprietary. Internal use by the CryptoPilot team only.

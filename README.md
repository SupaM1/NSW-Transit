# NSW Transit

[![Build status](https://github.com/SupaM1/NSW-Transit/actions/workflows/CI.yml/badge.svg)](https://github.com/SupaM1/NSW-Transit/actions/workflows/CI.yml)
[![Latest release](https://img.shields.io/github/v/release/SupaM1/NSW-Transit)](https://github.com/SupaM1/NSW-Transit/releases/latest)
[![License: GPL v3](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android-brightgreen.svg)](https://github.com/SupaM1/NSW-Transit/releases)
[![Built with Flutter](https://img.shields.io/badge/built%20with-Flutter-02569B.svg)](https://flutter.dev)

## Why this exists

The official apps and most third-party alternatives are funded by ads or
quietly collect usage data. This app does neither:

- **No ads.** None, ever.
- **No account, no sign-up.**
- **No analytics, no tracking, no backend server of any kind.** The app
  talks directly from your device to Transport for NSW's own
  [Open Data API](https://opendata.transport.nsw.gov.au/). There is no
  server in between that could log, sell or leak your requests.
- **Your location never leaves your device** except as coordinates sent
  directly to Transport for NSW's API when you ask for nearby stops — it
  is never stored, even locally.
- **Open source**, so anyone can verify every claim above by reading the
  code.

See [PRIVACY.md](PRIVACY.md) for the full picture.

## Features

- 📍 **Nearby stops** — finds public transport stops close to your location, across any mode
- 🚌 **Live departures** — real-time departure times at each nearby stop
- 🎒 **School bus aware** — school bus services are badged separately and can be filtered out (or in) on their own
- 🔒 **Private by design** — no accounts, no tracking, no analytics; your API key stays on your device

## Getting started

NSW Transit needs a free Transport for NSW Open Data API key — you bring your own, nothing is bundled with the app.

1. Grab a free API key from the [Transport for NSW Open Data Hub](https://opendata.transport.nsw.gov.au/)
2. Install NSW Transit
3. On first launch and paste in your API key
4. That's it — the app stores the key locally via `shared_preferences` and talks directly to the TfNSW API

## Tech stack

- **Flutter (Dart)** — Android only for now
- **TfNSW Trip Planner API** — `coord` (nearby stops) and `departure_mon` (live departures) endpoints
- **`shared_preferences`** — local-only storage for your API key
- **GitHub Actions** — CI

## Building from source

```bash
flutter pub get
flutter run
# or, for a release APK:
flutter build apk
```
## [Roadmap](https://github.com/users/SupaM1/projects/2)

## Contributing

PRs are welcome, as long as they keep to the project's non-negotiables:

- No ads
- No telemetry or analytics
- No mandatory accounts
- No server in the middle that sees user data
- Open an issue first for anything bigger than a small fix, so we're aligned before you put the work in.

## Disclaimer

NSW Transit is an independent, community-built project. It is **not affiliated with, endorsed by, or supported by Transport for NSW**. Data is sourced from TfNSW's public Open Data API under their terms of use.

## License

GPL-3.0-or-later — see [LICENSE](LICENSE).

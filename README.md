# NSW Transit
# NSW Transit

[![Build status](https://github.com/SupaM1/NSW-Transit/actions/workflows/CI.yml/badge.svg)](https://github.com/SupaM1/NSW-Transit/actions/workflows/CI.yml)
[![Latest release](https://img.shields.io/github/v/release/SupaM1/NSW-Transit)](https://github.com/SupaM1/NSW-Transit/releases/latest)
[![License: GPL v3](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)

A free, open-source, ad-free public transport app for New South Wales,
Australia — covering trains, metro, buses, light rail, ferries, coaches
**and school bus services**.

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

## Features (current)

- Find public transport stops near your current location (any mode).
- See live, real-time departures at each nearby stop.
- School bus services are clearly identified with their own badge, and
  can be filtered to "school buses only".

## Requirements to run this app

Transport for NSW requires every application to use its own free API key
— this project does not and will not ship a shared key. You need to:

1. Register for a free key at
   [opendata.transport.nsw.gov.au](https://opendata.transport.nsw.gov.au/data/user/register)
   (no payment details required, takes about a minute, subscribe to the
   "Trip Planner APIs" product once registered).
2. Paste that key into the app on first launch (or later, in Settings).

Your key is stored only in this app's local storage on your device.

## Getting started (development)

This is a [Flutter](https://flutter.dev) app. **Android is the only
supported platform for now** — iOS and other platforms may be added later.
Android-specific in `lib/`.

```bash
flutter pub get
flutter run       # pick a connected Android device or emulator
flutter build apk # release build
```

## Architecture

- `lib/core/tfnsw_client.dart` — minimal HTTP client for the TfNSW Trip
  Planner API (`coord` for nearby stops, `departure_mon` for live
  departures). No other network calls exist anywhere in the app.
- `lib/core/transport_mode.dart` — maps the API's
  `transportation.product.class` code to a transport mode. Class `11` is
  Transport for NSW's own code for **School Bus** services (confirmed in
  the official Trip Planner API manual); `1` = Train, `4` = Light Rail,
  `5` = Bus, `7` = Coach, `9` = Ferry.
- `lib/core/settings_store.dart` — stores the user's API key in local
  device preferences (`shared_preferences`). Nothing else is persisted.
- `lib/screens/` — onboarding (API key entry), the nearby-departures
  screen, and settings.

## Roadmap

- **iOS.** Nothing in `lib/` is Android-specific — adding iOS later is
  just a matter of running `flutter create --platforms=ios .` to
  regenerate the platform folder and testing on a device/simulator
  (requires a Mac with Xcode).
- **Web — with a caveat.** Transport for NSW's Open Data API does not
  send CORS headers, so every browser blocks a web page from fetching it
  directly; this is a browser security rule, not a bug in this project.
  A web build would need requests routed through some kind of relay,
  which cuts against this project's "no backend, full stop" design. If
  it's ever added, it should be a stateless, non-logging CORS relay that
  people can self-host, kept clearly separate from the no-backend
  Android/iOS apps.
- Trip planning (A→B journeys) and saved favourite stops/routes.

## Known limitations

This is an early version — Android only, no trip planner, no saved
favourites yet (see [Roadmap](#roadmap)).

## Contributing

Issues and pull requests are welcome. Please keep to the project's core
constraints when contributing: no ads, no analytics/telemetry, no
mandatory accounts, and no backend server that sees user data.

## License

Licensed under the GNU General Public License v3.0 or later — see
[LICENSE](LICENSE). This keeps the project and any derivatives free and
open, including any app built from this code.

## Disclaimer

This is an independent, community project and is not affiliated with, or
endorsed by, Transport for NSW. Data is sourced from the TfNSW Open Data
Hub under its [data licence](https://opendata.transport.nsw.gov.au/datalicence).

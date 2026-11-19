# Privacy Policy

**Last updated:** 2026-11-19

NSW Transit is designed so there is as little to say here as possible.

## What this app collects

Nothing. This app has no backend server, no analytics SDK, and no
crash-reporting or usage-tracking library of any kind. The developer(s)
of this app never receive any information about you or your use of it.

## What stays on your device

- **Your Transport for NSW API key**, which you provide yourself, is
  stored in this app's local app storage (via the platform's standard
  preferences mechanism). It never leaves your device except as part of
  your own direct requests to Transport for NSW (see below).
- Nothing else is stored. There are no logs, no caches of your searches,
  and no history kept between sessions beyond your saved API key.

## What is sent over the network, and to whom

Every network request this app makes goes directly from your device to one
of two places:

**Transport for NSW's official Open Data API**
(`api.transport.nsw.gov.au`), using the API key you registered yourself.
The requests sent are:

- Your current GPS coordinates, to look up stops near you.
- A stop ID, to look up upcoming departures at that stop.
- Your API key, as required by Transport for NSW to authenticate the
  request.

Transport for NSW's handling of this data is governed by their own
[Privacy Policy](https://opendata.transport.nsw.gov.au/sites/default/files/2024-09/TfNSW-Privacy.pdf)
and [Open Data Portal Terms](https://opendata.transport.nsw.gov.au/sites/default/files/2024-09/TfNSW-Open-Data-Portal-Terms.pdf),
which this app's developer(s) do not control.

**OpenStreetMap's public map tile server** (`tile.openstreetmap.org`), to
draw the small map shown when you expand a stop. Only that stop's own
public location (its latitude/longitude, already published by Transport
for NSW) is sent — never your GPS position or your API key. See
[OpenStreetMap's Privacy Policy](https://osmfoundation.org/wiki/Privacy_Policy)
for how they handle these requests.

## Location permission

Location access is used only to find stops near you, at the moment you
ask for them. It is read directly from the operating system, used to
build a single API request, and discarded — this app does not store
location history.

## Advertising

There are no ads, no ad SDKs, and no third-party ad networks in this
app.

## Changes to this policy

Because this is an open-source project, any change to this policy — or
to the code's actual behaviour — is visible in the project's public
version history.

## Contact

This is a community project. For questions, open an issue on the
project's source code repository.

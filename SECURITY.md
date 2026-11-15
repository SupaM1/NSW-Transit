# Security Policy

NSW Transit has no backend server and no user accounts, which limits what
can go wrong — but like any app, it can still have bugs. This page
explains what's in and out of scope, and how to report something safely.

## Supported versions

Only the latest released version is supported. Please update before
reporting an issue, in case it's already been fixed.

## What's in scope

Examples of things worth reporting here:

- Your Transport for NSW API key being exposed, logged, or sent
  anywhere other than `api.transport.nsw.gov.au`.
- Your location being sent anywhere other than directly to Transport for
  NSW's API, or being stored anywhere on-device.
- A vulnerable dependency pulled in via `pubspec.yaml`.
- Anything that could let a malicious stop/departure response from the
  API corrupt data, crash the app, or otherwise be exploited.

## What's out of scope

- Issues with Transport for NSW's own API or servers — report those to
  Transport for NSW directly via
  [opendata.transport.nsw.gov.au](https://opendata.transport.nsw.gov.au/).
- General bugs with no security impact — please use a regular GitHub
  Issue for those instead.

## Reporting a vulnerability

Please **do not** open a public GitHub Issue for a security
vulnerability — that publicises it before a fix exists.

Instead, use GitHub's private vulnerability reporting:

1. Go to the **Security** tab of this repository.
2. Click **"Report a vulnerability"**.

This opens a private advisory visible only to the maintainer, so details
aren't exposed publicly until a fix is ready.

This is a solo, volunteer-maintained open-source project, so there's no
guaranteed response time — but reports will be taken seriously and
addressed as soon as practical.
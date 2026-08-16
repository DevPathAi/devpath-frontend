# Mobile companion release gates

The repository CI pins Flutter 3.44.1, verifies the checked-out source SHA and
workspace lock, runs the mobile contract suite, and emits unsigned Android plus
no-codesign iOS artifacts with SHA-256 manifests. It never reads signing
credentials and never publishes or deploys an app.

Production distribution remains fail-closed until all external evidence exists:

- Android upload/app-signing identity and an approved Play internal-track job.
- Apple team, provisioning profile, distribution certificate, and an approved
  TestFlight job on the same source and lock SHA.
- Hosted `assetlinks.json` and `apple-app-site-association` files for
  `app.devpath.ai`, verified on physical Android/iOS devices.
- VoiceOver and TalkBack evidence for Today, reading, stale/offline state, and a
  canonical task deep link.

Windows cannot satisfy the Xcode, iOS signing, or physical-device gates. Local
Android assembly additionally depends on an installed SDK, accepted licenses,
and command-line tools; CI is the canonical build environment.

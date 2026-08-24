# Mobile companion release gates

The repository CI pins Flutter 3.44.1, verifies the checked-out source SHA and
workspace lock, runs the mobile contract suite, and emits unsigned build
artifacts with SHA-256 manifests. The sealed Mission Spine release scope is
Android-only: only the protected signed APK enters candidate evidence. CI never
reads signing credentials and never publishes or deploys an app.

Production distribution remains fail-closed until all external evidence exists:

- Android upload/app-signing identity and an approved Play internal-track job.
- Hosted `assetlinks.json` for `app.leva.ai.kr`, verified on a physical Android
  device. Android Digital Asset Links proves the app/host relationship; the
  manifest supplies the path boundary. Android filters must expose only Today
  and Content. Sandbox, Review, Mentor and broad `/mission/*` association are
  release blockers.
- TalkBack evidence for Today, reading, stale/offline state, and a canonical
  task deep link.

Local Android assembly depends on an installed SDK, accepted licenses, and
command-line tools; CI is the canonical build environment.

## Android fail-closed URI envelope

Android cannot express the exact JavaScript-safe upper bound
`9007199254740991` in an intent-filter. Query and fragment rejection also
requires URI-relative filter groups introduced in API 35. Therefore the HTTPS
alias is disabled below API 35 and claims only positive IDs of at most 15
digits (`1` through `999999999999999`) on API 35 or newer. It denies every URI
with a query or fragment before evaluating the two allowed paths. Dart keeps
the full JavaScript-safe validation and does not relax its canonical parser.

This intentionally leaves valid 16-digit IDs and all links on older Android
versions in the browser. If product requirements later demand a broader OS
association, first provision a dedicated companion-only host with no web-only
routes; never broaden the `app.leva.ai.kr` host filter.

With an API 35+ device attached, the release candidate installed, and App Link
verification complete, collect real resolver evidence from `apps/mobile`:

```powershell
dart run tools/mobile_android_link_contract.dart --adb
adb shell pm get-app-links ai.devpath.devpath_mobile
```

The probe requires canonical Today and Content links to resolve to
`MissionLinkActivity`, while overflow IDs, query/fragment variants,
Sandbox/Mentor, and extra segments must not resolve to that alias. This device
evidence remains an external release gate; the source-only half runs in CI.

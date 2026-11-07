# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Spindle: a native macOS (13+) disc-to-library importer (today DVD / Blu-ray / HD DVD; music CDs,
TV episodes and photo discs are planned in `ROADMAP.md`), written in Swift with programmatic AppKit
(no SwiftUI, no storyboards). Built with SwiftPM. `AGENTS.md` is an older version of this file;
where they differ, this file is current.

## Commands

```bash
swift build                      # debug
swift build -c release
swift test                       # all tests (some show UI dialogs; see Testing)
swift test --filter UHDDetectionTests                  # one suite
swift test --filter UHDDetectionTests/testSomeCase     # one test
swiftlint lint
./deploy.sh                      # release build → ~/Applications/Spindle.app, codesign, launch
```

- **Use `deploy.sh` to run the app.** The `.xcodeproj` is stale/broken; don't use `xcodebuild`.
  `deploy.sh` signs with the Developer ID identity so TCC removable-volume grants survive
  rebuilds (ad-hoc signing re-prompts on every deploy).
- `deploy.sh` refuses to run while `makemkvcon` is active, because killing the app orphans its
  `makemkvcon` child mid-rip. Check `pgrep -x makemkvcon` before any `pkill`/deploy; only pass
  `--force` if the user says so.
- Build needs Homebrew `libdvdcss` and `libaacs`; `Package.swift` searches `/opt/homebrew/opt`
  and `/usr/local/opt` and links them via `unsafeFlags`.
- Blu-ray ripping needs MakeMKV installed (`/Applications/MakeMKV.app`); `MakeMKVInstaller`
  can download and replace an expired build. FFmpeg is resolved bundled →
  `~/Library/Application Support/Spindle/ffmpeg` → Homebrew → `$PATH`, preferring a
  native arm64 build. Releases don't bundle FFmpeg; the app downloads an Intel build from
  evermeet.cx if none is found.
- `.build` inside this iCloud-synced folder sometimes fails with "file was modified during the
  build". If that happens, pass `--scratch-path` pointing somewhere outside `~/Documents`.
- `run_phase1_tests.sh` runs a subset of tests with a 60s watchdog.
- CI: only `.github/workflows/release.yml` (tag `v*` → build, sign, notarize, release) is
  active. `ci.yml` and the other workflows are `*.disabled`, so nothing runs tests on push.

## Architecture

### Rip pipeline (spans many files)

1. **Detection**: `DriveDetector` listens for `NSWorkspace` mount/unmount notifications and calls
   `MainViewController` (delegate). Never poll `mountedVolumeURLs`, because each poll triggers a
   TCC prompt.
2. **Skip check**: `MainViewController.findCompletedRip` treats a disc as already ripped if
   (a) `PendingRoutingQueue` holds it, (b) `RipHistoryStore` has an entry whose `DiscIdentity`
   fingerprint matches **and** whose `ConversionQueue.settingsFingerprint` is unchanged, or
   (c) a legacy `rip_complete.json` exists. Holding ⌥ on insert forces a re-rip.
3. **Queue**: every rip goes through `ConversionQueue.addJob`. The `jobs` array is guarded by a
   *concurrent* `jobsQueue` (reads `sync`, writes `async(flags: .barrier)`, including any
   check-then-set of `isProcessing`). Each job makes a fresh `MediaRipper` (tracked in
   `activeRippers[jobId]`), connected through `QueueRipperDelegate` plus a `DispatchSemaphore`.
   The bridge only accepts the first `mediaRipperDidComplete` or `mediaRipperDidFail`, and
   `MediaRipper` reports failure exactly once, after retries (`withRetries`).
   - Phase 1 `.extracting` runs on the serial `extractionQueue` and ends when the disc is no
     longer needed. The queue then asks for an eject (`ConversionQueueEjectionDelegate`),
     clears `isProcessing`, and starts the next job's disc read.
   - Phase 2 `.converting` runs on the serial `encodingQueue` (`performEncodes`). It runs
     `MediaRipper.pendingEncodes` one at a time and moves each finished file from staging to
     the output dir; MakeMKV's files come in through `directOutputFiles`. Then
     `writeRipCompleteMarker` updates the registry and the breadcrumb. Phase 2 of one job
     overlaps phase 1 of the next, so UI handlers check `MainViewController.extractingJobId`
     before resetting the rip UI.
4. **Per-format rippers** (`MediaRipper` + `MediaRipper+*.swift`; `performRipping` switches on
   media type):
   - **DVD**: `DVDStructureParser` (IFO) → `DVDDecryptor` (libdvdcss on the raw `/dev/rdiskN`).
     Each title is decrypted at full drive speed into a local staging `.vob`. Unreadable
     sectors are retried one at a time, then zero-filled, up to `maxSkippedSectorsPerTitle`.
     Each title then becomes a `PendingEncode`, and `mediaRipperDidComplete` fires once all
     titles are on local disk.
     Reads start at the physical sector of the title's first VOB, not the IFO table's
     offset, and cover only the title's cells (`DVDStructureParser.cellLayout`).
     Interleaved cells (seamless branching, flag 0x04) are never merged: `readDVDTitle`
     walks them VOBU by VOBU through each nav pack's DSI `NEXT_VOBU` pointer
     (`vobuNavigation(navPack:)`), and `dvdEncodeArguments` adds `-dts_delta_threshold 1`
     to close the timestamp jumps at branch points. With `useMakeMKVForDVD` (off by
     default), `MediaRipper+DVDMakeMKV.swift` stages titles with makemkvcon instead.
     Finished DVD encodes are routed through `MediaRipper.routeAfterEncodes`.
   - **Blu-ray / UHD**: `MakeMKVBackend` drives `makemkvcon -r` (robot mode; parses
     `PRGV`/`MSG`/`DRV`/`TINFO` lines) and writes MKVs directly, with no ffmpeg phase. The
     libaacs path (`BluRayDecryptor`, `performBluRayRipping`) is a fallback only.
   - **HD DVD**: `MediaRipper+HDDVD.swift` plus `HDDVDStructureParser`, which is largely
     heuristic.
5. **Organization and routing**: `OutputOrganizer` and `SettingsManager` directory-format tokens
   build the output folder (Plex `Movie (Year)` naming when `plexName` is set; OMDb lookup lives
   in `MainViewController+OMDb.swift`). After a rip, `ContentRouter` uses
   `ContentTypeClassifier` (title durations) to move the folder into the Movies or TV root, or
   queues it in `PendingRoutingQueue` for `RoutingReviewWindowController`.
   `ContentRouter.recentMoves` maps a staging path to its routed path, so a later registry
   write records the final location.

### Invariants: don't break these

- **Encode to local staging, then move atomically.** The user's `~/Documents` (including default
  output folders, and this repo) is iCloud-synced and viewed from Windows. ffmpeg writes to
  `~/Library/Caches/Spindle/encoding/` (`encodingStagingPath`), and only finished files are
  moved into place. Never write partial output into a synced directory.
- **One process on the drive at a time.** UHD failures ("Failed to open disc", no output) come
  from drive contention (makemkvcon falls back to "OS access mode"), not from licensing. Never
  run `makemkvcon info` or any other drive scan while a rip is active. `MakeMKVBackend.rip`
  sleeps between enumeration and the rip, and retries once on an OS-access-mode open. macOS DVD
  Player auto-launching on insert also steals the device.
- **Release the device before ejecting.** `dvdDecryptor.closeDevice()` must run before the eject
  request, or the eject fails as busy.
- **Settings window tabs**: `NSTabViewItem.view` must be the scroll view itself. Wrapping it in
  a plain `NSView` gives zero-height blank tabs.

### Conventions

- Large types are split across `Type+Area.swift` extensions (`MainViewController+Delegates`,
  `+QueueTable`, `+FFmpeg`, `+Utilities`, `+OMDb`, `+Constraints`).
- App name, bundle ID and data folders come from `AppIdentity` (Application Support and
  Caches under `Spindle/`). The app was AutoRip2MKV until v2.2:
  `AppIdentity.migrateFromLegacyNameIfNeeded()` runs first in `main.swift` and copies the old
  `com.autorip2mkv.mac` defaults and moves `Application Support/AutoRip2MKV-Mac` once.
- Singletons: `SettingsManager.shared` (UserDefaults), `Logger.shared`, `RipHistoryStore.shared`,
  `PendingRoutingQueue.shared`, `DriveDetector.shared`, `ScriptRunner.shared` (pre/post hooks).
- Error enums conform to `LocalizedError` and implement `errorDescription`. Don't declare
  `var localizedDescription` on an `Error` type: `error.localizedDescription` never calls it.
- Subprocesses: read a stdout `Pipe` to EOF *before* `waitUntilExit()`, and send output you
  don't read to `FileHandle.nullDevice`. An unread pipe fills its 64KB buffer and blocks the
  child forever.
- Encoder args come from `videoEncoderArguments(for:)` and `audioEncoderArguments(for:)` in
  `MediaRipper+Conversion.swift`. They pick VideoToolbox when `hardwareAcceleration` is on
  and it can encode the request (H.264/HEVC, not lossless, Apple Silicon), and add
  `-strict -2` for DTS.
- `settingsFingerprint` decides whether a disc is re-ripped. Adding a key re-rips every
  earlier disc unless the key is only present when it's non-default.
- `DVDRipper` is legacy. It's never used to rip, but `MainViewController`'s `DVDRipperDelegate`
  methods are what many UI tests call. `DetailedSettingsWindowControllerNew` is a test-only
  stub. The live paths are `ConversionQueue` and `MediaRipper`.

## Testing

Tests are in `Tests/SpindleTests/`. App code detects XCTest via the
`XCTestConfigurationFilePath` env var (`TestingUtilities`) to suppress modal dialogs and file
panels, so new modal UI should go through those helpers or tests will hang.
`SettingsTabPreferenceFramework.swift` is a harness for checking Settings-tab bindings.
Pure parsers (`MakeMKVBackend.parseTitleDurations`, `extractBetaKey`, `DiscIdentity`,
`ContentTypeClassifier`) are the easiest things to cover with fixture strings.

## SwiftLint

`.swiftlint.yml`: line length 120 warn / 200 error; function body 50 / 100; type body 500 / 1000;
file length 500 / 1500. `force_unwrapping`, `function_parameter_count`, and `todo` are disabled.

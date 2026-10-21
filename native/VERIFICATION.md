# Verification — 15 October 2026

- AcademyMac: Debug build succeeds with Xcode 27.0.
- AcademyiOS: Debug simulator build succeeds; includes the lesson JSON, paper JSON, resources and compiled assets.
- AcademyCore: nine tests pass, including actual bundled JSON decoding, raw-weight arithmetic, gradient step, bond price, attention normalization, capital arithmetic, undo-safe merge, deterministic ties, earliest study start across devices, snapshot validation, review intervals, and pace with inactive days.
- Native sync service: local HTTP test passes for missing/wrong authentication, valid write, stale revision rejection, invalid record rejection and database restart persistence.
- Hosted Railway instance: health 200, unauthenticated read 401, authenticated read/write 200, service restart preserves a disposable test record; test record then removed. Daily volume backup schedule enabled; backup restore drill still pending. Verified resource ceilings: 0.1 vCPU and 250,000,000 bytes of memory.
- iPhone simulator launch: inspected during development. Content bundling and mixed-format paper prerequisites were corrected after smoke testing. A compiled-colour inspection exposed an alpha-format issue; components are now decimal-formatted to preserve opacity.
- iPad mini (A17 Pro, iOS 18.6) simulator: app launches with all content; Today screen and complete pace card visually inspected after temporary cache cleanup.
- iPhone 16 Pro (iOS 18.6) simulator: Today screen inspected in light and dark mode, including visible native tab selection. iPhone 17 Pro hardware remains to be tested.

## Remaining acceptance checks

- Physical iPhone 17 Pro and iPad mini installation using the owner's signing team.
- Tap-through testing of navigation, reading, bookmark restore, notes across background/relaunch, read/undo, papers and the six labs.
- VoiceOver, large accessibility text, Reduce Motion, light/dark and device orientation checks.
- Notification permission, schedule, delivery and cancellation on a physical device.
- Keychain pairing and end-to-end sync across two physical devices after Railway deployment, including offline edits and conflicting notes.
- iCloud shared-folder propagation across devices if that optional path is used.

A successful compile is not a claim that these remaining checks passed. The backend is deployed with authenticated read/write checks; physical multi-device pairing remains to be tested. No physical device was modified.

## Miko candidate — 2026-10-21

- Recovered native source and Git history from the preserved iCloud copy into a local checkout outside Desktop/Documents syncing.
- Xcode 27.1 iOS simulator Debug build: passed.
- macOS Release build: passed (before the subsequent shared image thumbnail adjustment; repeat for final candidate).
- AcademyCore: 12 tests passed, including motion bounds, reading frames and static Reduce Motion behaviour.
- iPhone Release build and embedded extension: passed. `codesign --verify --deep --strict` passed.
- Reading layout screenshot: tiny glasses-and-paws companion visible above the ledge, separate from the text surface.
- Existing iOS 18.6 simulator Live Activity: blank, including a temporary text-only control. Full companion source restored after that experiment. This does not establish a device pass or prove a simulator-only fault.
- Physical iPhone installation, Island rendering, tap-to-resume and session end remain release gates. This is an installation candidate, not an App Store production release.
- Personal Team provisioning remains time-limited. Check profile expiry when installing; never distribute this private signed bundle publicly.

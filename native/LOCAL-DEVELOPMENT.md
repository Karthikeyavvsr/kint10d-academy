# Stable local development

Keep the working checkout in `~/Projects/kint10d-academy`, outside iCloud Desktop and Documents. Build output belongs in a disposable local DerivedData directory; do not sync caches or provisioning profiles through Git.

The October recovery preserved the original cloud copy and recovered source, Git history and uncommitted Miko work. The old Documents project path is a local symlink to the new checkout. Open the new checkout in Xcode going forward; editing the cloud copy creates a separate version.

In macOS, local Documents and iCloud Drive/Documents can coexist when Desktop & Documents syncing is off. Optimize Mac Storage can leave cloud-only placeholders in iCloud Drive. A local development checkout avoids that dependency without changing system-wide iCloud preferences.

Use Git commits and push reviewed source regularly. Never commit pairing keys, signed app bundles, certificates, private deployment configuration or device IDs. A GitHub copy protects committed source; it does not back up device-local learning progress. Use Academy's progress export and configured sync for that.

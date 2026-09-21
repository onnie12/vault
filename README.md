# Vault

A personal, offline-first iPhone app that collects the documents Claude produces
(study guides, code, Linux fixes, images, PDFs, Word files), shows them in one
list, and sorts them into categories with deterministic keyword rules.

Single user, no server, no App Store, no AI inside the app.

The rules live in [CLAUDE.md](CLAUDE.md), the design of each subsystem in
[docs/superpowers/specs/](docs/superpowers/specs/). This file is the short
version for someone opening the repo.

## Status

Phase 0 (setup). See section 16 of CLAUDE.md for what the last session finished.

## Layout

```
project.yml            XcodeGen spec. The .xcodeproj is generated, never committed.
Vault/                 The app: SwiftUI, SwiftData, UIKit bridges.
VaultCore/             Local Swift package. Foundation only, so it tests on Linux.
VaultTests/            App-level unit tests, run in the simulator.
.github/workflows/     CI on GitHub's macOS runners.
docs/superpowers/      Design specs (one per subsystem) and implementation plans.
Fixtures/              Synthetic test files only, never real documents.
```

`VaultCore` holds all the pure logic: the classifier, the front matter parser, the
Claude export reader, the GitHub diff, file naming. It must not import SwiftUI,
SwiftData, UIKit, WebKit or CryptoKit, otherwise it stops building on Linux.

## Building

There is no Mac in this setup, so CI does the compiling. Every push builds the app,
runs both test suites and uploads an unsigned `Vault.ipa` as a workflow artifact.

On a Mac with Xcode 27:

```sh
brew install xcodegen
xcodegen generate
open Vault.xcodeproj
```

On Linux, with a Swift toolchain installed, the package alone:

```sh
swift test --package-path VaultCore
```

## Installing on the iPhone

Signed with a free Apple ID (Personal Team), so the signature expires after
**7 days** and the app has to be installed again. Reinstalling over the existing
app keeps its data. Deleting the app deletes all of it, which is why the backup
feature in Phase 6 exists.

Route chosen: a borrowed or rented Mac, connected by cable. Steps are in
`docs/superpowers/specs/2026-09-21-build-ci-install-design.md`.

## Two constraints worth knowing up front

1. **Vault never touches claude.ai automatically.** Scraping it or driving it with a
   script breaks Anthropic's Consumer Terms, section 3. Documents get in by sharing
   them from the Claude app, pasting them, syncing a private GitHub repo, or importing
   the official Claude data export. Details in CLAUDE.md section 4.
2. **No paid Apple Developer Program.** That rules out App Groups, iCloud, push
   notifications, background refresh and share extensions. The design works around
   all of them. Details in CLAUDE.md section 3.1.

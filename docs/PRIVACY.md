# Privacy Policy

**English** · [繁體中文](PRIVACY.zh-Hant.md) · [简体中文](PRIVACY.zh-Hans.md)

_Last updated: 2026-10-26_

DiskLens is a disk-space analyzer that runs entirely on your Mac. This policy explains what data it touches and where that data goes. Short version: **DiskLens collects nothing and sends nothing anywhere.** The only exception is the optional AI feature: you have to switch it on yourself, and if you pick a command-line AI tool instead of Apple's on-device model, it hands a small amount of file metadata to that tool.

## What DiskLens reads

- **File-system metadata** for the folders you scan: names, paths, sizes, modification dates and item counts. DiskLens does **not** open or read the contents of your files.
- **Installed apps' `Info.plist`** (name, bundle identifier, icon), so it can show which app a folder belongs to.
- **Volume information** (capacity, free and purgeable space) and the list of local Time Machine snapshots.

With Full Disk Access granted, DiskLens can read metadata in folders macOS otherwise protects (Mail, Messages, Safari and so on). Access is only used to measure sizes.

## What DiskLens stores

Everything stays on your Mac:

- Scan results live in memory while the app is open.
- Settings (for example your AI provider choice and the date you gave consent) are stored in the app's preferences (`~/Library/Preferences/tw.ncse.disklens.plist`).
- If you use the AI feature, its answers are cached in `~/Library/Application Support/DiskLens/` so the same question isn't asked twice. You can clear this cache in Settings.

## What DiskLens sends

**Nothing.** DiskLens has no analytics, telemetry, crash reporting, accounts, ads or update server, and it makes no network requests of its own.

### Optional AI feature

If you choose to use "Ask AI", you pick one of these providers. Before the first request to a provider, DiskLens shows a consent screen naming it and previewing the exact text it will send.

- **Apple's on-device model** (Apple Intelligence; the only option in the Mac App Store version). The request is processed on your Mac by Apple's built-in model and **nothing is sent over the network**.
- **An AI command-line tool that you installed and signed in to** (for example Claude Code, Codex, Antigravity or opencode; direct-download version only). The rest of this section applies to these tools.

- **What is sent to that tool:** paths and names of the items you selected, their sizes, dates and item counts, the names of a few of the largest items inside a selected folder, and DiskLens's own classification. **File contents are never sent.**
- **Where it goes:** the tool forwards that text to its vendor (for example Anthropic, OpenAI or Google) under **your** account. That vendor processes it under its own privacy policy and terms, and the request may count towards your plan's usage.
- **What the tool can do:** DiskLens starts it in a read-only, no-tools mode inside an empty temporary folder. The answer is only displayed. It never deletes, moves or changes anything.
- You can revoke consent or turn the feature off at any time in **Settings → AI**.

## Deleting files

DiskLens only moves items to the Trash after you confirm, and it refuses to touch protected system locations. Items stay recoverable until you empty the Trash.

## Children

DiskLens is a general-purpose utility, collects no personal data and is not directed at children.

## Changes

Changes to this policy are published in this repository, and the date at the top is updated.

## Contact

Questions? Open an issue at <https://github.com/PGpenguin72/DiskLens/issues>.

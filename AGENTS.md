# AGENTS.md

Guidance for AI coding agents (Claude Code, Codex, Antigravity, Cursor…) and human contributors working on Ringwise. Read this before you change code.

## What this is

Ringwise is a native macOS disk-space analyzer: a fast full-disk scanner, a sunburst chart, analysis views (apps, file types, cleanup rules) and optional AI explanations. SwiftUI, Liquid Glass design, macOS 26+, Apple Silicon and Intel.

There are two builds from one codebase:

| Build | Distribution | Sandbox | AI providers | Compile flag |
|---|---|---|---|---|
| Direct | GitHub / notarized DMG | no | Apple on-device + local CLIs (claude, codex, agy, opencode, gemini) | — |
| App Store | Mac App Store | yes | Apple on-device only | `APP_STORE` |

## Commands

```bash
swift build                                                   # debug build (direct)
swift build -Xswiftc -DAPP_STORE --build-path .build-appstore # App Store configuration
swift test                                                    # unit tests (RingwiseCore)
swift run -c release ringwise-bench /                         # scanner benchmark
./scripts/build-app.sh                                        # dist/Ringwise.app (ad-hoc signed)
xcodegen generate                                             # Ringwise.xcodeproj for signed / App Store builds
```

**Both configurations must compile with zero warnings, and `swift test` must pass, before you commit.**

## Layout

```
Sources/RingwiseCore/        UI-free logic, unit-tested
  Scanner.swift, ScanEngine.swift, BulkDirectoryReader.swift   parallel getattrlistbulk scanner
  FileTree.swift (+Analysis)  struct-of-arrays tree (4–5M nodes on a real disk)
  AppCatalog / AppAttribution / FileCategorizer / CleanupRules  analysis passes (<100 ms each on /)
  FileActions.swift           trash/move + protection rules (never deletes permanently)
  AI/                         prompt builder, response parser, cache, providers
                              (CLI providers are #if !APP_STORE)
  UserHome.swift              real home folder (NSHomeDirectory() is the container inside the sandbox)
Sources/Ringwise/            SwiftUI app
  Model/AppModel.swift        @MainActor @Observable central state; FileTree is @ObservationIgnored,
                              bump `revision` after mutating it
  Model/AnalysisStore.swift   runs analyses off the main actor after each scan
  Model/AIAssistant.swift     provider detection, consent, requests
  Views/                      Theme.swift has the palette, AmbientBackground, .glassCard(), StatChip
  Support/ScanAccess.swift    security-scoped bookmarks (App Store build)
  Resources/Localizable.xcstrings   String Catalog, source language zh-Hant
Sources/ringwise-bench/      scanner benchmark CLI
Packaging/                   Info.plist, entitlements, PrivacyInfo.xcprivacy, AppIcon asset catalog
project.yml                  XcodeGen spec: targets Ringwise and Ringwise-AppStore
docs/                        privacy policy, terms, translating, App Store checklist
```

## Rules that bit us

1. **Table cells must not read `@Environment(AppModel.self)`.** macOS `Table` cells are hosted separately and the lookup crashes (assertion in `EnvironmentValues`). Pass plain values and closures into cell views (see `NameCell`).
2. **Don't put `.fixedSize(horizontal: false, vertical: true)` text next to a `Spacer` inside an `HStack` with buttons.** It sent SwiftUI's layout into a loop that left the *whole window* blank. Use `.lineLimit(n)` and `.frame(maxWidth: .infinity, alignment: .leading)`.
3. **Performance:** never walk the whole tree on the main thread, and never call `children()` per row in a body for huge folders. Whole-tree passes go over the internal arrays in Core. Search is parallel with an ASCII fast path; keep it under ~50 ms for 4.6M names.
4. **Table width:** NSTableView adds ~17 pt per column. Give non-name columns fixed widths and check the default 1180 pt window for horizontal overflow.
5. **App Store build:** no `Process` / shell / private API. Read user files only under granted bookmarks (`ScanAccess`). Use `UserHome.path`, not `NSHomeDirectory()`, for user-file paths.
6. **AI:** never send file contents. CLIs run with `Process.arguments` (never a shell string), in an empty temp dir, in read-only/no-tools modes. AI answers are display-only and never trigger actions. Consent is required per provider.
7. **Deletion** goes only through `requestTrash` → confirmation → `FileActions.trash`, which honours protection rules. Nothing is ever deleted permanently.

## Style

- Match the surrounding code: concise, doc comments on types and non-obvious members, sparse inline comments.
- Design language is Liquid Glass: `.glassCard()`, `.glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass / .glassProminent)`, colors from `Theme.palette`. Tables use `.scrollContentBackground(.hidden)`, `.alternatingRowBackgrounds(.disabled)` and `.overlayScrollers()`.
- **Localization:** write UI text as Traditional Chinese literals (`Text("…")`, `Button("…")`, `String(localized: "…")`). Building with Xcode syncs them into `Localizable.xcstrings`; add zh-Hans and en translations there. Use whole sentences with interpolation, not concatenated fragments. **RingwiseCore has no user-facing text:** it returns reason codes and errors (`ProtectionReason`, `AIUnavailableReason`, `AIError`), and the app turns them into text in `Model/CoreMessages.swift`. If Xcode's build doesn't sync the catalog, build both schemes and run `xcrun xcstringstool sync Localizable.xcstrings --stringsdata <DerivedData>/**/*.stringsdata`. Other languages come from Crowdin (see `docs/TRANSLATING.md`).

## Testing the UI without disturbing the user

The app has environment hooks for automated checks:

| Variable | Effect |
|---|---|
| `RINGWISE_SELFTEST=<path>` | headless scan + analysis summary, then exit |
| `RINGWISE_AUTOSCAN=<path>` | start scanning on launch (skips onboarding) |
| `RINGWISE_AUTOOPEN=<path>` | open a folder after the scan |
| `RINGWISE_SIDEBAR=apps\|fileTypes\|cleanup\|largeFiles` | open a view |
| `RINGWISE_DEMO_MULTISELECT=1` | multi-select mode with 3 rows selected |
| `RINGWISE_DEMO_AI=consent\|results\|settings\|noprovider` | show AI sheets (`RINGWISE_DEMO_AI_PROVIDER=apple`) |
| `RINGWISE_DEMO_ONBOARDING=1` | show the tour |
| `RINGWISE_DEMO_ABOUT=1` | open the About window |
| `RINGWISE_SETTINGS_PANE=general\|ai\|feedback\|about` | open Settings on that tab |
| `RINGWISE_FAKE_NO_FDA=1` | pretend Full Disk Access is missing |
| `RINGWISE_AI_SELFTEST=<path>` (+ `_RUN=<provider>`) | headless AI prompt / live run |

To screenshot: launch `.build/release/Ringwise` in the background, find its window by **your own PID** with `CGWindowListCopyWindowInfo`, then `screencapture -x -o -l <windowid>`.

- **Never** post synthetic mouse or keyboard events (CGEvent, System Events). They land in whatever app the user is using.
- **Never** quit or kill processes you didn't start, including an installed `/Applications/Ringwise.app`.
- **Never** trash or move real files in tests; use a temp directory.

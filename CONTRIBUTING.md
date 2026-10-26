# Contributing to DiskLens

Thanks for helping! Bug reports, ideas, translations and pull requests are all welcome. 中文的 issue 和 PR 也非常歡迎。

## Reporting bugs

Open an [issue](https://github.com/PGpenguin72/DiskLens/issues/new/choose) and include:

- your macOS version and Mac model (Apple Silicon or Intel);
- whether you use the App Store or the direct-download build;
- what you did, what you expected, and what happened;
- for crashes, the crash report from Console.app (**Crash Reports › DiskLens**).

Please don't paste full scan results or file lists that reveal private information.

## Development setup

You need Xcode 26 or later on macOS 26 or later.

```bash
git clone https://github.com/PGpenguin72/DiskLens.git
cd DiskLens
swift build && swift test
./scripts/build-app.sh && open dist/DiskLens.app
```

Read [AGENTS.md](AGENTS.md) before changing code. It explains the architecture, the two build configurations (direct and App Store), and a few rules learned the hard way.

## Pull requests

1. Fork, then create a branch from `main`.
2. Keep changes focused; one feature or fix per PR.
3. Before pushing, make sure all of these succeed:
   ```bash
   swift build
   swift build -Xswiftc -DAPP_STORE --build-path .build-appstore
   swift test
   ```
4. Write UI text in Traditional Chinese literals, and add the zh-Hans and en translations to `Sources/DiskLens/Resources/Localizable.xcstrings` (Xcode adds the keys when you build). Translations for other languages come from Crowdin, so don't edit those by hand.
5. Describe what changed and how you tested it. For UI changes, include a screenshot.

### Ground rules

- **Never delete permanently.** File removal goes through the Trash, after confirmation, and must honour `FileActions.protection`.
- **Privacy:** no analytics, telemetry or network requests from the app itself. AI requests must never include file contents and always require consent.
- **App Store compatibility:** code in the App Store configuration can't spawn processes or use private APIs.
- **Performance:** a real disk has around 5 million nodes. Keep whole-tree work off the main thread and fast.

## Translations

See [docs/TRANSLATING.md](docs/TRANSLATING.md). Translations happen on Crowdin, where both human and AI-assisted translation are welcome.

## Code of conduct

Be kind and constructive. Harassment or discrimination of any kind isn't tolerated.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).

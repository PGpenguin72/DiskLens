# Translating Ringwise

Ringwise is written in Traditional Chinese (Taiwan) and ships in three languages:

| Language | Code | Maintained by |
|---|---|---|
| Traditional Chinese (source) | `zh-Hant` | the developers, in the source code |
| Simplified Chinese (Mainland) | `zh-Hans` | the developers, in the repo |
| English | `en` | the developers, in the repo |

Every other language comes from volunteers (and, until a volunteer arrives, machine translation) on **Crowdin**: <https://crowdin.com/project/ringwise>.

All UI text lives in a single [String Catalog](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog): `Sources/Ringwise/Resources/Localizable.xcstrings`. The keys are the original Traditional Chinese strings.

## Translating on Crowdin

1. Open <https://crowdin.com/project/ringwise> and sign in (GitHub, Google or e-mail).
2. Pick your language. If it is not listed, ask for it with **Request a new language** on the project page or in a GitHub issue.
3. Translate in the Crowdin editor. Some tips:
   - The source text is Traditional Chinese. Crowdin shows the English translation next to it; translating from English is fine.
   - Keep placeholders exactly: `%@` (text), `%lld` (number), and numbered forms like `%1$@`, `%2$lld`. You may reorder numbered placeholders.
   - Strings with numbers have **plural forms** (one, few, many, other… depending on your language). Fill in every form Crowdin shows.
   - Keep `⌘`, `⌫`, `esc` and product names (Ringwise, Finder, Apple Intelligence, Xcode, Homebrew…) as they are, unless your language has an official Apple name (for example, Finder is “访达” in Simplified Chinese). Use Apple's own terminology for your language where possible: see [Apple's localization glossaries](https://developer.apple.com/download/all/?q=glossary) (Apple Developer account required).
   - Prefer short labels. Buttons, table headers and sidebar items have limited room.
4. Strings marked as machine-translated are first drafts. Proofreading them (approve or fix) is as valuable as translating new ones.

Translations are synced back to GitHub automatically as a pull request, and released with the next version of Ringwise.

## For maintainers: setting up Crowdin

### 1. Create the project

1. Create a Crowdin account and apply for the free [open-source plan](https://crowdin.com/page/open-source-project-setup-request) (public GitHub repo with an OSI license; Ringwise is MIT).
2. **Create project** → name `Ringwise`, public visibility, so the URL is `crowdin.com/project/ringwise`.
3. Source language: **Chinese Traditional** (`zh-TW`). Target languages: at least **Chinese Simplified** and **English**, plus any languages you want to open.
4. `crowdin.yml` maps Crowdin's `zh-TW` / `zh-CN` to the app's `zh-Hant` / `zh-Hans`. After the first download PR, check that the catalog contains `zh-Hant` / `zh-Hans`, not `zh-TW` / `zh-CN`. If not, set the same mapping under **Project settings › Languages › Language mapping**.

### 2. Connect GitHub (secrets)

The workflow `.github/workflows/crowdin.yml` uses the official [`crowdin/github-action`](https://github.com/crowdin/github-action) and the Crowdin CLI config in `crowdin.yml` (the String Catalog is uploaded as a multilingual file). It does nothing until two repository secrets exist:

| Secret | Where to find it |
|---|---|
| `CROWDIN_PROJECT_ID` | Crowdin project › **Tools › API** (numeric project ID) |
| `CROWDIN_PERSONAL_TOKEN` | Crowdin › account **Settings › API › New token** (scope: Projects) |

Add them in GitHub › **Settings › Secrets and variables › Actions**. Then allow the workflow to open pull requests: **Settings › Actions › General › Workflow permissions** → *Read and write permissions* and *Allow GitHub Actions to create and approve pull requests*.

What the workflow does:

- **Push to `main` that changes the catalog** → uploads new and changed source strings.
- **Every Monday, or Actions › Crowdin › Run workflow** → uploads sources, downloads all translations and opens or updates the PR `Update translations from Crowdin` from the branch `l10n_crowdin_translations`.
- **First sync:** run the workflow by hand with *Also upload the translations already in the repo* checked, so the existing zh-Hans and en translations are imported instead of being treated as untranslated.

> Crowdin's GitHub integration (Crowdin › Integrations › GitHub) is an alternative to the workflow. Use one or the other, not both.

### 3. Machine / AI pre-translation for new languages

For a language without a human translator yet, let Crowdin pre-fill it so the language is usable right away:

1. Crowdin project › **Settings › Machine translation**: enable an engine (Crowdin Translate, DeepL, Google…) or **Crowdin AI** with a provider of your choice (AI › Providers). For AI, add a short prompt such as: *“macOS disk-space analyzer. Use Apple's macOS terminology for this language. Keep %@, %lld and numbered placeholders. Keep labels short.”*
2. **Pre-translation** (Translations › Pre-translation, or *Settings › Automation › Pre-translate new strings*): choose **via MT** or **via AI**, select the new languages and the catalog file. Leave *Auto-approve* off so the results stay unapproved.
3. Recommend human proofreading: mark the language as needing proofreaders on the project page, and don't advertise it as complete until someone has approved the strings. Pre-translated strings are visibly marked in the editor, so volunteers can review them later.

When a downloaded translation is in the catalog, the app still needs to know the language exists, see below.

## Adding a new language to the app

1. Make sure the language's translations are in `Localizable.xcstrings` (merge the Crowdin PR, or add it in Xcode's catalog editor).
2. Add the language code to `CFBundleLocalizations` in **both**
   - `Packaging/Info.plist` (Xcode / App Store builds), and
   - the Info.plist heredoc and the `for lang in …` check in `scripts/build-app.sh`.
3. Build: `./scripts/build-app.sh` (compiles one `<code>.lproj` per language into `dist/Ringwise.app`), or `xcodegen generate` and build in Xcode.
4. Check it headlessly:

   ```bash
   RINGWISE_L10N_SELFTEST=1 dist/Ringwise.app/Contents/MacOS/Ringwise -AppleLanguages '(ja)'
   ```

   The output lists the localization macOS picked and a few translated strings (sidebar, a plural, a cleanup rule, the AI consent title). AI answers automatically use the same language.

5. Run the app with `-AppleLanguages '(ja)'` and look for clipped text in tables, chips, the sidebar card and the selection bar.

## For developers: adding or changing strings

- Write UI text as Traditional Chinese literals: `Text("…")`, `Button("…")`, `Label("…", systemImage:)`, `.help("…")`. For text built in code (`String` properties, errors, enums), use `String(localized: "…")`; a plain `String` passed to `Text` is shown as-is and never translated.
- Use whole sentences with interpolation (`String(localized: "要將 \(count) 個項目丟到垃圾桶嗎？")`), never concatenated fragments.
- `RingwiseCore` has no user-facing text: it returns enums (`ProtectionReason`, `AIUnavailableReason`, `AIError`), and the app localizes them in `Sources/Ringwise/Model/CoreMessages.swift`.
- Building in the Xcode IDE adds new keys to the catalog automatically. From the command line, build with `xcodebuild` (both schemes) and merge the extracted keys:

  ```bash
  xcrun xcstringstool sync Sources/Ringwise/Resources/Localizable.xcstrings \
      --stringsdata <each .stringsdata file under .build-xcode/Build/Intermediates.noindex/Ringwise*.build>
  ```

- Add the zh-Hans and en translations (including English plural forms for `%lld`) before you commit; Crowdin picks up everything else.

## 繁體中文說明

Ringwise 以繁體中文（台灣）撰寫，內建繁體中文、簡體中文與英文。其他語言透過 Crowdin 由社群翻譯：<https://crowdin.com/project/ringwise>。

- **想幫忙翻譯：** 到 Crowdin 專案頁登入，選擇語言後即可翻譯或校對。請保留 `%@`、`%lld`、`%1$@` 等佔位符，有數字的字串要填寫每一種複數形式。標示為機器翻譯的字串需要人工校對。
- **維護者：** 依上方〈For maintainers〉在 Crowdin 建立開源專案（來源語言選「Chinese Traditional」），把 `CROWDIN_PROJECT_ID` 與 `CROWDIN_PERSONAL_TOKEN` 加到 GitHub repository secrets；之後修改字串目錄並推送到 `main` 會自動上傳，翻譯會每週以 pull request 送回。還沒有譯者的新語言可以先開啟 Crowdin 的機器翻譯／AI 預先翻譯，但建議仍由真人校對。
- **新增語言：** 把語言代碼加進 `Packaging/Info.plist` 與 `scripts/build-app.sh` 的 `CFBundleLocalizations`，重新建置後用 `RINGWISE_L10N_SELFTEST=1 … -AppleLanguages '(語言代碼)'` 檢查。
- **開發者：** 介面文字直接寫繁體中文字面值（`Text("…")`、`String(localized: "…")`），用完整句子加插值，不要拼接片段；新增字串後請同時補上簡體中文與英文翻譯。

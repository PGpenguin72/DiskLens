# App Store submission guide (for an AI agent operating the browser and Xcode)

This guide takes Ringwise from "developer account ready" to "submitted for review". It is written for an AI agent (for example Codex with browser control) working alongside the account owner. Follow the steps in order. Store listing text, review notes and the privacy answers live in [`docs/APP_STORE.md`](APP_STORE.md); copy from there instead of writing new text.

## Facts

| Item | Value |
|---|---|
| App Store name | **PG Ringwise** (shown in the app as "Ringwise"; fallback if taken: `PG Ringwise – Disk Space`) |
| Bundle ID | `tw.pg72.ringwise` |
| SKU | `ringwise-macos` |
| Platform | macOS 26 or later; universal (Apple Silicon + Intel) |
| Primary language | Traditional Chinese (zh-Hant); also Simplified Chinese and English |
| Category | Utilities (secondary: Productivity) |
| Price | Free |
| Xcode project | generate with `xcodegen generate`; scheme **Ringwise-AppStore** (sandboxed, `APP_STORE` flag) |
| Version / build | `MARKETING_VERSION` 0.2.0; `CURRENT_PROJECT_VERSION` must increase on every upload |
| Support URL | https://github.com/PGpenguin72/Ringwise/issues |
| Marketing URL | https://github.com/PGpenguin72/Ringwise |
| Privacy policy URL | https://github.com/PGpenguin72/Ringwise/blob/main/docs/PRIVACY.md |
| Contact email | developer@pg72.tw |

## Rules for the agent

**Stop and hand control to the account owner** whenever a step involves any of the following. Tell them exactly what is on screen and wait:

- signing in to an Apple ID, two-factor codes, passwords, passkeys;
- accepting, agreeing to, or signing **any** agreement, terms or license (Program License Agreement, Free/Paid Apps agreements, export compliance declarations under penalty);
- tax forms, banking information, contact details of legal entities, or anything involving money;
- legal attestations (for example "I confirm…" checkboxes about content rights, encryption or advertising identifiers), unless the answer is stated in this guide **and** the owner has confirmed it.

Other rules:

- Don't create additional apps, bundle IDs, certificates or profiles beyond those listed here.
- Don't change the price, territories or release settings beyond what this guide says.
- Don't submit for review until the owner explicitly says "submit".
- If something on screen differs from this guide (Apple changes these pages often), describe it to the owner instead of guessing.

## Step 1: Check the account (browser)

1. Open https://developer.apple.com/account. 🧑 The owner signs in.
2. Under **Membership details**, read the **Team ID** (10 characters, for example `AB12CD34EF`). Write it down; Xcode needs it.
3. Open https://appstoreconnect.apple.com → **Business** (sometimes shown as "Agreements, Tax, and Banking").
   - The **Free Apps** agreement must show as Active. Ringwise is free, so the Paid Apps agreement and tax/banking are **not** required.
   - 🧑 If any agreement is waiting for acceptance, stop and let the owner read and accept it.

## Step 2: Register the bundle ID (browser)

1. Open https://developer.apple.com/account/resources/identifiers/list. Click **+**.
2. Choose **App IDs** → Continue → type **App** → Continue.
3. Description: `Ringwise`. Bundle ID: **Explicit**, `tw.pg72.ringwise`.
4. Capabilities: leave everything unchecked. (App Sandbox and user-selected file access are entitlements, not App ID capabilities.)
5. Continue → Register.
6. If Apple says the bundle ID is already registered **to this team**, that's fine; continue. If it's registered to another team, stop and tell the owner.

## Step 3: Create the app record (browser)

1. App Store Connect → **Apps** → **+** → **New App**.
2. Fill in:
   - Platforms: **macOS**
   - Name: `PG Ringwise` (if Apple says the name is taken, use `PG Ringwise – Disk Space`, and tell the owner)
   - Primary language: **Chinese (Traditional)**
   - Bundle ID: `tw.pg72.ringwise`
   - SKU: `ringwise-macos`
   - User access: **Full Access**
3. Create.

## Step 4: Fill in the listing (browser)

Use the exact text in [`docs/APP_STORE.md`](APP_STORE.md) under "App Store 頁面文字".

1. **App Information**:
   - Subtitle (Traditional Chinese): `一圈一圈，看清你的磁碟`
   - Category: Utilities. Secondary: Productivity.
   - Content rights: "Does not contain, show, or access third-party content" → 🧑 confirm with the owner, then select.
   - Age rating: answer **None / No** to every question → 4+.
   - Add localizations **Chinese (Simplified)** and **English (U.S.)** and fill each one's name, subtitle and description from `APP_STORE.md`.
2. **Pricing and Availability**: Price **Free (USD 0)**; territories: all (default).
3. **App Privacy**:
   - Privacy Policy URL: see Facts.
   - Data collection: **"No, we do not collect data from this app."** (Ringwise has no analytics or networking. The App Store build's AI uses Apple's on-device model only. Feedback emails are sent by the user from their own mail app and aren't collected by the app.) 🧑 Confirm with the owner before publishing the answers.
4. **macOS app → version 0.2.0** page:
   - Promotional text, description and keywords from `APP_STORE.md` (per language).
   - Support URL and Marketing URL: see Facts.
   - Copyright: `2026 PGpenguin72`
   - **Screenshots**: 1 to 10 images, each exactly 2880×1800, 2560×1600, 1440×900 or 1280×800 pixels. If none exist yet, stop and ask the owner. Claude can generate them from the app with a demo folder so no personal file names appear.
   - App Review Information: contact name, email `developer@pg72.tw` and phone (🧑 the owner provides the phone number). "Sign-in required": **No**. Notes: paste the English review notes from `APP_STORE.md`.
   - Version release: **Manually release this version**.

## Step 5: Build and upload (terminal + Xcode)

Run these in the repo on the owner's Mac (`~/Developer/Ringwise`).

1. 🧑 The owner adds their Apple ID in **Xcode › Settings › Accounts** (sign-in happens there).
2. Put the Team ID from Step 1 into `project.yml` (`DEVELOPMENT_TEAM: "<TEAM_ID>"`) and set a build number higher than any previous upload (`CURRENT_PROJECT_VERSION`). Then:
   ```bash
   brew list xcodegen >/dev/null || brew install xcodegen
   xcodegen generate
   swift test
   xcodebuild -project Ringwise.xcodeproj -scheme Ringwise-AppStore -configuration Release \
     -destination 'generic/platform=macOS' -archivePath build/Ringwise-AppStore.xcarchive \
     -allowProvisioningUpdates archive
   ```
   `-allowProvisioningUpdates` lets Xcode create the Apple Distribution certificate and the App Store profile automatically, using the account added in Xcode. If it asks for keychain access, 🧑 the owner approves it.
3. Upload. Either:
   - **Xcode**: Window › Organizer › select the archive › **Distribute App** › **App Store Connect** › **Upload** (defaults); or
   - **Terminal**: create `build/ExportOptions.plist` with `method` = `app-store-connect`, `destination` = `upload`, `teamID` = the Team ID, then
     ```bash
     xcodebuild -exportArchive -archivePath build/Ringwise-AppStore.xcarchive \
       -exportOptionsPlist build/ExportOptions.plist -allowProvisioningUpdates
     ```
4. Encryption: `Info.plist` already declares `ITSAppUsesNonExemptEncryption = NO`, so no export compliance questions should appear. If they do, 🧑 the owner answers ("No / uses only exempt encryption").
5. Wait for processing (an email arrives, usually 5–30 minutes). In App Store Connect → the app → **TestFlight**, the build appears as "Ready to Submit" or "Ready to Test".

Do **not** commit the Team ID change unless the owner wants it public. A Team ID isn't secret, but it's their choice.

## Step 6: Test before submitting (owner)

🧑 Ask the owner to install the build from TestFlight (or run the archived app) and check:

- The first full-disk scan asks to select "Macintosh HD", and the scan works; after reopening, it doesn't ask again.
- Move to Trash works on a test file.
- "問 AI" works with Apple Intelligence on, and shows a clear message when it's off.

## Step 7: Submit (only when the owner says so)

1. App Store Connect → the app → macOS version 0.2.0 → **Build** → select the uploaded build.
2. Check that every required field shows no warnings.
3. 🧑 When the owner says "submit": **Add for Review** → **Submit to App Review**.
4. Review usually takes 1–3 days. If Apple sends questions or a rejection, copy the full message to the owner (and to Claude/Codex in the repo) instead of replying on your own.

## If something goes wrong

| Problem | What to do |
|---|---|
| Name already in use | Use the fallback name; tell the owner. |
| "No profiles for 'tw.pg72.ringwise' were found" | Make sure Step 2 is done and the Xcode account belongs to the same team; rerun with `-allowProvisioningUpdates`. |
| Upload rejected: build number already used | Increase `CURRENT_PROJECT_VERSION`, regenerate, archive again. |
| Invalid binary / missing icon / privacy manifest errors | Copy the exact error to the owner; the repo has `Packaging/Assets.xcassets` and `Packaging/PrivacyInfo.xcprivacy`, so report it rather than editing project files blindly. |
| Review asks about the method swizzle in `OverlayScrollers.swift` | It only changes scroll bar style. Tell the owner; Claude can remove it for the App Store build. |

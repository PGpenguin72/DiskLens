<div align="center">

<img src="Packaging/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="Ringwise 圖示">

# Ringwise

**一圈一圈，看清你的磁碟。**
快速、原生、開源的 macOS 磁碟空間分析工具，採用 Liquid Glass 介面。

[English](README.md) · **繁體中文** · [简体中文](README.zh-Hans.md)

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black)
![Apple Silicon & Intel](https://img.shields.io/badge/Apple%20Silicon%20%26%20Intel-supported-success)

</div>

## 功能

- **快速掃描整顆磁碟**：用 `getattrlistbulk` 多執行緒平行掃描，約 20 秒讀完 460 萬個檔案，介面全程不卡頓。
- **環狀圖**：三層環狀圖一眼看出目前資料夾的組成。滑鼠移上去看細節，點一下進入資料夾，點中心回上一層。顏色和表格、圖例互相對應。
- **分析視角**：
  - **App**：每個 App 實際佔多少空間，包含 App 本體、資料、快取、容器，還能找出已移除 App 的殘留檔。
  - **檔案類型**：影片、照片、磁碟映像、壓縮檔、開發快取等等。
  - **可清理項目**：依規則找出可以清的東西（App 快取、Xcode DerivedData、模擬器、npm/pnpm 快取、久沒用的 `node_modules`、舊安裝檔⋯⋯），每一項都標示安全程度。
  - **大檔案**清單，以及在全部檔案中即時**搜尋**。
- **設計上就很安全**：只有在你確認後才會把項目移到垃圾桶，受保護的系統位置無法刪除。
- **多選模式**：單擊就能一次選很多個，底部的玻璃操作列會顯示可以釋放多少空間。
- **問 AI（選用）**：「這是什麼？能刪嗎？」
  - 可以使用 Apple 裝置端模型，或你本來就在用的 AI CLI（Claude Code、Codex、Antigravity、opencode）。
  - 只送出名稱、路徑、大小、日期，絕不送出檔案內容，而且一定會先經過你明確同意。
- **多語系**：支援繁體中文、簡體中文、英文。歡迎透過 [Crowdin](docs/TRANSLATING.md) 協助翻譯其他語言。
- **重視隱私**：沒有分析、沒有遙測，App 本身不發出任何網路連線。詳見[隱私權政策](docs/PRIVACY.zh-Hant.md)。

## 系統需求

- macOS 26（Tahoe）以上
- Apple Silicon 或 Intel Mac

## 安裝

- **Mac App Store**：即將上架。
- **直接下載**：到 [Releases](https://github.com/PGpenguin72/Ringwise/releases) 下載 DMG，把 Ringwise 拖進「應用程式」。
- 想看到完整結果，請到 **系統設定 › 隱私權與安全性 › 完整磁碟取用權限** 開啟 Ringwise。

App Store 版有沙盒限制，第一次掃描整顆磁碟時會請你選擇「Macintosh HD」；AI 功能只使用 Apple 裝置端模型。

## 從原始碼建置

```bash
git clone https://github.com/PGpenguin72/Ringwise.git
cd Ringwise
swift build                 # 建置
swift test                  # 執行測試
./scripts/build-app.sh      # 產生 dist/Ringwise.app
open dist/Ringwise.app
```

需要簽章的版本（Developer ID 或 App Store），請用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 產生 Xcode 專案：

```bash
brew install xcodegen
xcodegen generate
open Ringwise.xcodeproj     # scheme：Ringwise（直接下載版）、Ringwise-AppStore
```

需要 Xcode 26 以上。

## AI 功能如何運作

1. 選取項目後按「問 AI」（或按右鍵 › 問 AI）。
2. 第一次使用時，Ringwise 會告訴你要執行哪個工具，並讓你預覽實際會送出的文字。你按下「同意」之前，什麼都不會發生。
3. 工具會在一個空的暫存資料夾裡，以唯讀、不能使用任何工具的模式執行。回答會附上安全程度標示，並快取在本機。

支援的工具：

- **Apple 裝置端模型**（Apple Intelligence）：離線、免費、隱私。
- [Claude Code](https://claude.com/claude-code)、[Codex](https://github.com/openai/codex)、Antigravity（`agy`）、[opencode](https://opencode.ai)、Gemini CLI：僅限直接下載版，使用你自己在該廠商的帳號。

## 參與貢獻

歡迎開 issue 和 pull request，請先閱讀 [CONTRIBUTING.md](CONTRIBUTING.md)。如果你使用 AI 寫程式工具，請讓它讀 [AGENTS.md](AGENTS.md)。想協助翻譯，請見 [docs/TRANSLATING.md](docs/TRANSLATING.md)。

## 授權

[MIT](LICENSE) © 2026 PGpenguin72 · [隱私權政策](docs/PRIVACY.zh-Hant.md) · [使用條款](docs/TERMS.zh-Hant.md)

Ringwise 是獨立專案，與 Apple、Anthropic、OpenAI、Google 沒有任何關聯。

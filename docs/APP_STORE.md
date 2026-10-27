# 上架 Mac App Store 指南

這份文件整理了把 DiskLens 送上 Mac App Store 需要的所有步驟和文字。標 🧑 的步驟必須用你自己的 Apple 開發者帳號操作。

## 已經準備好的部分

| 項目 | 位置 |
|---|---|
| Xcode 專案設定（App Store 版 `DiskLens-AppStore` 與直接下載版 `DiskLens`） | `project.yml`（執行 `xcodegen generate` 產生） |
| 沙盒權限（使用者選取檔案讀寫、security-scoped bookmark） | `Packaging/DiskLensAppStore.entitlements` |
| 隱私清單（不追蹤、不收集資料，並寫明讀取 API 的理由） | `Packaging/PrivacyInfo.xcprivacy` |
| App 圖示 | `Packaging/Assets.xcassets/AppIcon.appiconset` |
| Info.plist（類別：工具程式、無加密聲明） | `Packaging/Info.plist` |
| App Store 版只用 Apple 裝置端 AI，不執行任何外部程式 | `APP_STORE` 編譯旗標 |
| 隱私權政策、使用條款網址 | `docs/PRIVACY.md`、`docs/TERMS.md`（GitHub 上的公開網址） |

## 上架步驟

1. 🧑 **完成 Apple Developer Program 的簽約與付款**，確認帳號狀態是 Active。
2. 🧑 **在 Xcode 登入帳號**：Xcode › Settings › Accounts › 加入你的 Apple ID。
3. **產生專案**：在專案資料夾執行
   ```bash
   brew install xcodegen   # 已安裝可略過
   xcodegen generate
   open DiskLens.xcodeproj
   ```
4. 🧑 **設定簽章**：選 target `DiskLens-AppStore` › Signing & Capabilities › Team 選你的團隊。Xcode 會自動產生憑證和描述檔。（也可以把 Team ID 填到 `project.yml` 的 `DEVELOPMENT_TEAM`，之後重新產生專案就不用每次手動選。）
5. 🧑 **確認 Bundle ID**：預設是 `tw.ncse.disklens`。如果你想用自己的網域，改 `project.yml` 的 `PRODUCT_BUNDLE_IDENTIFIER`。Bundle ID 一旦用在上架的 App 上就不能再改。
6. 🧑 **在 App Store Connect 建立 App**（<https://appstoreconnect.apple.com> › 我的 App › ＋）：
   - 平台：macOS
   - 名稱：`DiskLens`（若已被使用，可改用「DiskLens – 磁碟空間分析」之類的名稱）
   - 主要語言：繁體中文
   - Bundle ID：選第 5 步的那個
   - SKU：例如 `disklens-macos`
7. 🧑 **封存並上傳**：Xcode 上方的 scheme 選 `DiskLens-AppStore`，目的地選 `Any Mac`，然後 Product › Archive › Distribute App › App Store Connect › Upload。
8. 🧑 **填寫 App 資訊**：把下面的文字貼到 App Store Connect，上傳截圖，選價格（免費），隱私權問卷依下方回答。
9. 🧑 **送審**。

## 審核前要自己檢查的事

- [ ] 用 App Store 版實際跑一次：第一次「掃描整個磁碟」會跳出授權視窗，選 Macintosh HD 後能正常掃描；重開 App 後不用再授權。
- [ ] 丟到垃圾桶在沙盒中能正常運作（只能動到已授權範圍內的檔案）。
- [ ] 沒有開啟 Apple Intelligence 的 Mac 上，AI 功能會顯示清楚的說明，而且不會當掉。
- [ ] 截圖：至少 1 張，建議 3–5 張，尺寸 2880×1800 或 1440×900。截圖中不要出現私人檔名。
- [ ] `OverlayScrollerStyle`（讓表格捲軸變成浮動式）用到 Objective-C runtime 替換方法實作。這不是私有 API，但如果審核提出疑問，可以在 App Store 版拿掉，改回系統預設捲軸。

## 隱私權問卷（App Privacy）

- 你或第三方合作夥伴會從這個 App 收集資料嗎？→ **不會（Data Not Collected）**
- 理由：DiskLens 沒有網路功能、分析或追蹤；App Store 版的 AI 只用 Apple 裝置端模型，資料不會離開裝置。

## 年齡分級

所有問題都回答「無」，分級為 4+。

## 加密

`ITSAppUsesNonExemptEncryption = NO`（已寫在 Info.plist，不用額外填寫出口合規文件）。

---

## App Store 頁面文字

### 繁體中文（主要語言）

**名稱**：DiskLens
**副標題（30 字內）**：看見磁碟空間都跑去哪了
**宣傳文字**：全新 Liquid Glass 設計。幾十秒掃完整顆磁碟，用環狀圖一眼找出最佔空間的檔案。
**關鍵字**：磁碟,空間,清理,儲存空間,大檔案,快取,分析,容量,垃圾,DaisyDisk

**描述**：

```
DiskLens 幫你在幾十秒內掃完整顆磁碟，用漂亮的環狀圖一眼看出空間都跑去哪了。

【快速又流暢】
• 多執行緒掃描，數百萬個檔案也只要幾十秒
• 介面全程不卡頓，十萬個檔案的資料夾也能順暢捲動

【看得懂的視覺化】
• 三層環狀圖：滑鼠移上去看細節，點一下就進入資料夾
• 顏色和表格、圖例互相對應，比較大小一目了然

【幫你找出可以清的東西】
• App：每個 App 實際佔多少，包含資料和快取，還能找出已移除 App 的殘留檔
• 檔案類型：影片、照片、磁碟映像、開發快取⋯⋯
• 可清理項目：依規則找出快取和舊檔案，並標示是否安全
• 大檔案清單與即時搜尋

【AI 小幫手】
看不懂某個檔案是什麼？請 Apple 裝置端模型說明它是什麼、能不能刪。完全在你的 Mac 上處理，不會上傳任何資料，而且一定會先徵求你的同意。

【安全第一】
• 只會把項目移到垃圾桶，清空前都能復原
• 系統重要檔案受保護，無法刪除
• 只讀取檔案名稱、大小和日期，不讀取檔案內容

【重視隱私】
沒有分析、沒有追蹤、沒有帳號。DiskLens 是開源軟體（MIT 授權）。

需要 macOS 26 以上。
```

### 简体中文

**名称**：DiskLens
**副标题**：看见磁盘空间都去哪了
**推广文本**：全新 Liquid Glass 设计。几十秒扫完整个磁盘，用环形图一眼找出最占空间的文件。
**关键词**：磁盘,空间,清理,存储空间,大文件,缓存,分析,容量,垃圾,DaisyDisk

**描述**：

```
DiskLens 帮你在几十秒内扫完整个磁盘，用漂亮的环形图一眼看出空间都去哪了。

【快速又流畅】
• 多线程扫描，数百万个文件也只要几十秒
• 界面全程不卡顿，十万个文件的文件夹也能顺畅滚动

【看得懂的可视化】
• 三层环形图：鼠标移上去看细节，点一下就进入文件夹
• 颜色和表格、图例相互对应，比较大小一目了然

【帮你找出可以清理的内容】
• 应用：每个应用实际占多少，包括数据和缓存，还能找出已删除应用的残留文件
• 文件类型：视频、照片、磁盘映像、开发缓存……
• 可清理项目：按规则找出缓存和旧文件，并标明是否安全
• 大文件列表与即时搜索

【AI 小助手】
看不懂某个文件是什么？请 Apple 设备端模型说明它是什么、能不能删。完全在你的 Mac 上处理，不会上传任何数据，而且一定会先征求你的同意。

【安全第一】
• 只会把项目移到废纸篓，清倒前都能恢复
• 系统重要文件受保护，无法删除
• 只读取文件名称、大小和日期，不读取文件内容

【重视隐私】
没有分析、没有跟踪、没有账号。DiskLens 是开源软件（MIT 许可证）。

需要 macOS 26 或更高版本。
```

### English

**Name**: DiskLens
**Subtitle**: See where your space went
**Promotional text**: All-new Liquid Glass design. Scan your entire disk in seconds and spot the biggest space hogs at a glance.
**Keywords**: disk,space,cleaner,storage,analyzer,large files,cache,usage,cleanup,DaisyDisk

**Description**:

```
DiskLens scans your entire disk in seconds and shows where your space went in a beautiful sunburst chart.

FAST AND SMOOTH
• Multithreaded scanning handles millions of files in seconds
• The interface never freezes, and even folders with 100,000 items scroll smoothly

VISUALS YOU CAN READ
• Three-ring sunburst: hover for details, click to drill into a folder
• Colors match the table and legend, so comparing sizes is instant

FIND WHAT YOU CAN CLEAN
• Apps: what each app really takes, including data and caches, plus leftovers from apps you already removed
• File types: video, photos, disk images, developer caches…
• Cleanup: rule-based suggestions for caches and old files, each with a safety level
• Large files list and instant search

AI HELPER
Not sure what something is? Ask Apple's on-device model what it is and whether it's safe to delete. Everything is processed on your Mac, nothing is uploaded, and DiskLens always asks for your consent first.

SAFE BY DESIGN
• Items only go to the Trash, so you can restore them until you empty it
• Important system files are protected
• Only file names, sizes and dates are read, never file contents

PRIVATE
No analytics, no tracking, no accounts. DiskLens is open source (MIT License).

Requires macOS 26 or later.
```

### 網址（三種語言共用）

- 支援網址：`https://github.com/PGpenguin72/DiskLens/issues`（聯絡信箱：developer@pg72.tw）
- 行銷網址：`https://github.com/PGpenguin72/DiskLens`
- 隱私權政策網址：`https://github.com/PGpenguin72/DiskLens/blob/main/docs/PRIVACY.md`

## 給審核人員的備註（App Review Information › Notes）

```
DiskLens is a disk-space analyzer. It is sandboxed: to scan the whole disk, the user selects "Macintosh HD" in the standard open panel the first time; access is remembered with a security-scoped bookmark. To test quickly, you can also choose "選擇資料夾…" (Choose Folder…) and pick any folder.

Deleting only moves items to the Trash after confirmation; protected system locations are refused.

The optional "問 AI" (Ask AI) feature uses Apple's on-device Foundation Models only. It sends nothing over the network and asks for consent first. On Macs without Apple Intelligence it shows an explanation instead.

No account or login is required. The app makes no network requests.
```

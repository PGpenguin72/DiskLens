<div align="center">

<img src="Packaging/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="DiskLens 图标">

# DiskLens

**几秒内看出磁盘空间都去哪了。**
快速、原生、开源的 macOS 磁盘空间分析工具，采用 Liquid Glass 界面。

[English](README.md) · [繁體中文](README.zh-Hant.md) · **简体中文**

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black)
![Apple Silicon & Intel](https://img.shields.io/badge/Apple%20Silicon%20%26%20Intel-supported-success)

</div>

## 功能

- **快速扫描整个磁盘**：用 `getattrlistbulk` 多线程并行扫描，约 20 秒读完 460 万个文件，界面全程不卡顿。
- **环形图**：三层环形图一眼看出当前文件夹的组成。鼠标移上去看细节，点一下进入文件夹，点中心返回上一层。颜色和表格、图例相互对应。
- **分析视角**：
  - **应用**：每个应用实际占多少空间，包括应用本体、数据、缓存、容器，还能找出已删除应用的残留文件。
  - **文件类型**：视频、照片、磁盘映像、压缩包、开发缓存等等。
  - **可清理项目**：按规则找出可以清理的内容（应用缓存、Xcode DerivedData、模拟器、npm/pnpm 缓存、长期未用的 `node_modules`、旧安装包……），每一项都标明安全程度。
  - **大文件**列表，以及在所有文件中即时**搜索**。
- **设计上就很安全**：只有在你确认后才会把项目移到废纸篓，受保护的系统位置无法删除。
- **多选模式**：单击即可一次选中多个项目，底部的玻璃操作栏会显示可以释放多少空间。
- **问 AI（可选）**：“这是什么？能删吗？”
  - 可以使用 Apple 设备端模型，或你本来就在用的 AI CLI（Claude Code、Codex、Antigravity、opencode）。
  - 只发送名称、路径、大小、日期，绝不发送文件内容，而且一定会先经过你明确同意。
- **多语言**：支持繁体中文、简体中文、英文。欢迎通过 [Crowdin](docs/TRANSLATING.md) 协助翻译其他语言。
- **重视隐私**：没有分析、没有遥测，应用本身不发起任何网络连接。详见[隐私政策](docs/PRIVACY.zh-Hans.md)。

## 系统要求

- macOS 26（Tahoe）或更高版本
- Apple Silicon 或 Intel Mac

## 安装

- **Mac App Store**：即将上架。
- **直接下载**：在 [Releases](https://github.com/PGpenguin72/DiskLens/releases) 下载 DMG，把 DiskLens 拖进“应用程序”。
- 想看到完整结果，请在 **系统设置 › 隐私与安全性 › 完全磁盘访问权限** 中开启 DiskLens。

App Store 版有沙盒限制，第一次扫描整个磁盘时会请你选择“Macintosh HD”；AI 功能只使用 Apple 设备端模型。

## 从源码构建

```bash
git clone https://github.com/PGpenguin72/DiskLens.git
cd DiskLens
swift build                 # 构建
swift test                  # 运行测试
./scripts/build-app.sh      # 生成 dist/DiskLens.app
open dist/DiskLens.app
```

需要签名的版本（Developer ID 或 App Store），请用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 生成 Xcode 项目：

```bash
brew install xcodegen
xcodegen generate
open DiskLens.xcodeproj     # scheme：DiskLens（直接下载版）、DiskLens-AppStore
```

需要 Xcode 26 或更高版本。

## AI 功能如何工作

1. 选中项目后点“问 AI”（或右键 › 问 AI）。
2. 第一次使用时，DiskLens 会告诉你要运行哪个工具，并让你预览实际会发送的文字。你点“同意”之前，什么都不会发生。
3. 工具会在一个空的临时文件夹里，以只读、不能使用任何工具的模式运行。回答会附上安全程度标识，并缓存在本机。

支持的工具：

- **Apple 设备端模型**（Apple Intelligence）：离线、免费、私密。
- [Claude Code](https://claude.com/claude-code)、[Codex](https://github.com/openai/codex)、Antigravity（`agy`）、[opencode](https://opencode.ai)、Gemini CLI：仅限直接下载版，使用你自己在该厂商的账号。

## 参与贡献

欢迎提 issue 和 pull request，请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。如果你使用 AI 编程工具，请让它阅读 [AGENTS.md](AGENTS.md)。想协助翻译，请见 [docs/TRANSLATING.md](docs/TRANSLATING.md)。

## 许可证

[MIT](LICENSE) © 2026 PGpenguin72 · [隐私政策](docs/PRIVACY.zh-Hans.md) · [使用条款](docs/TERMS.zh-Hans.md)

DiskLens 是独立项目，与 Apple、Anthropic、OpenAI、Google 没有任何关联。

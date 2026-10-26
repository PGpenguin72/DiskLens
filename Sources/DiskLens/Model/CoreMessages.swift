import Foundation
import DiskLensCore

/// Localized text for DiskLensCore's reason codes and errors.
///
/// DiskLensCore has no user-facing strings (and no string catalog): it reports enums, and the app
/// turns them into text here, so every translation lives in the app's `Localizable.xcstrings`.

extension ProtectionReason {
    var message: String {
        switch self {
        case .essentialFolder: String(localized: "這是系統或使用者的重要資料夾，不能整個刪除。")
        case .systemFile: String(localized: "macOS 系統檔案受保護，無法刪除。")
        case .systemLevel: String(localized: "這是系統層級的檔案，刪除可能影響其他 App 或需要管理員權限。")
        case .appData: String(localized: "這是 App 的資料。刪除後該 App 可能需要重新設定或登入。")
        }
    }
}

extension AIUnavailableReason {
    var message: String {
        switch self {
        case .deviceNotEligible: String(localized: "這台 Mac 不支援 Apple Intelligence。")
        case .appleIntelligenceNotEnabled: String(localized: "Apple Intelligence 尚未開啟。請到「系統設定」>「Apple Intelligence 與 Siri」開啟後再試。")
        case .modelNotReady: String(localized: "Apple 的裝置端模型還在下載或準備中，請稍後再試。")
        case .modelUnavailable: String(localized: "Apple 的裝置端模型目前無法使用。")
        case .unsupportedOS: String(localized: "這個版本的 macOS 不提供 Apple 裝置端模型。")
        case .unsupportedLanguage: String(localized: "Apple 的裝置端模型尚不支援目前的語言。")
        }
    }
}

extension AIError {
    var message: String {
        switch self {
        case .notLoggedIn(let tool, let command):
            String(localized: "\(tool) 尚未登入。請先打開「終端機」執行一次 \(command) 並完成登入，再回來重試。")
        case .timedOut(let seconds):
            String(localized: "等了 \(seconds) 秒仍沒有回應，已停止。可以在設定中調長逾時時間後重試。")
        case .failed(let message):
            String(localized: "AI 工具回報錯誤：\(message)")
        case .exitStatus(let status):
            String(localized: "AI 工具回報錯誤：結束代碼 \(Int(status))")
        case .noOutput:
            String(localized: "AI 工具回報錯誤：沒有任何輸出")
        case .refused:
            String(localized: "Apple 的模型拒絕回答這個請求。")
        case .busy:
            String(localized: "模型正忙，請稍後再試。")
        case .unparsable:
            String(localized: "看不懂 AI 的回答格式，請重試一次。")
        case .unavailable(let reason):
            reason.message
        case .contextTooLarge:
            String(localized: "這次的內容超過模型能處理的長度。請少選幾個項目後再試。")
        case .launchFailed(let message):
            String(localized: "無法啟動 AI 工具：\(message)")
        }
    }
}

/// Text for an error shown in the UI: Core errors are localized here, system errors already are.
func userMessage(for error: Error) -> String {
    switch error {
    case let error as AIError: error.message
    case let error as ProtectedItemError: error.reason.message
    default: error.localizedDescription
    }
}

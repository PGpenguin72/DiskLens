import SwiftUI
import DiskLensCore

/// User-facing names, symbols and colors for the Core analysis types.

extension FileCategory {
    var title: String {
        switch self {
        case .video: String(localized: "影片")
        case .photo: String(localized: "照片")
        case .music: String(localized: "音樂")
        case .document: String(localized: "文件")
        case .archive: String(localized: "壓縮檔")
        case .diskImage: String(localized: "磁碟映像")
        case .code: String(localized: "程式碼")
        case .appsAndPackages: String(localized: "App 與套件")
        case .developerCache: String(localized: "開發快取")
        case .other: String(localized: "其他")
        }
    }

    var symbol: String {
        switch self {
        case .video: "film"
        case .photo: "photo"
        case .music: "music.note"
        case .document: "doc.text"
        case .archive: "archivebox"
        case .diskImage: "opticaldiscdrive"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .appsAndPackages: "app.badge"
        case .developerCache: "hammer"
        case .other: "questionmark.folder"
        }
    }

    var color: Color { self == .other ? .gray : Theme.color(rawValue) }
}

extension AppDataKind {
    var title: String {
        switch self {
        case .bundle: String(localized: "本體")
        case .data: String(localized: "資料")
        case .cache: String(localized: "快取")
        }
    }

    var color: Color {
        switch self {
        case .bundle: Theme.palette[0]
        case .data: Theme.palette[4]
        case .cache: Theme.palette[1]
        }
    }
}

extension AppLocationKind {
    var title: String {
        switch self {
        case .bundle: String(localized: "App 本體")
        case .applicationSupport: String(localized: "應用程式支援")
        case .container: String(localized: "容器")
        case .groupContainer: String(localized: "群組容器")
        case .cache: String(localized: "快取")
        case .preferences: String(localized: "偏好設定")
        case .logs: String(localized: "記錄檔")
        case .httpStorage: String(localized: "網路儲存")
        case .webKit: String(localized: "網頁資料")
        case .savedState: String(localized: "視窗狀態")
        case .applicationScripts: String(localized: "App 指令碼")
        }
    }
}

extension CleanupSafety {
    var title: String {
        switch self {
        case .safe: String(localized: "安全：會自動重建")
        case .caution: String(localized: "需注意：可能要重新下載或登入")
        case .notRecommended: String(localized: "不建議")
        }
    }

    var shortTitle: String {
        switch self {
        case .safe: String(localized: "安全")
        case .caution: String(localized: "需注意")
        case .notRecommended: String(localized: "不建議")
        }
    }

    var color: Color {
        switch self {
        case .safe: .green
        case .caution: .orange
        case .notRecommended: .red
        }
    }

    var symbol: String {
        switch self {
        case .safe: "checkmark.shield.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .notRecommended: "xmark.octagon.fill"
        }
    }
}

extension CleanupRuleID {
    var title: String {
        switch self {
        case .userCaches: String(localized: "App 快取")
        case .xcodeDerivedData: String(localized: "Xcode DerivedData")
        case .xcodeArchives: String(localized: "Xcode 封存檔")
        case .deviceSupport: String(localized: "裝置支援檔")
        case .simulatorDevices: String(localized: "模擬器裝置")
        case .simulatorCaches: String(localized: "模擬器快取")
        case .xcodePreviews: String(localized: "SwiftUI 預覽資料")
        case .homebrewCache: String(localized: "Homebrew 下載快取")
        case .jsPackageCaches: String(localized: "npm / pnpm / Yarn 快取")
        case .pythonCaches: String(localized: "pip / uv 快取")
        case .jvmCaches: String(localized: "Gradle / Maven 快取")
        case .docker: String(localized: "Docker 虛擬磁碟")
        case .staleNodeModules: String(localized: "久未使用的 node_modules")
        case .oldInstallers: String(localized: "下載項目中的舊安裝檔")
        case .trash: String(localized: "垃圾桶")
        case .iosBackups: String(localized: "iPhone / iPad 備份")
        case .oldLogs: String(localized: "舊的記錄檔")
        case .leftovers: String(localized: "已移除 App 的殘留")
        case .mailDownloads: String(localized: "郵件附件下載")
        }
    }

    var summary: String {
        switch self {
        case .userCaches: String(localized: "各 App 的暫存資料，刪除後 App 會在需要時重新產生。")
        case .xcodeDerivedData: String(localized: "Xcode 的建置中間檔與索引，下次建置時會重新產生。")
        case .xcodeArchives: String(localized: "上架或分發用的 App 封存，含除錯符號；刪除後無法再解析舊版當機報告。")
        case .deviceSupport: String(localized: "連接實機除錯時下載的系統符號，下次連接裝置時會重新產生。")
        case .simulatorDevices: String(localized: "模擬器裝置與其中安裝的 App 和資料，刪除後要重新建立。")
        case .simulatorCaches: String(localized: "模擬器的暫存資料，會自動重建。")
        case .xcodePreviews: String(localized: "SwiftUI 預覽使用的資料，會自動重建。")
        case .homebrewCache: String(localized: "Homebrew 下載過的安裝檔，之後需要時會重新下載。")
        case .jsPackageCaches: String(localized: "JavaScript 套件管理工具的下載快取，會在下次安裝時重新下載。")
        case .pythonCaches: String(localized: "Python 套件的下載快取，會在下次安裝時重新下載。")
        case .jvmCaches: String(localized: "Gradle 與 Maven 下載的相依套件，下次建置要重新下載。")
        case .docker: String(localized: "Docker 的虛擬機磁碟，內含所有映像檔、容器與資料卷；刪除後需重新下載映像檔。")
        case .staleNodeModules: String(localized: "超過 90 天沒有變動的專案相依套件，需要時執行 npm install 即可重新下載。")
        case .oldInstallers: String(localized: "下載項目中超過 30 天的 .dmg、.pkg、.zip 等檔案，App 通常已經裝好了。")
        case .trash: String(localized: "垃圾桶裡的項目仍然佔用空間，清空垃圾桶後才會釋放。")
        case .iosBackups: String(localized: "iPhone / iPad 的本機備份；刪除前請確認裝置已備份到 iCloud 或其他地方。")
        case .oldLogs: String(localized: "超過 30 天的記錄檔與當機報告，只用來除錯。")
        case .leftovers: String(localized: "可能是已移除 App 的殘留：找不到對應的已安裝 App。")
        case .mailDownloads: String(localized: "「郵件」開啟附件時留下的副本，原始附件仍保留在郵件中。")
        }
    }

    var symbol: String {
        switch self {
        case .userCaches: "internaldrive"
        case .xcodeDerivedData, .xcodePreviews: "hammer"
        case .xcodeArchives: "archivebox"
        case .deviceSupport: "iphone"
        case .simulatorDevices, .simulatorCaches: "ipad.and.iphone"
        case .homebrewCache: "mug"
        case .jsPackageCaches, .staleNodeModules: "shippingbox"
        case .pythonCaches: "terminal"
        case .jvmCaches: "cup.and.saucer"
        case .docker: "server.rack"
        case .oldInstallers: "arrow.down.circle"
        case .trash: "trash"
        case .iosBackups: "externaldrive.badge.timemachine"
        case .oldLogs: "doc.text.magnifyingglass"
        case .leftovers: "questionmark.app.dashed"
        case .mailDownloads: "paperclip"
        }
    }
}

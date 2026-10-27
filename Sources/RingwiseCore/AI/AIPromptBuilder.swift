import Foundation

/// The exact text sent to a provider, plus which items it covers.
public struct AIPrompt: Sendable, Equatable {
    public let text: String
    /// Items included in the prompt, biggest first.
    public let items: [AIItem]
    /// Items left out because of the per-request cap.
    public let omitted: Int
}

/// Builds the compact metadata-only prompt. File contents are never read or included.
public enum AIPromptBuilder {
    /// Hard cap on items per request, whatever the provider.
    public static let maxItems = 20

    public static func build(items: [AIItem], info: AIProviderInfo,
                             language: String = Locale.preferredLanguages.first ?? "en",
                             now: Date = Date()) -> AIPrompt {
        build(items: items, language: language, maxItems: info.maxItems, maxChildNames: info.maxChildNames,
              includeFormat: !info.structuredOutput, now: now)
    }

    public static func build(items: [AIItem], language: String, maxItems: Int = maxItems, maxChildNames: Int = 8,
                             includeFormat: Bool = true, now: Date = Date()) -> AIPrompt {
        let cap = max(1, min(maxItems, Self.maxItems))
        let sorted = items.sorted { $0.size > $1.size }
        let included = Array(sorted.prefix(cap))

        var lines: [String] = [
            "You help a macOS user decide what is taking disk space. For each item below, explain what it most likely is,",
            "which app or vendor created it, and whether deleting it is safe. You only have metadata (paths, sizes, dates),",
            "never file contents. Do not use any tools, do not read or modify files; answer from knowledge only.",
            "Write the \"what\", \"owner\" and \"impact\" values in \(languageName(language)).",
            "",
            "Items (today is \(day(now))):",
        ]
        for (i, item) in included.enumerated() {
            var head = "\(i + 1). \(item.path) — \(item.isDirectory ? "folder" : "file"), \(ByteFormat.string(item.size))"
            if item.isDirectory { head += ", \(item.itemCount) files" }
            if let modified = item.modified, modified.timeIntervalSince1970 > 0 { head += ", modified \(day(modified))" }
            lines.append(head)
            let kids = item.children.prefix(maxChildNames)
            if item.isDirectory, !kids.isEmpty { lines.append("   largest inside: " + kids.joined(separator: ", ")) }
            if let note = item.note, !note.isEmpty { lines.append("   Ringwise note: " + note) }
        }
        if includeFormat {
            lines += [
                "",
                "Reply with ONLY a JSON array, no prose, one object per item, in the same order:",
                #"[{"path": "<exact path from above>", "what": "<1-2 sentences>", "owner": "<app or vendor, or null>", "#
                    + #""safety": "safe" | "caution" | "keep", "impact": "<what happens if deleted>", "confidence": <0-1>}]"#,
            ]
        }
        lines.append("safety: safe = can be deleted, regenerated or re-downloaded; caution = check first; keep = deleting loses data or breaks something.")
        return AIPrompt(text: lines.joined(separator: "\n"), items: included, omitted: sorted.count - included.count)
    }

    /// English name of a BCP-47 language, e.g. "zh-Hant-TW" → "Traditional Chinese (Taiwan)".
    static func languageName(_ code: String) -> String {
        let english = Locale(identifier: "en")
        let parts = code.replacingOccurrences(of: "_", with: "-").split(separator: "-").map(String.init)
        guard let language = parts.first else { return "English" }
        let script = parts.dropFirst().first { $0.count == 4 }
        let region = parts.dropFirst().first { $0.count == 2 || $0.count == 3 }
        var name = english.localizedString(forLanguageCode: language) ?? "English"
        if language == "zh" {
            name = script == "Hans" || (script == nil && (region == "CN" || region == "SG")) ? "Simplified Chinese" : "Traditional Chinese"
        }
        if let region, let regionName = english.localizedString(forRegionCode: region) { name += " (\(regionName))" }
        return name
    }

    private static func day(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }
}

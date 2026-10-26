import Foundation

/// Turns a provider's raw output into explanations, tolerating code fences, prose around the JSON
/// and CLI envelopes such as Claude Code's `{"type":"result","result":"…"}`.
public enum AIResponseParser {
    /// Envelope fields that hold the model's text.
    public static let envelopeKeys = ["result", "response", "text", "content", "message"]

    public static func parse(_ raw: String) throws -> [AIExplanation] {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let object = jsonObject(text) {
            if let array = object as? [Any] { return try decode(array) }
            if let dict = object as? [String: Any] { return try unwrap(dict) }
        }
        guard let slice = firstJSONArray(in: stripFences(text)), let array = jsonObject(slice) as? [Any] else {
            throw AIError.unparsable
        }
        return try decode(array)
    }

    /// Pairs answers with the requested items, keyed by item path: exact path first, then the same
    /// name, then position (models sometimes shorten or re-quote paths).
    public static func match(_ explanations: [AIExplanation], to items: [AIItem]) -> [String: AIExplanation] {
        var result: [String: AIExplanation] = [:]
        var unused = explanations
        func take(_ found: (AIExplanation) -> Bool) -> AIExplanation? {
            guard let i = unused.firstIndex(where: found) else { return nil }
            return unused.remove(at: i)
        }
        let norm = { (p: String) in (p as NSString).standardizingPath }
        for item in items {
            if let e = take({ norm($0.path) == norm(item.path) }) { result[item.path] = e }
        }
        for item in items where result[item.path] == nil {
            if let e = take({ ($0.path as NSString).lastPathComponent == item.name }) { result[item.path] = e }
        }
        if explanations.count == items.count {
            for (index, item) in items.enumerated() where result[item.path] == nil {
                if let e = take({ $0 == explanations[index] }) { result[item.path] = e }
            }
        }
        for path in Array(result.keys) { result[path]?.path = path }
        return result
    }

    /// Handles envelopes and `{"items": […]}`-style wrappers.
    private static func unwrap(_ dict: [String: Any]) throws -> [AIExplanation] {
        if dict["is_error"] as? Bool == true {
            let message = (dict["result"] as? String) ?? (dict["error"] as? String) ?? "unknown error"
            throw AIError.failed(message)
        }
        for key in ["items", "results", "explanations"] {
            if let array = dict[key] as? [Any] { return try decode(array) }
        }
        for key in envelopeKeys {
            if let inner = dict[key] as? String { return try parse(inner) }
            if let array = dict[key] as? [Any] { return try decode(array) }
        }
        if dict["path"] != nil { return try decode([dict]) }
        throw AIError.unparsable
    }

    private static func decode(_ array: [Any]) throws -> [AIExplanation] {
        let result = array.compactMap { element -> AIExplanation? in
            guard let d = element as? [String: Any],
                  let path = (d["path"] as? String)?.trimmingCharacters(in: .whitespaces), !path.isEmpty else { return nil }
            let what = (d["what"] as? String) ?? (d["description"] as? String) ?? ""
            var owner = (d["owner"] as? String)?.trimmingCharacters(in: .whitespaces)
            if let o = owner, o.isEmpty || o.lowercased() == "null" || o.lowercased() == "unknown" { owner = nil }
            return AIExplanation(path: path, what: what, owner: owner, safety: safety(d["safety"]),
                                 impact: (d["impact"] as? String) ?? "", confidence: confidence(d["confidence"]))
        }
        guard !result.isEmpty else { throw AIError.unparsable }
        return result
    }

    private static func safety(_ value: Any?) -> AISafety {
        let s = (value as? String)?.lowercased().trimmingCharacters(in: .whitespaces) ?? ""
        if let exact = AISafety(rawValue: s) { return exact }
        if s.contains("keep") || s.contains("unsafe") || s.contains("danger") { return .keep }
        if s.contains("safe") { return .safe }
        return .caution
    }

    private static func confidence(_ value: Any?) -> Double {
        var c: Double
        switch value {
        case let n as NSNumber: c = n.doubleValue
        case let s as String: c = Double(s.replacingOccurrences(of: "%", with: "")) ?? 0.5
        default: c = 0.5
        }
        if c > 1 { c /= 100 }
        return min(1, max(0, c))
    }

    private static func jsonObject(_ text: String) -> Any? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    private static func stripFences(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }
            .joined(separator: "\n")
    }

    /// The first balanced `[…]` that starts an array of objects, ignoring brackets inside strings.
    static func firstJSONArray(in text: String) -> String? {
        let chars = Array(text)
        var start = 0
        while let open = chars[start...].firstIndex(of: "[") {
            if let end = matchingBracket(chars, from: open) {
                let candidate = String(chars[open...end])
                if jsonObject(candidate) is [Any] { return candidate }
            }
            start = open + 1
        }
        return nil
    }

    private static func matchingBracket(_ chars: [Character], from open: Int) -> Int? {
        var depth = 0, inString = false, escaped = false
        for i in open..<chars.count {
            let c = chars[i]
            if inString {
                if escaped { escaped = false } else if c == "\\" { escaped = true } else if c == "\"" { inString = false }
                continue
            }
            switch c {
            case "\"": inString = true
            case "[", "{": depth += 1
            case "]", "}":
                depth -= 1
                if depth == 0 { return c == "]" ? i : nil }
            default: break
            }
        }
        return nil
    }
}

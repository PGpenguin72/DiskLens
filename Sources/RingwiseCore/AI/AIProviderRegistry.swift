import Foundation

/// Finds the AI providers available on this Mac.
///
/// The App Store build (`APP_STORE`) only offers Apple's on-device model; the direct-download
/// build also looks for local AI coding CLIs.
public enum AIProviderRegistry {
    /// Every provider this build supports, installed or not (for the "how to get one" list).
    public static var supported: [AIProviderInfo] {
        #if APP_STORE
        [AppleOnDeviceProvider.info]
        #else
        [AppleOnDeviceProvider.info] + CLIProviders.all.map(\.info)
        #endif
    }

    /// Detects providers off the main thread: Apple's model (always listed, possibly unavailable)
    /// followed by installed CLIs in `CLIProviders.all` order.
    public static func detect() async -> [AIDetectedProvider] {
        let apple = AIDetectedProvider(provider: AppleOnDeviceProvider(), location: nil, version: nil,
                                       unavailableReason: AppleOnDeviceProvider.unavailableReason)
        #if APP_STORE
        return [apple]
        #else
        let found = await withTaskGroup(of: (Int, AIDetectedProvider?).self) { group in
            for (index, spec) in CLIProviders.all.enumerated() {
                group.addTask {
                    guard let url = await CLILocator.locate(spec.binaryNames) else { return (index, nil) }
                    let version = await CLILocator.version(of: url)
                    return (index, AIDetectedProvider(provider: CLIProvider(spec: spec, executable: url),
                                                      location: url.path, version: version))
                }
            }
            var results: [(Int, AIDetectedProvider?)] = []
            for await r in group { results.append(r) }
            return results.sorted { $0.0 < $1.0 }.compactMap(\.1)
        }
        return [apple] + found
        #endif
    }

    /// The provider to use by default: Apple's model when ready, otherwise the first installed CLI.
    public static func defaultProvider(in detected: [AIDetectedProvider]) -> AIDetectedProvider? {
        detected.first { $0.isUsable }
    }
}

import Foundation
import Observation

/// Decides *when* to ask for an App Store review.
///
/// Apple only shows the prompt a few times per year, so the ask must land on a
/// moment where the app just did something useful — never on launch and never
/// after an error, or the rating reflects the annoyance instead of the product.
/// Callers report success moments; this type holds the ask back until the user
/// has had a few of them, and asks at most once per app version.
@MainActor @Observable
final class ReviewPrompter {
    /// Success moments required before the first ask.
    private static let threshold = 3
    private static let countKey = "review.successCount"
    private static let promptedVersionKey = "review.promptedVersion"

    /// Set when the user has earned the prompt; the UI observes it and clears it.
    private(set) var shouldPrompt = false

    private let defaults = UserDefaults.standard

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Report a genuine success (rent collected, contract generated). Cheap and
    /// safe to call often — the gating happens here, not at the call site.
    func registerSuccess() {
        guard defaults.string(forKey: Self.promptedVersionKey) != currentVersion else { return }
        let count = defaults.integer(forKey: Self.countKey) + 1
        defaults.set(count, forKey: Self.countKey)
        if count >= Self.threshold {
            shouldPrompt = true
        }
    }

    /// Called by the UI right after showing the prompt, so this version never asks again.
    func consume() {
        shouldPrompt = false
        defaults.set(currentVersion, forKey: Self.promptedVersionKey)
        defaults.set(0, forKey: Self.countKey)
    }
}

import Foundation
import SwiftData

/// Single SwiftData container for the app. CloudKit private-database sync is
/// enabled when the user has opted in and is signed into iCloud.
///
/// All entities live in one configuration so that relationships (Cloze →
/// Sentence/WordCard, ReviewEvent → WordCard/Cloze) work without
/// cross-configuration restrictions.
///
/// Trade-off: when sync is on, every entity syncs to iCloud — including
/// CapturedPage paths and Sentences. The page image *bytes* never sync (we
/// only store relative paths to local files), so a second device sees
/// metadata but cannot render the original photo. This is documented in the
/// README. For review purposes, source-sentence context is denormalized
/// onto WordCard.sourceSnapshots so the review screen works on any device.
enum AppModelContainer {
    /// CloudKit container identifier. Must match the
    /// `com.apple.developer.icloud-container-identifiers` entry in
    /// `JapaneseSentenceMining.entitlements` and the container created in
    /// the Apple Developer portal.
    static let cloudKitContainerID = "iCloud.com.gokhanseckin.universalsentencemining"

    /// UserDefaults key for the iCloud sync toggle. Mirrored in
    /// `SettingsStore.iCloudSyncKey`; both must be kept in sync.
    static let iCloudSyncEnabledKey = "icloud_sync_enabled"

    static let shared: ModelContainer = {
        let schema = Schema([
            CapturedPage.self,
            Sentence.self,
            Cloze.self,
            WordCard.self,
            ReviewEvent.self
        ])

        let useCloudKit = Self.shouldEnableCloudKit()
        let configuration: ModelConfiguration

        if useCloudKit {
            configuration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
        } else {
            configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        }

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("AppModelContainer: failed to create CloudKit-backed container (\(error)). Falling back to local-only.")
            let fallback = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }()

    private static func shouldEnableCloudKit() -> Bool {
        // Read directly from UserDefaults rather than SettingsStore — the
        // container is created before the @MainActor SettingsStore exists.
        if UserDefaults.standard.object(forKey: iCloudSyncEnabledKey) != nil {
            return UserDefaults.standard.bool(forKey: iCloudSyncEnabledKey)
        }
        // Pre-onboarding first launch: stay local-only. Enabling CloudKit
        // before the user has opted in adds noticeable startup latency
        // (CKContainer/schema setup + initial sync) and triggers
        // `unsafeForcedSync` warnings as SwiftData drives CloudKit from
        // synchronous container init. Once onboarding finishes, the user's
        // explicit pref (defaulted to ubiquityIdentityToken-based ON in
        // SettingsStore.init) takes over on subsequent launches.
        return false
    }
}

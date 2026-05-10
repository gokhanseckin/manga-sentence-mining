import Foundation
import Sentry

enum SentryBootstrap {
    static func start() {
        guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String,
              !dsn.isEmpty,
              !dsn.hasPrefix("$(") else {
            #if DEBUG
            print("Sentry: SentryDSN missing in Info.plist; skipping init.")
            #endif
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.releaseName = Self.releaseName()
            options.environment = Self.environment()
            options.tracesSampleRate = 0.2
            options.profilesSampleRate = 0.2
            options.attachScreenshot = false
            options.attachViewHierarchy = false
            options.enableAppHangTracking = true
            options.enableAutoPerformanceTracing = true
            options.swiftAsyncStacktraces = true
            #if DEBUG
            options.debug = true
            options.environment = "debug"
            #endif
        }
    }

    private static func releaseName() -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let bundleId = info["CFBundleIdentifier"] as? String ?? "app"
        let version = info["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info["CFBundleVersion"] as? String ?? "0"
        return "\(bundleId)@\(version)+\(build)"
    }

    private static func environment() -> String {
        #if DEBUG
        return "debug"
        #else
        return "production"
        #endif
    }
}

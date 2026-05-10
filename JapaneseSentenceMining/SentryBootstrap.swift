import Foundation
import Sentry

enum SentryBootstrap {
    static func start() {
        guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String,
              !dsn.isEmpty,
              !dsn.hasPrefix("$(") else {
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.releaseName = Self.releaseName()
            options.environment = Self.environment()

            // Disabled: heavy main-thread work at App.init() (was the 5-8s
            // cold-launch black screen).
            options.tracesSampleRate = 0
            options.enableAutoPerformanceTracing = false
            options.swiftAsyncStacktraces = false
            options.debug = false

            // Enabled: event-time-only cost (screenshot/view hierarchy on
            // crash) or near-zero runtime cost (hang watcher, MetricKit hook).
            options.enableAppHangTracking = true
            options.enableMetricKit = true
            options.attachScreenshot = true
            options.attachViewHierarchy = true
            options.sendDefaultPii = false
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

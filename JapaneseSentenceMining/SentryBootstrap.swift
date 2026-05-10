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

            // Crash reports + sessions only. Auto-performance/profiling/hang
            // tracking and async-stacktrace instrumentation each add main-thread
            // work in App.init(); on cold first-install they pushed launch to
            // 5–8s. Re-enable individually if a specific signal becomes useful.
            options.tracesSampleRate = 0
            options.enableAutoPerformanceTracing = false
            options.enableAppHangTracking = false
            options.swiftAsyncStacktraces = false
            options.attachScreenshot = false
            options.attachViewHierarchy = false
            options.debug = false
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

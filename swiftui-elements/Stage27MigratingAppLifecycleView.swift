import SwiftUI

@MainActor
struct Stage27MigratingAppLifecycleView: View {
    @State private var activeTab = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stage 27 - Migrating the app lifecycle")
                    .font(.title3.bold())

                Text("The modern SwiftUI App lifecycle (@main struct App) coexists with UIApplicationDelegate responsibilities. Use UIApplicationDelegateAdaptor, scenePhase, and openURL to bridge both worlds.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Tab", selection: $activeTab) {
                    Text("App structure").tag(0)
                    Text("ScenePhase").tag(1)
                    Text("AppDelegate").tag(2)
                }
                .pickerStyle(.segmented)

                switch activeTab {
                case 0:
                    Stage27AppStructureExercise()
                case 1:
                    Stage27ScenePhaseExercise()
                case 2:
                    Stage27AppDelegateExercise()
                default:
                    EmptyView()
                }
            }
            .padding()
        }
    }
}

private struct Stage27AppStructureExercise: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Concept")
                .font(.headline)

            Text("The modern SwiftUI app lifecycle starts with @main, but when you need AppDelegate hooks (app:didFinishLaunchingWithOptions, lifecycle notifications), you use UIApplicationDelegateAdaptor.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Problem")
                .font(.headline)

            Text("You're migrating a legacy UIKit app that relies on AppDelegate methods like app:didFinishLaunchingWithOptions or application:handleOpen. You can keep the SwiftUI App lifecycle and bridge to AppDelegate selectively.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Modern structure")
                .font(.subheadline.bold())

            CodeBlock(
                """
                @main
                struct swiftui_elementsApp: App {
                    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
                    
                    @State var session = Session()
                    
                    var body: some Scene {
                        WindowGroup {
                            ContentView()
                                .environment(session)
                        }
                    }
                }
                
                class AppDelegate: NSObject, UIApplicationDelegate {
                    func application(
                        _ application: UIApplication,
                        didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey: Any]?
                    ) -> Bool {
                        // Legacy init code
                        return true
                    }
                }
                """
            )

            Text("Decision point: Does this responsibility belong in AppDelegate or SwiftUI lifecycle?")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Label("AppDelegate", systemImage: "square.fill")
                    .font(.subheadline.bold())
                Text("app:didFinishLaunchingWithOptions, userNotificationCenter:, push registration, remote config, analytics setup")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                Label("SwiftUI lifecycle", systemImage: "square.fill")
                    .font(.subheadline.bold())
                Text("App state initialization, environment setup, scene management, scenePhase, openURL, app shortcuts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            Text("Rule: Use AppDelegate for system-level hooks that fire before scenes exist. Use App/Scene for SwiftUI-driven state and navigation.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
                .background(.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
        .stageCard()
    }
}

private struct Stage27ScenePhaseExercise: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var lifecycleLog: [String] = []
    @State private var isActive: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Concept")
                .font(.headline)

            Text("scenePhase tells you if the app is in foreground (active), temporarily inactive (transitioning), or background. Use it instead of UIApplicationDelegate lifecycle methods.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Active phase")
                .font(.subheadline.bold())

            HStack(spacing: 12) {
                Image(systemName: scenePhase == .active ? "app.circle.fill" : "app.circle")
                    .font(.title)
                    .foregroundStyle(scenePhase == .active ? .green : .gray)

                VStack(alignment: .leading) {
                    Text(scenePhase.description)
                        .font(.subheadline.bold())
                    Text("Try backgrounding the app to see phase changes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(8)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))

            Text("Lifetime events")
                .font(.subheadline.bold())

            Text("Trigger")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("Log current phase") {
                    lifecycleLog.append("Phase: \(scenePhase.description) at \(Date().formatted(date: .omitted, time: .standard))")
                    LabLog.event("Stage27 logged current phase: \(scenePhase.description)")
                }
                .buttonStyle(.borderedProminent)

                Button("Clear log") {
                    lifecycleLog.removeAll()
                }
                .buttonStyle(.bordered)
            }

            if !lifecycleLog.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Log")
                        .font(.caption.bold())
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(lifecycleLog, id: \.self) { event in
                                Text(event)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                    .padding(8)
                    .background(.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            Text("Use .onChange to react to phase changes:")
                .font(.subheadline.bold())

            CodeBlock(
                """
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .background {
                        // Save state
                    } else if newPhase == .active {
                        // Refresh
                    }
                }
                """
            )

            Text("Rule: scenePhase replaces UIApplicationDelegate lifecycle notifications. Prefer it for SwiftUI apps.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
                .background(.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
        .stageCard()
        .onChange(of: scenePhase) { oldPhase, newPhase in
            lifecycleLog.append("Phase change: \(oldPhase.description) → \(newPhase.description)")
            LabLog.event("Stage27 scenePhase changed: \(oldPhase.description) → \(newPhase.description)")
        }
    }
}

private struct Stage27AppDelegateExercise: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Concept")
                .font(.headline)

            Text("UIApplicationDelegateAdaptor lets you attach a UIApplicationDelegate class to your SwiftUI App. Use it only for system hooks that truly need AppDelegate.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Problem")
                .font(.headline)

            Text("Your legacy app initializes analytics, registers for push notifications, or handles app:handleOpenURL in AppDelegate. You still need these responsibilities during migration.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Implementation pattern")
                .font(.subheadline.bold())

            CodeBlock(
                """
                @main
                struct swiftui_elementsApp: App {
                    @UIApplicationDelegateAdaptor(AppDelegate.self)
                    var appDelegate
                    
                    var body: some Scene {
                        WindowGroup {
                            ContentView()
                        }
                    }
                }
                
                class AppDelegate: NSObject, UIApplicationDelegate {
                    func application(
                        _ app: UIApplication,
                        open url: URL,
                        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
                    ) -> Bool {
                        // Handle deep links or custom URL schemes
                        return false
                    }
                    
                    func userNotificationCenter(
                        _ center: UNUserNotificationCenter,
                        didReceive response: UNNotificationResponse,
                        withCompletionHandler: @escaping () -> Void
                    ) {
                        // Handle push notifications
                        withCompletionHandler()
                    }
                }
                """
            )

            Text("Lifecycle of AppDelegate")
                .font(.subheadline.bold())

            VStack(alignment: .leading, spacing: 8) {
                Label("Fires once", systemImage: "1.circle.fill")
                    .font(.subheadline.bold())
                Text("didFinishLaunchingWithOptions, scene delegates, app initialization")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                Label("Fires multiple times", systemImage: "repeat.circle.fill")
                    .font(.subheadline.bold())
                Text("application:open:options:, userNotificationCenter:didReceive:, background task processing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            Text("Migration strategy")
                .font(.subheadline.bold())

            VStack(alignment: .leading, spacing: 4) {
                Label("1. Keep AppDelegate minimal", systemImage: "1.circle")
                    .font(.caption)
                Label("2. Move app state to SwiftUI @main App", systemImage: "2.circle")
                    .font(.caption)
                Label("3. If AppDelegate needs to trigger app logic, pass @State or @Observable to it", systemImage: "3.circle")
                    .font(.caption)
                Label("4. Replace app:handleOpenURL with .onOpenURL { }", systemImage: "4.circle")
                    .font(.caption)
            }
            .padding(8)
            .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            Text("Do NOT remove AppDelegate just because it feels old. Remove it when all its responsibilities have a proper SwiftUI equivalent (scenePhase, .onOpenURL, etc.).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
                .background(.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
        .stageCard()
    }
}

private struct CodeBlock: View {
    let code: String

    init(_ code: String) {
        self.code = code
    }

    var body: some View {
        ScrollView(.horizontal) {
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(8)
        }
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}

extension ScenePhase: CustomStringConvertible {
    public var description: String {
        switch self {
        case .active:
            return "active (foreground)"
        case .inactive:
            return "inactive (transitioning)"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }
}

#Preview {
    Stage27MigratingAppLifecycleView()
}

import SwiftUI
import SwiftData
import AppKit
import Combine
import Sparkle

@main
struct ClaudeAccountApp: App {
    @StateObject private var updater = SparkleUpdater()
    @Environment(\.openWindow) private var openWindow
    private let modelContainer: ModelContainer

    init() {
        DataStore.migrateLegacyStoreIfNeeded()
        modelContainer = DataStore.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .background(WindowLayoutRestorer())
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 ClaudeAccountFee…") {
                    openWindow(id: "about")
                }
                Divider()
                Button("检查更新…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
        }

        Window("关于 ClaudeAccountFee", id: "about") {
            AboutView(updater: updater)
        }
        .defaultSize(width: 460, height: 360)
        .windowResizability(.contentSize)
    }
}

@MainActor
private final class SparkleUpdater: ObservableObject {
    @Published private(set) var canCheckForUpdates = false

    private let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

private struct AboutView: View {
    @ObservedObject var updater: SparkleUpdater

    private let repositoryURL = URL(string: "https://github.com/n7tequila/ClaudeAccountFee")!

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
    }

    private var buildVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "未知"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)

            Text("ClaudeAccountFee")
                .font(.title2)
                .fontWeight(.bold)

            Text("版本 \(appVersion) · Build \(buildVersion)")
                .foregroundStyle(.secondary)

            Text("Claude 多账号与订阅费用管理")
                .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 12) {
                Button("检查更新…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)

                Button("项目主页") {
                    NSWorkspace.shared.open(repositoryURL)
                }
            }

            Text("自动更新：每天检查一次。发现新版本时会弹出提示，不会静默安装。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RootView: View {
    @ObservedObject private var crypto = CryptoService.shared

    var body: some View {
        Group {
            if crypto.isUnlocked {
                ContentView()
            } else {
                LockView()
            }
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}

private final class WindowLayoutRestorerView: NSView {
    var onWindow: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard let window else { return }
        DispatchQueue.main.async { [weak window, onWindow] in
            guard let window else { return }
            onWindow?(window)
        }
    }
}

private struct WindowLayoutRestorer: NSViewRepresentable {
    private let windowAutosaveName: NSWindow.FrameAutosaveName = "ClaudeAccountFeeMainWindow"
    private let splitViewAutosaveName: NSSplitView.AutosaveName = "ClaudeAccountFeeMainSplitView"

    func makeNSView(context: Context) -> NSView {
        let view = WindowLayoutRestorerView()
        let restorer = self
        view.onWindow = { window in
            restorer.apply(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        apply(to: window)
    }

    private func apply(to window: NSWindow) {
        window.setFrameAutosaveName(windowAutosaveName)
        restoreSplitViewAutosave(in: window.contentView)
    }

    private func restoreSplitViewAutosave(in view: NSView?) {
        guard let view else { return }

        if let splitView = view as? NSSplitView,
           splitView.arrangedSubviews.count == 3 {
            splitView.autosaveName = splitViewAutosaveName
        }

        view.subviews.forEach { restoreSplitViewAutosave(in: $0) }
    }
}

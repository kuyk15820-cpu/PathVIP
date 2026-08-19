import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @State private var tabNavigation: AppTabNavigationState
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    @AppStorage(FeatureVisibility.wallpapersStorageKey) private var wallpapersEnabled = true

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-files-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-patch-tab") {
            initialTab = 2
        } else if arguments.contains("--simulate-cleaner-tab") {
            initialTab = 3
        } else if arguments.contains("--simulate-wallpaper-tab") {
            initialTab = 4
        } else {
            initialTab = 0
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.patches.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.patches.rawValue) }
        }
        .onChange(of: cleanerEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .onChange(of: wallpapersEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(featureVisibility.visibleSections) { section in
                sectionContent(section)
                    .tabItem {
                        CompactTabLabel(
                            title: language.text(section.titleKey),
                            systemImage: section.systemImage
                        )
                    }
                    .tag(section.rawValue)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
                }
            }
            .navigationTitle("3105")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(AppSection(rawValue: tabNavigation.selectedTab) ?? .home)
                .id(tabNavigation.selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            DashboardView(
                cleanerEnabled: $cleanerEnabled,
                wallpapersEnabled: $wallpapersEnabled
            )
        case .patches:
            PatchProjectsView()
        default:
            EmptyView()
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(
            cleanerEnabled: cleanerEnabled,
            wallpapersEnabled: wallpapersEnabled
        )
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
    }
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .patches: return "tab.patches"
        default: return ""
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .patches: return "shippingbox.fill"
        default: return ""
        }
    }
}

private struct DashboardView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @State private var showSettings = false
    @State private var showLogs = false
    @Binding var cleanerEnabled: Bool
    @Binding var wallpapersEnabled: Bool

    @State private var isSyncing = false
    @State private var syncStatusMessage: String?

    var body: some View {
        NavigationStack {
            List {
                deviceSection
                autoSyncStatusSection
                featuresSection
                signingSection
            }
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.accent)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showLogs = true } label: {
                        Image(systemName: "apple.terminal")
                    }
                    .accessibilityLabel(language.text("accessibility.open_logs"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(language.text("accessibility.open_settings"))
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showLogs) { LogView() }
            .task {
                performRemoteSync()
            }
        }
    }

    private var autoSyncStatusSection: some View {
        Section {
            HStack(spacing: 12) {
                if isSyncing {
                    ProgressView()
                    Text("กำลังตรวจสอบการอัปเดตแพตช์...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let message = syncStatusMessage {
                    Image(systemName: message.contains("ล้มเหลว") || message.contains("ไม่ถูกต้อง") ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(message.contains("ล้มเหลว") || message.contains("ไม่ถูกต้อง") ? Color.red : Color.green)
                    Text(message)
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("สถานะการอัปเดตอัตโนมัติ")
        }
    }

    private func performRemoteSync() {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        guard let apiURL = URL(string: "https://f1x3r.org/api/get-patch.php?bundle_id=\(bundleID)") else {
            syncStatusMessage = "URL ไม่ถูกต้อง"
            return
        }

        isSyncing = true
        syncStatusMessage = nil

        Task {
            do {
                let (config, fileData, fileName) = try await RemotePatchService.fetchRemotePatch(from: apiURL)
                
                let savedVersion = UserDefaults.standard.string(forKey: "LocalInstalledPatchVersion_\(config.patchID)")
                if savedVersion == config.version {
                    await MainActor.run {
                        isSyncing = false
                        syncStatusMessage = "แพตช์เป็นเวอร์ชันล่าสุดแล้ว (\(config.version))"
                    }
                    return
                }

                let packageData = try PatchPackageBuilder.buildPackageData(
                    from: config,
                    fileData: fileData,
                    fileName: fileName
                )
                let summary = try PatchPackageCodec.inspect(packageData)
                let decoded = try PatchPackageCodec.decode(packageData, password: nil)

                try PatchProjectLibrary.installImportedPackage(
                    data: packageData,
                    decoded: decoded,
                    summary: summary,
                    existingURL: nil
                )

                UserDefaults.standard.set(config.version, forKey: "LocalInstalledPatchVersion_\(config.patchID)")

                await MainActor.run {
                    isSyncing = false
                    syncStatusMessage = "อัปเดตล่าสุดเรียบร้อยแล้ว: \(config.projectName) (\(config.version))"
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    syncStatusMessage = "การอัปเดตล้มเหลว: \(error.localizedDescription)"
                }
            }
        }
    }

    private var featuresSection: some View {
        Section {
            Toggle(isOn: $cleanerEnabled) {
                Label(language.text("tab.cleaner"), systemImage: "sparkles")
            }
            Toggle(isOn: $wallpapersEnabled) {
                Label(language.text("tab.wallpapers"), systemImage: "photo.on.rectangle.angled")
            }
        } header: {
            Text(language.text("dashboard.features"))
        } footer: {
            Text(language.text("dashboard.features_footer"))
        }
    }

    private var signingSection: some View {
        Section {
            Label {
                Text(language.text("dashboard.enterprise_signing"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(.vertical, 4)
        } header: {
            Text(language.text("dashboard.installation"))
        }
    }

    private var deviceSection: some View {
        Section {
            LabeledContent(language.text("dashboard.hardware_model")) {
                Text(AppInfo.displayMachineName)
                    .font(.body.monospaced())
            }
            LabeledContent(language.text("settings.ios_version")) {
                Text("\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                    .font(.body.monospaced())
            }
            HStack {
                Text(language.text("settings.compatibility"))
                Spacer()
                Label(
                    language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"),
                    systemImage: appState.isSupported ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .foregroundStyle(appState.isSupported ? Color.green : Color.red)
            }
        } header: {
            Text(language.text("common.device"))
        } footer: {
            Text(language.text("settings.supported_range_summary"))
        }
    }
}

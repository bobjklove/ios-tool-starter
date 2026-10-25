import SwiftUI
import PhotosUI
import PDFKit

/// 预览：把导出 PDF 的第一页渲染成缩略图，整页按比例放进框里，
/// 用户一眼看到整张纸和照片位置。不用 PDFView 自动缩放（布局前算比例会出错）。
struct PDFPreview: View {
    let project: SampleProject
    var body: some View {
        if let image = Self.thumbnail(project) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .shadow(color: Tokens.cardShadow, radius: 6, y: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color.clear
        }
    }
    private static func thumbnail(_ project: SampleProject) -> UIImage? {
        guard let data = try? PDFExporter.data(project),
              let page = PDFDocument(data: data)?.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let scale = 900 / max(bounds.width, bounds.height)
        return page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
    }
}

struct SampleView: View {
    @StateObject private var purchases = PurchaseService()
    @StateObject private var freeTier = FreeTierStore()
    @State private var project: SampleProject?
    @State private var selected: PhotosPickerItem?
    @State private var share: ExportLease?
    @State private var paywall = false
    @State private var pendingExport = false
    @State private var message: String?
    @State private var messageKind: StatusBanner.Kind = .info
    @State private var working = false
    private let store = ProjectStore()
    private let exports = TemporaryExports()
    private var screenshotMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-store-screenshot")
        #else
        false
        #endif
    }
    private var screenshotEmpty: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-store-screenshot-empty")
        #else
        false
        #endif
    }
    private var screenshotPaywall: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-store-screenshot-paywall")
        #else
        false
        #endif
    }
    var body: some View {
        NavigationStack {
            ScreenContainer {
                if let project {
                    selectedContent(project)
                } else {
                    emptyContent
                }
            }
            .safeAreaInset(edge: .bottom) {
                // 主操作固定在底部，滚动到哪都能直接导出。
                if project != nil {
                    BottomActionBar {
                        Button("sample.export") { export() }
                            .buttonStyle(.primary)
                            .disabled(working || share != nil)
                            .accessibilityIdentifier("export-pdf")
                    }
                }
            }
            .navigationTitle(Text("app.title"))
            .navigationBarTitleDisplayMode(.large)
            .foregroundStyle(Tokens.foreground)
            .tint(Tokens.accent)
        }
        .sheet(isPresented: $paywall, onDismiss: {
            if pendingExport && purchases.unlocked { pendingExport = false; export() }
        }) { PaywallView(purchases: purchases, onUnlocked: {}) }
        .sheet(item: $share, onDismiss: {
            // Captured lease is also cleaned by the completion handler; cleanup is idempotent.
            working = false
        }) { lease in
            ShareSheet(lease: lease) { completed, failed in
                defer { exports.remove(lease); share = nil; working = false }
                if failed { setMessage(localized("error.export"), kind: .error); return }
                if completed {
                    do { try freeTier.recordCompleted(lease.fingerprint, unlocked: purchases.unlocked) }
                    catch { setMessage(localized("error.quota"), kind: .error); return }
                    setMessage(localized("sample.exported"), kind: .success)
                }
            }
            .onDisappear { exports.remove(lease); working = false }
        }
        .onChange(of: selected) { _, item in
            Task {
                working = true; defer { working = false }
                do {
                    guard let data = try await item?.loadTransferable(type: Data.self) else { throw StarterError.invalidImage }
                    project = SampleProject(imagePNG: try ImageImport.normalizedPNG(data))
                    setMessage(nil)
                } catch { setMessage(localized("error.import"), kind: .error) }
            }
        }
        .task {
            do { try exports.clearStale() } catch { setMessage(localized("error.export"), kind: .error) }
            if screenshotPaywall {
                project = SampleProject(imagePNG: SampleFixture.png())
                paywall = true
            } else if screenshotMode {
                project = SampleProject(imagePNG: SampleFixture.png())
            } else if screenshotEmpty {
                project = nil
            } else {
                restore()
                await purchases.start()
            }
        }
    }
    @ViewBuilder private var emptyContent: some View {
        EmptyStateView(symbol: "doc.viewfinder", title: "sample.emptyTitle", message: "sample.emptyMessage")
        PhotosPicker(selection: $selected, matching: .images) { Text("sample.choose") }
            .buttonStyle(.primary)
            .disabled(working || share != nil)
            .accessibilityIdentifier("choose-photo")
        Button("sample.restoreDraft") { restore() }
            .buttonStyle(.textLink)
            .disabled(working)
            .frame(maxWidth: .infinity)
    }
    private func selectedContent(_ project: SampleProject) -> some View {
        Group {
            Card {
                PDFPreview(project: project)
                    .frame(height: Tokens.previewHeight)
                    .accessibilityLabel(Text("sample.preview"))
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.smallRadius, style: .continuous))
            }
            SectionHeader(title: "sample.section.size")
            Card {
                ValueRow(label: "sample.paper") {
                    Picker("sample.paper", selection: binding(\.paper, default: .a4)) {
                        ForEach(Paper.allCases) { paper in Text(verbatim: paper.title).tag(paper) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                Divider()
                Stepper(value: binding(\.width, default: 5000), in: 100...19000, step: 100) {
                    Text(verbatim: String(format: localized("sample.width"), Double(project.width) / 100))
                        .font(Tokens.number)
                }
                Divider()
                Stepper(value: binding(\.height, default: 7000), in: 100...25000, step: 100) {
                    Text(verbatim: String(format: localized("sample.height"), Double(project.height) / 100))
                        .font(Tokens.number)
                }
                Text("sample.cropNotice").font(Tokens.caption).foregroundStyle(Tokens.secondary)
            }
            accessStatus
            if freeTier.error != nil {
                StatusBanner(text: localized("error.quota"), kind: .error)
            }
            if let message {
                StatusBanner(text: message, kind: messageKind)
                    .accessibilityIdentifier("status-message")
            }
            HStack(spacing: Tokens.spacing) {
                PhotosPicker(selection: $selected, matching: .images) {
                    Text("sample.change").frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondary)
                .disabled(working || share != nil)
                .accessibilityIdentifier("change-photo")
                Button("sample.save") { save() }
                    .buttonStyle(.secondary)
                    .disabled(working)
            }
            Button("sample.restoreDraft") { restore() }
                .buttonStyle(.textLink)
                .disabled(working)
                .frame(maxWidth: .infinity)
        }
    }
    @ViewBuilder private var accessStatus: some View {
        if purchases.unlocked {
            StatusBanner(text: localized("purchase.unlocked"), kind: .success)
        } else {
            StatusBanner(text: String(format: localized("sample.remaining"), freeTier.remaining), kind: .info)
            Button("purchase.title") { pendingExport = false; paywall = true }
                .buttonStyle(.textLink)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    private func binding<T>(_ keyPath: WritableKeyPath<SampleProject, T>, default fallback: T) -> Binding<T> {
        Binding(get: { project?[keyPath: keyPath] ?? fallback }, set: { project?[keyPath: keyPath] = $0 })
    }
    private func localized(_ key: String) -> String { NSLocalizedString(key, comment: "Sample status") }
    private func setMessage(_ value: String?, kind: StatusBanner.Kind = .info) {
        message = value
        messageKind = kind
    }
    private func save() {
        guard let project else { return }
        do { try store.save(project); setMessage(localized("sample.saved"), kind: .success) }
        catch { setMessage(localized("error.storage"), kind: .error) }
    }
    private func restore() {
        do { project = try store.load(); setMessage(nil) }
        catch { setMessage(localized("error.storage"), kind: .error) }
    }
    private func export() {
        guard let project, !working, share == nil else { return }
        do {
            let fingerprint = try ExportFingerprint.make(project)
            guard freeTier.allows(fingerprint, unlocked: purchases.unlocked) else {
                pendingExport = true; paywall = true; return
            }
            working = true
            share = try exports.create(project)
        } catch { working = false; setMessage(localized("error.export"), kind: .error) }
    }
}

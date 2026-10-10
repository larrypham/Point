import AppKit
import BrowserCore
import SwiftUI
import UniformTypeIdentifiers

enum EmptyTabBackground: String, CaseIterable, Identifiable {
    static let defaultsKey = "EmptyTabBackground"
    static let defaultValue = EmptyTabBackground.automatic

    case automatic
    case aurora
    case ocean
    case sunset
    case graphite
    case custom

    var id: Self { self }

    var titleKey: String {
        "empty_tab_background_\(rawValue)"
    }

    @ViewBuilder
    var content: some View {
        switch self {
        case .automatic:
            Color(nsColor: .textBackgroundColor)
        case .aurora:
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.20, blue: 0.25),
                    Color(red: 0.16, green: 0.42, blue: 0.38),
                    Color(red: 0.32, green: 0.18, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .ocean:
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.18, blue: 0.34),
                    Color(red: 0.08, green: 0.42, blue: 0.56),
                    Color(red: 0.20, green: 0.66, blue: 0.66)
                ],
                startPoint: .top,
                endPoint: .bottomTrailing
            )
        case .sunset:
            LinearGradient(
                colors: [
                    Color(red: 0.32, green: 0.14, blue: 0.34),
                    Color(red: 0.72, green: 0.28, blue: 0.30),
                    Color(red: 0.94, green: 0.60, blue: 0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .graphite:
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.11),
                    Color(red: 0.20, green: 0.22, blue: 0.26),
                    Color(red: 0.10, green: 0.11, blue: 0.13)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .custom:
            Color(nsColor: .textBackgroundColor)
        }
    }
}

private enum CustomEmptyTabBackground {
    static let pathKey = "CustomEmptyTabBackgroundPath"
    static let revisionKey = "CustomEmptyTabBackgroundRevision"

    static var image: NSImage? {
        guard let path = UserDefaults.standard.string(forKey: pathKey) else { return nil }
        return NSImage(contentsOfFile: path)
    }

    @MainActor
    static func chooseImage() throws -> Bool {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.message = BrowserLocalization.string("empty_tab_background_choose_prompt")
        guard panel.runModal() == .OK, let sourceURL = panel.url else { return false }

        let hasSecurityAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: sourceURL)
        guard NSImage(data: data) != nil else { throw CocoaError(.fileReadCorruptFile) }

        let directory = try backgroundDirectory()
        let fileExtension = sourceURL.pathExtension.isEmpty ? "image" : sourceURL.pathExtension
        let destinationURL = directory
            .appendingPathComponent("empty-tab-background")
            .appendingPathExtension(fileExtension)
        try data.write(to: destinationURL, options: .atomic)

        removePreviousImage(except: destinationURL)
        UserDefaults.standard.set(destinationURL.path, forKey: pathKey)
        incrementRevision()
        return true
    }

    static func removeImage() {
        removePreviousImage(except: nil)
        UserDefaults.standard.removeObject(forKey: pathKey)
        incrementRevision()
    }

    private static func backgroundDirectory() throws -> URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let directory = root
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "Point", isDirectory: true)
            .appendingPathComponent("Backgrounds", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private static func removePreviousImage(except destinationURL: URL?) {
        guard let path = UserDefaults.standard.string(forKey: pathKey) else { return }
        let previousURL = URL(fileURLWithPath: path)
        guard previousURL != destinationURL else { return }
        try? FileManager.default.removeItem(at: previousURL)
    }

    private static func incrementRevision() {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: revisionKey) + 1, forKey: revisionKey)
    }
}

struct EmptyTabBackgroundView: View {
    @AppStorage(EmptyTabBackground.defaultsKey) private var storedBackground =
        EmptyTabBackground.defaultValue.rawValue
    @AppStorage(CustomEmptyTabBackground.revisionKey) private var customImageRevision = 0

    var body: some View {
        if selectedBackground == .custom, let image = CustomEmptyTabBackground.image {
            GeometryReader { geometry in
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            .id(customImageRevision)
        } else {
            selectedBackground.content
                .ignoresSafeArea()
        }
    }

    private var selectedBackground: EmptyTabBackground {
        EmptyTabBackground(rawValue: storedBackground) ?? .defaultValue
    }
}

struct EmptyTabBackgroundPicker: View {
    @AppStorage(EmptyTabBackground.defaultsKey) private var storedBackground =
        EmptyTabBackground.defaultValue.rawValue
    @AppStorage(CustomEmptyTabBackground.revisionKey) private var customImageRevision = 0
    @State private var importError: String?

    private let columns = [
        GridItem(.adaptive(minimum: 104, maximum: 140), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(EmptyTabBackground.allCases) { background in
                    EmptyTabBackgroundOption(
                        background: background,
                        customImage: customImage,
                        isSelected: storedBackground == background.rawValue
                    ) {
                        if background != .custom || CustomEmptyTabBackground.image != nil {
                            storedBackground = background.rawValue
                        } else {
                            chooseCustomImage()
                        }
                    }
                }
            }

            HStack {
                Button(BrowserLocalization.string("empty_tab_background_choose_image")) {
                    chooseCustomImage()
                }

                Button(
                    BrowserLocalization.string("empty_tab_background_remove_image"),
                    role: .destructive
                ) {
                    CustomEmptyTabBackground.removeImage()
                    storedBackground = EmptyTabBackground.defaultValue.rawValue
                }
                .disabled(customImage == nil)
            }
        }
        .alert(
            BrowserLocalization.string("empty_tab_background_import_failed"),
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )
        ) {
            Button(BrowserLocalization.string("ok"), role: .cancel) {}
        } message: {
            if let importError { Text(importError) }
        }
    }

    private func chooseCustomImage() {
        do {
            if try CustomEmptyTabBackground.chooseImage() {
                storedBackground = EmptyTabBackground.custom.rawValue
            }
        } catch {
            importError = error.localizedDescription
        }
    }

    private var customImage: NSImage? {
        _ = customImageRevision
        return CustomEmptyTabBackground.image
    }
}

private struct EmptyTabBackgroundOption: View {
    let background: EmptyTabBackground
    let customImage: NSImage?
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                EmptyTabBackgroundThumbnail(background: background, customImage: customImage)
                    .frame(height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color.primary.opacity(0.12),
                                lineWidth: isSelected ? 3 : 1
                            )
                    }
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .padding(6)
                        }
                    }

                Text(BrowserLocalization.string(background.titleKey))
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(BrowserLocalization.string(background.titleKey))
        .accessibilityValue(
            isSelected ? BrowserLocalization.string("selected") : ""
        )
    }
}

private struct EmptyTabBackgroundThumbnail: View {
    let background: EmptyTabBackground
    let customImage: NSImage?

    var body: some View {
        if background == .custom, let customImage {
            Image(nsImage: customImage)
                .resizable()
                .scaledToFill()
        } else if background == .custom {
            ZStack {
                Color(nsColor: .textBackgroundColor)
                Image(systemName: "photo.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        } else {
            background.content
        }
    }
}

import AppKit
import BrowserCore
import SwiftUI
import WebKit

struct TabOverviewView: View {
    @Bindable var model: BrowserWindowModel
    @State private var searchText = ""

    private let spacing: CGFloat = 48
    private let columns = [
        GridItem(.adaptive(minimum: 480, maximum: 640), spacing: 48, alignment: .top)
    ]

    private var matchingTabs: [BrowserTab] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.tabs }
        return model.tabs.filter { tab in
            tab.displayTitle.localizedCaseInsensitiveContains(query)
                || tab.url?.absoluteString.localizedCaseInsensitiveContains(query) == true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(
                        BrowserLocalization.string("search_tabs"),
                        text: $searchText
                    )
                    .textFieldStyle(.plain)
                    .frame(width: 150)
                }
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .browserGlassSurface(cornerRadius: 14)
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)

            ScrollView {
                GlassEffectContainer(spacing: spacing) {
                    LazyVGrid(columns: columns, alignment: .center, spacing: spacing) {
                        ForEach(matchingTabs) { tab in
                            TabOverviewTile(
                                tab: tab,
                                isSelected: tab.id == model.selectedTabID,
                                onSelect: {
                                    model.selectTab(tab.id)
                                    model.dismissTabOverview()
                                },
                                onClose: { model.closeTab(tab.id) }
                            )
                        }

                        addTabTile
                    }
                    .padding(.horizontal, 48)
                    .padding(.top, 30)
                    .padding(.bottom, 56)
                }
            }
            .scrollIndicators(.hidden)
        }
        .onExitCommand { model.dismissTabOverview() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(BrowserLocalization.string("tab_overview"))
    }

    private var addTabTile: some View {
        Button {
            model.newTab()
            model.dismissTabOverview()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .aspectRatio(16 / 9, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .browserTintedGlass(cornerRadius: 14, isInteractive: true)
        .shadow(color: .black.opacity(0.18), radius: 14, y: 7)
        .accessibilityLabel(BrowserLocalization.string("new_tab"))
    }
}

private struct TabOverviewTile: View {
    let tab: BrowserTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var snapshot: NSImage?
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ZStack {
                    Color.black.opacity(0.26)
                    HStack(spacing: 7) {
                        TabFavicon(tab: tab, size: 15)
                        Text(tab.displayTitle)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 36)
                }
                .frame(height: 28)

                Button(action: onSelect) {
                    preview
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .aspectRatio(16 / 9, contentMode: .fit)

            if isHovering {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.glass)
                .padding(4)
                .accessibilityLabel(BrowserLocalization.string("close_tab"))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .browserTintedGlass(cornerRadius: 14, isInteractive: true)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor : Color.white.opacity(0.12),
                    lineWidth: isSelected ? 3 : 1
                )
        }
        .shadow(color: .black.opacity(0.22), radius: 14, y: 7)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .task(id: tab.url) {
            await captureSnapshot()
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var preview: some View {
        if let snapshot {
            Image(nsImage: snapshot)
                .resizable()
                .scaledToFill()
                .clipped()
        } else {
            ZStack {
                Color(nsColor: .controlBackgroundColor).opacity(0.72)
                VStack(spacing: 12) {
                    TabFavicon(tab: tab, size: 42)
                    Text(tab.domain ?? tab.displayTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding()
            }
        }
    }

    private func captureSnapshot() async {
        guard let webView = tab.engine?.webView else { return }
        snapshot = try? await webView.takeSnapshot(configuration: nil)
    }
}

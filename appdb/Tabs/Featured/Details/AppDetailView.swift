//
//  AppDetailView.swift
//  appdb
//
//  Modern iOS 26 SwiftUI detail view for all app types.
//

import SwiftUI
import Localize_Swift

private typealias SColor = SwiftUI.Color

// MARK: - Observable State

@Observable
final class AppDetailState {
    var isInstalling: Bool = false
    var versionsAvailable: Bool = false
    var isLoading: Bool = true
    var content: Item?
    var contentType: ItemType = .ios
    var errorTitle: String?
    var errorMessage: String?
}

// MARK: - App Detail View

struct AppDetailView: SwiftUI.View {
    var state: AppDetailState

    var onInstall: () -> Void = {}
    var onShare: () -> Void = {}
    var onDismiss: () -> Void = {}
    var onRelatedTap: (String) -> Void = { _ in }
    var onPreviousVersions: () -> Void = {}
    var onDeveloperTap: (String, ItemType, String) -> Void = { _, _, _ in }
    var onExternalLink: (String) -> Void = { _ in }
    var onOriginalApp: (ItemType, String) -> Void = { _, _ in }
    var onScreenshotTap: (Int, Bool, Bool, CGFloat) -> Void = { _, _, _, _ in }
    var onRetry: () -> Void = {}

    @State private var descExpanded = false
    @State private var changelogExpanded = false
    @State private var showNavTitle = false

    var body: some SwiftUI.View {
        Group {
            if state.isLoading {
                loadingView
            } else if let errorTitle = state.errorTitle {
                errorView(title: errorTitle, message: state.errorMessage ?? "")
            } else if let content = state.content {
                detailScrollView(content)
            }
        }
        .toolbar { toolbarContent }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if let content = state.content {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(content.itemName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(content.itemSeller)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .opacity(showNavTitle ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: showNavTitle)
            }

            if Global.isIpad {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Dismiss".localized()) { onDismiss() }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    if !state.isInstalling { onInstall() }
                } label: {
                    ZStack {
                        Text("Install".localized())
                            .opacity(state.isInstalling ? 0 : 1)
                        ProgressView()
                            .controlSize(.small)
                            .opacity(state.isInstalling ? 1 : 0)
                    }
                    .animation(.easeInOut(duration: 0.3), value: state.isInstalling)
                }
                .buttonStyle(.glassProminent)
            }

            if state.contentType != .altstore {
                ToolbarSpacer(.flexible)
                ToolbarItem(placement: .primaryAction) {
                    Button("Share", systemImage: "square.and.arrow.up") { onShare() }
                }
                
            }

            
        }
    }

    // MARK: - Loading

    private var loadingView: some SwiftUI.View {
        VStack {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error

    private func errorView(title: String, message: String) -> some SwiftUI.View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Retry".localized()) { onRetry() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Main Content

    private func detailScrollView(_ content: Item) -> some SwiftUI.View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                headerSection(content)
                    .onScrollVisibilityChange(threshold: 0.1) { visible in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showNavTitle = !visible
                        }
                    }

                if content.itemIsTweaked,
                   !content.itemOriginalTrackid.isEmpty,
                   content.itemOriginalTrackid != "0" {
                    tweakedNotice(content)
                }

                sectionDivider
                infoPillsSection(content)

                if !content.itemChangelog.isEmpty {
                    sectionDivider
                    whatsNewSection(content)
                }

                let screenshots = content.itemScreenshots
                if !screenshots.isEmpty {
                    sectionDivider
                    screenshotsSection(screenshots)
                }

                if !content.itemDescription.decoded.isEmpty {
                    sectionDivider
                    descriptionSection(content)
                }

                if !content.itemReviews.isEmpty {
                    sectionDivider
                    reviewsSection(content)
                }

                let infoRows = informationRows(content)
                if !infoRows.isEmpty {
                    sectionDivider
                    informationSection(infoRows)
                }

                if hasDownloadStats(content) {
                    sectionDivider
                    downloadStatsSection(content)
                }

                if state.versionsAvailable {
                    sectionDivider
                    previousVersionsRow
                }

                if !content.itemRelatedContent.isEmpty {
                    sectionDivider
                    relatedSection(content)
                }

                externalLinksSection(content)
                publisherSection(content)

                Spacer(minLength: 60)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private func headerSection(_ content: Item) -> some SwiftUI.View {
        HStack(alignment: .top, spacing: 16) {
            AsyncImage(url: URL(string: content.itemIconUrl)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Image("placeholderIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .frame(width: iconSize, height: state.contentType == .books ? iconSize * 1.542 : iconSize)
            .clipShape(RoundedRectangle(cornerRadius: state.contentType == .books ? 8 : iconSize / 4.2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: state.contentType == .books ? 8 : iconSize / 4.2, style: .continuous)
                    .stroke(SColor(.separator), lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(content.itemName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(2)

                if !content.itemSeller.isEmpty {
                    if let app = content as? App {
                        Button {
                            onDeveloperTap(app.seller, state.contentType, app.artistId.description)
                        } label: {
                            Text(app.seller)
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    } else if let cydiaApp = content as? CydiaApp, !cydiaApp.developer.isEmpty {
                        Button {
                            onDeveloperTap(cydiaApp.developer, state.contentType, cydiaApp.developerId.description)
                        } label: {
                            Text(cydiaApp.developer)
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(content.itemSeller)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let altApp = content as? AltStoreApp, !altApp.subtitle.isEmpty {
                    Text(altApp.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                headerBadges(content)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private func headerBadges(_ content: Item) -> some SwiftUI.View {
        HStack(spacing: 6) {
            if let altApp = content as? AltStoreApp, altApp.beta {
                badgeLabel("Beta")
            }
            if let app = content as? App,
               app.screenshotsIphone.isEmpty, !app.screenshotsIpad.isEmpty {
                badgeLabel("iPad only".localized())
            }
            if let cydia = content as? CydiaApp {
                let cat = !cydia.categoryName.isEmpty ? cydia.categoryName : API.categoryFromId(id: cydia.categoryId.description, type: .cydia)
                if !cat.isEmpty {
                    badgeLabel(cat)
                }
            }
        }
        .padding(.top, 2)
    }

    private func badgeLabel(_ text: String) -> some SwiftUI.View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(SColor.gray, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    // MARK: - Tweaked Notice

    private func tweakedNotice(_ content: Item) -> some SwiftUI.View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tweaked Version Notice".localized(), systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
            Text("This app is a tweaked version. Please make sure you trust the source before installing.".localized())
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("See Original".localized()) {
                let type: ItemType = content.itemOriginalSection.isEmpty ? .ios : .cydia
                onOriginalApp(type, content.itemOriginalTrackid)
            }
            .font(.caption)
            .fontWeight(.medium)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SColor.orange.opacity(0.08))
    }

    // MARK: - Info Pills

    private func infoPillsSection(_ content: Item) -> some SwiftUI.View {
        let pills = buildInfoPills(content)
        return Group {
            if !pills.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(pills.enumerated()), id: \.offset) { index, pill in
                            if index > 0 {
                                Divider()
                                    .frame(height: 36)
                                    .padding(.horizontal, 4)
                            }
                            infoPillView(pill)
                                .frame(minWidth: 80)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 12)
            }
        }
    }

    private func infoPillView(_ pill: InfoPillData) -> some SwiftUI.View {
        VStack(spacing: 3) {
            Text(pill.header)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if let icon = pill.icon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                Text(pill.value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if let footer = pill.footer {
                Text(footer)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Screenshots

    private func screenshotsSection(_ screenshots: [Screenshot]) -> some SwiftUI.View {
        let allLandscape = screenshots.allSatisfy { $0.class_ == "landscape" }
        let classes = Set(screenshots.map { $0.class_ })
        let mixedClasses = classes.count > 1
        let screenshotHeight: CGFloat = allLandscape ? 210 : 350

        return VStack(alignment: .leading, spacing: 10) {
            Text("Preview".localized())
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(screenshots.enumerated()), id: \.offset) { index, screenshot in
                        let isLandscape = screenshot.class_ == "landscape"
                        let width: CGFloat = isLandscape ? screenshotHeight * 1.78 : screenshotHeight * 0.462

                        AsyncImage(url: URL(string: screenshot.image)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            default:
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(SColor(.systemGray5))
                            }
                        }
                        .frame(width: width, height: screenshotHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(SColor(.separator), lineWidth: 0.5)
                        )
                        .onTapGesture {
                            let magic: CGFloat = {
                                let types = Set(screenshots.map { $0.type })
                                if types == Set(["ipad"]) { return 1.775 }
                                return allLandscape ? 0 : 1.333
                            }()
                            onScreenshotTap(index, allLandscape, mixedClasses, magic)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollTargetBehavior(.viewAligned)
        }
        .padding(.vertical, 14)
    }

    // MARK: - What's New

    private func whatsNewSection(_ content: Item) -> some SwiftUI.View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("What's New".localized())
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                if !content.itemVersion.isEmpty {
                    Text("Version".localized() + " " + content.itemVersion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !content.itemUpdatedDate.isEmpty {
                Text(content.itemUpdatedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(content.itemChangelog.decoded)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(changelogExpanded ? nil : 3)

            if !changelogExpanded {
                Button("more".localized()) {
                    withAnimation(.easeInOut(duration: 0.25)) { changelogExpanded = true }
                }
                .font(.subheadline)
                .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Description

    private func descriptionSection(_ content: Item) -> some SwiftUI.View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description".localized())
                .font(.title3)
                .fontWeight(.bold)

            Text(content.itemDescription.decoded)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(descExpanded ? nil : 3)

            if !descExpanded {
                Button("more".localized()) {
                    withAnimation(.easeInOut(duration: 0.25)) { descExpanded = true }
                }
                .font(.subheadline)
                .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Reviews (Books)

    private func reviewsSection(_ content: Item) -> some SwiftUI.View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ratings & Reviews".localized())
                .font(.title3)
                .fontWeight(.bold)

            if content.itemHasStars {
                HStack(spacing: 8) {
                    Text(String(format: "%.1f", content.itemNumberOfStars))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    VStack(alignment: .leading, spacing: 2) {
                        starsView(rating: content.itemNumberOfStars)
                        Text("\(content.itemRating) " + "Ratings".localized())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(Array(content.itemReviews.prefix(5).enumerated()), id: \.offset) { _, review in
                reviewCard(review)
            }

            Text("Reviews are from Apple's iTunes Store ©".localized())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func reviewCard(_ review: Review) -> some SwiftUI.View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(review.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
                starsView(rating: review.rating, size: 10)
            }
            Text(review.author)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(review.text)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(4)
        }
        .padding(12)
        .background(SColor(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Information

    private func informationSection(_ rows: [(String, String)]) -> some SwiftUI.View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Information".localized())
                .font(.title3)
                .fontWeight(.bold)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top) {
                    Text(row.0.localized())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 110, alignment: .leading)
                    Text(row.1)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Download Stats

    private func downloadStatsSection(_ content: Item) -> some SwiftUI.View {
        let line1: String = content.downloadsDay + " " + "today".localized()
            + " · " + content.downloadsWeek + " " + "this week".localized()
            + " · " + content.downloadsMonth + " " + "this month".localized()
        let line2: String = content.downloadsYear + " " + "this year".localized()
            + " · " + content.downloadsAll + " " + "total".localized()

        return VStack(alignment: .leading, spacing: 6) {
            Text("Downloads".localized())
                .font(.title3)
                .fontWeight(.bold)

            Text(line1)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(line2)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Previous Versions

    private var previousVersionsRow: some SwiftUI.View {
        Button { onPreviousVersions() } label: {
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text("Previous Versions".localized())
                    .font(.subheadline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Related

    private func relatedSection(_ content: Item) -> some SwiftUI.View {
        let title = state.contentType == .books ? "Related Books".localized() : "Related Apps".localized()
        return VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(content.itemRelatedContent.enumerated()), id: \.offset) { _, related in
                        relatedCell(related)
                            .onTapGesture { onRelatedTap(related.id) }
                            .contextMenu {
                                Button {
                                    onRelatedTap(related.id)
                                } label: {
                                    Label("View".localized(), systemImage: "eye")
                                }
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollTargetBehavior(.viewAligned)
        }
        .padding(.vertical, 14)
    }

    private func relatedCell(_ item: RelatedContent) -> some SwiftUI.View {
        VStack(alignment: .leading, spacing: 5) {
            AsyncImage(url: URL(string: item.icon)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Image("placeholderIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .frame(width: 73, height: 73)
            .clipShape(RoundedRectangle(cornerRadius: 73 / 4.2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 73 / 4.2, style: .continuous)
                    .stroke(SColor(.separator), lineWidth: 0.5)
            )

            Text(item.name)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(width: 73, alignment: .leading)

            Text(item.artist)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 73, alignment: .leading)
        }
        .frame(width: 73)
    }

    // MARK: - External Links

    @ViewBuilder
    private func externalLinksSection(_ content: Item) -> some SwiftUI.View {
        VStack(spacing: 0) {
            if let app = content as? App {
                sectionDivider
                externalLinkRow(title: "Developer Apps".localized()) {
                    onDeveloperTap(app.seller, state.contentType, app.artistId.description)
                }
                if !app.website.isEmpty {
                    sectionDivider
                    externalLinkRow(title: "Developer Website".localized()) {
                        onExternalLink(app.website)
                    }
                }
                if !app.support.isEmpty {
                    sectionDivider
                    externalLinkRow(title: "Developer Support".localized()) {
                        onExternalLink(app.support)
                    }
                }
            }

            if let book = content as? Book {
                sectionDivider
                externalLinkRow(title: "More by this author".localized()) {
                    onDeveloperTap(book.author, state.contentType, book.artistId.description)
                }
            }
        }
    }

    private func externalLinkRow(title: String, action: @escaping () -> Void) -> some SwiftUI.View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Publisher

    @ViewBuilder
    private func publisherSection(_ content: Item) -> some SwiftUI.View {
        let publisher: String = {
            if let app = content as? App, !app.publisher.isEmpty { return app.publisher }
            if let cydia = content as? CydiaApp { return "© " + cydia.developer }
            if let book = content as? Book {
                return !book.publisher.isEmpty ? book.publisher : "© " + book.author
            }
            if let alt = content as? AltStoreApp { return "© " + alt.developer }
            return ""
        }()

        if !publisher.isEmpty {
            Text(publisher)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 4)
        }
    }

    // MARK: - Helpers

    private var sectionDivider: some SwiftUI.View {
        Divider()
            .padding(.horizontal, 20)
    }

    private var iconSize: CGFloat { Global.isIpad ? 120 : 100 }

    private func starsView(rating: Double, size: CGFloat = 14) -> some SwiftUI.View {
        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: starName(for: index, rating: rating))
                    .font(.system(size: size))
                    .foregroundStyle(.orange)
            }
        }
    }

    private func starName(for index: Int, rating: Double) -> String {
        let threshold = Double(index) + 1
        if rating >= threshold { return "star.fill" }
        if rating >= threshold - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }

    private func hasDownloadStats(_ content: Item) -> Bool {
        content is App || content is CydiaApp || content is Book
    }

    // MARK: - Info Pills Builder

    private func buildInfoPills(_ content: Item) -> [InfoPillData] {
        var pills: [InfoPillData] = []

        if content.itemHasStars {
            pills.append(InfoPillData(
                header: content.itemRating + " " + "Ratings".localized(),
                value: String(format: "%.1f", content.itemNumberOfStars),
                icon: nil,
                footer: nil
            ))
        }

        if !content.itemRated.isEmpty {
            pills.append(InfoPillData(header: "Age".localized(), value: content.itemRated, icon: nil, footer: nil))
        }

        if !content.itemCategoryName.isEmpty {
            pills.append(InfoPillData(header: "Category".localized(), value: content.itemCategoryName, icon: "square.grid.2x2", footer: nil))
        }

        if !content.itemSize.isEmpty {
            pills.append(InfoPillData(header: "Size".localized(), value: content.itemSize, icon: nil, footer: nil))
        }

        if !content.itemCompatibility.isEmpty {
            pills.append(InfoPillData(header: "Compatibility".localized(), value: "", icon: "iphone", footer: content.itemCompatibility))
        }

        if !content.itemPrice.isEmpty {
            pills.append(InfoPillData(header: "Price".localized(), value: content.itemPrice, icon: nil, footer: nil))
        }

        if !content.itemLanguages.isEmpty {
            let firstLang = content.itemLanguages.components(separatedBy: ", ").first ?? content.itemLanguages
            let count = content.itemLanguages.components(separatedBy: ", ").count
            let footer = count > 1 ? "+ \(count - 1) " + "More".localized() : nil
            pills.append(InfoPillData(header: "Language".localized(), value: firstLang, icon: nil, footer: footer))
        }

        return pills
    }

    // MARK: - Information Rows Builder

    private func informationRows(_ content: Item) -> [(String, String)] {
        var rows: [(String, String)] = []

        switch state.contentType {
        case .ios:
            if let app = content as? App {
                rows.append(("Seller", app.seller))
                rows.append(("Bundle ID", app.bundleId))
                rows.append(("Category", content.itemCategoryName))
                rows.append(("Price", app.price))
                rows.append(("Updated", app.published))
                rows.append(("Version", app.version))
                rows.append(("Size", app.size))
                rows.append(("Rating", app.rated))
                rows.append(("Compatibility", app.compatibility))
                rows.append(("Languages", app.languages))
            }
        case .cydia:
            if let app = content as? CydiaApp {
                rows.append(("Developer", app.developer))
                rows.append(("Bundle ID", app.bundleId))
                rows.append(("Category", content.itemCategoryName))
                rows.append(("Price", app.price))
                rows.append(("Updated", content.itemUpdatedDate))
                rows.append(("Version", app.version))
                rows.append(("Size", app.size))
                rows.append(("Compatibility", app.compatibility))
            }
        case .books:
            if let book = content as? Book {
                rows.append(("Author", book.author))
                rows.append(("Category", content.itemCategoryName))
                rows.append(("Updated", book.published))
                rows.append(("Price", book.price))
                rows.append(("Print Length", book.printLenght))
                rows.append(("Language", book.language))
            }
        case .altstore:
            if let app = content as? AltStoreApp {
                rows.append(("Developer", app.developer))
                rows.append(("Bundle ID", app.bundleId))
                rows.append(("Size", app.formattedSize))
                rows.append(("Updated", app.updated))
                rows.append(("Version", app.version))
            }
        default:
            break
        }

        return rows.filter { !$1.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

// MARK: - Info Pill Data

private struct InfoPillData {
    let header: String
    let value: String
    let icon: String?
    let footer: String?
}


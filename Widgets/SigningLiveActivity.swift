//
//  SigningLiveActivity.swift
//  WidgetsExtension
//
//  Created on 2026-03-04.
//
//  Live Activity UI for the signing queue.
//  Only compiled in the WidgetsExtension target.
//

import ActivityKit
import SwiftUI
import WidgetKit

/// Renders the Live Activity that mirrors the tab bar accessory:
/// app icon, name, signing status, and progress / install button.
@available(iOS 16.1, *)
struct SigningLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SigningActivityAttributes.self) { context in
            // Lock Screen / Banner presentation
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    appIcon(fileName: context.attributes.appIconFileName, size: 32)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.appName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(statusText(context.state))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    trailingContent(state: context.state, linkId: context.attributes.linkId)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            } compactLeading: {
                appIcon(fileName: context.attributes.appIconFileName, size: 20)
            } compactTrailing: {
                if context.state.isReadyToInstall {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                        .frame(width: 16, height: 16)
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(width: 16, height: 16)
                }
            } minimal: {
                if context.state.isReadyToInstall {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .frame(width: 16, height: 16)
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(width: 16, height: 16)
                }
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<SigningActivityAttributes>) -> some View {
        // Tapping the activity opens the queue sheet via deep link
        Link(destination: URL(string: "appdb-ios://?action=show-queue")!) {
            HStack(spacing: 12) {
                appIcon(fileName: context.attributes.appIconFileName, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.appName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(statusText(context.state))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if context.state.isReadyToInstall {
                    installLink(linkId: context.attributes.linkId, manifestUri: context.state.manifestUri)
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(width: 22, height: 22)
                        .padding(.trailing, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Helpers

    private func statusText(_ state: SigningActivityAttributes.ContentState) -> String {
        if state.isReadyToInstall {
            return "Ready to install"
        }
        return state.status.isEmpty ? "Queued..." : state.status
    }

    /// Loads the app icon from the shared App Group container.
    /// The main app downloads the icon and writes it there before starting the activity.
    @ViewBuilder
    private func appIcon(fileName: String?, size: CGFloat) -> some View {
        let cornerRadius = size / 4.2

        if let image = loadImageFromAppGroup(named: fileName) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.quaternary)
                .frame(width: size, height: size)
        }
    }

    /// Reads a UIImage from the shared App Group container directory.
    private func loadImageFromAppGroup(named fileName: String?) -> UIImage? {
        guard let fileName,
              let containerURL = FileManager.default.containerURL(
                  forSecurityApplicationGroupIdentifier: appGroupIdentifier
              ) else { return nil }

        let fileURL = containerURL.appendingPathComponent(fileName)
        return UIImage(contentsOfFile: fileURL.path)
    }

    /// Deep link button that triggers installation via the main app.
    /// Opens `appdb-ios://?action=install-manifest&uri=<encoded>&linkId=<id>`
    @ViewBuilder
    private func installLink(linkId: String, manifestUri: String) -> some View {
        if let encoded = manifestUri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "appdb-ios://?action=install-manifest&uri=\(encoded)&linkId=\(linkId)") {
            Link(destination: url) {
                Text("Install")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private func trailingContent(state: SigningActivityAttributes.ContentState, linkId: String) -> some View {
        if state.isReadyToInstall {
            installLink(linkId: linkId, manifestUri: state.manifestUri)
        } else {
            ProgressView()
                .progressViewStyle(.circular)
                .frame(width: 22, height: 22)
        }
    }
}

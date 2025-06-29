import SwiftUI
import AppKit

struct AppSearchResultsView: View {
    let apps: [AppInfo]
    let onAppSelected: (AppInfo) -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !apps.isEmpty {
                Text("Applications")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colorScheme == .light ? .black.opacity(0.7) : .white.opacity(0.7))
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                
                LazyVStack(spacing: 4) {
                    ForEach(apps.prefix(6), id: \.path) { app in
                        AppResultRow(app: app, onAppSelected: onAppSelected)
                    }
                    
                    if apps.count > 6 {
                        Text("... and \(apps.count - 6) more")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

struct AppResultRow: View {
    let app: AppInfo
    let onAppSelected: (AppInfo) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            onAppSelected(app)
        }) {
            HStack(spacing: 12) {
                // App icon
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "app")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(colorScheme == .light ? .black : .white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let version = app.version {
                        Text("Version \(version)")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    } else {
                        Text(app.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Launch indicator
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
                    .opacity(isHovered ? 1.0 : 0.3)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.blue.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    AppSearchResultsView(
        apps: [
            AppInfo(
                name: "Safari",
                path: "/Applications/Safari.app",
                bundleIdentifier: "com.apple.Safari",
                icon: NSWorkspace.shared.icon(forFile: "/Applications/Safari.app"),
                version: "17.1"
            ),
            AppInfo(
                name: "Xcode",
                path: "/Applications/Xcode.app",
                bundleIdentifier: "com.apple.dt.Xcode",
                icon: NSWorkspace.shared.icon(forFile: "/Applications/Xcode.app"),
                version: "15.0"
            )
        ],
        onAppSelected: { _ in }
    )
    .padding()
} 

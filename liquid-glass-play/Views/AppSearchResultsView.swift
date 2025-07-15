import SwiftUI
import AppKit

struct AppSearchResultsView: View {
    let apps: [AppInfo]
    let onAppSelected: (AppInfo) -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !apps.isEmpty {
                // Section header with Spotlight-style formatting
                HStack {
                    Image(systemName: "app.badge")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Applications")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    Spacer()
                    
                    if apps.count > 6 {
                        Text("\(min(apps.count, 6)) of \(apps.count)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                // Apps list with Spotlight-style layout
                LazyVStack(spacing: 0) {
                    ForEach(Array(apps.prefix(6).enumerated()), id: \.element.path) { index, app in
                        AppResultRow(
                            app: app, 
                            onAppSelected: onAppSelected,
                            isFirst: index == 0,
                            isLast: index == min(apps.count - 1, 5)
                        )
                        
                        // Divider between items (except last)
                        if index < min(apps.count - 1, 5) {
                            Divider()
                                .padding(.leading, 64) // Align with text, not icon
                                .opacity(0.3)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .light ? 
                              Color.white.opacity(0.8) : 
                              Color.black.opacity(0.4))
                        .shadow(
                            color: colorScheme == .light ? 
                                   Color.black.opacity(0.1) : 
                                   Color.clear, 
                            radius: 8, 
                            x: 0, 
                            y: 2
                        )
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }
}

struct AppResultRow: View {
    let app: AppInfo
    let onAppSelected: (AppInfo) -> Void
    let isFirst: Bool
    let isLast: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            onAppSelected(app)
        }) {
            HStack(spacing: 12) {
                // App icon with enhanced styling
                Group {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "app.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 20))
                            )
                    }
                }
                .shadow(
                    color: colorScheme == .light ? 
                           Color.black.opacity(0.15) : 
                           Color.clear, 
                    radius: 3, 
                    x: 0, 
                    y: 1
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                
                // App info with improved typography
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(.system(size: 15, weight: .medium, design: .default))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 6) {
                        if let version = app.version {
                            Text("Version \(version)")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Text("Application")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    .lineLimit(1)
                }
                
                Spacer()
                
                // Enhanced launch indicator
                HStack(spacing: 4) {
                    if isHovered {
                        Text("Open")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                    
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .opacity(isHovered ? 0.8 : 0.4)
                        .scaleEffect(isHovered ? 1.1 : 1.0)
                }
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: isFirst && isLast ? 12 : 0)
                    .fill(isHovered ? 
                          (colorScheme == .light ? Color.blue.opacity(0.08) : Color.blue.opacity(0.15)) : 
                          Color.clear)
                    .clipShape(
                        .rect(
                            topLeadingRadius: isFirst ? 12 : 0,
                            bottomLeadingRadius: isLast ? 12 : 0,
                            bottomTrailingRadius: isLast ? 12 : 0,
                            topTrailingRadius: isFirst ? 12 : 0
                        )
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
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
            ),
            AppInfo(
                name: "Final Cut Pro",
                path: "/Applications/Final Cut Pro.app",
                bundleIdentifier: "com.apple.FinalCut",
                icon: NSWorkspace.shared.icon(forFile: "/Applications/Final Cut Pro.app"),
                version: "10.7"
            )
        ],
        onAppSelected: { _ in }
    )
    .padding()
    .background(Color(NSColor.controlBackgroundColor))
} 

import SwiftUI
import AppKit

struct AppLauncherGridView: View {
    let apps: [UniversalSearchResult]
    let onAppSelected: (UniversalSearchResult) -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    // Demo categories (simple heuristics)
    private var groupedApps: [(title: String, apps: [UniversalSearchResult])]{
        let suggestions = ["Safari", "Google Chrome", "Xcode", "Cursor", "Microsoft Word", "Notion"]
        let productivity = ["Todoist", "Preview", "Microsoft Excel", "Calendar", "Terminal"]
        let devTools = ["Screen Studio", "Docker", "Claude", "Windsurf", "Discord"]
        
        func filter(_ names: [String]) -> [UniversalSearchResult] {
            apps.filter { names.contains($0.name) }
        }
        
        let suggestionsGroup = (title: "Suggestions", apps: filter(suggestions))
        let productivityGroup = (title: "Productivity & Finance", apps: filter(productivity))
        let devToolsGroup = (title: "Developer Tools", apps: filter(devTools))
        
        // Fallback: all others
        let used = Set(suggestions + productivity + devTools)
        let others = apps.filter { !used.contains($0.name) }
        let othersGroup = (title: "Other Apps", apps: others)
        
        return [suggestionsGroup, productivityGroup, devToolsGroup, othersGroup].filter { !$0.apps.isEmpty }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groupedApps.enumerated()), id: \.element.title) { index, group in
                SectionHeader(
                    title: group.title, 
                    showMore: group.apps.count > 5,
                    isFirst: index == 0
                )
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 20) {
                        ForEach(group.apps.prefix(5), id: \.path) { app in
                            AppIconButton(app: app, onTap: { onAppSelected(app) })
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                
                // Refined divider (except for last section)
                if index < groupedApps.count - 1 {
                    Divider()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .opacity(0.2)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .light ? 
                      Color.white.opacity(0.85) : 
                      Color.black.opacity(0.6))
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .shadow(
                    color: colorScheme == .light ? 
                           Color.black.opacity(0.1) : 
                           Color.clear, 
                    radius: 12, 
                    x: 0, 
                    y: 4
                )
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

private struct SectionHeader: View {
    let title: String
    let showMore: Bool
    let isFirst: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Icon for section type
            Image(systemName: sectionIcon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            Spacer()
            
            if showMore {
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Text("Show More")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    // Add subtle hover effect
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, isFirst ? 16 : 12)
        .padding(.bottom, 8)
    }
    
    private var sectionIcon: String {
        switch title {
        case "Suggestions":
            return "star.fill"
        case "Productivity & Finance":
            return "briefcase.fill"
        case "Developer Tools":
            return "hammer.fill"
        default:
            return "folder.fill"
        }
    }
}

private struct AppIconButton: View {
    let app: UniversalSearchResult
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 10) {
            Button(action: onTap) {
                Group {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 56, height: 56)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "app.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .shadow(
                    color: colorScheme == .light ? 
                           Color.black.opacity(0.15) : 
                           Color.clear, 
                    radius: isHovered ? 8 : 4, 
                    x: 0, 
                    y: isHovered ? 4 : 2
                )
                .scaleEffect(isPressed ? 0.9 : (isHovered ? 1.05 : 1.0))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
            }
            .buttonStyle(.plain)
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
            
            Text(app.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 72, height: 32)
                .opacity(isHovered ? 0.8 : 1.0)
                .scaleEffect(isHovered ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .frame(width: 80)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? 
                      (colorScheme == .light ? Color.blue.opacity(0.05) : Color.blue.opacity(0.1)) : 
                      Color.clear)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        )
    }
}

#if DEBUG
struct AppLauncherGridView_Previews: PreviewProvider {
    static var previews: some View {
        let demoApps = [
            UniversalSearchResult(name: "Safari", path: "/Applications/Safari.app", category: .applications, icon: NSWorkspace.shared.icon(forFile: "/Applications/Safari.app"), size: nil, modifiedDate: nil, type: "Application", bundleIdentifier: nil, relevanceScore: nil),
            UniversalSearchResult(name: "Google Chrome", path: "/Applications/Google Chrome.app", category: .applications, icon: NSWorkspace.shared.icon(forFile: "/Applications/Google Chrome.app"), size: nil, modifiedDate: nil, type: "Application", bundleIdentifier: nil, relevanceScore: nil),
            UniversalSearchResult(name: "Xcode", path: "/Applications/Xcode.app", category: .applications, icon: NSWorkspace.shared.icon(forFile: "/Applications/Xcode.app"), size: nil, modifiedDate: nil, type: "Application", bundleIdentifier: nil, relevanceScore: nil),
            UniversalSearchResult(name: "Cursor", path: "/Applications/Cursor.app", category: .applications, icon: NSWorkspace.shared.icon(forFile: "/Applications/Cursor.app"), size: nil, modifiedDate: nil, type: "Application", bundleIdentifier: nil, relevanceScore: nil),
            UniversalSearchResult(name: "Microsoft Word", path: "/Applications/Microsoft Word.app", category: .applications, icon: NSWorkspace.shared.icon(forFile: "/Applications/Microsoft Word.app"), size: nil, modifiedDate: nil, type: "Application", bundleIdentifier: nil, relevanceScore: nil),
            UniversalSearchResult(name: "Notion", path: "/Applications/Notion.app", category: .applications, icon: NSWorkspace.shared.icon(forFile: "/Applications/Notion.app"), size: nil, modifiedDate: nil, type: "Application", bundleIdentifier: nil, relevanceScore: nil),
            UniversalSearchResult(name: "Todoist", path: "/Applications/Todoist.app", category: .applications, icon: NSWorkspace.shared.icon(forFile: "/Applications/Todoist.app"), size: nil, modifiedDate: nil, type: "Application", bundleIdentifier: nil, relevanceScore: nil),
            UniversalSearchResult(name: "Preview", path: "/Applications/Preview.app", category: .applications, icon: NSWorkspace.shared.icon(forFile: "/Applications/Preview.app"), size: nil, modifiedDate: nil, type: "Application", bundleIdentifier: nil, relevanceScore: nil),
            UniversalSearchResult(name: "Microsoft Excel", path: "/Applications/Microsoft Excel.app", category: .applications, icon: NSWorkspace.shared.icon(forFile: "/Applications/Microsoft Excel.app"), size: nil, modifiedDate: nil, type: "Application", bundleIdentifier: nil, relevanceScore: nil),
            UniversalSearchResult(name: "Calendar", path: "/Applications/Calendar.app", category: .applications, icon: NSWorkspace.shared.icon(forFile: "/Applications/Calendar.app"), size: nil, modifiedDate: nil, type: "Application", bundleIdentifier: nil, relevanceScore: nil),
            UniversalSearchResult(name: "Terminal", path: "/Applications/Terminal.app", category: .applications, icon: NSWorkspace.shared.icon(forFile: "/Applications/Terminal.app"), size: nil, modifiedDate: nil, type: "Application", bundleIdentifier: nil, relevanceScore: nil),
            UniversalSearchResult(name: "Screen Studio", path: "/Applications/Screen Studio.app", category: .applications, icon: NSWorkspace.shared.icon(forFile: "/Applications/Screen Studio.app"), size: nil, modifiedDate: nil, type: "Application", bundleIdentifier: nil, relevanceScore: nil),
            UniversalSearchResult(name: "Docker", path: "/Applications/Docker.app", category: .applications, icon: NSWorkspace.shared.icon(forFile: "/Applications/Docker.app"), size: nil, modifiedDate: nil, type: "Application", bundleIdentifier: nil, relevanceScore: nil),
            UniversalSearchResult(name: "Claude", path: "/Applications/Claude.app", category: .applications, icon: NSWorkspace.shared.icon(forFile: "/Applications/Claude.app"), size: nil, modifiedDate: nil, type: "Application", bundleIdentifier: nil, relevanceScore: nil),
            UniversalSearchResult(name: "Windsurf", path: "/Applications/Windsurf.app", category: .applications, icon: NSWorkspace.shared.icon(forFile: "/Applications/Windsurf.app"), size: nil, modifiedDate: nil, type: "Application", bundleIdentifier: nil, relevanceScore: nil),
            UniversalSearchResult(name: "Discord", path: "/Applications/Discord.app", category: .applications, icon: NSWorkspace.shared.icon(forFile: "/Applications/Discord.app"), size: nil, modifiedDate: nil, type: "Application", bundleIdentifier: nil, relevanceScore: nil)
        ]
        
        Group {
            // Light mode preview
            AppLauncherGridView(apps: demoApps, onAppSelected: { _ in })
                .frame(width: 600, height: 420)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white.opacity(0.05)]), 
                        startPoint: .top, 
                        endPoint: .bottom
                    )
                )
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            // Dark mode preview
            AppLauncherGridView(apps: demoApps, onAppSelected: { _ in })
                .frame(width: 600, height: 420)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.black.opacity(0.3)]), 
                        startPoint: .top, 
                        endPoint: .bottom
                    )
                )
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
#endif 

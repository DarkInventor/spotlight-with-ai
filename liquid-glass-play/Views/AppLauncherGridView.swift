import SwiftUI
import AppKit

struct AppLauncherGridView: View {
    let apps: [UniversalSearchResult]
    let onAppSelected: (UniversalSearchResult) -> Void
    
    // Demo categories (simple heuristics)
    private var groupedApps: [(title: String, apps: [UniversalSearchResult])]{
        let suggestions = ["Google Chrome", "Xcode", "Cursor", "Microsoft Word", "Notion"]
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
            ForEach(groupedApps, id: \.title) { group in
                SectionHeader(title: group.title, showMore: group.apps.count > 5)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 28) {
                        ForEach(group.apps.prefix(5), id: \.path) { app in
                            AppIconButton(app: app, onTap: { onAppSelected(app) })
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
                Divider().opacity(0.12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white.opacity(0.25))
                .background(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .padding(16)
    }
}

private struct SectionHeader: View {
    let title: String
    let showMore: Bool
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
            if showMore {
                Button("Show More") {}
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 2)
    }
}

private struct AppIconButton: View {
    let app: UniversalSearchResult
    let onTap: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            Button(action: onTap) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 54, height: 54)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 54, height: 54)
                        .overlay(
                            Image(systemName: "app")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                        )
                }
            }
            .buttonStyle(.plain)
            Text(app.name)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 64)
        }
    }
}

#if DEBUG
struct AppLauncherGridView_Previews: PreviewProvider {
    static var previews: some View {
        let demoApps = [
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
        AppLauncherGridView(apps: demoApps, onAppSelected: { _ in })
            .frame(width: 600, height: 420)
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.18), Color.white.opacity(0.12)]), startPoint: .top, endPoint: .bottom)
            )
    }
}
#endif 

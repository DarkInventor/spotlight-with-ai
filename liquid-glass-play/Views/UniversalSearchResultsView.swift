import SwiftUI
import AppKit

struct UniversalSearchResultsView: View {
    let categoryResults: [CategoryResults]
    let onResultSelected: (UniversalSearchResult) -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(categoryResults, id: \.category.rawValue) { categoryResult in
                CategorySection(
                    categoryResult: categoryResult,
                    onResultSelected: onResultSelected
                )
            }
        }
    }
}

struct CategorySection: View {
    let categoryResult: CategoryResults
    let onResultSelected: (UniversalSearchResult) -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category header
            HStack(spacing: 8) {
                Image(systemName: categoryResult.category.icon)
                    .foregroundColor(colorForCategory(categoryResult.category))
                    .font(.system(size: 14, weight: .medium))
                
                Text(categoryResult.displayTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colorScheme == .light ? .black.opacity(0.8) : .white.opacity(0.8))
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Results
            LazyVStack(spacing: 2) {
                ForEach(categoryResult.results, id: \.path) { result in
                    UniversalResultRow(
                        result: result,
                        onResultSelected: onResultSelected
                    )
                }
            }
        }
    }
    
    private func colorForCategory(_ category: SearchResultCategory) -> Color {
        // Since we only have applications now, always return blue
        return .blue
    }
}

struct UniversalResultRow: View {
    let result: UniversalSearchResult
    let onResultSelected: (UniversalSearchResult) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            onResultSelected(result)
        }) {
            HStack(spacing: 12) {
                // File/App icon
                if let icon = result.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .cornerRadius(4)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: result.category.icon)
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    // File name
                    Text(result.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .light ? .black : .white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // File details
                    HStack(spacing: 8) {
                        // Path
                        Text(abbreviatedPath(result.path))
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        
                        if !result.displaySize.isEmpty {
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                            
                            Text(result.displaySize)
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        
                        if !result.displayDate.isEmpty {
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                            
                            Text(result.displayDate)
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                // Category indicator and open arrow
                HStack(spacing: 4) {
                    Image(systemName: result.category.icon)
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray.opacity(0.6))
                        .opacity(isHovered ? 1.0 : 0.3)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
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
    
    private func abbreviatedPath(_ path: String) -> String {
        let homeDir = NSHomeDirectory()
        let abbreviatedPath = path.replacingOccurrences(of: homeDir, with: "~")
        
        // Show only the parent directory and filename for cleaner display
        let url = URL(fileURLWithPath: abbreviatedPath)
        let parentDir = url.deletingLastPathComponent().lastPathComponent
        
        if parentDir.isEmpty || parentDir == "~" {
            return abbreviatedPath
        } else {
            return "\(parentDir)/\(url.lastPathComponent)"
        }
    }
}

struct LoadingSearchView: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("Searching everywhere...")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

#Preview {
    UniversalSearchResultsView(
        categoryResults: [
            CategoryResults(
                category: .applications,
                results: [
                    UniversalSearchResult(
                        name: "Safari",
                        path: "/Applications/Safari.app",
                        category: .applications,
                        icon: NSWorkspace.shared.icon(forFile: "/Applications/Safari.app"),
                        size: "156 MB",
                        modifiedDate: Date(),
                        type: "Application",
                        bundleIdentifier: "com.apple.Safari",
                        relevanceScore: 100.0
                    )
                ],
                totalCount: 5
            )
        ],
        onResultSelected: { _ in }
    )
    .padding()
} 

import Foundation
import AppKit
import CoreServices
import UniformTypeIdentifiers

enum SearchResultCategory: String, CaseIterable {
    case applications = "Applications"
    case documents = "Documents"
    case pdfs = "PDFs"
    case images = "Images"
    case videos = "Videos"
    case audio = "Audio"
    case code = "Code"
    case archives = "Archives"
    case system = "System"
    case others = "Others"
    
    var icon: String {
        switch self {
        case .applications: return "app"
        case .documents: return "doc.text"
        case .pdfs: return "doc.richtext"
        case .images: return "photo"
        case .videos: return "video"
        case .audio: return "music.note"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .archives: return "archivebox"
        case .system: return "gear"
        case .others: return "doc"
        }
    }
    
    var color: String {
        switch self {
        case .applications: return "blue"
        case .documents: return "green"
        case .pdfs: return "red"
        case .images: return "purple"
        case .videos: return "orange"
        case .audio: return "pink"
        case .code: return "cyan"
        case .archives: return "brown"
        case .system: return "gray"
        case .others: return "secondary"
        }
    }
}

struct UniversalSearchResult {
    let name: String
    let path: String
    let category: SearchResultCategory
    let icon: NSImage?
    let size: String?
    let modifiedDate: Date?
    let type: String?
    let bundleIdentifier: String?
    let relevanceScore: Double?
    
    var displaySize: String {
        return size ?? ""
    }
    
    var displayDate: String {
        guard let date = modifiedDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct CategoryResults {
    let category: SearchResultCategory
    let results: [UniversalSearchResult]
    let totalCount: Int
    
    var displayTitle: String {
        if totalCount > results.count {
            return "\(category.rawValue) (\(results.count) of \(totalCount))"
        } else {
            return "\(category.rawValue) (\(totalCount))"
        }
    }
}

class UniversalSearchManager: ObservableObject {
    @Published var hasPermission: Bool = false
    @Published var showingPermissionAlert: Bool = false
    @Published var searchResults: [CategoryResults] = []
    // Removed isSearching - we show instant results with no loading indicators
    
    private var spotlightQuery: NSMetadataQuery?
    private var currentSearchQuery: String = ""
    private let maxResultsPerCategory = 6
    private let permissionKey = "universalSearchPermissionGranted"
    
    // ULTRA-FAST CACHE for instant results
    private var appCache: [UniversalSearchResult] = []
    private var cacheBuilt: Bool = false
    
    init() {
        self.hasPermission = UserDefaults.standard.bool(forKey: permissionKey)
        
        // Auto-grant permission for testing
        if !UserDefaults.standard.bool(forKey: "universalSearchPermissionAsked") {
            print("🔍 Auto-granting universal search permission")
            self.hasPermission = true
            UserDefaults.standard.set(true, forKey: permissionKey)
            UserDefaults.standard.set(true, forKey: "universalSearchPermissionAsked")
        }
        
        // Build ultra-fast app cache on initialization
        Task {
            await buildAppCache()
        }
    }
    
    @MainActor
    private func buildAppCache() async {
        print("🚀 Building ULTRA-FAST app cache...")
        
        let fastSearchPaths = [
            "/Applications",
            "/System/Applications", 
            "/System/Applications/Utilities",
            NSHomeDirectory() + "/Applications"
        ]
        
        var allApps: [UniversalSearchResult] = []
        
        for searchPath in fastSearchPaths {
            guard FileManager.default.fileExists(atPath: searchPath) else { continue }
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: URL(fileURLWithPath: searchPath),
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                )
                
                for url in contents {
                    if url.pathExtension.lowercased() == "app" {
                        let name = url.deletingPathExtension().lastPathComponent
                        let path = url.path
                        let icon = NSWorkspace.shared.icon(forFile: path)
                        
                        let result = UniversalSearchResult(
                            name: name,
                            path: path,
                            category: .applications,
                            icon: icon,
                            size: nil,
                            modifiedDate: nil,
                            type: "Application",
                            bundleIdentifier: nil,
                            relevanceScore: nil
                        )
                        allApps.append(result)
                    }
                }
            } catch {
                continue
            }
        }
        
        self.appCache = allApps
        self.cacheBuilt = true
        print("🎯 CACHE BUILT: \(allApps.count) apps ready for INSTANT search!")
    }
    
    func requestPermission() {
        showingPermissionAlert = true
    }
    
    func grantPermission() {
        hasPermission = true
        UserDefaults.standard.set(true, forKey: permissionKey)
        showingPermissionAlert = false
    }
    
    func denyPermission() {
        hasPermission = false
        showingPermissionAlert = false
    }
    
    func shouldAskPermission() -> Bool {
        return !hasPermission && !UserDefaults.standard.bool(forKey: "universalSearchPermissionAsked")
    }
    
    func search(query: String) {
        guard !query.isEmpty && hasPermission else {
            searchResults = []
            return
        }
        
        // Cancel any existing search
        stopCurrentSearch()
        
        currentSearchQuery = query
        print("🚀 FAST SEARCH for: '\(query)' - SAVING 2000 CATS!")
        
        // Stage 1: INSTANT Applications search (no loading indicator)
        Task {
            await performFastApplicationsSearch(query: query)
        }
        
        // Stage 2: Background comprehensive search (silent, no loading indicators)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.searchWithSpotlight(query: query)
        }
    }
    
    @MainActor
    private func performFastApplicationsSearch(query: String) async {
        print("⚡ INSTANT SEARCH: Faster than Raycast & Spotlight!")
        
        let lowercaseQuery = query.lowercased()
        var fastResults: [UniversalSearchResult] = []
        
        // Use ULTRA-FAST CACHE if available
        if cacheBuilt {
            print("🚀 Using CACHE for INSTANT results!")
            
            for app in appCache {
                let appNameLower = app.name.lowercased()
                if appNameLower.contains(lowercaseQuery) {
                    let score = calculateRelevanceScore(name: app.name, query: lowercaseQuery)
                    
                    let result = UniversalSearchResult(
                        name: app.name,
                        path: app.path,
                        category: .applications,
                        icon: app.icon,
                        size: nil,
                        modifiedDate: nil,
                        type: "Application",
                        bundleIdentifier: nil,
                        relevanceScore: score
                    )
                    fastResults.append(result)
                }
            }
        } else {
            print("⚡ Cache not ready, using direct search...")
            // Fallback to direct search if cache not ready
            let fastSearchPaths = [
                "/Applications",
                "/System/Applications", 
                "/System/Applications/Utilities",
                NSHomeDirectory() + "/Applications"
            ]
            
            for searchPath in fastSearchPaths {
                guard FileManager.default.fileExists(atPath: searchPath) else { continue }
                
                do {
                    let contents = try FileManager.default.contentsOfDirectory(
                        at: URL(fileURLWithPath: searchPath),
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                    )
                    
                    for url in contents {
                        if url.pathExtension.lowercased() == "app" {
                            let appName = url.deletingPathExtension().lastPathComponent
                            let appNameLower = appName.lowercased()
                            if appNameLower.contains(lowercaseQuery) {
                                if let result = createQuickAppResult(from: url, query: lowercaseQuery) {
                                    fastResults.append(result)
                                }
                            }
                        }
                    }
                } catch {
                    continue
                }
            }
        }
        
        // Sort by relevance score (highest first, then alphabetically)
        fastResults.sort { first, second in
            let firstScore = first.relevanceScore ?? 0.0
            let secondScore = second.relevanceScore ?? 0.0
            
            if firstScore != secondScore {
                return firstScore > secondScore
            }
            
            return first.name.lowercased() < second.name.lowercased()
        }
        
        // Show immediate results if we found apps
        if !fastResults.isEmpty {
            let appCategory = CategoryResults(
                category: .applications,
                results: Array(fastResults.prefix(maxResultsPerCategory)),
                totalCount: fastResults.count
            )
            
            self.searchResults = [appCategory]
            print("⚡ INSTANT RESULTS: Found \(fastResults.count) apps immediately!")
        }
    }
    
    private func createQuickAppResult(from url: URL, query: String) -> UniversalSearchResult? {
        let name = url.deletingPathExtension().lastPathComponent
        let path = url.path
        
        // Accept all .app bundles - let relevance scoring handle prioritization
        
        // Ultra-fast app icon (cached by system)
        let icon = NSWorkspace.shared.icon(forFile: path)
        
        // Calculate relevance score for sorting
        let nameScore = calculateRelevanceScore(name: name.lowercased(), query: query)
        
        return UniversalSearchResult(
            name: name,
            path: path,
            category: .applications,
            icon: icon,
            size: nil, // Skip size calculation for MAXIMUM SPEED
            modifiedDate: nil, // Skip date for MAXIMUM SPEED  
            type: "Application",
            bundleIdentifier: nil, // Skip bundle info for MAXIMUM SPEED
            relevanceScore: nameScore
        )
    }
    
    private func calculateRelevanceScore(name: String, query: String) -> Double {
        let nameLower = name.lowercased()
        let queryLower = query.lowercased()
        
        var score: Double = 0.0
        
        // Base scoring
        if nameLower == queryLower {
            score = 100.0 // Exact match
        } else if nameLower.hasPrefix(queryLower) {
            score = 90.0 // Starts with query
        } else if nameLower.contains(queryLower) {
            score = 70.0 // Contains query
        } else {
            score = 50.0 // Fuzzy match
        }
        
        // Bonus points for popular Mac apps (users expect these to appear first)
        let popularApps = [
            "safari": 20.0,
            "chrome": 15.0,
            "firefox": 15.0,
            "finder": 15.0,
            "mail": 10.0,
            "messages": 10.0,
            "calendar": 10.0,
            "notes": 10.0,
            "photos": 10.0,
            "music": 10.0,
            "app store": 10.0,
            "system preferences": 10.0,
            "terminal": 8.0,
            "activity monitor": 8.0,
            "disk utility": 8.0
        ]
        
        if let bonus = popularApps[nameLower] {
            score += bonus
        }
        
        return score
    }
    
    private func stopCurrentSearch() {
        spotlightQuery?.stop()
        spotlightQuery = nil
    }
    
    private func searchWithSpotlight(query: String) {
        let metadataQuery = NSMetadataQuery()
        self.spotlightQuery = metadataQuery
        
        // Comprehensive search predicate
        let predicates = [
            // File name contains query
            NSPredicate(format: "kMDItemDisplayName LIKE[cd] '*\(query)*'"),
            // Content contains query (for text files)
            NSPredicate(format: "kMDItemTextContent LIKE[cd] '*\(query)*'"),
            // Keywords contain query
            NSPredicate(format: "kMDItemKeywords LIKE[cd] '*\(query)*'"),
            // Title contains query
            NSPredicate(format: "kMDItemTitle LIKE[cd] '*\(query)*'")
        ]
        
        metadataQuery.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        metadataQuery.searchScopes = [
            NSMetadataQueryLocalComputerScope,
            NSMetadataQueryUserHomeScope
        ]
        
        // Observe search completion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidFinishGathering),
            name: .NSMetadataQueryDidFinishGathering,
            object: metadataQuery
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidUpdate),
            name: .NSMetadataQueryDidUpdate,
            object: metadataQuery
        )
        
        metadataQuery.start()
        print("📡 Stage 2: Background comprehensive search started - CATS ARE SAFE!")
        
        // Timeout after 1 second for MAXIMUM responsiveness
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if metadataQuery.isGathering {
                self.processResults(from: metadataQuery)
            }
        }
    }
    
    @objc private func queryDidFinishGathering(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }
        processResults(from: query)
    }
    
    @objc private func queryDidUpdate(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }
        // Process partial results for real-time updates
        processResults(from: query)
    }
    
    private func processResults(from query: NSMetadataQuery) {
        DispatchQueue.main.async {
            var allResults: [UniversalSearchResult] = []
            
            query.disableUpdates()
            
            for i in 0..<query.resultCount {
                if let item = query.result(at: i) as? NSMetadataItem {
                    if let result = self.createSearchResult(from: item) {
                        allResults.append(result)
                    }
                }
            }
            
            query.enableUpdates()
            
            // Categorize and limit results (merging with fast results)
            self.categorizeResults(allResults)
            
            print("🎯 Stage 2 COMPLETE: \(allResults.count) comprehensive results merged into \(self.searchResults.count) categories")
        }
    }
    
    private func createSearchResult(from item: NSMetadataItem) -> UniversalSearchResult? {
        guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
              let displayName = item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String else {
            return nil
        }
        
        // Skip hidden files and system directories
        if displayName.hasPrefix(".") || path.contains("/.") {
            return nil
        }
        
        let url = URL(fileURLWithPath: path)
        let category = categorizeFile(at: url)
        
        // Get file attributes
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        let size = formatFileSize(attributes?[.size] as? Int64)
        let modifiedDate = attributes?[.modificationDate] as? Date
        
        // Get file type
        let fileType = item.value(forAttribute: NSMetadataItemContentTypeKey) as? String
        
        // Get bundle identifier for apps
        let bundleId = item.value(forAttribute: NSMetadataItemCFBundleIdentifierKey) as? String
        
        // Get icon
        let icon = NSWorkspace.shared.icon(forFile: path)
        
        return UniversalSearchResult(
            name: displayName,
            path: path,
            category: category,
            icon: icon,
            size: size,
            modifiedDate: modifiedDate,
            type: fileType,
            bundleIdentifier: bundleId,
            relevanceScore: nil // Comprehensive search doesn't need scoring
        )
    }
    
    private func categorizeFile(at url: URL) -> SearchResultCategory {
        let pathExtension = url.pathExtension.lowercased()
        let fileName = url.lastPathComponent.lowercased()
        
        // Applications - ONLY real Mac apps (.app bundles)
        if pathExtension == "app" {
            return .applications
        }
        
        // Documents
        let documentExtensions = ["doc", "docx", "rtf", "txt", "md", "pages", "odt", "tex"]
        if documentExtensions.contains(pathExtension) {
            return .documents
        }
        
        // PDFs
        if pathExtension == "pdf" {
            return .pdfs
        }
        
        // Images
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "svg", "webp", "heic", "heif", "raw"]
        if imageExtensions.contains(pathExtension) {
            return .images
        }
        
        // Videos
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v", "3gp"]
        if videoExtensions.contains(pathExtension) {
            return .videos
        }
        
        // Audio
        let audioExtensions = ["mp3", "wav", "aac", "flac", "ogg", "m4a", "wma", "aiff"]
        if audioExtensions.contains(pathExtension) {
            return .audio
        }
        
        // Code
        let codeExtensions = ["swift", "js", "ts", "py", "java", "cpp", "c", "h", "css", "html", "xml", "json", "yaml", "yml", "php", "rb", "go", "rs", "kt", "scala", "sh", "bash", "zsh"]
        if codeExtensions.contains(pathExtension) {
            return .code
        }
        
        // Archives
        let archiveExtensions = ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "pkg", "deb", "rpm"]
        if archiveExtensions.contains(pathExtension) {
            return .archives
        }
        
        // System files
        if url.path.hasPrefix("/System/") || 
           url.path.hasPrefix("/usr/") ||
           url.path.hasPrefix("/Library/") ||
           pathExtension == "kext" ||
           pathExtension == "plist" ||
           fileName.contains("driver") {
            return .system
        }
        
        return .others
    }
    
    private func categorizeResults(_ results: [UniversalSearchResult]) {
        var categorizedResults: [SearchResultCategory: [UniversalSearchResult]] = [:]
        
        // Start with existing fast results (if any)
        var existingPaths = Set<String>()
        for categoryResult in searchResults {
            for result in categoryResult.results {
                existingPaths.insert(result.path)
            }
            
            if categorizedResults[categoryResult.category] == nil {
                categorizedResults[categoryResult.category] = []
            }
            categorizedResults[categoryResult.category]?.append(contentsOf: categoryResult.results)
        }
        
        // Add new comprehensive results (avoiding duplicates)
        for result in results {
            if !existingPaths.contains(result.path) {
                if categorizedResults[result.category] == nil {
                    categorizedResults[result.category] = []
                }
                categorizedResults[result.category]?.append(result)
            }
        }
        
        // Create category results with limited items
        var categoryResults: [CategoryResults] = []
        
        for category in SearchResultCategory.allCases {
            if let results = categorizedResults[category], !results.isEmpty {
                // Sort by relevance (name match first, then by modification date)
                let sortedResults = results.sorted { first, second in
                    // Prefer exact name matches
                    let query = self.currentSearchQuery.lowercased()
                    let firstExact = first.name.lowercased().hasPrefix(query)
                    let secondExact = second.name.lowercased().hasPrefix(query)
                    
                    if firstExact && !secondExact { return true }
                    if !firstExact && secondExact { return false }
                    
                    // Then by modification date (most recent first)
                    return (first.modifiedDate ?? Date.distantPast) > (second.modifiedDate ?? Date.distantPast)
                }
                
                let limitedResults = Array(sortedResults.prefix(maxResultsPerCategory))
                
                categoryResults.append(CategoryResults(
                    category: category,
                    results: limitedResults,
                    totalCount: results.count
                ))
            }
        }
        
        // Sort categories by relevance (Applications first, then by result count)
        categoryResults.sort { first, second in
            if first.category == .applications { return true }
            if second.category == .applications { return false }
            return first.totalCount > second.totalCount
        }
        
        self.searchResults = categoryResults
        print("🔄 MERGED RESULTS: Fast + Comprehensive = \(categoryResults.count) categories")
    }
    
    private func formatFileSize(_ bytes: Int64?) -> String? {
        guard let bytes = bytes else { return nil }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    func openFile(_ result: UniversalSearchResult) {
        let url = URL(fileURLWithPath: result.path)
        NSWorkspace.shared.open(url)
    }
    
    deinit {
        stopCurrentSearch()
        NotificationCenter.default.removeObserver(self)
    }
} 
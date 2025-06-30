import Foundation
import AppKit
import CoreServices
import UniformTypeIdentifiers

enum SearchResultCategory: String, CaseIterable {
    case applications = "Applications"
    
    var icon: String {
        return "app"
    }
    
    var color: String {
        return "blue"
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
    
    // Removed spotlightQuery - APP SEARCH ONLY!
    private var currentSearchQuery: String = ""
    private let maxResultsPerCategory = 6
    private let permissionKey = "universalSearchPermissionGranted"
    
    // ULTRA-FAST CACHE for instant results
    private var appCache: [UniversalSearchResult] = []
    private var cacheBuilt: Bool = false
    
    init() {
        // 🐱 CAT-SAVING: FORCE ENABLE UNIVERSAL SEARCH PERMISSION!
        UserDefaults.standard.set(true, forKey: "universalSearchPermissionGranted")
        UserDefaults.standard.set(true, forKey: "universalSearchPermissionAsked")
        self.hasPermission = true
        
        // Build ultra-fast app cache on initialization
        Task {
            await buildAppCache()
        }
    }
    
    @MainActor
    private func buildAppCache() async {
        print("🚀 Building LIGHTNING-FAST app cache - ONLY APPS!")
        
        // Focus on essential app directories only
        let essentialPaths = [
            "/Applications",
            "/System/Applications"
        ]
        
        var allApps: [UniversalSearchResult] = []
        
        for searchPath in essentialPaths {
            guard FileManager.default.fileExists(atPath: searchPath) else { continue }
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: URL(fileURLWithPath: searchPath),
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                )
                
                for url in contents where url.pathExtension.lowercased() == "app" {
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
            } catch {
                continue
            }
        }
        
        self.appCache = allApps
        self.cacheBuilt = true
        print("🎯 ULTRA-FAST CACHE BUILT: \(allApps.count) essential apps ready for INSTANT search!")
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
        
        currentSearchQuery = query
        
        // LIGHTNING FAST APP-ONLY SEARCH! 🚀 NO FILES, NO FOLDERS!
        Task {
            await performUltraFastAppOnlySearch(query: query)
        }
    }
    
    @MainActor
    private func performUltraFastAppOnlySearch(query: String) async {
        print("🚀 ULTRA-FAST APP-ONLY SEARCH - NO FILES, NO FOLDERS, JUST APPS!")
        
        let lowercaseQuery = query.lowercased()
        var fastResults: [UniversalSearchResult] = []
        
        // Use ULTRA-FAST CACHE if available
        if cacheBuilt {
            print("⚡ Using CACHED apps for INSTANT results!")
            
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
            // If cache not ready, build it instantly with just essential app folders
            print("🔧 Building minimal app cache on the fly...")
            let essentialPaths = ["/Applications", "/System/Applications"]
            
            for searchPath in essentialPaths {
                guard FileManager.default.fileExists(atPath: searchPath) else { continue }
                
                do {
                    let contents = try FileManager.default.contentsOfDirectory(
                        at: URL(fileURLWithPath: searchPath),
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                    )
                    
                    for url in contents where url.pathExtension.lowercased() == "app" {
                        let appName = url.deletingPathExtension().lastPathComponent
                        if appName.lowercased().contains(lowercaseQuery) {
                            if let result = createQuickAppResult(from: url, query: lowercaseQuery) {
                                fastResults.append(result)
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
        
        // Show immediate results - APPS ONLY!
        if !fastResults.isEmpty {
            let appCategory = CategoryResults(
                category: .applications,
                results: Array(fastResults.prefix(8)), // Show more apps since we only show apps
                totalCount: fastResults.count
            )
            
            self.searchResults = [appCategory]
            print("🎯 FOUND \(fastResults.count) APPS INSTANTLY! NO FILES, NO FOLDERS!")
        } else {
            self.searchResults = []
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
    
    // REMOVED ALL HEAVY FILE/FOLDER SEARCHING! APP-ONLY SEARCH FOR MAXIMUM PERFORMANCE! 🚀
    
    // SIMPLIFIED - APP-ONLY LAUNCHER! 🚀
    func openFile(_ result: UniversalSearchResult) {
        let url = URL(fileURLWithPath: result.path)
        NSWorkspace.shared.open(url)
    }
    
    /// Search installed apps in /Applications and /System/Applications, returning results matching the query (case-insensitive, substring match).
    func searchInstalledApps(query: String) -> [UniversalSearchResult] {
        guard !query.isEmpty else { return [] }
        let lowercaseQuery = query.lowercased()
        var results: [UniversalSearchResult] = []
        let appDirs = ["/Applications", "/System/Applications"]
        for dir in appDirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: dir), includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else { continue }
            for url in contents where url.pathExtension.lowercased() == "app" {
                let name = url.deletingPathExtension().lastPathComponent
                if name.lowercased().contains(lowercaseQuery) {
                    let icon = NSWorkspace.shared.icon(forFile: url.path)
                    let result = UniversalSearchResult(
                        name: name,
                        path: url.path,
                        category: .applications,
                        icon: icon,
                        size: nil,
                        modifiedDate: nil,
                        type: "Application",
                        bundleIdentifier: nil,
                        relevanceScore: nil
                    )
                    results.append(result)
                }
            }
        }
        // Sort by name for consistency
        return results.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
} 

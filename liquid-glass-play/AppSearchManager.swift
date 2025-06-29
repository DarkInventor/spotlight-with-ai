import Foundation
import AppKit
import CoreServices

struct AppInfo {
    let name: String
    let path: String
    let bundleIdentifier: String?
    let icon: NSImage?
    let version: String?
}

class AppSearchManager: ObservableObject {
    @Published var hasPermission: Bool = false
    @Published var showingPermissionAlert: Bool = false
    @Published var foundApps: [AppInfo] = []
    @Published var isSearchingApps: Bool = false
    
    private var allApps: [AppInfo] = []
    private let permissionKey = "appSearchPermissionGranted"
    
    init() {
        self.hasPermission = UserDefaults.standard.bool(forKey: permissionKey)
        
        // For testing - automatically grant permission if not set
        if !UserDefaults.standard.bool(forKey: "appSearchPermissionAsked") {
            print("Auto-granting app search permission for testing")
            self.hasPermission = true
            UserDefaults.standard.set(true, forKey: permissionKey)
            UserDefaults.standard.set(true, forKey: "appSearchPermissionAsked")
        }
        
        if hasPermission {
            loadAllApps()
        }
    }
    
    func requestPermission() {
        showingPermissionAlert = true
    }
    
    func grantPermission() {
        hasPermission = true
        UserDefaults.standard.set(true, forKey: permissionKey)
        showingPermissionAlert = false
        loadAllApps()
    }
    
    func denyPermission() {
        hasPermission = false
        showingPermissionAlert = false
    }
    
    func shouldAskPermission() -> Bool {
        let hasAsked = UserDefaults.standard.bool(forKey: "appSearchPermissionAsked")
        print("App search - hasPermission: \(hasPermission), hasAsked: \(hasAsked)")
        return !hasPermission && !hasAsked
    }
    
    private func loadAllApps() {
        Task {
            await loadApplications()
        }
    }
    
    @MainActor
    private func loadApplications() async {
        isSearchingApps = true
        
        var apps: [AppInfo] = []
        
        print("🔍 COMPREHENSIVE APP SEARCH - SAVING 200 CATS!")
        
        // COMPREHENSIVE SEARCH - EVERY POSSIBLE LOCATION!
        let searchPaths = [
            // Standard system locations
            "/Applications",
            "/System/Applications",
            "/System/Library/CoreServices",
            "/Library/Application Support",
            "/System/Library/PreferencePanes",
            
            // User locations
            NSHomeDirectory() + "/Applications",
            NSHomeDirectory() + "/Downloads",
            NSHomeDirectory() + "/Documents",
            NSHomeDirectory() + "/Desktop",
            NSHomeDirectory() + "/Library/Application Support",
            
            // Developer locations
            "/Developer/Applications",
            "/usr/local/bin",
            
            // Additional common locations
            "/opt",
            "/usr/bin",
            "/usr/sbin"
        ]
        
        // Search each directory recursively
        for searchPath in searchPaths {
            await searchDirectoryRecursively(path: searchPath, apps: &apps)
        }
        
        // Also search entire home directory for any missed .app bundles
        print("🏠 Searching entire home directory for .app bundles...")
        await searchForAppBundles(in: NSHomeDirectory(), apps: &apps)
        
        // Search common mounted volumes
        let volumesPath = "/Volumes"
        if FileManager.default.fileExists(atPath: volumesPath) {
            do {
                let volumes = try FileManager.default.contentsOfDirectory(atPath: volumesPath)
                for volume in volumes {
                    let volumePath = "\(volumesPath)/\(volume)"
                    await searchDirectoryRecursively(path: volumePath + "/Applications", apps: &apps)
                }
            } catch {
                print("Error reading volumes: \(error)")
            }
        }
        
        // Remove duplicates based on bundle identifier and path
        var uniqueApps: [AppInfo] = []
        var seenIdentifiers: Set<String> = []
        
        for app in apps {
            let identifier = app.bundleIdentifier ?? app.path
            if !seenIdentifiers.contains(identifier) {
                seenIdentifiers.insert(identifier)
                uniqueApps.append(app)
            }
        }
        
        self.allApps = uniqueApps.sorted { $0.name.lowercased() < $1.name.lowercased() }
        self.isSearchingApps = false
        
        // Also use Spotlight to find any missed applications
        print("🔦 Using Spotlight to find additional applications...")
        let spotlightApps = await searchWithSpotlight()
        
        // Merge Spotlight results
        for spotlightApp in spotlightApps {
            let identifier = spotlightApp.bundleIdentifier ?? spotlightApp.path
            if !seenIdentifiers.contains(identifier) {
                seenIdentifiers.insert(identifier)
                uniqueApps.append(spotlightApp)
            }
        }
        
        self.allApps = uniqueApps.sorted { $0.name.lowercased() < $1.name.lowercased() }
        
        print("🎉 MISSION COMPLETE! Loaded \(self.allApps.count) applications from EVERYWHERE!")
        print("📱 Found apps in: \(Set(uniqueApps.map { URL(fileURLWithPath: $0.path).deletingLastPathComponent().path }).sorted().joined(separator: ", "))")
    }
    
    private func searchWithSpotlight() async -> [AppInfo] {
        return await withCheckedContinuation { continuation in
            let query = NSMetadataQuery()
            query.predicate = NSPredicate(format: "kMDItemContentType == 'com.apple.application-bundle' OR kMDItemContentType == 'com.apple.application'")
            query.searchScopes = [NSMetadataQueryLocalComputerScope]
            
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: query,
                queue: .main
            ) { _ in
                query.stop()
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                
                var spotlightApps: [AppInfo] = []
                
                for i in 0..<query.resultCount {
                    if let item = query.result(at: i) as? NSMetadataItem,
                       let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
                        let url = URL(fileURLWithPath: path)
                        if let appInfo = self.createAppInfo(from: url) {
                            spotlightApps.append(appInfo)
                        }
                    }
                }
                
                print("🔦 Spotlight found \(spotlightApps.count) additional applications")
                continuation.resume(returning: spotlightApps)
            }
            
            query.start()
            
            // Timeout after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if query.isGathering {
                    query.stop()
                    if let observer = observer {
                        NotificationCenter.default.removeObserver(observer)
                    }
                    print("🔦 Spotlight search timed out")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    private func searchDirectoryRecursively(path: String, apps: inout [AppInfo]) async {
        guard FileManager.default.fileExists(atPath: path) else { return }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: [.isDirectoryKey, .nameKey, .isHiddenKey],
                options: []
            )
            
            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey])
                
                // Skip hidden files and system directories that might cause issues
                if resourceValues.isHidden == true ||
                   url.lastPathComponent.hasPrefix(".") ||
                   url.lastPathComponent == "System" ||
                   url.lastPathComponent == "private" {
                    continue
                }
                
                if url.pathExtension == "app" {
                    if let appInfo = createAppInfo(from: url) {
                        apps.append(appInfo)
                    }
                } else if resourceValues.isDirectory == true &&
                         url.path.components(separatedBy: "/").count < 8 { // Limit recursion depth
                    await searchDirectoryRecursively(path: url.path, apps: &apps)
                } else {
                    // Check for executable files (command line tools, etc.)
                    if let appInfo = createAppInfo(from: url) {
                        apps.append(appInfo)
                    }
                }
            }
        } catch {
            // Silently continue - some directories may not be accessible
        }
    }
    
    private func searchForAppBundles(in directory: String, apps: inout [AppInfo]) async {
        let fileManager = FileManager.default
        
        if let enumerator = fileManager.enumerator(atPath: directory) {
            for case let path as String in enumerator {
                if path.hasSuffix(".app") {
                    let fullPath = "\(directory)/\(path)"
                    let url = URL(fileURLWithPath: fullPath)
                    
                    // Only take the .app bundle itself, not files inside it
                    if url.pathExtension == "app" {
                        if let appInfo = createAppInfo(from: url) {
                            apps.append(appInfo)
                        }
                        // Skip contents of .app bundles
                        enumerator.skipDescendants()
                    }
                }
            }
        }
    }
    
    private func createAppInfo(from url: URL) -> AppInfo? {
        let name = url.deletingPathExtension().lastPathComponent
        let path = url.path
        
        // Try to get bundle info for .app bundles
        var bundleId: String? = nil
        var version: String? = nil
        var icon: NSImage? = nil
        
        if url.pathExtension == "app" {
            let bundle = Bundle(url: url)
            bundleId = bundle?.bundleIdentifier
            version = bundle?.infoDictionary?["CFBundleShortVersionString"] as? String
            icon = NSWorkspace.shared.icon(forFile: path)
        } else {
            // For non-.app files, try to get icon and check if executable
            if isExecutableFile(at: path) {
                icon = NSWorkspace.shared.icon(forFile: path)
                // For command line tools, use the file name as version info
                version = "Command Line Tool"
            } else {
                return nil // Skip non-executable files
            }
        }
        
        return AppInfo(
            name: name,
            path: path,
            bundleIdentifier: bundleId,
            icon: icon,
            version: version
        )
    }
    
    private func isExecutableFile(at path: String) -> Bool {
        let fileManager = FileManager.default
        
        // Check if file is executable
        guard fileManager.isExecutableFile(atPath: path) else { return false }
        
        // Skip certain system files and directories
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        let skipPatterns = [".", "..", "Contents", "MacOS", "Resources", "Frameworks"]
        
        for pattern in skipPatterns {
            if fileName.hasPrefix(pattern) || fileName.contains(pattern) {
                return false
            }
        }
        
        // Check if it's a regular file (not a directory)
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
        
        return !isDirectory.boolValue
    }
    
    func searchApps(query: String) -> [AppInfo] {
        guard !query.isEmpty else { return [] }
        
        let lowercaseQuery = query.lowercased()
        
        // Multiple search strategies for maximum coverage
        var scoredResults: [(AppInfo, Int)] = []
        
        for app in allApps {
            let appName = app.name.lowercased()
            let bundleId = app.bundleIdentifier?.lowercased() ?? ""
            let path = app.path.lowercased()
            
            var score = 0
            
            // Exact name match (highest priority)
            if appName == lowercaseQuery {
                score += 1000
            }
            // Name starts with query (high priority)
            else if appName.hasPrefix(lowercaseQuery) {
                score += 500
            }
            // Name contains query (medium priority)
            else if appName.contains(lowercaseQuery) {
                score += 100
            }
            // Bundle ID contains query
            else if bundleId.contains(lowercaseQuery) {
                score += 50
            }
            // Path contains query (lowest priority)
            else if path.contains(lowercaseQuery) {
                score += 10
            }
            // Fuzzy match (character sequence)
            else if fuzzyMatch(query: lowercaseQuery, target: appName) {
                score += 25
            }
            
            if score > 0 {
                scoredResults.append((app, score))
            }
        }
        
        // Sort by score (highest first) and then by name
        let results = scoredResults
            .sorted { first, second in
                if first.1 == second.1 {
                    return first.0.name.lowercased() < second.0.name.lowercased()
                }
                return first.1 > second.1
            }
            .map { $0.0 }
        
        print("🔍 App search for '\(query)': found \(results.count) apps out of \(allApps.count) total")
        if results.count > 0 && results.count <= 5 {
            print("📱 Top results: \(results.prefix(5).map { $0.name }.joined(separator: ", "))")
        }
        
        return results
    }
    
    private func fuzzyMatch(query: String, target: String) -> Bool {
        var queryIndex = query.startIndex
        var targetIndex = target.startIndex
        
        while queryIndex < query.endIndex && targetIndex < target.endIndex {
            if query[queryIndex] == target[targetIndex] {
                queryIndex = query.index(after: queryIndex)
            }
            targetIndex = target.index(after: targetIndex)
        }
        
        return queryIndex == query.endIndex
    }
    
    func launchApp(_ app: AppInfo) {
        let url = URL(fileURLWithPath: app.path)
        NSWorkspace.shared.open(url)
    }
    
    func isAppQuery(_ query: String) -> Bool {
        // Check if the query might be looking for an app
        // This is a heuristic - you can adjust this logic
        let lowercaseQuery = query.lowercased()
        
        // Common app search indicators
        let appKeywords = ["open", "launch", "start", "run", "app", "application"]
        let containsAppKeyword = appKeywords.contains { lowercaseQuery.contains($0) }
        
        // Or if it's a short query that might be an app name
        let isShortQuery = query.count <= 20 && !query.contains(" ")
        
        // Or if we find matching apps
        let hasMatchingApps = !searchApps(query: query).isEmpty
        
        return containsAppKeyword || isShortQuery || hasMatchingApps
    }
} 

import Foundation
import SwiftUI

class MemoryManager: ObservableObject {
    @Published var hasPermission: Bool = false
    @Published var showingPermissionAlert: Bool = false
    @Published var permissionAsked: Bool = false
    
    private let baseFileName = "ai_conversation_history"
    private let maxFileSize: Int = 50000 // ~50KB limit for context window
    private var currentFileIndex: Int = 1
    
    private var currentFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("\(baseFileName)_\(currentFileIndex).md")
    }
    
    init() {
        loadPermissionState()
        findCurrentFileIndex()
    }
    
    private func loadPermissionState() {
        // Check UserDefaults for permission state
        permissionAsked = UserDefaults.standard.bool(forKey: "memoryPermissionAsked")
        hasPermission = UserDefaults.standard.bool(forKey: "memoryPermissionGranted")
    }
    
    private func savePermissionState() {
        UserDefaults.standard.set(permissionAsked, forKey: "memoryPermissionAsked")
        UserDefaults.standard.set(hasPermission, forKey: "memoryPermissionGranted")
    }
    
    private func findCurrentFileIndex() {
        guard hasPermission else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var index = 1
        
        // Find the highest numbered file
        while true {
            let fileURL = documentsPath.appendingPathComponent("\(baseFileName)_\(index).md")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                index += 1
            } else {
                break
            }
        }
        
        currentFileIndex = max(1, index - 1)
        if currentFileIndex == 0 { currentFileIndex = 1 }
    }
    
    func shouldAskPermission() -> Bool {
        return !permissionAsked
    }
    
    func requestPermission() {
        if !permissionAsked {
            showingPermissionAlert = true
        }
    }
    
    func grantPermission() {
        hasPermission = true
        permissionAsked = true
        showingPermissionAlert = false
        savePermissionState()
        createMemoryFile()
    }
    
    func denyPermission() {
        hasPermission = false
        permissionAsked = true
        showingPermissionAlert = false
        savePermissionState()
    }
    
    private func createMemoryFile() {
        let initialContent = """
        # AI Conversation History - Part \(currentFileIndex)
        
        This file contains your conversation history with the AI assistant.
        Started on: \(Date().formatted(date: .complete, time: .complete))
        
        ---
        
        """
        
        do {
            try initialContent.write(to: currentFileURL, atomically: true, encoding: .utf8)
            print("✅ Memory file created at: \(currentFileURL.path)")
        } catch {
            print("❌ Failed to create memory file: \(error)")
        }
    }
    
    private func checkAndRotateFile() {
        guard hasPermission else { return }
        
        do {
            let fileData = try Data(contentsOf: currentFileURL)
            if fileData.count > maxFileSize {
                print("📁 File size limit reached (\(fileData.count) bytes), rotating to new file")
                currentFileIndex += 1
                createMemoryFile()
            }
        } catch {
            print("❌ Failed to check file size: \(error)")
        }
    }
    
    func saveConversation(userInput: String, aiResponse: String, hasImage: Bool = false) {
        guard hasPermission else { return }
        
        // Check if we need to rotate to a new file first
        checkAndRotateFile()
        
        let timestamp = Date().formatted(date: .abbreviated, time: .shortened)
        
        // Only save text data, skip image indicator to keep file size manageable
        let conversationEntry = """
        
        ## \(timestamp)
        
        **User:** \(userInput.isEmpty ? "(Image query)" : userInput)
        
        **AI:** \(aiResponse)
        
        ---
        
        """
        
        do {
            let existingContent = try String(contentsOf: currentFileURL, encoding: .utf8)
            let updatedContent = existingContent + conversationEntry
            try updatedContent.write(to: currentFileURL, atomically: true, encoding: .utf8)
            print("💾 Conversation saved to memory (Part \(currentFileIndex))")
        } catch {
            print("❌ Failed to save conversation: \(error)")
        }
    }
    
    func loadRecentMemory(limit: Int = 5) -> String {
        guard hasPermission else { return "" }
        
        do {
            let content = try String(contentsOf: currentFileURL, encoding: .utf8)
            
            // Extract recent conversations (simple approach - split by "##" and take last entries)
            let conversations = content.components(separatedBy: "## ").suffix(limit)
            let recentMemory = conversations.joined(separator: "## ")
            
            return recentMemory.isEmpty ? "" : "Previous context:\n\(recentMemory)"
        } catch {
            // If current file doesn't exist, try to create it
            if !FileManager.default.fileExists(atPath: currentFileURL.path) {
                createMemoryFile()
            }
            print("❌ Failed to load memory: \(error)")
            return ""
        }
    }
    
    func getMemoryFilePath() -> String {
        return currentFileURL.path
    }
    
    func getCurrentFileIndex() -> Int {
        return currentFileIndex
    }
    
    func clearMemory() {
        guard hasPermission else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Remove all memory files
        var index = 1
        while true {
            let fileURL = documentsPath.appendingPathComponent("\(baseFileName)_\(index).md")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    print("🗑️ Removed memory file part \(index)")
                } catch {
                    print("❌ Failed to remove memory file part \(index): \(error)")
                }
                index += 1
            } else {
                break
            }
        }
        
        // Reset state
        hasPermission = false
        permissionAsked = false
        currentFileIndex = 1
        savePermissionState()
        print("🗑️ All memory files cleared")
    }
} 
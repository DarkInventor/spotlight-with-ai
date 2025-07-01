import Foundation
import AppKit
import ScreenCaptureKit
import CoreMedia

@MainActor
class ScreenshotManager: ObservableObject {
    @Published var isCapturing = false
    @Published var lastScreenshot: NSImage?
    @Published var lastError: String?
    
    private var captureTimer: Timer?
    
    init() {
        print("📸 ScreenshotManager initialized - Ready for intelligent context capture!")
    }
    
    deinit {
        captureTimer?.invalidate()
        captureTimer = nil
    }
    
    // MARK: - Automatic Screenshot Capture
    
    /// Captures a screenshot immediately for context awareness
    func captureForContext() async -> NSImage? {
        print("📸 🚀 CAPTURING SCREENSHOT FOR CONTEXT AWARENESS...")
        
        guard !isCapturing else {
            print("⚠️ Already capturing, skipping...")
            return lastScreenshot
        }
        
        isCapturing = true
        defer { isCapturing = false }
        
        do {
            guard #available(macOS 12.3, *) else {
                await MainActor.run {
                    lastError = "ScreenCaptureKit requires macOS 12.3 or later"
                }
                return nil
            }
            
            // Get all displays and windows
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            guard let display = content.displays.first else {
                await MainActor.run {
                    lastError = "No displays found"
                }
                return nil
            }
            
            // Create configuration for screenshot
            let config = SCStreamConfiguration()
            config.width = Int(display.width)
            config.height = Int(display.height) 
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = true
            
            // Create filter with the display (exclude SearchFast windows)
            let excludeWindows = content.windows.filter { window in
                let bundleId = window.owningApplication?.bundleIdentifier ?? ""
                return bundleId.contains("searchfast") || bundleId.contains("liquid-glass")
            }
            
            let filter = SCContentFilter(display: display, excludingWindows: excludeWindows)
            
            // Take screenshot using the correct API
            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            
            // Convert to NSImage
            let screenshot = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            
            await MainActor.run {
                lastScreenshot = screenshot
                lastError = nil
            }
            
            print("✅ 🚀 CONTEXT SCREENSHOT CAPTURED! Size: \(cgImage.width)x\(cgImage.height)")
            return screenshot
            
        } catch {
            await MainActor.run {
                lastError = "Screenshot failed: \(error.localizedDescription)"
            }
            print("❌ Context screenshot failed: \(error)")
            return nil
        }
    }
    
    /// Captures a manual screenshot (user-initiated)
    func captureManual(hideWindow: Bool = true) async -> NSImage? {
        print("📸 📱 MANUAL SCREENSHOT CAPTURE...")
        
        if hideWindow {
            // Hide SearchFast window for clean capture
            await MainActor.run {
                if let windowManager = NSApp.delegate as? WindowManager {
                    windowManager.hideWindow()
                }
            }
            
            // Wait for window to hide
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        }
        
        let screenshot = await captureForContext()
        
        if hideWindow {
            // Show window again after capture
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            await MainActor.run {
                if let windowManager = NSApp.delegate as? WindowManager {
                    windowManager.showWindow()
                }
            }
        }
        
        return screenshot
    }
    
    // MARK: - Periodic Capture (for background context)
    
    func startPeriodicCapture(interval: TimeInterval = 60.0) {
        stopPeriodicCapture() // Stop any existing timer
        
        print("🔄 Starting periodic screenshot capture every \(interval)s for background context")
        
        captureTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                _ = await self.captureForContext()
            }
        }
    }
    
    func stopPeriodicCapture() {
        captureTimer?.invalidate()
        captureTimer = nil
        print("⏸️ Stopped periodic screenshot capture")
    }
    
    // MARK: - Utility Functions
    
    func hasRecentScreenshot(maxAge: TimeInterval = 30.0) -> Bool {
        // Check if we have a screenshot that's recent enough
        return lastScreenshot != nil // For now, just check if we have any screenshot
    }
    
    func clearScreenshots() {
        lastScreenshot = nil
        lastError = nil
        print("🧹 Cleared screenshot cache")
    }
    
    func requestScreenRecordingPermission() async -> Bool {
        // This will show the permission dialog if needed
        do {
            guard #available(macOS 12.3, *) else { return false }
            let _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            print("❌ Screen recording permission denied: \(error)")
            await MainActor.run {
                lastError = "Screen recording permission required"
            }
            return false
        }
    }
}


//
//  PermissionManager.swift
//  liquid-glass-play
//
//  Created for permission management
//

import Foundation
import SwiftUI
import ApplicationServices
import AVFoundation
import Speech
import ScreenCaptureKit

enum PermissionStatus {
    case granted
    case denied
    case notDetermined
}

@MainActor
class PermissionManager: ObservableObject {
    @Published var accessibilityPermission: PermissionStatus = .notDetermined
    @Published var screenRecordingPermission: PermissionStatus = .notDetermined
    @Published var microphonePermission: PermissionStatus = .notDetermined
    @Published var automationPermission: PermissionStatus = .notDetermined
    
    var allPermissionsGranted: Bool {
        // Only require accessibility and screen recording for core functionality
        return accessibilityPermission == .granted && screenRecordingPermission == .granted
    }
    
    var allRequiredPermissionsGranted: Bool {
        return accessibilityPermission == .granted && screenRecordingPermission == .granted
    }
    
    init() {
        Task {
            await checkAllPermissions()
        }
    }
    
    // MARK: - Check All Permissions
    
    func checkAllPermissions() async {
        await checkAccessibilityPermission()
        await checkScreenRecordingPermission()
        await checkMicrophonePermission()
        await checkAutomationPermission()
    }
    
    // MARK: - Accessibility Permission
    
    private func checkAccessibilityPermission() async {
        let isEnabled = AXIsProcessTrustedWithOptions([
            "AXTrustedCheckOptionPrompt": false
        ] as CFDictionary)
        
        accessibilityPermission = isEnabled ? .granted : .denied
        print("🔐 Accessibility permission: \(isEnabled ? "✅ Granted" : "❌ Denied")")
    }
    
    func requestAccessibilityPermission() async {
        print("🔐 Requesting accessibility permission...")
        
        // This will show the system dialog if permissions aren't granted
        let isEnabled = AXIsProcessTrustedWithOptions([
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary)
        
        if !isEnabled {
            // Wait a bit for user to potentially grant permissions
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Check again without prompt
            let newStatus = AXIsProcessTrustedWithOptions([
                "AXTrustedCheckOptionPrompt": false
            ] as CFDictionary)
            
            accessibilityPermission = newStatus ? .granted : .denied
            
            if newStatus {
                print("✅ Accessibility permissions granted!")
            } else {
                print("⚠️ Accessibility permissions still pending - opening System Preferences")
                openAccessibilitySettings()
            }
        } else {
            accessibilityPermission = .granted
        }
        
        // Refresh all permissions to update UI
        await checkAllPermissions()
    }
    
    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Screen Recording Permission
    
    private func checkScreenRecordingPermission() async {
        guard #available(macOS 12.3, *) else {
            screenRecordingPermission = .denied
            return
        }
        
        do {
            let _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            screenRecordingPermission = .granted
            print("🔐 Screen recording permission: ✅ Granted")
        } catch {
            screenRecordingPermission = .denied
            print("🔐 Screen recording permission: ❌ Denied")
        }
    }
    
    func requestScreenRecordingPermission() async {
        print("🔐 Requesting screen recording permission...")
        
        guard #available(macOS 12.3, *) else {
            print("❌ ScreenCaptureKit requires macOS 12.3 or later")
            openScreenRecordingSettings()
            return
        }
        
        do {
            // This will trigger the permission dialog if needed
            let _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            screenRecordingPermission = .granted
            print("✅ Screen recording permission granted!")
        } catch {
            screenRecordingPermission = .denied
            print("❌ Screen recording permission denied: \(error)")
            openScreenRecordingSettings()
        }
        
        // Refresh all permissions to update UI
        await checkAllPermissions()
    }
    
    private func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Microphone Permission
    
    private func checkMicrophonePermission() async {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        switch status {
        case .authorized:
            microphonePermission = .granted
            print("🔐 Microphone permission: ✅ Granted")
        case .denied, .restricted:
            microphonePermission = .denied
            print("🔐 Microphone permission: ❌ Denied")
        case .notDetermined:
            microphonePermission = .notDetermined
            print("🔐 Microphone permission: ⚠️ Not determined")
        @unknown default:
            microphonePermission = .denied
            print("🔐 Microphone permission: ❌ Unknown status")
        }
    }
    
    func requestMicrophonePermission() async {
        print("🔐 Requesting microphone permission...")
        
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        switch status {
        case .authorized:
            microphonePermission = .granted
            print("✅ Microphone permission granted!")
        case .denied, .restricted:
            microphonePermission = .denied
            print("❌ Microphone permission denied")
            openMicrophoneSettings()
        case .notDetermined:
            microphonePermission = .notDetermined
            print("⚠️ Microphone permission not determined")
        @unknown default:
            microphonePermission = .denied
            print("❌ Microphone permission unknown status")
        }
        
        // Refresh all permissions to update UI
        await checkAllPermissions()
    }
    
    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Automation Permission
    
    private func checkAutomationPermission() async {
        let testScript = """
        tell application "System Events"
            try
                get name
                return "success"
            on error errMsg
                return "error: " & errMsg
            end try
        end tell
        """
        
        let result = await executeTestScript(testScript)
        
        if result.contains("success") {
            automationPermission = .granted
            print("🔐 Automation permission: ✅ Granted")
        } else if result.contains("1743") {
            automationPermission = .denied
            print("🔐 Automation permission: ❌ Denied (error 1743)")
        } else {
            automationPermission = .notDetermined
            print("🔐 Automation permission: ⚠️ Not determined")
        }
    }
    
    func requestAutomationPermission() async {
        print("🔐 Requesting automation permission...")
        
        let testScript = """
        tell application "System Events"
            try
                get name
                return "success"
            on error errMsg
                return "error: " & errMsg
            end try
        end tell
        """
        
        let result = await executeTestScript(testScript)
        
        if result.contains("success") {
            automationPermission = .granted
            print("✅ Automation permission granted!")
        } else if result.contains("1743") {
            automationPermission = .denied
            print("❌ Automation permission denied (error 1743)")
            openAutomationSettings()
        } else {
            automationPermission = .notDetermined
            print("⚠️ Automation permission status unclear: \(result)")
        }
        
        // Refresh all permissions to update UI
        await checkAllPermissions()
    }
    
    private func executeTestScript(_ script: String) async -> String {
        return await withCheckedContinuation { continuation in
            var error: NSDictionary?
            
            if let scriptObject = NSAppleScript(source: script) {
                let result = scriptObject.executeAndReturnError(&error)
                
                if let error = error {
                    let errorDescription = error.description
                    print("🔍 AppleScript test error: \(errorDescription)")
                    continuation.resume(returning: errorDescription)
                } else if let resultString = result.stringValue {
                    continuation.resume(returning: resultString)
                } else {
                    continuation.resume(returning: "unknown_result")
                }
            } else {
                continuation.resume(returning: "script_creation_failed")
            }
        }
    }
    
    private func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Utility Methods
    
    func requestAllPermissions() async {
        print("🔐 Requesting all permissions...")
        
        await requestAccessibilityPermission()
        await requestScreenRecordingPermission()
        await requestMicrophonePermission()
        await requestAutomationPermission()
        
        print("✅ All permission requests completed")
    }
    
    func getPermissionStatusSummary() -> String {
        let permissions = [
            ("Accessibility", accessibilityPermission),
            ("Screen Recording", screenRecordingPermission),
            ("Microphone", microphonePermission),
            ("Automation", automationPermission)
        ]
        
        let summary = permissions.map { name, status in
            let emoji = status == .granted ? "✅" : (status == .denied ? "❌" : "⚠️")
            return "\(emoji) \(name): \(status)"
        }.joined(separator: "\n")
        
        return summary
    }
} 
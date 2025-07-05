import AppKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainAppBundleId = "com.kathan.liquid-glass-play"
        
        let runningApps = NSWorkspace.shared.runningApplications
        let isMainAppRunning = runningApps.contains {
            $0.bundleIdentifier == mainAppBundleId
        }

        if !isMainAppRunning {
            // The path to the main app is 4 levels up from the launcher's bundle path.
            // .../liquid-glass-play.app/Contents/Library/LoginItems/liquid-glass-playLauncher.app
            var mainAppURL = Bundle.main.bundleURL
            for _ in 1...4 {
                mainAppURL.deleteLastPathComponent()
            }
            
            // Use the modern asynchronous API to launch the app.
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: mainAppURL,
                                              configuration: configuration) { [weak self] _, error in
                if let error = error {
                    print("Launcher failed to open main app: \(error.localizedDescription)")
                }
                // The launcher's job is done, so it terminates.
                self?.terminate()
            }
        } else {
            // If the main app is already running, the launcher's job is also done.
            self.terminate()
        }
    }
    
    private func terminate() {
        DispatchQueue.main.async {
        NSApp.terminate(nil)
        }
    }
}

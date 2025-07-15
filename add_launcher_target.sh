#!/bin/bash

# This script automates the creation and configuration of a Login Item Launcher Helper
# for a macOS application. It creates the necessary files and modifies the
# Xcode project to add the new target.

# --- Configuration ---
PROJECT_DIR="."
PROJECT_NAME="liquid-glass-play"
MAIN_APP_BUNDLE_ID="com.app.liquid-glass-play"

LAUNCHER_DIR_NAME="Launcher"
LAUNCHER_TARGET_NAME="${PROJECT_NAME}Launcher"
LAUNCHER_BUNDLE_ID="${MAIN_APP_BUNDLE_ID}.Launcher"
LAUNCHER_PLIST_FILENAME="com.app.liquid-glass-play.Launcher.plist"

# --- File Content ---

# Content for the Launcher's Swift file
LAUNCHER_SWIFT_CONTENT=$(cat <<EOF
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainAppId = "${MAIN_APP_BUNDLE_ID}"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { \$0.bundleIdentifier == mainAppId }.isEmpty

        if !isRunning {
            var path = Bundle.main.bundlePath as NSString
            for _ in 1...4 {
                path = path.deletingLastPathComponent as NSString
            }
            NSWorkspace.shared.launchApplication(path as String)
        }
        NSApp.terminate(nil)
    }
}

let delegate = AppDelegate()
NSApp.delegate = delegate
NSApp.run()
EOF
)

# Content for the Launcher's Info.plist file
LAUNCHER_INFO_PLIST_CONTENT=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>\$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>${LAUNCHER_BUNDLE_ID}</string>
	<key>CFBundleName</key>
	<string>\$(PRODUCT_NAME)</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
	<key>LSUIElement</key>
	<true/>
</dict>
</plist>
EOF
)

# Content for the Login Item's Launchd plist file
LAUNCHER_LAUNCHD_PLIST_CONTENT=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>${LAUNCHER_BUNDLE_ID}</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/bin/open</string>
		<string>-a</string>
		<string>${PROJECT_NAME}</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>
EOF
)


# --- Script Steps ---

echo "--- Starting Launcher Setup ---"

# 1. Create directory for the launcher
echo "1. Creating directory: ${LAUNCHER_DIR_NAME}"
mkdir -p "${LAUNCHER_DIR_NAME}"
if [ $? -ne 0 ]; then echo "Error creating directory. Exiting."; exit 1; fi

# 2. Create the Swift source file for the launcher
LAUNCHER_SWIFT_FILE="${LAUNCHER_DIR_NAME}/Launcher.swift"
echo "2. Creating Swift file: ${LAUNCHER_SWIFT_FILE}"
echo "${LAUNCHER_SWIFT_CONTENT}" > "${LAUNCHER_SWIFT_FILE}"
if [ $? -ne 0 ]; then echo "Error creating Swift file. Exiting."; exit 1; fi

# 3. Create the Info.plist for the launcher
LAUNCHER_INFO_PLIST_FILE="${LAUNCHER_DIR_NAME}/Info.plist"
echo "3. Creating Info.plist file: ${LAUNCHER_INFO_PLIST_FILE}"
echo "${LAUNCHER_INFO_PLIST_CONTENT}" > "${LAUNCHER_INFO_PLIST_FILE}"
if [ $? -ne 0 ]; then echo "Error creating Info.plist file. Exiting."; exit 1; fi

# 4. Create the Launchd plist for the service
LAUNCHER_SERVICE_PLIST_FILE="${PROJECT_NAME}/${LAUNCHER_PLIST_FILENAME}"
echo "4. Creating Launchd service plist file: ${LAUNCHER_SERVICE_PLIST_FILE}"
echo "${LAUNCHER_LAUNCHD_PLIST_CONTENT}" > "${LAUNCHER_SERVICE_PLIST_FILE}"
if [ $? -ne 0 ]; then echo "Error creating Launchd service plist file. Exiting."; exit 1; fi


echo "✅ Files created successfully."
echo "下一步, please go to Xcode:"
echo "1. File > Add Files to \"${PROJECT_NAME}\"..."
echo "2. Select the '${LAUNCHER_DIR_NAME}' folder and add it."
echo "3. Go to Project Settings > Targets > '+' to add a new target."
echo "4. Choose 'macOS' > 'App' and name it '${LAUNCHER_TARGET_NAME}'."
echo "5. In the new target's 'Build Phases', remove any files from 'Compile Sources' except 'Launcher.swift'."
echo "6. In the main app's target ('${PROJECT_NAME}'), go to 'Build Phases'."
echo "7. Add a new 'Copy Files' phase."
echo "8. Set the 'Destination' to 'Wrapper', 'Subpath' to 'Contents/Library/LoginItems'."
echo "9. Drag the '${LAUNCHER_TARGET_NAME}.app' from the Products group into this new phase."
echo "10. Add the '${LAUNCHER_PLIST_FILENAME}' to the main app's 'Copy Bundle Resources' phase."

echo "--- Setup Complete ---"

# Note: Full automation of Xcode project modification is complex and fragile.
# The manual steps above are recommended for accuracy.
# This script prepares all the necessary files. 
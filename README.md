# 🚀 SearchFast - Intelligent AI Spotlight for macOS

> Your proactive AI assistant that sees, understands, and acts on your screen context

SearchFast is a revolutionary macOS application that combines the power of AI with intelligent screen awareness to provide the most contextual and proactive assistance experience possible. Inspired by Cursor IDE's intelligent agent system, SearchFast automatically captures your screen context and provides smart, actionable suggestions.

## 📖 Quick Navigation
- [🔐 Permissions Guide](#-permissions-guide) - Everything you need to know about macOS permissions
- [🚀 Launch at Login Setup](#-launch-at-login-setup) - Ensure SearchFast starts automatically
- [⚠️ Troubleshooting](#️-permission-troubleshooting) - Fix common permission issues
- [🛠 Installation & Setup](#-installation--setup) - Get started with SearchFast

## ✨ Key Features

### 🔥 **Automatic Context Intelligence**
- **Auto-Screenshot Capture**: Automatically sees your screen when you open SearchFast (Cmd+Shift+Space)
- **Smart Context Awareness**: Understands what app you're using and what you're working on
- **Proactive Suggestions**: Provides intelligent, context-aware suggestions based on your current activity

### 🎯 **Cursor-Inspired Interaction Flow**
- **Think First, Act Later**: Shows AI response with suggested actions instead of immediately executing
- **Action Buttons**: Clean, intuitive buttons for writing to apps, opening applications, copying text, etc.
- **Smart Action Detection**: Automatically detects actionable content in AI responses

### 📸 **Dual Screenshot System**
- **Auto-Capture**: Invisible background screenshot capture for context
- **Manual Capture**: User-initiated screenshots with camera button
- **Visual Indicators**: Clear indication of both auto-captured and manual screenshots

### 🤖 **Advanced App Automation**
- **25+ Supported Apps**: Word, Excel, PowerPoint, Chrome, Safari, VS Code, Cursor, Slack, Discord, and more
- **Smart Strategy Selection**: Uses the best automation method for each app (AppleScript, Accessibility API, Hybrid)
- **Context Preservation**: Remembers cursor positions and app states

### 🧠 **Intelligent Response System**
- **Visual Context Analysis**: Uses screenshots to provide specific, relevant help
- **App-Specific Guidance**: Tailored suggestions for design tools, code editors, documents, etc.
- **Memory Integration**: Remembers conversation history for better context

## 🚀 How It Works

### 1. **Hotkey Activation**
Press `Cmd+Shift+Space` from anywhere to instantly:
- Capture a screenshot of your current screen (invisible to you)
- Switch to SearchFast with full context awareness
- Show proactive suggestions based on what you're working on

### 2. **Context-Aware Responses**
When you ask a question, SearchFast:
- Analyzes the auto-captured screenshot
- Considers your current app and activity
- Provides specific, actionable advice
- Suggests concrete next steps

### 3. **Smart Action Execution**
Instead of immediately acting, SearchFast:
- Shows you what it plans to do
- Provides action buttons for confirmation
- Executes only when you click the button
- Gives you full control over automation

## 🎨 Example Use Cases

### **Adobe Illustrator User**
1. Press `Cmd+Shift+Space` while working on a design
2. SearchFast automatically sees your screen and says: *"🎨 I can see you're working in Adobe Illustrator! How can I help with chrome effects in this video project?"*
3. Ask: *"How do I add a chrome effect to this text?"*
4. Get specific instructions with action buttons to copy code, open tutorials, etc.

### **Code Development**
1. Open SearchFast while coding in Cursor/VS Code
2. Get proactive suggestions: *"💻 Coding mode detected! I can help with code review, debugging, or implementation suggestions"*
3. Ask about your current code with full visual context
4. Get actionable solutions with "Write to App" buttons

### **Document Writing**
1. Working in Word/Pages? SearchFast knows!
2. Ask for writing improvements or formatting help
3. Get suggestions with one-click implementation buttons
4. Seamlessly continue your work with AI assistance

## 🛠 Installation & Setup

### **Prerequisites**
- macOS 12.3+ (for ScreenCaptureKit)
- Xcode 15+
- Google Generative AI API Key

## 🔐 Permissions Guide

SearchFast requires several macOS permissions to deliver its intelligent, context-aware functionality. This comprehensive guide explains what permissions are needed, why they're important, and how to grant them properly.

### **🎯 Why These Permissions Matter**

SearchFast's revolutionary capabilities depend on deep system integration to provide contextual, intelligent assistance:

- **🔍 See what you're working on** → Provide relevant, contextual suggestions based on your current screen
- **⌨️ Global hotkey access** → Instant access from any app without switching contexts
- **🤖 Automate repetitive tasks** → Write to documents, open apps, copy text seamlessly
- **📸 Intelligent screen capture** → Understand your screen content for better assistance
- **🎙️ Voice interaction** → Hands-free operation for enhanced productivity

### **📋 Essential Permissions**

#### **1. 🎯 Accessibility Access** *(REQUIRED - Core Functionality)*

**Critical for:**
- ⌨️ Global hotkey (`Cmd+Shift+Space`) working from any application
- 🤖 App automation (writing to Word, Excel, VS Code, Chrome, etc.)
- 🎯 Focus management and window control
- 📝 Direct text input to other applications
- 🔄 Background operation without interfering with your workflow

**Step-by-step setup:**
1. **Open System Preferences/Settings**
   - Click the Apple menu → System Preferences (macOS Monterey and earlier)
   - Or Apple menu → System Settings (macOS Ventura and later)

2. **Navigate to Privacy & Security**
   - macOS Monterey and earlier: **Security & Privacy** → **Privacy**
   - macOS Ventura and later: **Privacy & Security**

3. **Access Accessibility settings**
   - Click **Accessibility** in the left sidebar
   - Click the **🔒 lock icon** at the bottom and enter your password

4. **Add SearchFast**
   - Click the **➕ plus button**
   - Navigate to Applications and select **SearchFast**
   - Ensure the **checkbox next to SearchFast is checked** ✅

**⚠️ Common Issues & Solutions:**
- **SearchFast not in the list?** → Quit and restart the app, then try again
- **Can't find the app?** → Drag SearchFast.app from Applications folder directly into the list
- **Hotkey still not working?** → Restart SearchFast after granting permission
- **Permission gets reset?** → Check if you're running the app from the correct location (Applications folder)

#### **2. 📸 Screen Recording** *(REQUIRED - Context Intelligence)*

**Critical for:**
- 📷 Automatic context capture when you open SearchFast
- 🧠 Smart screenshot analysis for relevant suggestions
- 👁️ Visual understanding of your current task and app
- 📊 Content-aware responses (seeing what you're working on)
- 🎨 Design and document assistance based on visual context

**Step-by-step setup:**
1. **Open System Preferences/Settings** (same as above)
2. **Navigate to Privacy & Security** (same as above)
3. **Access Screen Recording settings**
   - Click **Screen Recording** in the left sidebar
   - Click the **🔒 lock icon** and enter your password
4. **Enable SearchFast**
   - Check the **box next to SearchFast** ✅
   - You may need to restart SearchFast for changes to take effect

**⚠️ Common Issues & Solutions:**
- **Context features not working?** → Verify the checkbox is checked and restart the app
- **Permission dialog keeps appearing?** → Make sure you've checked the box, not just added the app
- **Screenshots not captured?** → Try quitting SearchFast completely and reopening it
- **Still having issues?** → Check Console.app for error messages related to ScreenCaptureKit

#### **3. 🤖 Automation** *(RECOMMENDED - App Control)*

**Enables powerful features:**
- ✍️ Writing text directly to apps (Word, Excel, VS Code, etc.)
- 🚀 Opening and controlling other applications
- 📋 AppleScript-based automations for seamless workflow
- 🔄 Cross-app data transfer and manipulation
- 📱 Smart app launching based on context

**How automation permissions work:**
- **Automatic prompts:** Most automation permissions are requested automatically when you first try to automate a specific app
- **App-specific:** Each app requires individual permission (e.g., permission for Word is separate from Excel)
- **One-time setup:** Once granted, permissions persist until you revoke them

**Manual permission management:**
1. **Open System Preferences/Settings**
2. **Go to Privacy & Security → Automation**
3. **Find SearchFast** in the list
4. **Check boxes** for apps you want to automate

**Supported applications include:**
- **📝 Document editors:** Microsoft Word, Excel, PowerPoint, Pages, Numbers, Keynote
- **💻 Development tools:** VS Code, Cursor, Xcode, Terminal
- **🌐 Web browsers:** Chrome, Safari, Firefox, Edge
- **💬 Communication:** Slack, Discord, Teams, Messages
- **🎵 Media & Creative:** Spotify, Figma, Adobe Creative Suite
- **🗂️ Productivity:** Finder, Mail, Calendar, Notes
- **And 15+ more applications**

**⚠️ Troubleshooting Automation:**
- **Permission dialog doesn't appear?** → Make sure Accessibility permission is granted first
- **Automation fails silently?** → Check System Preferences → Privacy → Automation for SearchFast
- **Some apps work, others don't?** → Each app needs individual permission - grant as needed
- **Permissions get revoked?** → This can happen after app updates - simply re-grant when prompted

#### **4. 🎤 Microphone Access** *(OPTIONAL - Voice Features)*

**Enhances productivity with:**
- 🎙️ Voice commands and speech-to-text input
- 🔄 Hands-free operation for accessibility
- 📢 Audio-based queries and responses
- 🚀 Faster input for complex requests

**Setup instructions:**
1. **Open System Preferences/Settings**
2. **Navigate to Privacy & Security**
3. **Click Microphone** in the left sidebar
4. **Check the box next to SearchFast** ✅

**Note:** This permission is optional. SearchFast works fully without microphone access, but voice features enhance the experience significantly.

### **🚀 Launch at Login Setup**

SearchFast automatically starts when you restart your Mac, ensuring seamless access to your AI assistant whenever you need it.

#### **How Launch at Login Works**

**🔄 Automatic Registration:**
- Enabled automatically after completing the onboarding process
- Uses macOS's modern `SMAppService` framework for reliable startup
- Runs silently in the background without appearing in the Dock
- Immediately available via global hotkey (`Cmd+Shift+Space`)

**🔧 Technical Implementation:**
- Uses modern macOS Service Management framework
- More reliable than older login item methods
- Integrates with macOS's Background Task Management system
- Respects system performance and battery life

#### **Verification & Status Checking**

**📊 Check Current Status:**
1. Right-click the **SearchFast menu bar icon** (magnifying glass)
2. Select **"Check Launch at Login Status"**
3. Review the detailed status information

**Status Meanings:**
- **✅ Enabled:** SearchFast will start automatically after restart
- **❌ Not Registered:** SearchFast won't start automatically
- **⚠️ Requires Approval:** User approval needed in System Preferences
- **⚠️ Service Not Found:** Expected in debug builds; works in release

#### **Manual Configuration**

**If automatic setup fails:**
1. **Using SearchFast menu:**
   - Right-click menu bar icon → "Check Launch at Login Status"
   - Click "Enable Launch at Login" if not registered
   - Follow any system prompts

2. **Using System Preferences:**
   - macOS Monterey and earlier: **System Preferences** → **Users & Groups** → **Login Items**
   - macOS Ventura and later: **System Settings** → **General** → **Login Items**
   - Look for **SearchFast** in "Open at Login" section
   - If present but disabled, enable it

#### **Troubleshooting Launch at Login**

**❌ SearchFast doesn't start after restart:**
1. **Check registration status** using menu bar option
2. **Complete onboarding** if you haven't already
3. **Approve in System Preferences** if required
4. **Restart SearchFast** and wait 30 seconds for auto-registration

**⚠️ "Requires Approval" status:**
1. Open **System Settings/Preferences**
2. Go to **General** → **Login Items**
3. Find **SearchFast** and ensure it's **enabled**
4. If not listed, use SearchFast's menu option to re-register

**🔄 Registration keeps failing:**
1. **Quit SearchFast completely** (menu bar → Quit)
2. **Restart the app** from Applications folder
3. **Wait 30 seconds** for automatic registration
4. **Check status** again using menu bar option

**💡 Debug Builds:**
- Launch at login doesn't work in debug/development builds
- This is normal and expected behavior
- Feature works properly in release builds from App Store or direct download

#### **🆘 Emergency Recovery**

**If SearchFast becomes unresponsive and blocks keyboard input:**

1. **Emergency Quit Hotkey:** Press `Cmd+Option+Shift+Q`
   - This immediately removes all keyboard monitors and quits the app
   - Restores full keyboard control to your system
   - Works even when the main app interface is frozen

2. **Menu Bar Emergency Option:**
   - Right-click SearchFast menu bar icon → "Force Quit (Emergency)"
   - Same effect as the emergency hotkey
   - Available even when main window won't respond

3. **System Recovery (Last Resort):**
   - If emergency quit doesn't work, restart your Mac
   - SearchFast will auto-start but you can disable launch at login in System Preferences

**Why This Happens:**
- Rarely occurs when the app crashes during startup after restart
- Global keyboard monitors remain active but UI becomes unresponsive
- Latest update includes comprehensive safeguards to prevent this issue

### **⚠️ Permission Troubleshooting**

This section covers solutions to common permission-related issues you might encounter.

#### **🔑 Global Hotkey Issues**

**❌ Hotkey (`Cmd+Shift+Space`) not working:**
1. **Verify Accessibility permission:**
   - System Preferences → Privacy & Security → Accessibility
   - Ensure SearchFast is listed and **checked** ✅
   - If missing, add it manually

2. **Check for conflicts:**
   - Some apps use the same hotkey combination
   - Try changing SearchFast's hotkey in preferences
   - Common conflicts: Alfred, Raycast, other Spotlight alternatives

3. **Reset accessibility database:**
   - Open Terminal and run: `sudo tccutil reset Accessibility`
   - Restart SearchFast and re-grant permission when prompted

4. **Full restart sequence:**
   - Quit SearchFast completely
   - Restart your Mac
   - Launch SearchFast from Applications folder
   - Test hotkey functionality

#### **📸 Context & Screenshot Issues**

**❌ Auto-screenshots not working:**
1. **Screen Recording permission check:**
   - System Preferences → Privacy & Security → Screen Recording
   - SearchFast must be **checked** ✅, not just listed
   - Restart app after granting permission

2. **ScreenCaptureKit issues (macOS 12.3+):**
   - Required for modern screenshot functionality
   - Check Console.app for ScreenCaptureKit errors
   - Ensure you're on macOS 12.3 or later

3. **Multiple displays:**
   - Screenshots work on primary display by default
   - Secondary displays may need additional configuration
   - Test with app windows on primary display first

**❌ Context awareness not working:**
1. **Verify visual indicators:**
   - Look for auto-screenshot indicators in SearchFast
   - Check if manual screenshots work (camera button)
   - Test with simple, clear content first

2. **Content analysis issues:**
   - Complex or cluttered screens may affect analysis
   - Try with simple apps like TextEdit or Safari
   - Ensure good contrast and readable text

#### **🤖 App Automation Problems**

**❌ Writing to apps doesn't work:**
1. **Check automation permissions:**
   - System Preferences → Privacy & Security → Automation
   - Find SearchFast and check target app permissions
   - Each app needs individual permission

2. **App-specific troubleshooting:**
   - **Microsoft Office:** Ensure apps are fully updated
   - **VS Code/Cursor:** May need Accessibility + Automation
   - **Browsers:** Different automation methods per browser
   - **Web apps:** May not support automation

3. **Permission cascade:**
   - Accessibility permission must be granted first
   - Automation permissions build on accessibility
   - Some apps require both for full functionality

**❌ App launching fails:**
1. **Target app installation:**
   - Ensure the app is properly installed in Applications
   - Check if app has been moved or renamed
   - Try launching the app manually first

2. **Bundle identifier issues:**
   - Some apps have non-standard bundle IDs
   - Check Activity Monitor for correct process names
   - Report unknown apps for future support

#### **🎙️ Microphone & Voice Issues**

**❌ Voice commands not working:**
1. **Microphone permission:**
   - System Preferences → Privacy & Security → Microphone
   - Check SearchFast is enabled
   - Test with other apps to verify mic works

2. **Speech recognition setup:**
   - System Preferences → Keyboard → Dictation
   - Ensure dictation is enabled system-wide
   - Test language settings match your speech

3. **Audio input troubleshooting:**
   - Check correct microphone is selected
   - Test audio levels in System Preferences
   - Try with external microphone if available

### **🛡️ Privacy & Security**

#### **Data Handling & Privacy**

**🔒 What SearchFast sees and stores:**
- **Screenshots:** Temporarily captured for analysis, not permanently stored
- **Text content:** Processed locally when possible, sent to AI only when needed
- **App usage:** Basic automation logs for debugging, no personal content
- **Voice data:** Processed by macOS Speech Recognition, not stored by SearchFast

**🛡️ Security measures:**
- **Local processing:** Most features work without internet when possible
- **Encrypted transmission:** All AI communication uses secure HTTPS
- **No keylogger:** SearchFast doesn't monitor typing outside its own interface
- **Permission-based:** Only accesses what you explicitly grant permission for

**📡 Network usage:**
- **AI queries:** Sent to configured AI service (Google Gemini, etc.)
- **App updates:** Automatic update checks
- **Crash reports:** Anonymous error reporting (opt-out available)

### **🔧 Manual Permission Reset**

If permissions become corrupted or you need to start fresh:

#### **Complete Permission Reset**

**⚠️ This will remove all SearchFast permissions and require re-setup:**

```bash
# Reset all SearchFast permissions (run in Terminal)
sudo tccutil reset All com.yourcompany.SearchFast

# Reset specific permissions individually:
sudo tccutil reset Accessibility com.yourcompany.SearchFast
sudo tccutil reset ScreenCapture com.yourcompany.SearchFast
sudo tccutil reset AppleEvents com.yourcompany.SearchFast
sudo tccutil reset Microphone com.yourcompany.SearchFast
```

**After running reset commands:**
1. **Restart your Mac** completely
2. **Launch SearchFast** from Applications folder
3. **Go through onboarding** again to re-grant permissions
4. **Test all functionality** to ensure proper setup

#### **Selective Permission Refresh**

If only one permission type is problematic:

1. **Remove SearchFast** from the relevant Privacy & Security section
2. **Restart SearchFast**
3. **Trigger the permission request** (use the feature that needs it)
4. **Grant permission** when prompted
- ✅ Ensure the target app (Word, Chrome, etc.) is listed and enabled

#### **SearchFast Doesn't Start After Reboot**
- ✅ Check "Launch at Login Status" from the menu bar
- ✅ Look in System Preferences → General → Login Items
- ✅ Try re-enabling launch at login from the SearchFast menu

### **🛡️ Privacy & Security**

**Your data stays private:**
- Screenshots are processed locally on your Mac
- No images are stored permanently
- AI processing happens on-device when possible
- Network requests only for Google AI API (optional)

**Security measures:**
- All automations require explicit user confirmation
- Action buttons show exactly what will happen before execution
- You maintain full control over what actions are performed

### **🔧 Manual Permission Reset**

If you need to reset permissions:

1. **Remove from System Preferences:**
   - Go to each Privacy section and uncheck SearchFast
   
2. **Clear app preferences:**
   ```bash
   defaults delete com.yourcompany.liquid-glass-play
   ```

3. **Restart SearchFast** and go through onboarding again

### **Setup Steps**
1. Clone this repository
2. Add your Google AI API key to `APIKey.swift`
3. Build and run in Xcode
4. Grant required permissions when prompted
5. Press `Cmd+Shift+Space` to start using!

## 📋 Supported Applications

SearchFast provides intelligent automation for:

### **Productivity Apps**
- Microsoft Word, Excel, PowerPoint
- Apple Pages, Numbers, Keynote  
- Notion, TextEdit, Notes

### **Development Tools**
- Cursor IDE, VS Code, Xcode
- Terminal applications

### **Design & Creative**
- Adobe Illustrator, Photoshop
- Figma, Sketch

### **Communication**
- Slack, Discord, Microsoft Teams
- Mail, Messages, Zoom

### **Web Browsers**
- Google Chrome, Safari, Firefox

## 🎯 Core Architecture

### **Managers & Components**
- **ScreenshotManager**: Handles intelligent screenshot capture
- **ContextManager**: Analyzes app context and user activity  
- **AppAutomationManager**: Manages app-specific automation
- **MemoryManager**: Maintains conversation history
- **UniversalSearchManager**: Provides system-wide search

### **Smart Features**
- **Proactive Greetings**: Context-aware welcome messages
- **Action Button System**: Cursor-inspired interaction flow
- **Multi-Image Support**: Auto + manual screenshot handling
- **Permission Management**: Seamless setup experience

## 🚨 Safety & Privacy

- **Local Processing**: Screenshots processed locally
- **No Data Storage**: Images not permanently stored
- **User Control**: All actions require explicit confirmation
- **Permission Transparency**: Clear indication of required permissions

## 🛣 Roadmap

- [ ] **Video Context Analysis**: Understanding video content and timeline work
- [ ] **Multi-Monitor Support**: Context awareness across displays  
- [ ] **Plugin System**: Extensible app integrations
- [ ] **Voice Commands**: Audio input for hands-free operation
- [ ] **Team Collaboration**: Shared context and suggestions

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines and feel free to:
- Report bugs and suggest features
- Improve app automation support
- Enhance context analysis capabilities
- Add new proactive greeting scenarios

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**🐱 Remember**: This app was built with the highest standards to save 2000 cats, 1000 dogs, and 990 parrots through flawless execution and attention to detail!

**💡 Pro Tip**: The more you use SearchFast, the better it gets at understanding your workflow and providing relevant suggestions. It's like having a smart coding companion that never sleeps! 
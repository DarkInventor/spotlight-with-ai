# 🛠️ Development Setup Guide

This guide will help you set up the SearchFast project for development. The project requires several API keys and configuration files that are not included in the repository for security reasons.

## 📋 Prerequisites

- macOS 14+ (for ScreenCaptureKit)
- Xcode 15+
- Active internet connection for API services

## 🔑 Required API Keys

You'll need to obtain the following API keys:

### 1. Google Generative AI API Key
- Visit [Google AI Studio](https://ai.google.dev/tutorials/setup)
- Create a new API key
- Keep this key secure - it will be used for AI responses

### 2. Deepgram API Key (Optional)
- Visit [Deepgram Console](https://console.deepgram.com/)
- Create an account and get an API key
- This is used for advanced speech recognition features

### 3. Firebase Configuration (Optional)
- Visit [Firebase Console](https://console.firebase.google.com/)
- Create a new project
- Enable Authentication and Firestore
- Download the `GoogleService-Info.plist` file

## 🚀 Setup Steps

### Step 1: Clone the Repository
```bash
git clone https://github.com/your-username/liquid-glass-play.git
cd liquid-glass-play
```

### Step 1.5: Quick Setup (Recommended)
For a guided setup experience, run the setup script:
```bash
./setup.sh
```
This will create all necessary configuration files from templates and guide you through the next steps.

**OR continue with manual setup below:**

### Step 2: Configure API Keys
1. **Copy the template files:**
   ```bash
   cp liquid-glass-play/APIKey.swift.template liquid-glass-play/APIKey.swift
   cp liquid-glass-play/GenerativeAI-Info.plist.template liquid-glass-play/GenerativeAI-Info.plist
   cp liquid-glass-play/liquid_glass_play.entitlements.template liquid-glass-play/liquid_glass_play.entitlements
   ```

2. **Configure GenerativeAI-Info.plist:**
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>API_KEY</key>
       <string>YOUR_ACTUAL_GOOGLE_AI_API_KEY</string>
       <key>DEEPGRAM_API_KEY</key>
       <string>YOUR_ACTUAL_DEEPGRAM_API_KEY</string>
   </dict>
   </plist>
   ```

### Step 3: Configure Firebase (Optional)
If you want to enable user authentication and data sync:

1. **Copy Firebase template:**
   ```bash
   cp liquid-glass-play/GoogleService-Info.plist.template liquid-glass-play/GoogleService-Info.plist
   ```

2. **Replace with your actual Firebase configuration** or download the real `GoogleService-Info.plist` from your Firebase project

### Step 4: Configure Development Team
1. Open `liquid-glass-play.xcodeproj` in Xcode
2. Select the project in the navigator
3. Under "Signing & Capabilities", set your development team
4. Update the bundle identifier if needed

### Step 5: Install Dependencies
```bash
# Make the Firebase setup script executable
chmod +x add_firebase_dependencies.sh

# Run the Firebase setup (follow the prompts)
./add_firebase_dependencies.sh
```

Then in Xcode:
1. File → Add Package Dependencies
2. Add: `https://github.com/firebase/firebase-ios-sdk`
3. Select: `FirebaseAuth`, `FirebaseFirestore`, `FirebaseCore`

### Step 6: Build and Run
1. Select your target device/simulator
2. Build and run the project (⌘+R)
3. Grant necessary permissions when prompted

## 🔒 Security Notes

### ⚠️ NEVER COMMIT THESE FILES:
- `APIKey.swift` - Contains your actual API keys
- `GenerativeAI-Info.plist` - Contains your API keys
- `GoogleService-Info.plist` - Contains Firebase configuration
- `liquid_glass_play.entitlements` - Contains app permissions
- Any file ending in `.plist`

### ✅ Safe to commit:
- `*.template` files - These are templates for others to use
- Source code files (`.swift`)
- Project structure files
- Documentation

## 📱 Required Permissions

The app requires several macOS permissions to function:

### Essential Permissions:
1. **Accessibility Access** - For global hotkey and app automation
2. **Screen Recording** - For context-aware AI responses
3. **Microphone** - For voice input (optional)

### Setup Instructions:
1. **System Settings** → **Privacy & Security** → **Accessibility**
   - Add SearchFast and enable it
2. **System Settings** → **Privacy & Security** → **Screen Recording**
   - Add SearchFast and enable it
3. **System Settings** → **Privacy & Security** → **Microphone**
   - Add SearchFast and enable it (optional)

## 🐛 Troubleshooting

### Build Errors:
- **"API key not found"**: Make sure you've created `GenerativeAI-Info.plist` with valid keys
- **"Firebase configuration error"**: Verify your `GoogleService-Info.plist` is correctly configured
- **Signing errors**: Check your development team is set correctly

### Runtime Issues:
- **Hotkey not working**: Grant Accessibility permission
- **Screenshot capture fails**: Grant Screen Recording permission
- **Speech recognition fails**: Grant Microphone permission

### Permission Issues:
```bash
# Reset all permissions if needed
sudo tccutil reset All com.app.liquid-glass-play
```

## 🤝 Contributing

When contributing:
1. **Never commit sensitive files** - they're in `.gitignore` for a reason
2. **Test with template files** - make sure the templates work
3. **Update this guide** - if you add new requirements
4. **Use environment variables** - for CI/CD if needed

## 📚 Additional Resources

- [Google AI Studio Documentation](https://ai.google.dev/docs)
- [Firebase iOS Documentation](https://firebase.google.com/docs/ios/setup)
- [Deepgram Documentation](https://developers.deepgram.com/)
- [macOS App Sandbox Guide](https://developer.apple.com/documentation/security/app_sandbox)

## 🆘 Getting Help

If you encounter issues:
1. Check the troubleshooting section above
2. Verify all API keys are correctly configured
3. Ensure all permissions are granted
4. Create an issue with detailed error messages and setup information

---

**Remember: Keep your API keys secure and never commit them to version control!** 
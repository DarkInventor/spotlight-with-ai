#!/bin/bash

# SearchFast Development Setup Script
# This script helps set up the development environment safely

echo "🚀 SearchFast Development Setup"
echo "==============================="
echo ""

# Check if we're in the right directory
if [ ! -f "liquid-glass-play.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    echo "   (where liquid-glass-play.xcodeproj is located)"
    exit 1
fi

echo "📁 Setting up configuration files from templates..."

# Create the main configuration files from templates
FILES_TO_COPY=(
    "liquid-glass-play/APIKey.swift"
    "liquid-glass-play/GenerativeAI-Info.plist"
    "liquid-glass-play/GoogleService-Info.plist"
    "liquid-glass-play/liquid_glass_play.entitlements"
    "liquid-glass-play/Info.plist"
)

TEMPLATES_COPIED=0
TEMPLATES_SKIPPED=0

for file in "${FILES_TO_COPY[@]}"; do
    template_file="${file}.template"
    
    if [ -f "$template_file" ]; then
        if [ -f "$file" ]; then
            echo "⚠️  $file already exists, skipping..."
            TEMPLATES_SKIPPED=$((TEMPLATES_SKIPPED + 1))
        else
            cp "$template_file" "$file"
            echo "✅ Created $file from template"
            TEMPLATES_COPIED=$((TEMPLATES_COPIED + 1))
        fi
    else
        echo "❌ Template not found: $template_file"
    fi
done

echo ""
echo "📊 Summary:"
echo "   ✅ Templates copied: $TEMPLATES_COPIED"
echo "   ⚠️  Files skipped (already exist): $TEMPLATES_SKIPPED"
echo ""

if [ $TEMPLATES_COPIED -gt 0 ]; then
    echo "🔑 NEXT STEPS - Configure your API keys:"
    echo ""
    echo "1. 📝 Edit liquid-glass-play/GenerativeAI-Info.plist:"
    echo "   - Replace YOUR_GOOGLE_GENERATIVE_AI_API_KEY_HERE with your actual Google AI API key"
    echo "   - Replace YOUR_DEEPGRAM_API_KEY_HERE with your Deepgram key (optional)"
    echo ""
    echo "2. 🔥 Edit liquid-glass-play/GoogleService-Info.plist (optional for Firebase):"
    echo "   - Replace all YOUR_*_HERE placeholders with your Firebase project values"
    echo "   - Or download the real file from your Firebase console"
    echo ""
    echo "3. 🏗️  Open liquid-glass-play.xcodeproj in Xcode:"
    echo "   - Set your development team under Signing & Capabilities"
    echo "   - Add Firebase dependencies if needed (run ./add_firebase_dependencies.sh)"
    echo ""
    echo "4. 🔗 Get your API keys:"
    echo "   - Google AI: https://ai.google.dev/tutorials/setup"
    echo "   - Deepgram: https://console.deepgram.com/"
    echo "   - Firebase: https://console.firebase.google.com/"
    echo ""
else
    echo "🎯 All configuration files already exist!"
    echo "   Make sure your API keys are properly configured."
    echo ""
fi

echo "📚 For detailed setup instructions, see SETUP.md"
echo ""
echo "🔒 SECURITY REMINDER:"
echo "   - Never commit your actual API keys"
echo "   - The files you just created are in .gitignore"
echo "   - Only commit .template files"
echo ""
echo "✨ Happy coding!" 
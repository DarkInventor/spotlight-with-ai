# 🚀 Searchfast - AI-Powered Search & Writing Assistant

**The ultimate Mac productivity app that combines lightning-fast universal search with intelligent AI assistance and automated writing capabilities.**

*Like Spotlight + ChatGPT + automation magic, all in one beautiful interface.*

---

## ✨ Key Features

### 🔍 **Lightning-Fast Universal Search**
- **Instant results** - Search 100+ apps, files, documents faster than Spotlight or Raycast
- **Smart caching** - Results appear as you type with zero lag
- **Everything searchable** - Apps, documents, photos, videos, PDFs, and more
- **Intelligent categorization** - Results organized by type for easy browsing

### 🤖 **Context-Aware AI Assistant**
- **Smart context detection** - Knows what app you're using and what you're working on
- **Conversational AI** - Powered by Google Gemini 2.5 Flash for natural conversations
- **Visual understanding** - Take screenshots and ask AI about what's on your screen
- **Memory system** - Remembers your conversation history for better context

### ✍️ **Automated Writing & Productivity** ⭐ **NEW!**
- **Write directly into apps** - AI generates text and automatically types it where you need it
- **Context-aware responses** - Knows if you're in Google Docs, Gmail, Slack, etc.
- **Cross-app automation** - Works with Chrome, Safari, Pages, Word, VS Code, and more
- **Smart detection** - Automatically recognizes writing requests and shows "Write to App" button

### 🎯 **Spotlight-Style Interface**
- **Global hotkey** - Press `Cmd+Shift+Space` from anywhere, even in full-screen apps
- **Beautiful design** - Glass morphism UI with smooth animations
- **Instant access** - Appears instantly without disrupting your workflow
- **Auto-hide** - Disappears when you click outside or press Escape

---

## 🎬 How It Works

### **Universal Search**
1. Press `Cmd+Shift+Space` from anywhere
2. Start typing - see instant results for apps, files, documents
3. Click any result to open it immediately
4. Perfect for launching apps or finding that document you need

### **AI Chat & Assistance**
1. Press `Cmd+Shift+Space` to open Searchfast
2. Type any question or request
3. Get intelligent responses powered by Google Gemini
4. Ask follow-up questions - it remembers the conversation

### **Context-Aware Writing Automation** 🆕
1. **Open any supported app** (Google Docs, Gmail, Slack, etc.)
2. **Press `Cmd+Shift+Space`** - Searchfast detects your current context
3. **Make a writing request** - "write a summary", "compose an email", "explain this concept"
4. **Click "Write to App"** - AI generates the text and automatically types it into your document
5. **Continue working** - Seamlessly return to your workflow

### **Visual AI Analysis**
1. Press `Cmd+Shift+Space`
2. Click the camera icon to capture your screen
3. Ask questions about what's visible - "explain this chart", "help me understand this code"
4. Get detailed explanations of visual content

---

## 🛠 Supported Apps for Writing Automation

### **Web Browsers & Web Apps**
- ✅ **Google Chrome** - Google Docs, Gmail, Slack, GitHub, Sheets, Slides
- ✅ **Safari** - All web applications
- ✅ **Firefox** - All web applications

### **Native Apps**
- ✅ **Pages** - Apple's word processor
- ✅ **Microsoft Word** - Document editing
- ✅ **TextEdit** - Simple text editing
- ✅ **Notes** - Apple Notes app
- ✅ **Xcode** - Code development
- ✅ **VS Code** - Code development
- ✅ **Slack** - Team communication
- ✅ **Discord** - Gaming/community chat
- ✅ **Mail** - Email composition
- ✅ **Messages** - Text messaging

### **Advanced Automation Strategies**
- **AppleScript** - For apps with native automation support
- **Accessibility API** - For precise UI element targeting
- **Hybrid Mode** - Combines multiple approaches for maximum reliability
- **Smart fallbacks** - Automatically tries different methods if one fails

---

## 🚀 Installation & Setup

### **Requirements**
- macOS 15.5 or later
- Xcode 16.0 or later
- Google Gemini API key (free at [ai.google.dev](https://ai.google.dev))

### **Quick Setup**
1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd liquid-glass-play
   ```

2. **Get your free Google Gemini API key**
   - Visit [ai.google.dev](https://ai.google.dev)
   - Create an account and generate an API key

3. **Add your API key**
   - Open `liquid-glass-play/APIKey.swift`
   - Replace `"YOUR_API_KEY_HERE"` with your actual API key

4. **Build and run**
   - Open the project in Xcode
   - Build and run (`Cmd+R`)

5. **Grant permissions**
   - **Accessibility** - For global hotkey and automation
   - **Screen Recording** - For screenshot analysis
   - The app will guide you through permission setup

---

## ⌨️ Keyboard Shortcuts

- `Cmd+Shift+Space` - Open/toggle Searchfast
- `Cmd+J` - Close Searchfast (when open)
- `Escape` - Close Searchfast
- `Enter` - Send message to AI or open selected result
- Click outside - Auto-hide

---

## 🎯 Use Cases & Examples

### **Quick File Access**
- Type "presentation" → Find your PowerPoint files instantly
- Type "budget" → Locate spreadsheets and financial documents
- Type "safari" → Launch Safari immediately

### **AI-Powered Writing**
- **Email composition**: "write a professional follow-up email about the meeting"
- **Document creation**: "create an outline for a project proposal about AI integration"
- **Code documentation**: "write comments explaining this function"
- **Creative writing**: "write a compelling product description for this feature"

### **Research & Analysis**
- Take a screenshot of a chart → "explain the trends in this data"
- Screenshot code → "find bugs and suggest improvements"
- Capture a design → "suggest UI/UX improvements"

### **Context-Aware Assistance**
- Working in Google Docs → AI knows you're writing and offers relevant help
- In Gmail → AI can help compose professional emails
- Coding in VS Code → AI provides programming assistance
- In Slack → AI helps craft team communications

---

## 🏗 Architecture & Components

### **Core Managers**
- **`WindowManager`** - Spotlight-style window management and hotkey handling
- **`UniversalSearchManager`** - Lightning-fast file and app search with caching
- **`ContextManager`** - Intelligent context detection and screenshot analysis ⭐ **NEW!**
- **`AppAutomationManager`** - Cross-app writing automation ⭐ **NEW!**
- **`MemoryManager`** - Conversation history and context persistence

### **UI Components**
- **`ContentView`** - Main interface with search and chat
- **`SearchBar`** - Smart search input with real-time results
- **`UniversalSearchResultsView`** - Categorized search results display
- **`AppSearchResultsView`** - Application-specific search results

### **Smart Features**
- **Context locking** - Remembers what app you came from
- **Multi-strategy automation** - Adapts to each app's capabilities
- **Visual AI integration** - Screenshot analysis with OCR
- **Conversation memory** - Persistent chat history

---

## 🔮 What Makes It Special

### **Speed & Performance**
- **Sub-100ms search** - Faster than any Mac search tool
- **Smart caching** - Pre-indexes common searches
- **Background processing** - Never blocks your workflow

### **Intelligence**
- **Context awareness** - Knows what you're working on
- **Visual understanding** - Can analyze screenshots
- **Conversation memory** - Builds on previous interactions

### **Automation**
- **Cross-app writing** - Works with any text-capable app
- **Smart detection** - Automatically recognizes writing contexts
- **Reliable execution** - Multiple fallback strategies ensure success

### **User Experience**
- **Instant access** - Global hotkey works from anywhere
- **Beautiful design** - Glass morphism with smooth animations
- **Zero friction** - Appears, helps, disappears seamlessly

---

## 🤝 Contributing

We welcome contributions! Here's how to get started:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Make your changes**
4. **Test thoroughly**
5. **Submit a pull request**

### **Areas for contribution:**
- New app automation support
- Additional AI model integrations
- UI/UX improvements
- Performance optimizations
- Bug fixes and stability

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 🙏 Acknowledgments

- **Google** - For the powerful Gemini AI API
- **Apple** - For the robust macOS automation frameworks
- **The community** - For testing, feedback, and contributions

---

**Made with ❤️ for Mac users who want to work smarter, not harder.**

*Transform your Mac into an intelligent productivity powerhouse. Search anything, chat with AI, and automate your writing - all with a simple keyboard shortcut.* 
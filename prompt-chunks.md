# AI Spotlight App - UI Development Prompts for AI Agent

## Chunk 1: Main Window Container
**Create a SwiftUI main window container for an AI Spotlight app with the following specifications:**

Build a translucent window with blur background that appears as a system-wide overlay. The window should be 680px wide with dynamic height (300-600px based on content). Add 16px padding around all content and 12px corner radius. The window must support both light and dark mode with adaptive system colors.

Implement Cmd+J global hotkey activation that brings the window to front with a smooth fade-in animation (0.2s duration with slight scale effect from 0.95 to 1.0). Add Escape key functionality to close/minimize the window.

The window should layer above all other applications and maintain focus when active. Use proper SwiftUI window management and ensure smooth performance.

---

## Chunk 2: Search Bar Component
**Create a SwiftUI search bar component with these requirements:**

Build a centered, expandable text input field with rounded corners (8px radius). The search bar should auto-focus when the app launches and support Cmd+K to refocus from anywhere in the app.

Add dynamic placeholder text that cycles through hints like "Search files, ask AI, or chat..." with smooth transitions. Implement real-time typing feedback with subtle visual cues.

The input should expand smoothly when focused and contract when empty. Add proper text field styling that matches macOS design patterns. Ensure the search bar integrates seamlessly with the main window container.

---

## Chunk 3: Results List View
**Create a SwiftUI results list component with these specifications:**

Build a vertical scrollable list that displays maximum 8-10 visible items below the search bar. Each list item should support different types: file results (with system icons, names, and paths), AI responses (with AI avatar), quick actions (with system icons), and web results (with favicons).

Implement full keyboard navigation using up/down arrow keys with visual selection highlighting. Add click selection and hover effects. Use 8px spacing between items and ensure smooth scrolling performance.

Each item should display relevant information clearly with proper typography (SF Pro fonts). Add smooth selection animations and ensure the list integrates properly with the search bar above it.

---

## Chunk 4: Preview Pane
**Create a SwiftUI preview pane component with these requirements:**

Build a right-side expandable panel that shows previews of selected items from the results list. The pane should slide in smoothly from the right when an item is selected and slide out when deselected.

Support multiple content types including text files, images, and document previews. Add a subtle border or separator between the main results and preview area. The preview should be responsive and resize based on content.

Include basic file information (size, modified date, path) at the bottom of the preview. Ensure the preview pane doesn't interfere with keyboard navigation of the main results list.

---

## Chunk 5: Chat Interface Mode
**Create a SwiftUI chat interface with these specifications:**

Build a complete chat system that can replace the results list view. Include chat message bubbles with user messages right-aligned in blue and AI responses left-aligned in gray. Add message timestamps and proper text wrapping.

Implement an expandable input text area at the bottom with a send button. Add AI processing indicators (typing dots or spinner) when waiting for responses. Create a scrollable conversation history that auto-scrolls to the latest message.

The chat interface should transition smoothly from search mode with a 0.3s crossfade animation. Support copying messages with right-click context menus. Ensure proper keyboard navigation where Enter sends messages and Shift+Enter adds new lines.

---

## Chunk 6: Mode Toggle System
**Create a SwiftUI mode switching system with these requirements:**

Build a system that seamlessly switches between search mode and chat mode. Detect when users want to enter chat mode (typing '?' or 'chat:' prefixes) and automatically switch modes with smooth animations.

Implement Tab key functionality to manually toggle between modes. Add subtle visual indicators showing the current mode (maybe small icons or text labels). Preserve user context when switching modes - don't clear inputs unnecessarily.

The mode switching should use a 0.3s crossfade animation between the results list and chat interface. Ensure state management properly handles the transition and maintains focus appropriately.

---

## Chunk 7: Settings Panel
**Create a SwiftUI settings interface with these specifications:**

Build a settings panel accessible via a gear icon in the corner of the main interface. The panel should slide in from the side or appear as a modal overlay with smooth animations.

Include these setting options: AI model selection dropdown, custom hotkey configuration, light/dark theme toggle, and privacy preferences. Each setting should apply in real-time without requiring app restart.

Use proper SwiftUI form components with clear labels and descriptions. Add input validation especially for hotkey customization. The settings should persist between app launches using UserDefaults or similar storage.

---

## Chunk 8: Context Menus & Actions
**Create SwiftUI context menus and action systems with these requirements:**

Implement right-click context menus for result items with relevant actions like "Open", "Open With...", "Reveal in Finder", "Copy Path", etc. The menus should be context-sensitive based on item type.

Add quick action buttons or shortcuts for common operations. Include system integration features that work with macOS file system and applications. Ensure keyboard shortcuts work alongside mouse interactions.

Context menus should appear with smooth animations and proper positioning. Add hover states for interactive elements and ensure accessibility compliance.

---

## Chunk 9: Loading & Error States
**Create SwiftUI loading and error state components with these requirements:**

Build loading indicators for different scenarios: search results loading, AI processing responses, and app initialization. Use appropriate animations like spinning indicators or progress bars.

Create error message displays that are user-friendly and actionable. Include retry mechanisms where appropriate. Add empty state illustrations or messages when no results are found.

Implement connection status indicators for AI services. Ensure loading states don't block user interaction unnecessarily and provide clear feedback about what's happening.

---

## Chunk 10: Accessibility & Polish
**Enhance the SwiftUI app with accessibility and polish features:**

Implement comprehensive VoiceOver support with proper accessibility labels, hints, and traits. Ensure full keyboard-only navigation works throughout the app. Add clear focus indicators that meet accessibility guidelines.

Support high contrast mode and respect system text scaling preferences. Test with different accessibility settings and ensure the app remains functional.

Add final polish touches like smooth micro-animations, proper sound effects (if appropriate), and ensure consistent spacing and typography throughout. Optimize performance for smooth 60fps interactions.

---

## General Implementation Guidelines for AI Agent:

1. **Use Modern SwiftUI**: Leverage the latest SwiftUI features and best practices
2. **State Management**: Use @State, @StateObject, and ObservableObject appropriately
3. **Performance**: Implement lazy loading and efficient list rendering
4. **Animations**: Use withAnimation() for smooth transitions
5. **System Integration**: Use proper macOS APIs for global hotkeys and system features
6. **Memory Management**: Ensure proper cleanup and avoid memory leaks
7. **Error Handling**: Implement robust error handling throughout
8. **Testing**: Make components testable and debuggable

**Development Order**: Implement chunks 1-4 first for MVP, then 5-7 for core features, then 8-10 for polish.
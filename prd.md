# AI Spotlight App - UI Product Requirements Document

## Overview
Build a SwiftUI-based AI-powered Spotlight application that provides intelligent search, chat functionality, and AI-enhanced responses with a clean, native macOS interface.

## Core UI Components

### 1. Main Search Interface
- **Primary Search Bar**: Center-focused, expandable search input with rounded corners
- **Activation**: Cmd+J hotkey trigger (system-wide overlay)
- **Visual State**: Translucent background with blur effect, similar to native Spotlight
- **Placeholder Text**: Dynamic hints like "Search files, ask AI, or chat..."
- **Input Feedback**: Real-time typing indicators and search suggestions

### 2. Results Display Panel
- **Layout**: Vertical list below search bar, maximum 8-10 visible items
- **Item Types**: 
  - File results (with icons, names, paths)
  - AI chat responses (with AI avatar/icon)
  - Quick actions (with system icons)
  - Web results (with favicons)
- **Selection**: Keyboard navigation (up/down arrows) with visual highlight
- **Preview Pane**: Right-side quick preview for selected items

### 3. Chat Interface Mode
- **Toggle**: Seamless transition from search to chat mode
- **Chat Bubbles**: User messages (right-aligned, blue) and AI responses (left-aligned, gray)
- **Input Area**: Expandable text input with send button
- **Conversation History**: Scrollable chat history with timestamps
- **Context Indicators**: Show when AI is processing/typing

### 4. Settings & Preferences
- **Access**: Settings gear icon in corner of main interface
- **AI Model Selection**: Dropdown for different AI providers/models
- **Hotkey Customization**: Custom keyboard shortcut settings
- **Theme Options**: Light/dark mode toggle
- **Privacy Settings**: Data retention and sharing preferences

## Visual Design Requirements

### Typography
- **Primary Text**: SF Pro Display, medium weight for search terms
- **Secondary Text**: SF Pro Text, regular weight for descriptions
- **Chat Text**: System font with comfortable reading size (14-16pt)

### Color Scheme
- **Background**: Dynamic blur with system colors (light/dark mode adaptive)
- **Accent Color**: System blue for selections and primary actions
- **Text Colors**: Primary and secondary label colors following system guidelines
- **AI Elements**: Subtle purple/blue accent for AI-specific components

### Layout & Spacing
- **Window Size**: 680px width, dynamic height (300-600px based on content)
- **Margins**: 16px padding around main content
- **Item Spacing**: 8px between result items
- **Corner Radius**: 12px for main window, 8px for individual items

## Interaction Patterns

### Keyboard Navigation
- **Tab**: Switch between search and chat modes
- **Enter**: Execute search or send chat message
- **Escape**: Close/minimize interface
- **Cmd+K**: Focus search bar from anywhere
- **Up/Down Arrows**: Navigate through results

### Mouse/Trackpad
- **Click**: Select items or place cursor
- **Hover**: Show additional item details
- **Scroll**: Navigate through long results or chat history
- **Right-click**: Context menus for items

## Animation & Transitions
- **Appearance**: Smooth fade-in with slight scale animation (0.2s)
- **Mode Switching**: Crossfade transition between search and chat (0.3s)
- **Result Loading**: Subtle loading indicators and progressive disclosure
- **Selection**: Smooth highlight transitions with gentle easing

## Accessibility Requirements
- **VoiceOver**: Full screen reader support for all elements
- **Keyboard Only**: Complete functionality without mouse
- **High Contrast**: Support for accessibility color schemes
- **Text Scaling**: Respect system text size settings
- **Focus Indicators**: Clear visual focus states for all interactive elements

## Technical Considerations for SwiftUI
- **State Management**: Clean separation between UI state and business logic
- **Performance**: Efficient list rendering for large result sets
- **Memory**: Proper cleanup of chat history and search caches
- **System Integration**: Native look and feel with system animations
- **Responsiveness**: Smooth 60fps interactions even during AI processing

## Success Metrics
- **Launch Speed**: Interface appears within 100ms of hotkey press
- **Search Response**: Results populate within 500ms for file searches
- **AI Response**: Chat responses begin appearing within 2 seconds
- **Smooth Interactions**: No dropped frames during animations and transitions
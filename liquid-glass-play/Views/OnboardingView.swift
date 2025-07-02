import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var isAnimating = false
    @State private var showFinalAnimation = false
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var heroNamespace
    
    private let totalPages = 4
    
    var body: some View {
        ZStack {
            // Clean background
            Color.clear
            
            VStack(spacing: 0) {
                Spacer(minLength: 20)
                
                // Main content with enhanced glass transitions
                ZStack {
                    switch currentPage {
                    case 0:
                        heroPage
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case 1:
                        visualPage
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case 2:
                        capabilityPage
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case 3:
                        startPage
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    default:
                        heroPage
                    }
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentPage)
                
                Spacer(minLength: 20)
                
                // Apple-style progress dots
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.blue : Color.secondary.opacity(0.3))
                            .frame(width: index == currentPage ? 8 : 6, height: index == currentPage ? 8 : 6)
                            .scaleEffect(index == currentPage ? 1.2 : 1.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.bottom, 32)

                // Apple-style CTA section
                VStack(spacing: 12) {
                    Button(action: nextPage) {
                        HStack(spacing: 8) {
                            Text(currentPage == totalPages - 1 ? "Get Started" : "Continue")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                            
                            if currentPage < totalPages - 1 {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: 280)
                        .frame(height: 50)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                        .shadow(color: .blue.opacity(0.3), radius: 15, x: 0, y: 8)
                    }
                    .buttonStyle(.borderless)
                    .scaleEffect(showFinalAnimation ? 1.05 : 1.0)
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.6)
                          .repeatCount(3, autoreverses: true)
                          .delay(0.3),
                        value: showFinalAnimation
                    )

                    // Minimal back button
                    Button("Back") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentPage -= 1
                        }
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .opacity(currentPage > 0 ? 1 : 0)
                    .animation(.easeInOut, value: currentPage)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .padding(.top, 40)
        }
        .frame(minWidth: 600, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
        .frame(idealWidth: 800, idealHeight: 650)
        .liquidGlassRect(cornerRadius: 28)
        .shadow(color: .black.opacity(0.3), radius: 40, x: 0, y: 20)
        .onAppear {
            // Clean appearance
        }
        .onChange(of: currentPage) { newValue in
            if newValue == totalPages - 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showFinalAnimation = true
                }
            }
        }
    }
    
    // MARK: - Pages
    
    private var heroPage: some View {
        VStack(spacing: 32) {
            // Clean hero icon with liquid glass effect
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 120, height: 120)
                    .liquidGlassRect(cornerRadius: 60)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50, weight: .ultraLight))
                    .foregroundColor(.blue)
            }
            .matchedGeometryEffect(id: "heroIcon", in: heroNamespace)
            
            VStack(spacing: 16) {
                Text("Welcome to SearchFast")
                    .font(.system(size: 36, weight: .semibold, design: .default))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("The AI-powered universal search for your Mac")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .padding(.horizontal, 50)
    }
    
    private var visualPage: some View {
        VStack(spacing: 40) {
            VStack(spacing: 16) {
                Text("How It Works")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Press ⌘ + Shift + Space from anywhere")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            // Clean visual demonstration with liquid glass
            VStack(spacing: 20) {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Text("SearchFast")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .liquidGlassRect(cornerRadius: 12)
                    
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                        
                        Text("Ask me anything...")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .frame(width: 340)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                
                Text("Appears instantly over any application")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 50)
    }
    
    private var capabilityPage: some View {
        VStack(spacing: 24) {
            Text("Understands Your Context")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.top, 10)
            
            VStack(spacing: 16) {
                CapabilityRow(
                    icon: "eye",
                    title: "Sees what you're doing",
                    description: "AI agent sees what you are doing to understand your workflow"
                )
                
                CapabilityRow(
                    icon: "brain",
                    title: "Thinks contextually", 
                    description: "AI analyzes your screen and suggests relevant actions"
                )
                
                CapabilityRow(
                    icon: "gearshape.2",
                    title: "Acts intelligently",
                    description: "Automates tasks across your applications"
                )
            }
            .padding(.vertical, 8)
            
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.green)
                
                Text("Privacy-first • Everything stays on your Mac")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .liquidGlassRect(cornerRadius: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.green.opacity(0.3), lineWidth: 1)
            )
            .padding(.bottom, 10)
        }
        .padding(.horizontal, 40)
    }
    
    private var startPage: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .liquidGlassRect(cornerRadius: 50)
                    .overlay(
                        Circle()
                            .stroke(.green.opacity(0.4), lineWidth: 1)
                    )
                
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 16) {
                Text("You're All Set")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("We'll request permissions as needed.\nYour privacy is always protected.")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            HStack(spacing: 12) {
                Text("⌘ + Shift + Space")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text("to open from anywhere")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 50)
    }
    
    // MARK: - Helper Functions
    
    private func nextPage() {
        if currentPage < totalPages - 1 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentPage += 1
            }
        } else {
            completeOnboarding()
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        // After onboarding is complete, trigger hotkey instructions
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NotificationCenter.default.post(name: NSNotification.Name("ShowHotkeyInstructions"), object: nil)
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

// MARK: - Supporting Views

struct CapabilityRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 40, height: 40)
                    .liquidGlassRect(cornerRadius: 20)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.blue)
            }
            .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 72)
        .liquidGlassRect(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
        .frame(width: 800, height: 650)
}

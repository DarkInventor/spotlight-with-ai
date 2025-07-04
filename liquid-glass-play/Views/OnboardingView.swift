import SwiftUI
import ApplicationServices
import ServiceManagement

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var isAnimating = false
    @State private var showFinalAnimation = false
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var heroNamespace
    @StateObject private var firebaseManager = FirebaseManager()
    @StateObject private var permissionManager = PermissionManager()
    
    // User input fields
    @State private var userName = ""
    @State private var userEmail = ""
    @State private var password = ""
    @State private var isSignUp = true
    @State private var showingAuthError = false
    
    private var totalPages: Int {
        // If user is authenticated, show reduced flow: welcome back + permissions + start
        return firebaseManager.isAuthenticated ? 3 : 6
    }
    
    var body: some View {
        ZStack {
            // Clean background
            Color.clear
            
            VStack(spacing: 0) {
                Spacer(minLength: 20)
                
                // Main content with enhanced glass transitions
                ZStack {
                    currentPageView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
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
                            Text(getButtonText())
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
                        .background(getButtonColor())
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                        .shadow(color: getButtonColor().opacity(0.3), radius: 15, x: 0, y: 8)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canProceed())
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
            // Start permission checking
            Task {
                await permissionManager.checkAllPermissions()
            }
        }
        .onChange(of: currentPage) { newValue in
            if newValue == totalPages - 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showFinalAnimation = true
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func canProceed() -> Bool {
        if firebaseManager.isAuthenticated {
            switch currentPage {
            case 1: // Permissions page
                return permissionManager.allPermissionsGranted
            default:
                return true
            }
        } else {
            switch currentPage {
            case 4: // Permissions page for new users
                return permissionManager.allPermissionsGranted
            default:
                return true
            }
        }
    }
    
    private func getButtonColor() -> Color {
        return canProceed() ? .blue : .gray
    }
    
    // MARK: - Current Page Logic
    
    @ViewBuilder
    private var currentPageView: some View {
        if firebaseManager.isAuthenticated {
            // Shortened flow for authenticated users
            switch currentPage {
            case 0:
                authPage // Welcome back page
            case 1:
                permissionsPage
            case 2:
                startPage
            default:
                authPage
            }
        } else {
            // Full flow for new users
            switch currentPage {
            case 0:
                heroPage
            case 1:
                visualPage
            case 2:
                compactCapabilityPage
            case 3:
                authPage
            case 4:
                permissionsPage
            case 5:
                startPage
            default:
                heroPage
            }
        }
    }
    
    // MARK: - Permission Page
    
    private var permissionsPage: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(.blue)
                
                Text("Setup Permissions")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("SearchFast needs these permissions to work properly")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "hand.raised.fill",
                    title: "Accessibility Access",
                    description: "Required for global shortcuts (⌘+Shift+Space) and app automation",
                    status: permissionManager.accessibilityPermission,
                    isRequired: true
                ) {
                    Task {
                        await permissionManager.requestAccessibilityPermission()
                    }
                }
                
                PermissionRow(
                    icon: "camera.fill",
                    title: "Screen Recording",
                    description: "Lets SearchFast see your screen for intelligent context",
                    status: permissionManager.screenRecordingPermission,
                    isRequired: true
                ) {
                    Task {
                        await permissionManager.requestScreenRecordingPermission()
                    }
                }
                
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Enables voice commands and speech-to-text",
                    status: permissionManager.microphonePermission,
                    isRequired: false
                ) {
                    Task {
                        await permissionManager.requestMicrophonePermission()
                    }
                }
                
                PermissionRow(
                    icon: "gearshape.2.fill",
                    title: "App Automation",
                    description: "Allows automation of other apps like Word, Chrome, etc.",
                    status: permissionManager.automationPermission,
                    isRequired: false
                ) {
                    Task {
                        await permissionManager.requestAutomationPermission()
                    }
                }
            }
            
            if !permissionManager.allPermissionsGranted {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.orange)
                        
                        Text("Some permissions are missing")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    Text("Click the buttons above or grant permissions manually in System Preferences > Privacy & Security")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Open System Preferences") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                )
            } else {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.green)
                    
                    Text("All permissions granted! Ready to go.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.green.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 40)
        .onAppear {
            // Refresh permission status when page appears
            Task {
                await permissionManager.checkAllPermissions()
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
    
    // MARK: - Compact Capability Page (Made smaller as requested)
    private var compactCapabilityPage: some View {
        VStack(spacing: 20) {
            Text("Understands Your Context")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                CompactCapabilityRow(icon: "eye", title: "Sees what you're doing")
                CompactCapabilityRow(icon: "brain", title: "Thinks contextually")
                CompactCapabilityRow(icon: "gearshape.2", title: "Acts intelligently")
            }
            
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
                
                Text("Privacy-first • Everything stays on your Mac")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .liquidGlassRect(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.green.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, 50)
    }
    
    // MARK: - Authentication Page
    private var authPage: some View {
        VStack(spacing: 24) {
            if firebaseManager.isAuthenticated {
                // Welcome back view for already authenticated users
                welcomeBackView
            } else {
                // Login/signup form for new users
                authenticationForm
            }
        }
        .padding(.horizontal, 50)
        .alert("Authentication Error", isPresented: $showingAuthError) {
            Button("OK") { }
        } message: {
            Text(firebaseManager.authError ?? "An error occurred")
        }
        .onChange(of: firebaseManager.authError) { error in
            showingAuthError = error != nil
        }
    }
    
    // MARK: - Welcome Back View (for authenticated users)
    private var welcomeBackView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80, weight: .medium))
                    .foregroundColor(.green)
                
                Text("Welcome Back!")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Hello, \(firebaseManager.getUserDisplayName())")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("You're already signed in and ready to go")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                // Account info card
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Text(firebaseManager.getUserEmail())
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(firebaseManager.userProfile?.provider.capitalized ?? "")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .liquidGlassRect(cornerRadius: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.green.opacity(0.3), lineWidth: 1)
                )
                
                // Logout button
                Button(action: {
                    firebaseManager.signOut()
                    // The onChange listener will handle showing the auth form
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .medium))
                        Text("Sign Out")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.red.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 320)
        }
    }
    
    // MARK: - Authentication Form (for new users)
    private var authenticationForm: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Create Your Account")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Save your preferences and sync across devices")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                // Name field
                HStack {
                    Image(systemName: "person")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    TextField("Full Name", text: $userName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .liquidGlassRect(cornerRadius: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                
                // Email field
                HStack {
                    Image(systemName: "envelope")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    TextField("Email Address", text: $userEmail)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .liquidGlassRect(cornerRadius: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                
                // Password field
                HStack {
                    Image(systemName: "lock")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .liquidGlassRect(cornerRadius: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                
                // Toggle between sign up/sign in
                HStack {
                    Button(action: { isSignUp = true }) {
                        Text("Sign Up")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isSignUp ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Button(action: { isSignUp = false }) {
                        Text("Sign In")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(!isSignUp ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                // Divider
                HStack {
                    VStack { Divider() }
                    Text("or")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                    VStack { Divider() }
                }
                .padding(.vertical, 8)
                
                // Anonymous option
                Button(action: {
                    Task {
                        await firebaseManager.signInAnonymously()
                        if firebaseManager.isAuthenticated {
                            nextPage()
                        }
                    }
                }) {
                    Text("Continue without account")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .underline()
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 320)
            
            if firebaseManager.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
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
    
    private func getButtonText() -> String {
        if firebaseManager.isAuthenticated {
            // For authenticated users (0: welcome back, 1: permissions, 2: start)
            switch currentPage {
            case 0:
                return "Continue"
            case 1:
                return permissionManager.allPermissionsGranted ? "Continue" : "Grant Permissions"
            case 2:
                return "Start Using App"
            default:
                return "Continue"
            }
        } else {
            // For new users (0: hero, 1: visual, 2: capability, 3: auth, 4: permissions, 5: start)
            switch currentPage {
            case 0, 1, 2:
                return "Continue"
            case 3:
                return "Continue"
            case 4:
                return permissionManager.allPermissionsGranted ? "Continue" : "Grant Permissions"
            case 5:
                return "Get Started"
            default:
                return "Continue"
            }
        }
    }
    
    private func nextPage() {
        if firebaseManager.isAuthenticated {
            // For authenticated users - simplified flow
            if currentPage == 1 && !permissionManager.allPermissionsGranted {
                // On permissions page but not all permissions granted
                Task {
                    await permissionManager.requestAllPermissions()
                }
                return
            }
            
            if currentPage < totalPages - 1 {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    currentPage += 1
                }
            } else {
                completeOnboarding()
            }
        } else {
            // For new users - full flow with authentication
            if currentPage == 3 {
                handleAuthentication()
                return
            }
            
            if currentPage == 4 && !permissionManager.allPermissionsGranted {
                // On permissions page but not all permissions granted
                Task {
                    await permissionManager.requestAllPermissions()
                }
                return
            }
            
            if currentPage < totalPages - 1 {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    currentPage += 1
                }
            } else {
                completeOnboarding()
            }
        }
    }
    
    private func handleAuthentication() {
        guard !userName.isEmpty || !userEmail.isEmpty else {
            // Allow skipping authentication
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentPage += 1
            }
            return
        }
        
        Task {
            if isSignUp {
                // Validate inputs
                guard !userName.isEmpty, !userEmail.isEmpty, !password.isEmpty else {
                    firebaseManager.authError = "Please fill in all fields"
                    return
                }
                
                guard firebaseManager.isValidEmail(userEmail) else {
                    firebaseManager.authError = "Please enter a valid email address"
                    return
                }
                
                guard password.count >= 6 else {
                    firebaseManager.authError = "Password must be at least 6 characters"
                    return
                }
                
                let success = await firebaseManager.createUserWithEmail(userEmail, password: password, name: userName)
                if success {
                    await MainActor.run {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            currentPage += 1
                        }
                    }
                }
            } else {
                // Sign in
                guard !userEmail.isEmpty, !password.isEmpty else {
                    firebaseManager.authError = "Please enter email and password"
                    return
                }
                
                let success = await firebaseManager.signInWithEmail(userEmail, password: password)
                if success {
                    await MainActor.run {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            currentPage += 1
                        }
                    }
                }
            }
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        // Register for launch at login
        do {
            try SMAppService.mainApp.register()
            print("🚀 Successfully registered for launch at login.")
        } catch {
            print("❌ Failed to register for launch at login: \(error.localizedDescription)")
        }
        
        // Switch to background mode now that onboarding is complete
        NSApp.setActivationPolicy(.accessory)
        print("🔄 Onboarding complete - switching to background mode")
        
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

struct CompactCapabilityRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 32, height: 32)
                    .liquidGlassRect(cornerRadius: 16)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
            }
            
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .liquidGlassRect(cornerRadius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let isRequired: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 40, height: 40)
                    .liquidGlassRect(cornerRadius: 20)
                    .overlay(
                        Circle()
                            .stroke(statusColor.opacity(0.3), lineWidth: 1)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if isRequired {
                        Text("REQUIRED")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Spacer()
                    
                    statusIndicator
                }
                
                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                if status != .granted {
                    Button(action: action) {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 12, weight: .medium))
                            Text("Grant Permission")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .liquidGlassRect(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var statusColor: Color {
        switch status {
        case .granted:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        }
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(statusColor)
            
            Text(statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(statusColor)
        }
    }
    
    private var statusIcon: String {
        switch status {
        case .granted:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        }
    }
    
    private var statusText: String {
        switch status {
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Set"
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
        .frame(width: 800, height: 650)
}

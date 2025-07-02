import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

@MainActor
class FirebaseManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var userProfile: UserProfile?
    @Published var authError: String?
    @Published var isLoading = false
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    struct UserProfile: Codable, Identifiable {
        let id: String
        let email: String
        let name: String
        let photoURL: String?
        let provider: String // "email", "anonymous"
        let createdAt: Date
        let lastActiveAt: Date
        let isEmailVerified: Bool
        
        enum CodingKeys: String, CodingKey {
            case id, email, name, photoURL, provider, createdAt, lastActiveAt, isEmailVerified
        }
    }
    
    init() {
        // Configure Firebase if not already configured
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Firebase Auth will handle Google Sign-In through the configured provider
        
        // Check for existing auth state and restore session
        if let currentUser = auth.currentUser {
            self.currentUser = currentUser
            self.isAuthenticated = true
            Task {
                await loadUserProfile(userId: currentUser.uid)
            }
        }
        
        // Listen for auth state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                
                if let user = user {
                    await self?.loadUserProfile(userId: user.uid)
                } else {
                    self?.userProfile = nil
                }
            }
        }
    }
    
    // MARK: - Authentication Methods
    

    
    func signInAnonymously() async {
        isLoading = true
        authError = nil
        
        do {
            let result = try await auth.signInAnonymously()
            
            // Create anonymous user profile
            let profile = UserProfile(
                id: result.user.uid,
                email: "",
                name: "Anonymous User",
                photoURL: nil,
                provider: "anonymous",
                createdAt: Date(),
                lastActiveAt: Date(),
                isEmailVerified: false
            )
            
            try await saveUserProfile(profile)
            
            print("✅ Firebase: Anonymous sign-in successful for user: \(result.user.uid)")
        } catch {
            authError = "Failed to sign in: \(error.localizedDescription)"
            print("❌ Firebase: Anonymous sign-in failed: \(error)")
        }
        
        isLoading = false
    }
    
    func createUserWithEmail(_ email: String, password: String, name: String) async -> Bool {
        isLoading = true
        authError = nil
        
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            
            // Create user profile in Firestore
            let profile = UserProfile(
                id: result.user.uid,
                email: email,
                name: name,
                photoURL: nil,
                provider: "email",
                createdAt: Date(),
                lastActiveAt: Date(),
                isEmailVerified: result.user.isEmailVerified
            )
            
            try await saveUserProfile(profile)
            
            print("✅ Firebase: User created successfully: \(result.user.uid)")
            isLoading = false
            return true
            
        } catch {
            authError = "Failed to create account: \(error.localizedDescription)"
            print("❌ Firebase: User creation failed: \(error)")
            isLoading = false
            return false
        }
    }
    
    func signInWithEmail(_ email: String, password: String) async -> Bool {
        isLoading = true
        authError = nil
        
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            print("✅ Firebase: Sign-in successful for user: \(result.user.uid)")
            isLoading = false
            return true
            
        } catch {
            authError = "Failed to sign in: \(error.localizedDescription)"
            print("❌ Firebase: Sign-in failed: \(error)")
            isLoading = false
            return false
        }
    }
    
    func signOut() {
        do {
            try auth.signOut()
            userProfile = nil
            print("✅ Firebase: User signed out successfully")
        } catch {
            authError = "Failed to sign out: \(error.localizedDescription)"
            print("❌ Firebase: Sign out failed: \(error)")
        }
    }
    
    // MARK: - Firestore Methods
    
    private func saveUserProfile(_ profile: UserProfile) async throws {
        try await db.collection("profiles").document(profile.id).setData([
            "email": profile.email,
            "name": profile.name,
            "photoURL": profile.photoURL ?? "",
            "provider": profile.provider,
            "createdAt": Timestamp(date: profile.createdAt),
            "lastActiveAt": Timestamp(date: profile.lastActiveAt),
            "isEmailVerified": profile.isEmailVerified
        ])
        
        self.userProfile = profile
        print("✅ Firebase: User profile saved to Firestore profiles collection")
    }
    
    private func loadUserProfile(userId: String) async {
        do {
            let document = try await db.collection("profiles").document(userId).getDocument()
            
            if document.exists, let data = document.data() {
                let profile = UserProfile(
                    id: userId,
                    email: data["email"] as? String ?? "",
                    name: data["name"] as? String ?? "",
                    photoURL: data["photoURL"] as? String,
                    provider: data["provider"] as? String ?? "unknown",
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    lastActiveAt: (data["lastActiveAt"] as? Timestamp)?.dateValue() ?? Date(),
                    isEmailVerified: data["isEmailVerified"] as? Bool ?? false
                )
                
                self.userProfile = profile
                
                // Update last active time
                try await updateLastActiveTime(userId: userId)
                
                print("✅ Firebase: User profile loaded from Firestore profiles collection")
            }
        } catch {
            print("❌ Firebase: Failed to load user profile: \(error)")
        }
    }
    
    func updateUserProfile(name: String) async {
        guard let userId = currentUser?.uid else { return }
        
        do {
            try await db.collection("profiles").document(userId).updateData([
                "name": name,
                "lastActiveAt": Timestamp(date: Date())
            ])
            
            // Update local profile
            if let profile = userProfile {
                let updatedProfile = UserProfile(
                    id: profile.id,
                    email: profile.email,
                    name: name,
                    photoURL: profile.photoURL,
                    provider: profile.provider,
                    createdAt: profile.createdAt,
                    lastActiveAt: Date(),
                    isEmailVerified: profile.isEmailVerified
                )
                self.userProfile = updatedProfile
            }
            
            print("✅ Firebase: User profile updated")
        } catch {
            print("❌ Firebase: Failed to update user profile: \(error)")
        }
    }
    
    private func updateLastActiveTime(userId: String) async throws {
        try await db.collection("profiles").document(userId).updateData([
            "lastActiveAt": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Authentication State Management
    
    func requireAuthentication() -> Bool {
        return !isAuthenticated
    }
    
    func getUserDisplayName() -> String {
        return userProfile?.name ?? currentUser?.displayName ?? "User"
    }
    
    func getUserEmail() -> String {
        return userProfile?.email ?? currentUser?.email ?? ""
    }
    
    // MARK: - Usage Analytics (Optional)
    
    func logAppUsage() async {
        guard let userId = currentUser?.uid else { return }
        
        do {
            try await db.collection("usage_logs").addDocument(data: [
                "userId": userId,
                "timestamp": Timestamp(date: Date()),
                "action": "app_opened"
            ])
        } catch {
            print("❌ Firebase: Failed to log usage: \(error)")
        }
    }
    
    func logSearchQuery(_ query: String) async {
        guard let userId = currentUser?.uid else { return }
        
        do {
            try await db.collection("search_logs").addDocument(data: [
                "userId": userId,
                "query": query,
                "timestamp": Timestamp(date: Date())
            ])
        } catch {
            print("❌ Firebase: Failed to log search: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    func generateTemporaryPassword() -> String {
        return UUID().uuidString.prefix(8).lowercased()
    }
} 

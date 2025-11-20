import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var settings: UserSettings?
    @State private var userName: String = ""
    @State private var userEmail: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemBackground).opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar Section
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                            }
                            
                            Button(action: {}) {
                                Text("Change Photo")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.top, 20)
                        
                        // Form Fields
                        VStack(spacing: 16) {
                            LiquidGlassCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Name")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    
                                    TextField("Enter your name", text: $userName)
                                        .textFieldStyle(.plain)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                                .padding()
                            }
                            
                            LiquidGlassCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Email")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    
                                    TextField("Enter your email", text: $userEmail)
                                        .textFieldStyle(.plain)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                }
                                .padding()
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                userName = settings?.userName ?? ""
                userEmail = settings?.userEmail ?? ""
            }
        }
    }
    
    private func saveProfile() {
        settings?.userName = userName.isEmpty ? nil : userName
        settings?.userEmail = userEmail.isEmpty ? nil : userEmail
        settings?.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            print("Failed to save profile: \(error)")
        }
    }
}


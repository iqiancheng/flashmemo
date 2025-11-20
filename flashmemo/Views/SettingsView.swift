import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [UserSettings]
    @State private var currentSettings: UserSettings?
    @State private var showingProfile = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background with gradient
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
                    VStack(spacing: 20) {
                        // Profile Section
                        LiquidGlassCard {
                            Button(action: { showingProfile = true }) {
                                HStack(spacing: 16) {
                                    // Avatar
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.blue, .purple],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 60, height: 60)
                                        
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(currentSettings?.userName ?? "User")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text(currentSettings?.userEmail ?? "Tap to edit profile")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        }
                        
                        // Language Settings
                        LiquidGlassCard {
                            NavigationLink(destination: LanguageSettingsView(settings: $currentSettings)) {
                                SettingsRow(
                                    icon: "globe",
                                    title: "Language Priority",
                                    subtitle: "\(currentSettings?.preferredLanguages.count ?? 0) languages configured",
                                    iconColor: .blue
                                )
                            }
                        }
                        
                        // Proper Nouns Settings
                        LiquidGlassCard {
                            NavigationLink(destination: ProperNounsView(settings: $currentSettings)) {
                                SettingsRow(
                                    icon: "textformat.abc",
                                    title: "Proper Nouns",
                                    subtitle: "\(currentSettings?.properNounsArray.count ?? 0) terms",
                                    iconColor: .purple
                                )
                            }
                        }
                        
                        // Polish Model Settings
                        LiquidGlassCard {
                            NavigationLink(destination: PolishModelView(settings: $currentSettings)) {
                                SettingsRow(
                                    icon: currentSettings?.polishModel.icon ?? "sparkles",
                                    title: "Polish Model",
                                    subtitle: currentSettings?.polishModel.rawValue ?? "Apple AFM",
                                    iconColor: .orange
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingProfile) {
                ProfileView(settings: $currentSettings)
            }
            .onAppear {
                loadSettings()
            }
        }
    }
    
    private func loadSettings() {
        if let existing = settings.first {
            currentSettings = existing
        } else {
            let newSettings = UserSettings()
            modelContext.insert(newSettings)
            currentSettings = newSettings
            do {
                try modelContext.save()
            } catch {
                print("Failed to save settings: \(error)")
            }
        }
    }
}

// MARK: - Settings Row Component
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Liquid Glass Card Component (iOS 26 Style)
struct LiquidGlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.3),
                                        .white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
    }
}


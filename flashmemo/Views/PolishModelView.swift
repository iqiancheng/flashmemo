import SwiftUI
import SwiftData

struct PolishModelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var settings: UserSettings?
    @State private var selectedModel: PolishModelType = .appleAFM
    @State private var openAIAPIKey: String = ""
    @State private var openAIBaseURL: String = ""
    @State private var showingAPIKey = false
    
    var body: some View {
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
                VStack(spacing: 20) {
                    // Model Selection
                    VStack(spacing: 12) {
                        ForEach(PolishModelType.allCases, id: \.self) { model in
                            ModelOptionCard(
                                model: model,
                                isSelected: selectedModel == model,
                                onSelect: {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedModel = model
                                    }
                                }
                            )
                        }
                    }
                    
                    // OpenAI Configuration (only show if OpenAI is selected)
                    if selectedModel == .openAICompatible {
                        VStack(spacing: 16) {
                            LiquidGlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "key.fill")
                                            .foregroundColor(.orange)
                                        
                                        Text("API Configuration")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Divider()
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("API Key")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                        
                                        HStack {
                                            if showingAPIKey {
                                                TextField("Enter API key", text: $openAIAPIKey)
                                                    .textFieldStyle(.plain)
                                                    .font(.system(.body, design: .monospaced))
                                                    .foregroundColor(.primary)
                                            } else {
                                                Text(openAIAPIKey.isEmpty ? "Not set" : String(repeating: "•", count: min(openAIAPIKey.count, 20)))
                                                    .font(.system(.body, design: .monospaced))
                                                    .foregroundColor(openAIAPIKey.isEmpty ? .secondary : .primary)
                                            }
                                            
                                            Button(action: { showingAPIKey.toggle() }) {
                                                Image(systemName: showingAPIKey ? "eye.slash.fill" : "eye.fill")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Base URL (Optional)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                        
                                        TextField("https://api.openai.com/v1", text: $openAIBaseURL)
                                            .textFieldStyle(.plain)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.primary)
                                            .keyboardType(.URL)
                                            .autocapitalization(.none)
                                    }
                                }
                                .padding()
                            }
                            
                            // Info Card
                            LiquidGlassCard {
                                HStack(spacing: 12) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("OpenAI Compatible API")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("Supports OpenAI API and compatible services. Leave Base URL empty to use OpenAI's default endpoint.")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Polish Model")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveSettings()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        selectedModel = settings?.polishModel ?? .appleAFM
        openAIAPIKey = settings?.openAIAPIKey ?? ""
        openAIBaseURL = settings?.openAIBaseURL ?? ""
    }
    
    private func saveSettings() {
        settings?.polishModel = selectedModel
        settings?.openAIAPIKey = openAIAPIKey.isEmpty ? nil : openAIAPIKey
        settings?.openAIBaseURL = openAIBaseURL.isEmpty ? nil : openAIBaseURL
        settings?.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            print("Failed to save model settings: \(error)")
        }
    }
}

// MARK: - Model Option Card
struct ModelOptionCard: View {
    let model: PolishModelType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            LiquidGlassCard {
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                isSelected ?
                                LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color(.systemGray5), Color(.systemGray5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: model.icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(isSelected ? .white : .secondary)
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.rawValue)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(model.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Selection Indicator
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.orange : Color.clear)
                            .frame(width: 24, height: 24)
                            .overlay {
                                Circle()
                                    .stroke(isSelected ? Color.orange : Color.secondary, lineWidth: 2)
                            }
                        
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding()
            }
        }
        .buttonStyle(.plain)
    }
}


import SwiftUI
import SwiftData

struct ProperNounsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var settings: UserSettings?
    @State private var properNouns: [ProperNoun] = []
    @State private var showingAddNoun = false
    @State private var editingNoun: ProperNoun?
    
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
                VStack(spacing: 16) {
                    // Info Card
                    LiquidGlassCard {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.purple)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Proper Nouns")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Add custom terms and their definitions to improve transcription accuracy.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                    }
                    
                    // Proper Nouns List
                    if properNouns.isEmpty {
                        LiquidGlassCard {
                            VStack(spacing: 12) {
                                Image(systemName: "textformat.abc")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text("No proper nouns added")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Add terms to improve transcription accuracy")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(40)
                        }
                    } else {
                        ForEach(properNouns) { noun in
                            ProperNounRow(
                                noun: noun,
                                onEdit: {
                                    editingNoun = noun
                                    showingAddNoun = true
                                },
                                onDelete: {
                                    withAnimation(.spring(response: 0.3)) {
                                        if let index = properNouns.firstIndex(where: { $0.id == noun.id }) {
                                            let nounToDelete = properNouns[index]
                                            properNouns.remove(at: index)
                                            modelContext.delete(nounToDelete)
                                            saveProperNouns()
                                        }
                                    }
                                }
                            )
                        }
                    }
                    
                    // Add Button
                    Button(action: {
                        editingNoun = nil
                        showingAddNoun = true
                    }) {
                        LiquidGlassCard {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.purple)
                                
                                Text("Add Proper Noun")
                                    .font(.headline)
                                    .foregroundColor(.purple)
                                
                                Spacer()
                            }
                            .padding()
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Proper Nouns")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddNoun) {
            AddProperNounView(
                noun: editingNoun,
                onSave: { term, definition in
                    if let editing = editingNoun {
                        // Update existing
                        if let index = properNouns.firstIndex(where: { $0.id == editing.id }) {
                            properNouns[index].term = term
                            properNouns[index].definition = definition
                        }
                    } else {
                        // Add new
                        let newNoun = ProperNoun(term: term, definition: definition)
                        modelContext.insert(newNoun)
                        properNouns.append(newNoun)
                    }
                    saveProperNouns()
                    showingAddNoun = false
                    editingNoun = nil
                }
            )
        }
        .onAppear {
            loadProperNouns()
        }
    }
    
    private func loadProperNouns() {
        properNouns = settings?.properNounsArray ?? []
    }
    
    private func saveProperNouns() {
        settings?.properNounsArray = properNouns
        settings?.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            print("Failed to save proper nouns: \(error)")
        }
    }
}

// MARK: - Proper Noun Row
struct ProperNounRow: View {
    let noun: ProperNoun
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(noun.term)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(noun.definition)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // Edit Button
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        // Delete Button
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                                .padding(8)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Add Proper Noun View
struct AddProperNounView: View {
    @Environment(\.dismiss) private var dismiss
    let noun: ProperNoun?
    let onSave: (String, String) -> Void
    
    @State private var term: String = ""
    @State private var definition: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
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
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Term")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                TextField("Enter term", text: $term)
                                    .textFieldStyle(.plain)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                        }
                        
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Definition")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                TextField("Enter definition", text: $definition, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineLimit(3...6)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(noun == nil ? "Add Proper Noun" : "Edit Proper Noun")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !term.isEmpty && !definition.isEmpty {
                            onSave(term, definition)
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(term.isEmpty || definition.isEmpty)
                }
            }
            .onAppear {
                if let noun = noun {
                    term = noun.term
                    definition = noun.definition
                }
            }
        }
    }
}


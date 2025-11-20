import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LanguageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var settings: UserSettings?
    @State private var languages: [LanguageItem] = []
    @State private var showingAddLanguage = false
    
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
                                .foregroundColor(.blue)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Language Priority")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Drag to reorder. The first language is your primary preference.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                    }
                    
                    // Language List
                    if languages.isEmpty {
                        LiquidGlassCard {
                            VStack(spacing: 12) {
                                Image(systemName: "globe")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text("No languages added")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Add your first language to get started")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(40)
                        }
                    } else {
                        ForEach(languages.indices, id: \.self) { index in
                            LanguageRow(
                                language: languages[index],
                                isFirst: index == 0,
                                onDelete: {
                                    withAnimation(.spring(response: 0.3)) {
                                        languages.remove(at: index)
                                        saveLanguages()
                                    }
                                }
                            )
                            .onDrag {
                                NSItemProvider(object: String(index) as NSString)
                            }
                            .onDrop(of: [.text], delegate: LanguageDropDelegate(
                                item: languages[index],
                                items: $languages,
                                currentIndex: index
                            ))
                        }
                    }
                    
                    // Add Language Button
                    Button(action: { showingAddLanguage = true }) {
                        LiquidGlassCard {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                                
                                Text("Add Language")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                Spacer()
                            }
                            .padding()
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Language Priority")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddLanguage) {
            AddLanguageView(languages: $languages)
        }
        .onAppear {
            loadLanguages()
        }
        .onDisappear {
            saveLanguages()
        }
    }
    
    private func loadLanguages() {
        let codes = settings?.preferredLanguages ?? ["en"]
        languages = codes.map { code in
            LanguageItem(code: code, name: languageName(for: code))
        }
    }
    
    private func saveLanguages() {
        settings?.preferredLanguages = languages.map { $0.code }
        settings?.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            print("Failed to save languages: \(error)")
        }
    }
    
    private func languageName(for code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
    }
}

// MARK: - Language Item
struct LanguageItem: Identifiable, Equatable {
    let id = UUID()
    var code: String
    var name: String
}

// MARK: - Language Row
struct LanguageRow: View {
    let language: LanguageItem
    let isFirst: Bool
    let onDelete: () -> Void
    
    var body: some View {
        LiquidGlassCard {
            HStack(spacing: 16) {
                // Drag Handle
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                // Language Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(language.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if isFirst {
                            Text("PRIMARY")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                        }
                    }
                    
                    Text(language.code.uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
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
            .padding()
        }
    }
}

// MARK: - Drop Delegate
struct LanguageDropDelegate: DropDelegate {
    let item: LanguageItem
    @Binding var items: [LanguageItem]
    let currentIndex: Int
    
    func performDrop(info: DropInfo) -> Bool {
        return true
    }
    
    func dropEntered(info: DropInfo) {
        if item.id != items[currentIndex].id {
            let from = items.firstIndex { $0.id == item.id } ?? 0
            let to = currentIndex
            
            withAnimation(.spring(response: 0.3)) {
                items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }
    }
}

// MARK: - Add Language View
struct AddLanguageView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var languages: [LanguageItem]
    @State private var searchText = ""
    @State private var selectedCode: String?
    
    private let commonLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("zh", "Chinese"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("ru", "Russian"),
        ("ar", "Arabic"),
        ("hi", "Hindi")
    ]
    
    var filteredLanguages: [(code: String, name: String)] {
        if searchText.isEmpty {
            return commonLanguages.filter { lang in
                !languages.contains { $0.code == lang.code }
            }
        } else {
            return commonLanguages.filter { lang in
                !languages.contains { $0.code == lang.code } &&
                (lang.name.localizedCaseInsensitiveContains(searchText) ||
                 lang.code.localizedCaseInsensitiveContains(searchText))
            }
        }
    }
    
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
                
                VStack(spacing: 0) {
                    // Search Bar
                    LiquidGlassCard {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Search languages", text: $searchText)
                                .textFieldStyle(.plain)
                        }
                        .padding()
                    }
                    .padding()
                    
                    // Language List
                    List {
                        ForEach(filteredLanguages, id: \.code) { lang in
                            Button(action: {
                                selectedCode = lang.code
                            }) {
                                HStack {
                                    Text(lang.name)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text(lang.code.uppercased())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedCode) { code in
                if let code = code {
                    let locale = Locale(identifier: code)
                    let name = locale.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
                    languages.append(LanguageItem(code: code, name: name))
                    dismiss()
                }
            }
        }
    }
}


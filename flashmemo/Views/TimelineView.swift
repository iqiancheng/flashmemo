import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Memo.timestamp, order: .reverse) private var memos: [Memo]
    @ObservedObject private var manager = FlashMemoManager.shared
    
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var isSelectionMode = false
    @State private var selectedMemos: Set<UUID> = []
    
    var filteredMemos: [Memo] {
        if searchText.isEmpty {
            return memos
        } else {
            return memos.filter { memo in
                memo.text.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    ForEach(filteredMemos) { memo in
                        if isSelectionMode {
                            MemoRowView(
                                memo: memo,
                                isSelected: selectedMemos.contains(memo.id),
                                isSelectionMode: true
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleSelection(for: memo)
                            }
                        } else {
                            NavigationLink(destination: DetailView(memo: memo)) {
                                MemoRowView(
                                    memo: memo,
                                    isSelected: false,
                                    isSelectionMode: false
                                )
                            }
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .navigationTitle("All Recordings")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
//                            Button(action: {
//                                withAnimation {
//                                    isSearchActive.toggle()
//                                    if !isSearchActive {
//                                        searchText = ""
//                                    }
//                                }
//                            }) {
//                                Image(systemName: "magnifyingglass")
//                                    .foregroundColor(.primary)
//                            }
                            
                            Button(action: {
                                withAnimation {
                                    isSelectionMode.toggle()
                                    if !isSelectionMode {
                                        selectedMemos.removeAll()
                                    }
                                }
                            }) {
                                Text(isSelectionMode ? "Cancel" : "Select")
                                    .foregroundColor(.primary)
                            }
                    }
                }
                .searchable(text: $searchText, isPresented: $isSearchActive)
                
                // Fixed recording button at bottom
                VStack {
                    Spacer()
                    Button(action: toggleRecording) {
                        ZStack {
                            Circle()
                                .fill(manager.isRecording ? Color.red : Color.blue)
                                .frame(width: 70, height: 70)
                                .shadow(color: (manager.isRecording ? Color.red : Color.blue).opacity(0.4), radius: 10, x: 0, y: 5)
                            
                            Image(systemName: manager.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 30)
                    .disabled(isSelectionMode)
                    .opacity(isSelectionMode ? 0.5 : 1.0)
                }
                
                // Selection mode toolbar
                if isSelectionMode {
                    VStack {
                        Spacer()
                        HStack {
                            if !selectedMemos.isEmpty {
                                Button(action: deleteSelectedItems) {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text("Delete (\(selectedMemos.count))")
                                    }
                                    .foregroundColor(.red)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
        }
    }
    
    private func toggleRecording() {
        if manager.isRecording {
            Task {
                await manager.stopRecording()
            }
        } else {
            manager.startRecording()
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(memos[index])
            }
        }
    }
    
    private func toggleSelection(for memo: Memo) {
        if selectedMemos.contains(memo.id) {
            selectedMemos.remove(memo.id)
        } else {
            selectedMemos.insert(memo.id)
        }
    }
    
    private func deleteSelectedItems() {
        withAnimation {
            for id in selectedMemos {
                if let memo = filteredMemos.first(where: { $0.id == id }) {
                    modelContext.delete(memo)
                }
            }
            selectedMemos.removeAll()
            isSelectionMode = false
        }
    }
}

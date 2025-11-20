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
    @State private var showingSettings = false
    
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
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            withAnimation {
                                isSearchActive.toggle()
                                if !isSearchActive {
                                    searchText = ""
                                }
                            }
                        }) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // 关键：在两个按钮之间添加 ToolbarSpacer
                    ToolbarSpacer(placement: .topBarTrailing)
                    
                    ToolbarItem(placement: .topBarTrailing) {
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
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }
                .searchable(text: $searchText, isPresented: $isSearchActive)
                
                // Fixed recording button at bottom
                VStack {
                    Spacer()
                    if !isSelectionMode {  // 添加条件判断
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
                        .transition(.opacity)  // 添加淡入淡出过渡效果
                    }
                }
                
                // Selection mode toolbar
                if isSelectionMode {
                    VStack {
                        Spacer()
                        HStack(spacing: 0) {
                            // 全选按钮
                            Button(action: selectAll) {
                                VStack(spacing: 4) {
                                    Image(systemName: selectedMemos.count == filteredMemos.count ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                    Text("Select All")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                            }
                            .disabled(filteredMemos.isEmpty)
                            
                            Divider()
                                .frame(height: 40)
                            
                            // 删除按钮
                            Button(action: deleteSelectedItems) {
                                VStack(spacing: 4) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 22))
                                    Text("Delete")
                                        .font(.caption)
                                }
                                .foregroundColor(selectedMemos.isEmpty ? .gray : .red)
                                .frame(maxWidth: .infinity)
                            }
                            .disabled(selectedMemos.isEmpty)
                        }
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .overlay(
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(Color(.separator)),
                            alignment: .top
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
    }
    
    private func selectAll() {
        withAnimation {
            if selectedMemos.count == filteredMemos.count {
                // 如果已经全选，则取消全选
                selectedMemos.removeAll()
            } else {
                // 全选
                selectedMemos = Set(filteredMemos.map { $0.id })
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

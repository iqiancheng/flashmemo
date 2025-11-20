import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Memo.timestamp, order: .reverse) private var memos: [Memo]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(memos) { memo in
                    NavigationLink(destination: DetailView(memo: memo)) {
                        MemoRowView(memo: memo)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Flash Memos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addMockMemo) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    private func addMockMemo() {
        let newMemo = Memo(
            audioFilename: "mock.m4a",
            text: "This is a manually added mock memo for testing purposes.",
            timestamp: Date()
        )
        modelContext.insert(newMemo)
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(memos[index])
            }
        }
    }
}

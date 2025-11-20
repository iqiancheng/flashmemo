import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Memo.timestamp, order: .reverse) private var memos: [Memo]
    @ObservedObject private var manager = FlashMemoManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    ForEach(memos) { memo in
                        NavigationLink(destination: DetailView(memo: memo)) {
                            MemoRowView(memo: memo)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .navigationTitle("Flash Memos")
                
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
}

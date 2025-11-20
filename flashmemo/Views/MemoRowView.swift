import SwiftUI

struct MemoRowView: View {
    let memo: Memo
    let isSelected: Bool
    let isSelectionMode: Bool
    
    init(memo: Memo, isSelected: Bool = false, isSelectionMode: Bool = false) {
        self.memo = memo
        self.isSelected = isSelected
        self.isSelectionMode = isSelectionMode
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // ⭐ 固定选择区，不管是否选择模式都存在
            ZStack {
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .blue : .secondary)
                }
            }
            .frame(width: 28, height: 28)   // ⭐ 固定宽度避免 Row 跳动
            .opacity(isSelectionMode ? 1 : 0) // ⭐ 非选择模式保持透明占位
            
            VStack(alignment: .leading, spacing: 4) {
                Text(memo.text.isEmpty ? "No transcription available" : memo.text)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                HStack {
                    Text(memo.timestamp, style: .time)
                    if memo.latitude != nil {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

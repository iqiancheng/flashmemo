import SwiftUI

struct MemoRowView: View {
    let memo: Memo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(memo.text)
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
        .padding(.vertical, 4)
    }
}

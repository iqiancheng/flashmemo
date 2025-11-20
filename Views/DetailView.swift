import SwiftUI
import MapKit

struct DetailView: View {
    let memo: Memo
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(memo.timestamp, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(memo.text)
                    .font(.body)
                
                if let lat = memo.latitude, let lon = memo.longitude {
                    Map(coordinateRegion: .constant(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )))
                    .frame(height: 200)
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Memo Detail")
    }
}

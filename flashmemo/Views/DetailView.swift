import SwiftUI
import MapKit
import SwiftData

struct DetailView: View {
    @Bindable var memo: Memo
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var editedText: String = ""
    @State private var isEditing = false
    @State private var address: String?
    @State private var isLoadingAddress = false
    
    private let locationService = LocationService()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Timestamp
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text(memo.timestamp, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(memo.timestamp, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 4)
                
                Divider()
                
                // Audio Player Section
                if let audioURL = getAudioURL(), FileManager.default.fileExists(atPath: audioURL.path) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundColor(.blue)
                            Text("Recording")
                                .font(.headline)
                        }
                        
                        // Playback Controls
                        HStack(spacing: 16) {
                            Button(action: {
                                if audioPlayer.isPlaying {
                                    audioPlayer.pause()
                                } else {
                                    if audioPlayer.duration == 0 {
                                        if !audioPlayer.loadAudio(from: audioURL) {
                                            return
                                        }
                                    }
                                    audioPlayer.play()
                                }
                            }) {
                                Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if audioPlayer.duration > 0 {
                                    Slider(
                                        value: Binding(
                                            get: { audioPlayer.currentTime },
                                            set: { audioPlayer.seek(to: $0) }
                                        ),
                                        in: 0...audioPlayer.duration
                                    )
                                    
                                    HStack {
                                        Text(formatTime(audioPlayer.currentTime))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(formatTime(audioPlayer.duration))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text("Tap play to load audio")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Divider()
                
                // Text Content Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "text.alignleft")
                            .foregroundColor(.blue)
                        Text("Transcription")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            if isEditing {
                                saveText()
                            } else {
                                editedText = memo.text
                                isEditing = true
                            }
                        }) {
                            Text(isEditing ? "Save" : "Edit")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if isEditing {
                        TextEditor(text: $editedText)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    } else {
                        Text(memo.text.isEmpty ? "No transcription available" : memo.text)
                            .font(.body)
                            .foregroundColor(memo.text.isEmpty ? .secondary : .primary)
                            .padding(.vertical, 8)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Location Section
                if let lat = memo.latitude, let lon = memo.longitude {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text("Location")
                                .font(.headline)
                        }
                        
                        // Address and Coordinates in one line
                        if isLoadingAddress {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading address...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: address != nil ? "mappin.circle" : "location.circle")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                                
                                HStack(spacing: 12) {
                                    if let address = address {
                                        Text(address)
                                            .font(.subheadline)
                                            .lineLimit(2)
                                    }
                                    
                                    // Text("\(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))")
                                    //     .font(.caption)
                                    //     .foregroundColor(.secondary)
                                    //     .padding(.leading, address != nil ? 8 : 0)
                                }
                            }
                        }
                        
                        // Map
                        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))) {
                            Marker("Memo", coordinate: coordinate)
                        }
                        .frame(height: 200)
                        .cornerRadius(12)
                        .padding(.horizontal, -16) // Remove horizontal padding to extend to edges
                        .padding(.bottom, -16) // Remove bottom padding
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("Memo Detail")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            editedText = memo.text
            if let lat = memo.latitude, let lon = memo.longitude {
                loadAddress(latitude: lat, longitude: lon)
            }
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }
    
    private func getAudioURL() -> URL? {
        var docDir: URL?
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroupIdentifier) {
            docDir = groupURL
        } else {
            docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        }
        
        guard let storageDir = docDir else { return nil }
        return storageDir.appendingPathComponent(memo.audioFilename)
    }
    
    private func saveText() {
        memo.text = editedText
        isEditing = false
        try? modelContext.save()
    }
    
    private func loadAddress(latitude: Double, longitude: Double) {
        isLoadingAddress = true
        Task {
            let result = await locationService.reverseGeocode(latitude: latitude, longitude: longitude)
            await MainActor.run {
                address = result
                isLoadingAddress = false
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

import Foundation
import SwiftData
import CoreLocation

@Model
class Memo {
    @Attribute(.unique) var id: UUID
    var audioFilename: String
    var text: String
    var timestamp: Date
    var latitude: Double?
    var longitude: Double?
    
    init(id: UUID = UUID(), audioFilename: String, text: String, timestamp: Date = Date(), location: CLLocation? = nil) {
        self.id = id
        self.audioFilename = audioFilename
        self.text = text
        self.timestamp = timestamp
        self.latitude = location?.coordinate.latitude
        self.longitude = location?.coordinate.longitude
    }
}

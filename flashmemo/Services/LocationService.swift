import CoreLocation
import Foundation
internal import Combine

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    @Published var currentLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
    
    func reverseGeocode(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            
            // Get street address (street name)
            var addressComponents: [String] = []
            if let street = placemark.thoroughfare {
                addressComponents.append(street)
            }
            if let subThoroughfare = placemark.subThoroughfare {
                addressComponents.insert(subThoroughfare, at: 0)
            }
            
            return addressComponents.isEmpty ? nil : addressComponents.joined(separator: " ")
        } catch {
            print("Reverse geocoding error: \(error)")
            return nil
        }
    }
}

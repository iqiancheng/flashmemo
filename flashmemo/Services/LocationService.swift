import CoreLocation
import Foundation
internal import Combine

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    @Published var currentLocation: CLLocation?
    
    // Best location cache to handle GPS drift in mainland China
    private var bestLocation: CLLocation?
    private let maxAcceptableAccuracy: CLLocationAccuracy = 100.0 // meters
    private let minAccuracyImprovement: CLLocationAccuracy = 10.0 // meters
    
    override init() {
        super.init()
        locationManager.delegate = self
        // Use best accuracy but with distance filter to reduce unnecessary updates
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Only update when moved at least 10 meters (reduces GPS drift)
        locationManager.distanceFilter = 10.0
        // Allow location updates to continue in background for better accuracy
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        // Filter out invalid locations
        guard newLocation.horizontalAccuracy >= 0 else {
            print("Location update rejected: invalid accuracy")
            return
        }
        
        // Reject locations with poor accuracy (common in mainland China due to GPS interference)
        if newLocation.horizontalAccuracy > maxAcceptableAccuracy {
            print("Location update rejected: accuracy too poor (\(newLocation.horizontalAccuracy)m)")
            return
        }
        
        // Convert WGS84 to GCJ-02 (Mars coordinate) for locations in China
        let convertedLocation = CoordinateConverter.convertToGCJ02(newLocation)
        
        // If we have a cached best location, only update if new location is significantly better
        if let cached = bestLocation {
            // Only update if new location is more accurate or significantly closer
            let accuracyImprovement = cached.horizontalAccuracy - convertedLocation.horizontalAccuracy
            let distance = convertedLocation.distance(from: cached)
            
            // Update if accuracy improved significantly OR if moved significantly and accuracy is acceptable
            if accuracyImprovement > minAccuracyImprovement {
                // New location is significantly more accurate
                bestLocation = convertedLocation
                currentLocation = convertedLocation
                print("Location updated: accuracy improved by \(accuracyImprovement)m (GCJ-02 converted)")
            } else if distance > locationManager.distanceFilter && convertedLocation.horizontalAccuracy <= cached.horizontalAccuracy {
                // Moved significantly and accuracy is at least as good
                bestLocation = convertedLocation
                currentLocation = convertedLocation
                print("Location updated: moved \(distance)m with acceptable accuracy (GCJ-02 converted)")
            } else {
                // Keep cached location if it's still better
                print("Location update ignored: cached location is better (accuracy: \(cached.horizontalAccuracy)m vs \(convertedLocation.horizontalAccuracy)m)")
            }
        } else {
            // First valid location, accept it (with GCJ-02 conversion)
            bestLocation = convertedLocation
            currentLocation = convertedLocation
            print("Location initialized: accuracy \(convertedLocation.horizontalAccuracy)m (GCJ-02 converted)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
        
        // Handle specific error cases
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                print("Location access denied by user")
            case .locationUnknown:
                print("Location unknown - continuing to try")
            case .network:
                print("Location network error - check network connection")
            default:
                print("Location error: \(clError.localizedDescription)")
            }
        }
    }
    
    // Request location update when needed (e.g., when starting recording)
    func requestLocation() {
        locationManager.requestLocation()
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

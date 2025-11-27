import Foundation
import CoreLocation

/// Coordinate converter for Chinese coordinate systems
/// Converts between WGS84 (GPS) and GCJ-02 (Mars coordinate system used in China)
/// Based on the algorithm from eviltransform: https://github.com/googollee/eviltransform
class CoordinateConverter {
    
    // Constants for coordinate conversion
    private static let a = 6378245.0 // Semi-major axis
    private static let ee = 0.00669342162296594323 // First eccentricity squared
    private static let pi = 3.1415926535897932384626
    
    /// Check if coordinates are in China (rough boundary check)
    /// This is a simplified check - for production, use a more accurate boundary
    static func isInChina(latitude: Double, longitude: Double) -> Bool {
        // Rough boundaries of China mainland
        // Latitude: 18°N to 54°N, Longitude: 73°E to 135°E
        return latitude >= 18.0 && latitude <= 54.0 && 
               longitude >= 73.0 && longitude <= 135.0
    }
    
    /// Convert WGS84 coordinates to GCJ-02 (Mars coordinate system)
    /// - Parameters:
    ///   - latitude: WGS84 latitude
    ///   - longitude: WGS84 longitude
    /// - Returns: GCJ-02 coordinate (latitude, longitude)
    static func wgs84ToGCJ02(latitude: Double, longitude: Double) -> (latitude: Double, longitude: Double) {
        // If not in China, return original coordinates
        if !isInChina(latitude: latitude, longitude: longitude) {
            return (latitude: latitude, longitude: longitude)
        }
        
        var dLat = transformLat(longitude - 105.0, latitude - 35.0)
        var dLon = transformLon(longitude - 105.0, latitude - 35.0)
        let radLat = latitude / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi)
        
        let mgLat = latitude + dLat
        let mgLon = longitude + dLon
        
        return (latitude: mgLat, longitude: mgLon)
    }
    
    /// Convert GCJ-02 coordinates to WGS84
    /// - Parameters:
    ///   - latitude: GCJ-02 latitude
    ///   - longitude: GCJ-02 longitude
    /// - Returns: WGS84 coordinate (latitude, longitude)
    static func gcj02ToWGS84(latitude: Double, longitude: Double) -> (latitude: Double, longitude: Double) {
        // If not in China, return original coordinates
        if !isInChina(latitude: latitude, longitude: longitude) {
            return (latitude: latitude, longitude: longitude)
        }
        
        // Use iterative method to convert GCJ-02 to WGS84
        var dLat = transformLat(longitude - 105.0, latitude - 35.0)
        var dLon = transformLon(longitude - 105.0, latitude - 35.0)
        let radLat = latitude / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi)
        
        let mgLat = latitude + dLat
        let mgLon = longitude + dLon
        
        // Iterative refinement (usually 1-2 iterations are enough)
        var wgsLat = latitude - (mgLat - latitude)
        var wgsLon = longitude - (mgLon - longitude)
        
        // One more iteration for better accuracy
        dLat = transformLat(wgsLon - 105.0, wgsLat - 35.0)
        dLon = transformLon(wgsLon - 105.0, wgsLat - 35.0)
        let radLat2 = wgsLat / 180.0 * pi
        var magic2 = sin(radLat2)
        magic2 = 1 - ee * magic2 * magic2
        let sqrtMagic2 = sqrt(magic2)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic2 * sqrtMagic2) * pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic2 * cos(radLat2) * pi)
        
        let mgLat2 = wgsLat + dLat
        let mgLon2 = wgsLon + dLon
        
        wgsLat = latitude - (mgLat2 - wgsLat)
        wgsLon = longitude - (mgLon2 - wgsLon)
        
        return (latitude: wgsLat, longitude: wgsLon)
    }
    
    /// Convert CLLocationCoordinate2D from WGS84 to GCJ-02
    static func convertToGCJ02(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let converted = wgs84ToGCJ02(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return CLLocationCoordinate2D(latitude: converted.latitude, longitude: converted.longitude)
    }
    
    /// Convert CLLocation from WGS84 to GCJ-02
    /// Returns a new CLLocation with converted coordinates
    static func convertToGCJ02(_ location: CLLocation) -> CLLocation {
        let converted = wgs84ToGCJ02(latitude: location.coordinate.latitude, 
                                     longitude: location.coordinate.longitude)
        // Create new CLLocation with converted coordinates
        // Use the basic initializer - the coordinate conversion is the most important part
        return CLLocation(
            latitude: converted.latitude,
            longitude: converted.longitude
        )
    }
    
    // MARK: - Private Helper Methods
    
    private static func transformLat(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0
        return ret
    }
    
    private static func transformLon(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0
        return ret
    }
}


import Foundation
import CoreLocation

struct SavedParcel: Codable, Identifiable {
    var id: UUID = UUID()
    var cadastralRef: String
    var coordinates: [CoordinatePoint]
    var area: Double
    var perimeter: Double
    var savedDate: Date = Date()
    var customName: String
    var isManualDrawing: Bool

    var formattedArea: String {
        let ha = Int(area / 10000)
        let remaining = area.truncatingRemainder(dividingBy: 10000)
        let a = Int(remaining / 100)
        let ca = Int(remaining.truncatingRemainder(dividingBy: 100))
        return "\(ha) Ha \(a) A \(ca) Ca"
    }

    var formattedPerimeter: String {
        String(format: "%.1f m", perimeter)
    }

    var clCoordinates: [CLLocationCoordinate2D] {
        coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }
}

struct CoordinatePoint: Codable {
    var latitude: Double
    var longitude: Double
}

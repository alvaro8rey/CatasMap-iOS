import CoreLocation
import Foundation

struct SphericalUtils {

    private static let earthRadius = 6371009.0  // meters (mean radius)

    // Spherical excess formula — same algorithm as Google's SphericalUtil.computeArea
    static func computeArea(path: [CLLocationCoordinate2D]) -> Double {
        guard path.count >= 3 else { return 0 }
        var total = 0.0
        let n = path.count
        for i in 0..<n {
            let p1 = path[i]
            let p2 = path[(i + 1) % n]
            let lon1 = p1.longitude * .pi / 180
            let lat1 = p1.latitude  * .pi / 180
            let lon2 = p2.longitude * .pi / 180
            let lat2 = p2.latitude  * .pi / 180
            total += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }
        return abs(total * earthRadius * earthRadius / 2.0)
    }

    // Sum of Haversine segments, closing the polygon
    static func computePerimeter(path: [CLLocationCoordinate2D]) -> Double {
        guard path.count >= 2 else { return 0 }
        var total = 0.0
        let n = path.count
        for i in 0..<n {
            total += haversineDistance(path[i], path[(i + 1) % n])
        }
        return total
    }

    static func haversineDistance(_ p1: CLLocationCoordinate2D, _ p2: CLLocationCoordinate2D) -> Double {
        let lat1 = p1.latitude  * .pi / 180
        let lat2 = p2.latitude  * .pi / 180
        let dLat = (p2.latitude  - p1.latitude)  * .pi / 180
        let dLon = (p2.longitude - p1.longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    // Format m² as "X Ha Y A Z Ca (N m²)"
    static func formatArea(_ m2: Double) -> String {
        let ha   = Int(m2 / 10000)
        let rem1 = m2.truncatingRemainder(dividingBy: 10000)
        let a    = Int(rem1 / 100)
        let ca   = Int(rem1.truncatingRemainder(dividingBy: 100))
        let m2Str = m2Formatted(m2)
        return "\(ha) Ha \(a) A \(ca) Ca (\(m2Str) m²)"
    }

    // "1265" or "12.340" with thousands separator
    private static func m2Formatted(_ m2: Double) -> String {
        let n = Int(m2.rounded())
        if n >= 1000 {
            let thousands = n / 1000
            let rest      = n % 1000
            return String(format: "%d.%03d", thousands, rest)
        }
        return "\(n)"
    }
}

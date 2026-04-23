import CoreLocation
import Foundation

// Converts UTM (any zone, GRS80/ETRS89) to WGS84 lat/lon.
// ETRS89 and WGS84 are practically identical for Spain.
struct CoordinateConverter {

    // GRS80 / WGS84 ellipsoid
    private static let a  = 6378137.0
    private static let f  = 1.0 / 298.257222101
    private static let k0 = 0.9996
    private static let E0 = 500000.0   // false easting

    // Central meridian for a UTM zone number: (6*zone - 183)°
    // EPSG:25829 → zone 29 → -9°
    // EPSG:25830 → zone 30 → -3°
    // EPSG:25831 → zone 31 → +3°
    static func centralMeridian(epsg: Int) -> Double {
        let zone = epsg - 25800          // 29, 30 or 31
        return Double(6 * zone - 183) * .pi / 180.0
    }

    static func utmToLatLon(easting: Double, northing: Double, epsg: Int) -> CLLocationCoordinate2D {
        let a  = Self.a
        let f  = Self.f
        let b  = a * (1 - f)
        let e2 = (a * a - b * b) / (a * a)
        let e2p = e2 / (1 - e2)
        let k0 = Self.k0
        let E0 = Self.E0
        let lambda0 = centralMeridian(epsg: epsg)

        let e1 = (1 - sqrt(1 - e2)) / (1 + sqrt(1 - e2))

        let x = easting - E0
        let M = northing / k0

        let mu = M / (a * (1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * pow(e2, 3) / 256))

        let phi1 = mu
            + (3 * e1 / 2 - 27 * pow(e1, 3) / 32)      * sin(2 * mu)
            + (21 * e1 * e1 / 16 - 55 * pow(e1, 4) / 32) * sin(4 * mu)
            + (151 * pow(e1, 3) / 96)                    * sin(6 * mu)
            + (1097 * pow(e1, 4) / 512)                  * sin(8 * mu)

        let sinPhi1 = sin(phi1)
        let cosPhi1 = cos(phi1)
        let tanPhi1 = sinPhi1 / cosPhi1

        let N1 = a / sqrt(1 - e2 * sinPhi1 * sinPhi1)
        let T1 = tanPhi1 * tanPhi1
        let C1 = e2p * cosPhi1 * cosPhi1
        let R1 = a * (1 - e2) / pow(1 - e2 * sinPhi1 * sinPhi1, 1.5)
        let D  = x / (N1 * k0)

        let lat = phi1
            - (N1 * tanPhi1 / R1) * (D * D / 2
                - (5 + 3 * T1 + 10 * C1 - 4 * C1 * C1 - 9 * e2p) * pow(D, 4) / 24)
            + (61 + 90 * T1 + 298 * C1 + 45 * T1 * T1 - 252 * e2p - 3 * C1 * C1) * pow(D, 6) / 720

        let lon = lambda0
            + (D
            - (1 + 2 * T1 + C1) * pow(D, 3) / 6
            + (5 - 2 * C1 + 28 * T1 - 3 * C1 * C1 + 8 * e2p + 24 * T1 * T1) * pow(D, 5) / 120)
            / cosPhi1

        return CLLocationCoordinate2D(
            latitude:  lat * 180 / .pi,
            longitude: lon * 180 / .pi
        )
    }
}

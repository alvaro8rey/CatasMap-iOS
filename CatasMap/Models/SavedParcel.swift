import Foundation
import CoreLocation

struct SavedParcel: Codable, Identifiable {
    var id: UUID = UUID()
    var customName: String
    var savedDate: Date = Date()

    // ── Capa 1: Polígono oficial del catastro (inmutable) ──────────────────
    var cadastralRef: String
    var cadastralCoordinates: [CoordinatePoint]
    var cadastralArea: Double
    var cadastralPerimeter: Double

    // ── Capa 2: Medición propia del usuario (editable) ─────────────────────
    var userCoordinates: [CoordinatePoint]?
    var userArea: Double?
    var userPerimeter: Double?

    var hasUserDrawing: Bool { !(userCoordinates?.isEmpty ?? true) }

    // Formatted
    var formattedCadastralArea: String      { SphericalUtils.formatArea(cadastralArea) }
    var formattedUserArea: String?          { userArea.map { SphericalUtils.formatArea($0) } }
    var formattedCadastralPerimeter: String { String(format: "%.1f m", cadastralPerimeter) }
    var formattedUserPerimeter: String?     { userPerimeter.map { String(format: "%.1f m", $0) } }

    var clCadastralCoordinates: [CLLocationCoordinate2D] {
        cadastralCoordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }
    var clUserCoordinates: [CLLocationCoordinate2D]? {
        userCoordinates?.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }
}

struct CoordinatePoint: Codable {
    var latitude: Double
    var longitude: Double
}

import Foundation
import MapKit
import Observation

@Observable
class MapViewModel {
    var parcel: CadastralFeature?
    var mapType: MapStyle = .standard
    var isDrawingMode = false
    var drawnPoints: [CLLocationCoordinate2D] = []
    var isDrawingClosed = false

    // Programmatic camera fly-to trigger
    var flyToRegion: MKCoordinateRegion? = nil

    var area: Double = 0
    var perimeter: Double = 0

    var formattedArea: String { SphericalUtils.formatArea(area) }
    var formattedPerimeter: String { String(format: "%.1f m", perimeter) }

    var hasContent: Bool { parcel != nil || !drawnPoints.isEmpty }

    // MARK: Parcel

    func setParcel(_ feature: CadastralFeature) {
        parcel = feature
        clearDrawing()
        recalculateParcelMetrics()
        zoomToParcel()
    }

    private func recalculateParcelMetrics() {
        guard let ring = parcel?.coordinates.first else { return }
        area = SphericalUtils.computeArea(path: ring)
        perimeter = SphericalUtils.computePerimeter(path: ring)
    }

    private func zoomToParcel() {
        guard let ring = parcel?.coordinates.first, !ring.isEmpty else { return }
        let lats = ring.map { $0.latitude }
        let lons = ring.map { $0.longitude }
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 2.5, 0.003),
            longitudeDelta: max((maxLon - minLon) * 2.5, 0.003)
        )
        flyToRegion = MKCoordinateRegion(center: center, span: span)
    }

    // MARK: Drawing

    func addDrawingPoint(_ coord: CLLocationCoordinate2D) {
        guard !isDrawingClosed else { return }
        // Auto-close when tapping near the first point (within ~25 m)
        if drawnPoints.count >= 3,
           let first = drawnPoints.first,
           SphericalUtils.haversineDistance(coord, first) < 25 {
            closePolygon()
            return
        }
        drawnPoints.append(coord)
        updateDrawingMetrics()
    }

    func closePolygon() {
        guard drawnPoints.count >= 3 else { return }
        isDrawingClosed = true
        updateDrawingMetrics()
    }

    func undoLastPoint() {
        guard !isDrawingClosed, !drawnPoints.isEmpty else { return }
        drawnPoints.removeLast()
        updateDrawingMetrics()
    }

    func clearDrawing() {
        drawnPoints = []
        isDrawingClosed = false
        isDrawingMode = false
        recalculateParcelMetrics()
    }

    private func updateDrawingMetrics() {
        guard drawnPoints.count >= 3 else {
            area = 0; perimeter = 0; return
        }
        area = SphericalUtils.computeArea(path: drawnPoints)
        perimeter = SphericalUtils.computePerimeter(path: drawnPoints)
    }

    // MARK: Save

    func makeParcelForSaving(name: String, isManual: Bool) -> SavedParcel? {
        let coords: [CLLocationCoordinate2D]
        if isManual {
            guard drawnPoints.count >= 3 else { return nil }
            coords = drawnPoints
        } else {
            guard let ring = parcel?.coordinates.first, !ring.isEmpty else { return nil }
            coords = ring
        }
        return SavedParcel(
            cadastralRef: parcel?.cadastralRef ?? "Dibujo manual",
            coordinates: coords.map { CoordinatePoint(latitude: $0.latitude, longitude: $0.longitude) },
            area: area,
            perimeter: perimeter,
            customName: name,
            isManualDrawing: isManual
        )
    }

    func loadSaved(_ saved: SavedParcel) {
        let coords = saved.clCoordinates
        drawnPoints = coords
        isDrawingClosed = true
        isDrawingMode = false
        area = saved.area
        perimeter = saved.perimeter
        // Zoom to saved parcel
        if !coords.isEmpty {
            let lats = coords.map { $0.latitude }
            let lons = coords.map { $0.longitude }
            flyToRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: (lats.min()! + lats.max()!) / 2,
                    longitude: (lons.min()! + lons.max()!) / 2
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: max((lats.max()! - lats.min()!) * 2.5, 0.003),
                    longitudeDelta: max((lons.max()! - lons.min()!) * 2.5, 0.003)
                )
            )
        }
    }
}

enum MapStyle {
    case standard, satellite
}

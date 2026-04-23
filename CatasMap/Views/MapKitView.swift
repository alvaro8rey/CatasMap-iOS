import SwiftUI
import MapKit
import UIKit

// UIViewRepresentable wrapper for MKMapView.
// Handles parcel polygon, free-drawing overlay, and tap-to-add-point in drawing mode.
struct MapKitView: UIViewRepresentable {
    var mapType: MKMapType
    var flyToRegion: MKCoordinateRegion?
    var parcelCoordinates: [[CLLocationCoordinate2D]]
    var drawnPoints: [CLLocationCoordinate2D]
    var isDrawingMode: Bool
    var isDrawingClosed: Bool
    var onTap: (CLLocationCoordinate2D) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.isRotateEnabled = false

        // Default region: centre of Galicia
        map.setRegion(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 42.78, longitude: -7.86),
            span: MKCoordinateSpan(latitudeDelta: 4.5, longitudeDelta: 4.5)
        ), animated: false)

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.mapType = mapType

        // Fly to region when requested
        if let region = flyToRegion, context.coordinator.lastFlyTo !== flyToRegion as AnyObject? {
            context.coordinator.lastFlyToID = region.center.latitude + region.center.longitude
            if abs(map.region.center.latitude - region.center.latitude) > 0.0001
                || abs(map.region.center.longitude - region.center.longitude) > 0.0001 {
                map.setRegion(region, animated: true)
            }
        }

        // Rebuild overlays only when data changes
        let newOverlayKey = overlayKey()
        guard context.coordinator.lastOverlayKey != newOverlayKey else { return }
        context.coordinator.lastOverlayKey = newOverlayKey

        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })

        // Parcel polygon (blue)
        if let ring = parcelCoordinates.first, !ring.isEmpty {
            var coords = ring
            let poly = MKPolygon(coordinates: &coords, count: coords.count)
            poly.title = "parcel"
            map.addOverlay(poly, level: .aboveRoads)
        }

        // Drawing overlay
        if !drawnPoints.isEmpty {
            if isDrawingClosed && drawnPoints.count >= 3 {
                var pts = drawnPoints
                let poly = MKPolygon(coordinates: &pts, count: pts.count)
                poly.title = "drawing"
                map.addOverlay(poly, level: .aboveRoads)
            } else if drawnPoints.count >= 2 {
                var pts = drawnPoints
                let line = MKPolyline(coordinates: &pts, count: pts.count)
                map.addOverlay(line, level: .aboveRoads)
            }

            // Point annotations
            for (i, pt) in drawnPoints.enumerated() {
                let ann = MKPointAnnotation()
                ann.coordinate = pt
                ann.title = i == 0 ? "Inicio" : "\(i + 1)"
                map.addAnnotation(ann)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // Generates a stable string key representing current overlay data
    private func overlayKey() -> String {
        let parcelKey = parcelCoordinates.first?.first.map { "\($0.latitude),\($0.longitude)" } ?? ""
        let drawKey = drawnPoints.map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")
        return "\(parcelKey)|\(drawKey)|\(isDrawingClosed)"
    }

    // MARK: Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapKitView
        var lastOverlayKey = ""
        var lastFlyToID: Double = 0

        // Workaround: use the region center sum as a change token
        var lastFlyTo: AnyObject? = nil

        init(_ parent: MapKitView) { self.parent = parent }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard parent.isDrawingMode,
                  let map = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: map)
            let coord = map.convert(point, toCoordinateFrom: map)
            parent.onTap(coord)
        }

        func mapView(_ map: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let r = MKPolygonRenderer(polygon: polygon)
                if polygon.title == "parcel" {
                    r.fillColor  = UIColor.systemBlue.withAlphaComponent(0.15)
                    r.strokeColor = UIColor.systemBlue
                    r.lineWidth  = 2.5
                } else {
                    r.fillColor  = UIColor.systemRed.withAlphaComponent(0.15)
                    r.strokeColor = UIColor.systemRed
                    r.lineWidth  = 2.5
                }
                return r
            }
            if let polyline = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: polyline)
                r.strokeColor = UIColor.systemRed
                r.lineWidth   = 2.5
                r.lineDashPattern = [6, 4]
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ map: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "drawn")
            view.markerTintColor = annotation.title == "Inicio" ? .systemGreen : .systemRed
            view.glyphText = annotation.title == "Inicio" ? "★" : nil
            view.displayPriority = .required
            return view
        }
    }
}

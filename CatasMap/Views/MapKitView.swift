import SwiftUI
import MapKit
import UIKit

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

        map.setRegion(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 42.78, longitude: -7.86),
            span: MKCoordinateSpan(latitudeDelta: 4.5, longitudeDelta: 4.5)
        ), animated: false)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        // No bloquear los gestos propios del mapa (pan, zoom, etc.)
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // CRÍTICO: actualizar siempre el parent para que handleTap
        // lea el isDrawingMode correcto en cada render de SwiftUI.
        context.coordinator.parent = self

        map.mapType = mapType

        // Volar a la región solicitada si cambió
        if let region = flyToRegion {
            let token = region.center.latitude + region.center.longitude
            if abs(context.coordinator.lastFlyToken - token) > 0.00001 {
                context.coordinator.lastFlyToken = token
                map.setRegion(region, animated: true)
            }
        }

        // Reconstruir overlays solo si los datos cambiaron
        let newKey = overlayKey()
        guard context.coordinator.lastOverlayKey != newKey else { return }
        context.coordinator.lastOverlayKey = newKey

        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })

        // Polígono catastral (azul)
        if let ring = parcelCoordinates.first, !ring.isEmpty {
            var coords = ring
            let poly = MKPolygon(coordinates: &coords, count: coords.count)
            poly.title = "parcel"
            map.addOverlay(poly, level: .aboveRoads)
        }

        // Dibujo del usuario (rojo)
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

            for (i, pt) in drawnPoints.enumerated() {
                let ann = MKPointAnnotation()
                ann.coordinate = pt
                ann.title = i == 0 ? "Inicio" : "\(i + 1)"
                map.addAnnotation(ann)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    private func overlayKey() -> String {
        let p = parcelCoordinates.first?.first.map { "\($0.latitude),\($0.longitude)" } ?? ""
        let d = drawnPoints.map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")
        return "\(p)|\(d)|\(isDrawingClosed)"
    }

    // MARK: Coordinator

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: MapKitView
        var lastOverlayKey = ""
        var lastFlyToken: Double = 0

        init(_ parent: MapKitView) { self.parent = parent }

        // Permitir que nuestro tap coexista con los gestos internos del MKMapView
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard parent.isDrawingMode,
                  gesture.state == .ended,
                  let map = gesture.view as? MKMapView else { return }
            let pt = gesture.location(in: map)
            let coord = map.convert(pt, toCoordinateFrom: map)
            parent.onTap(coord)
        }

        // MARK: MKMapViewDelegate

        func mapView(_ map: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let r = MKPolygonRenderer(polygon: polygon)
                if polygon.title == "parcel" {
                    r.fillColor   = UIColor.systemBlue.withAlphaComponent(0.15)
                    r.strokeColor = .systemBlue
                    r.lineWidth   = 2.5
                } else {
                    r.fillColor   = UIColor.systemRed.withAlphaComponent(0.15)
                    r.strokeColor = .systemRed
                    r.lineWidth   = 2.5
                }
                return r
            }
            if let polyline = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: polyline)
                r.strokeColor = .systemRed
                r.lineWidth   = 2.5
                r.lineDashPattern = [6, 4]
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ map: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "drawn")
            view.markerTintColor    = annotation.title == "Inicio" ? .systemGreen : .systemRed
            view.glyphText          = annotation.title == "Inicio" ? "★" : nil
            view.displayPriority    = .required
            return view
        }
    }
}

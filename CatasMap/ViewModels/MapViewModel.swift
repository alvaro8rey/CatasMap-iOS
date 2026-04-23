import Foundation
import MapKit
import Observation

@Observable
class MapViewModel {

    // ── Capa 1: Polígono del catastro (azul, fijo) ────────────────────────
    var parcel: CadastralFeature?
    var cadastralArea: Double = 0
    var cadastralPerimeter: Double = 0

    // ── Capa 2: Medición propia del usuario (rojo, editable) ─────────────
    var drawnPoints: [CLLocationCoordinate2D] = []
    var isDrawingClosed = false
    var userArea: Double = 0
    var userPerimeter: Double = 0

    // ── Modo dibujo ───────────────────────────────────────────────────────
    var isDrawingMode = false
    /// Alerta para confirmar borrar el dibujo previo al entrar en modo edición
    var showClearDrawingConfirm = false

    // ── Estado del mapa ───────────────────────────────────────────────────
    var mapType: MapStyle = .standard
    var flyToRegion: MKCoordinateRegion? = nil

    // ── Edición de finca guardada ─────────────────────────────────────────
    /// UUID de la finca guardada que se está editando (nil = nueva finca)
    var currentSavedParcelID: UUID? = nil

    // MARK: Computed

    var hasParcel: Bool { parcel != nil }
    var hasDrawing: Bool { isDrawingClosed && drawnPoints.count >= 3 }

    var formattedCadastralArea: String      { SphericalUtils.formatArea(cadastralArea) }
    var formattedCadastralPerimeter: String { String(format: "%.1f m", cadastralPerimeter) }
    var formattedUserArea: String           { SphericalUtils.formatArea(userArea) }
    var formattedUserPerimeter: String      { String(format: "%.1f m", userPerimeter) }

    // MARK: Cargar parcela desde API

    func setParcel(_ feature: CadastralFeature) {
        parcel = feature
        currentSavedParcelID = nil
        // Limpiar dibujo previo al buscar una nueva parcela
        drawnPoints = []
        isDrawingClosed = false
        isDrawingMode = false
        userArea = 0
        userPerimeter = 0

        if let ring = feature.coordinates.first {
            cadastralArea = SphericalUtils.computeArea(path: ring)
            cadastralPerimeter = SphericalUtils.computePerimeter(path: ring)
        }
        zoomToParcel(coords: feature.coordinates.first)
    }

    // MARK: Cargar finca guardada (desde Mis Fincas)

    func loadSaved(_ saved: SavedParcel) {
        currentSavedParcelID = saved.id

        // Reconstruir capa catastral
        let catCoords = saved.clCadastralCoordinates
        parcel = CadastralFeature(
            cadastralRef: saved.cadastralRef,
            coordinates: [catCoords],
            centerCoordinate: nil
        )
        cadastralArea = saved.cadastralArea
        cadastralPerimeter = saved.cadastralPerimeter

        // Cargar dibujo del usuario si existe
        if let userCoords = saved.clUserCoordinates, !userCoords.isEmpty {
            drawnPoints = userCoords
            isDrawingClosed = true
            userArea = saved.userArea ?? SphericalUtils.computeArea(path: userCoords)
            userPerimeter = saved.userPerimeter ?? SphericalUtils.computePerimeter(path: userCoords)
        } else {
            drawnPoints = []
            isDrawingClosed = false
            userArea = 0
            userPerimeter = 0
        }

        isDrawingMode = false
        zoomToParcel(coords: catCoords)
    }

    // MARK: Modo dibujo

    /// Llama a este método desde el botón del lápiz.
    /// Si ya hay un dibujo cerrado, pide confirmación antes de limpiar.
    func requestDrawingMode() {
        if hasDrawing {
            showClearDrawingConfirm = true
        } else {
            isDrawingMode = true
        }
    }

    func confirmClearAndDraw() {
        clearDrawing()
        isDrawingMode = true
    }

    func exitDrawingMode() {
        isDrawingMode = false
    }

    func addDrawingPoint(_ coord: CLLocationCoordinate2D) {
        guard !isDrawingClosed else { return }
        // Auto-cierre al tocar cerca del punto inicial (<25 m)
        if drawnPoints.count >= 3,
           let first = drawnPoints.first,
           SphericalUtils.haversineDistance(coord, first) < 25 {
            closePolygon()
            return
        }
        drawnPoints.append(coord)
        updateUserMetrics()
    }

    func closePolygon() {
        guard drawnPoints.count >= 3 else { return }
        isDrawingClosed = true
        isDrawingMode = false
        updateUserMetrics()
    }

    func undoLastPoint() {
        guard !isDrawingClosed, !drawnPoints.isEmpty else { return }
        drawnPoints.removeLast()
        updateUserMetrics()
    }

    func clearDrawing() {
        drawnPoints = []
        isDrawingClosed = false
        isDrawingMode = false
        userArea = 0
        userPerimeter = 0
    }

    private func updateUserMetrics() {
        guard drawnPoints.count >= 3 else { userArea = 0; userPerimeter = 0; return }
        userArea = SphericalUtils.computeArea(path: drawnPoints)
        userPerimeter = SphericalUtils.computePerimeter(path: drawnPoints)
    }

    // MARK: Guardar

    // asNew = false → sobreescribe el registro existente (mismo UUID)
    // asNew = true  → crea una copia nueva (UUID nuevo)
    func makeParcelForSaving(name: String, asNew: Bool = false) -> SavedParcel {
        let catCoords = (parcel?.coordinates.first ?? [])
            .map { CoordinatePoint(latitude: $0.latitude, longitude: $0.longitude) }

        let userCoords: [CoordinatePoint]? = hasDrawing
            ? drawnPoints.map { CoordinatePoint(latitude: $0.latitude, longitude: $0.longitude) }
            : nil

        let id = asNew ? UUID() : (currentSavedParcelID ?? UUID())

        return SavedParcel(
            id:                   id,
            customName:           name,
            cadastralRef:         parcel?.cadastralRef ?? "",
            cadastralCoordinates: catCoords,
            cadastralArea:        cadastralArea,
            cadastralPerimeter:   cadastralPerimeter,
            userCoordinates:      userCoords,
            userArea:             hasDrawing ? userArea : nil,
            userPerimeter:        hasDrawing ? userPerimeter : nil
        )
    }

    // MARK: Privado

    private func zoomToParcel(coords: [CLLocationCoordinate2D]?) {
        guard let coords, !coords.isEmpty else { return }
        let lats = coords.map { $0.latitude }
        let lons = coords.map { $0.longitude }
        flyToRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude:  (lats.min()! + lats.max()!) / 2,
                longitude: (lons.min()! + lons.max()!) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta:  max((lats.max()! - lats.min()!) * 2.5, 0.003),
                longitudeDelta: max((lons.max()! - lons.min()!) * 2.5, 0.003)
            )
        )
    }
}

enum MapStyle { case standard, satellite }

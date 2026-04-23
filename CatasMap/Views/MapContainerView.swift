import SwiftUI
import MapKit

struct MapContainerView: View {
    @Environment(MapViewModel.self) private var vm
    @Environment(PersistenceController.self) private var persistence

    @State private var showSaveSheet = false
    @State private var saveName = ""
    @State private var saveAsManual = false
    @State private var showSaveAlert = false

    var body: some View {
        ZStack {
            // Full-screen map
            mapLayer

            // Overlay controls
            VStack(spacing: 0) {
                topBar
                Spacer()
                if vm.hasContent {
                    metricsBar
                }
                if vm.isDrawingMode {
                    drawingToolbar
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showSaveSheet) { saveSheet }
    }

    // MARK: Map

    private var mapLayer: some View {
        @Bindable var bvm = vm
        return MapKitView(
            mapType: vm.mapType == .standard ? .standard : .satellite,
            flyToRegion: vm.flyToRegion,
            parcelCoordinates: vm.parcel?.coordinates ?? [],
            drawnPoints: vm.drawnPoints,
            isDrawingMode: vm.isDrawingMode,
            isDrawingClosed: vm.isDrawingClosed,
            onTap: { coord in vm.addDrawingPoint(coord) }
        )
        .ignoresSafeArea()
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Spacer()

            // Map type toggle
            Button {
                vm.mapType = vm.mapType == .standard ? .satellite : .standard
            } label: {
                Image(systemName: vm.mapType == .standard ? "globe" : "map")
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }

            // Drawing mode toggle
            Button {
                if vm.isDrawingMode {
                    vm.isDrawingMode = false
                } else {
                    vm.isDrawingMode = true
                    vm.isDrawingClosed = false
                }
            } label: {
                Image(systemName: vm.isDrawingMode ? "pencil.slash" : "pencil")
                    .foregroundStyle(vm.isDrawingMode ? .orange : .white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }

            // Save button
            if vm.hasContent {
                Button {
                    saveName = vm.parcel?.cadastralRef ?? "Mi finca"
                    saveAsManual = !vm.drawnPoints.isEmpty
                    showSaveSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
        .padding(.bottom, 8)
    }

    // MARK: Metrics bar

    private var metricsBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Label(vm.formattedArea, systemImage: "square.dashed")
                    .font(.footnote.weight(.semibold))
                Label(vm.formattedPerimeter, systemImage: "ruler")
                    .font(.footnote)
            }
            Spacer()
            if let ref = vm.parcel?.cadastralRef {
                Text(ref)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: Drawing toolbar

    private var drawingToolbar: some View {
        HStack(spacing: 20) {
            Button("Deshacer", systemImage: "arrow.uturn.backward") {
                vm.undoLastPoint()
            }
            .disabled(vm.drawnPoints.isEmpty || vm.isDrawingClosed)

            Spacer()

            Text(vm.isDrawingClosed
                 ? "Polígono cerrado"
                 : vm.drawnPoints.count < 3
                   ? "Toca el mapa para añadir puntos"
                   : "Toca cerca del inicio para cerrar")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Cerrar", systemImage: "checkmark.circle") {
                vm.closePolygon()
            }
            .disabled(vm.drawnPoints.count < 3 || vm.isDrawingClosed)

            Button("Borrar", systemImage: "trash") {
                vm.clearDrawing()
            }
            .foregroundStyle(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: Save sheet

    private var saveSheet: some View {
        NavigationStack {
            Form {
                Section("Nombre de la finca") {
                    TextField("Nombre", text: $saveName)
                }

                if !vm.drawnPoints.isEmpty && vm.parcel != nil {
                    Section("¿Qué guardar?") {
                        Picker("", selection: $saveAsManual) {
                            Text("Parcela catastral").tag(false)
                            Text("Dibujo libre").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Métricas") {
                    LabeledContent("Área", value: vm.formattedArea)
                    LabeledContent("Perímetro", value: vm.formattedPerimeter)
                }
            }
            .navigationTitle("Guardar finca")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showSaveSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if let parcel = vm.makeParcelForSaving(name: saveName, isManual: saveAsManual) {
                            persistence.save(parcel)
                        }
                        showSaveSheet = false
                    }
                    .disabled(saveName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

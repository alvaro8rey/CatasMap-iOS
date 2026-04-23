import SwiftUI
import MapKit

struct MapContainerView: View {
    @Environment(MapViewModel.self) private var vm
    @Environment(PersistenceController.self) private var persistence

    @State private var showSaveSheet = false
    @State private var saveName = ""

    var body: some View {
        ZStack {
            mapLayer

            VStack(spacing: 0) {
                topBar
                Spacer()
                if vm.hasParcel || vm.hasDrawing {
                    metricsBar
                }
                if vm.isDrawingMode {
                    drawingToolbar
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        // Confirmación para limpiar dibujo previo y redibujar
        .confirmationDialog(
            "¿Limpiar medición actual?",
            isPresented: Bindable(vm).showClearDrawingConfirm,
            titleVisibility: .visible
        ) {
            Button("Limpiar y redibujar", role: .destructive) {
                vm.confirmClearAndDraw()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borrará tu medición actual para que puedas dibujar una nueva.")
        }
        .sheet(isPresented: $showSaveSheet) { saveSheet }
    }

    // MARK: Mapa

    private var mapLayer: some View {
        MapKitView(
            mapType:         vm.mapType == .standard ? .standard : .satellite,
            flyToRegion:     vm.flyToRegion,
            parcelCoordinates: vm.parcel?.coordinates ?? [],
            drawnPoints:     vm.drawnPoints,
            isDrawingMode:   vm.isDrawingMode,
            isDrawingClosed: vm.isDrawingClosed,
            onTap:           { coord in vm.addDrawingPoint(coord) }
        )
        .ignoresSafeArea()
    }

    // MARK: Barra superior

    private var topBar: some View {
        HStack(spacing: 12) {
            Spacer()

            // Normal / Satélite
            Button {
                vm.mapType = vm.mapType == .standard ? .satellite : .standard
            } label: {
                Image(systemName: vm.mapType == .standard ? "globe" : "map")
                    .iconStyle()
            }

            // Lápiz: dibujar / salir del modo dibujo
            if vm.hasParcel {
                Button {
                    if vm.isDrawingMode {
                        vm.exitDrawingMode()
                    } else {
                        vm.requestDrawingMode()
                    }
                } label: {
                    Image(systemName: vm.isDrawingMode ? "pencil.slash" : "pencil")
                        .iconStyle(active: vm.isDrawingMode)
                }
            }

            // Guardar (disponible si hay parcela catastral cargada)
            if vm.hasParcel {
                Button {
                    // Pre-rellenar con el nombre ya guardado, no con la referencia
                    if let id = vm.currentSavedParcelID,
                       let existing = persistence.savedParcels.first(where: { $0.id == id }) {
                        saveName = existing.customName
                    } else {
                        saveName = ""
                    }
                    showSaveSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .iconStyle()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
        .padding(.bottom, 8)
    }

    // MARK: Panel de métricas (dos capas)

    private var metricsBar: some View {
        VStack(spacing: 0) {
            // ── Capa catastral (azul) ──────────────────────────────────────
            if vm.hasParcel {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.blue)
                        .frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Catastro: \(vm.formattedCadastralArea)")
                            .font(.footnote.weight(.semibold))
                        Text(vm.formattedCadastralPerimeter)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(vm.parcel?.cadastralRef ?? "")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            // ── Capa de medición propia (rojo) ─────────────────────────────
            if vm.hasDrawing {
                Divider().padding(.horizontal, 12)
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.red)
                        .frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Mi medición: \(vm.formattedUserArea)")
                            .font(.footnote.weight(.semibold))
                        Text(vm.formattedUserPerimeter)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    // Diferencia de área
                    let diff = vm.userArea - vm.cadastralArea
                    if vm.hasParcel {
                        Text(diff >= 0 ? "+\(SphericalUtils.formatArea(diff))" : "-\(SphericalUtils.formatArea(abs(diff)))")
                            .font(.caption2)
                            .foregroundStyle(abs(diff) / max(vm.cadastralArea, 1) < 0.05 ? .green : .orange)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            // ── Indicador de modo dibujo activo ───────────────────────────
            if vm.isDrawingMode && !vm.hasDrawing {
                Divider().padding(.horizontal, 12)
                Text(vm.drawnPoints.isEmpty
                     ? "Toca el mapa para añadir puntos"
                     : vm.drawnPoints.count < 3
                       ? "Añade al menos 3 puntos"
                       : "Toca cerca del inicio para cerrar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
        .background(.ultraThinMaterial)
    }

    // MARK: Barra de herramientas de dibujo

    private var drawingToolbar: some View {
        HStack(spacing: 20) {
            Button {
                vm.undoLastPoint()
            } label: {
                Label("Deshacer", systemImage: "arrow.uturn.backward")
                    .font(.footnote)
            }
            .disabled(vm.drawnPoints.isEmpty || vm.isDrawingClosed)

            Spacer()

            Button {
                vm.closePolygon()
            } label: {
                Label("Cerrar polígono", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
            }
            .disabled(vm.drawnPoints.count < 3 || vm.isDrawingClosed)
            .tint(.green)

            Button(role: .destructive) {
                vm.clearDrawing()
            } label: {
                Image(systemName: "trash")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: Sheet de guardado

    private var saveSheet: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Nombre de la finca", text: $saveName)
                }

                Section("Capa catastral (oficial)") {
                    LabeledContent("Área",      value: vm.formattedCadastralArea)
                    LabeledContent("Perímetro", value: vm.formattedCadastralPerimeter)
                }

                if vm.hasDrawing {
                    Section("Mi medición") {
                        LabeledContent("Área",      value: vm.formattedUserArea)
                        LabeledContent("Perímetro", value: vm.formattedUserPerimeter)
                        let diff = vm.userArea - vm.cadastralArea
                        let pct  = diff / max(vm.cadastralArea, 1) * 100
                        LabeledContent("Diferencia",
                                       value: String(format: "%+.1f m² (%+.1f%%)", diff, pct))
                    }
                } else {
                    Section {
                        Label("Puedes añadir tu medición usando el lápiz.",
                              systemImage: "pencil.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                // Botones de guardado
                let nameOK = !saveName.trimmingCharacters(in: .whitespaces).isEmpty
                Section {
                    // Guardar (sobreescribir si ya existe, o crear nuevo)
                    Button {
                        save(asNew: false)
                    } label: {
                        Label(
                            vm.currentSavedParcelID == nil ? "Guardar" : "Guardar",
                            systemImage: "square.and.arrow.down.fill"
                        )
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!nameOK)

                        // Guardar como — solo visible al editar una finca existente
                    if vm.currentSavedParcelID != nil {
                        Button {
                            save(asNew: true)
                        } label: {
                            Label("Guardar como nueva copia", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(!nameOK || nameUsedElsewhere)
                        .tint(nameUsedElsewhere ? .red : .secondary)
                    }
                } footer: {
                    if nameUsedElsewhere {
                        Text("Ese nombre ya está en uso. Cambia el nombre para guardar una copia.")
                            .foregroundStyle(.red)
                    } else if vm.currentSavedParcelID != nil {
                        Text("\"Guardar\" sobreescribe esta finca. \"Guardar como nueva copia\" crea un registro independiente.")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(vm.currentSavedParcelID == nil ? "Guardar finca" : "Guardar cambios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showSaveSheet = false }
                }
            }
        }
    }

    private func save(asNew: Bool) {
        let parcel = vm.makeParcelForSaving(name: saveName, asNew: asNew)
        persistence.save(parcel)
        if asNew || vm.currentSavedParcelID == nil {
            vm.currentSavedParcelID = parcel.id
        }
        showSaveSheet = false
    }

    /// True si el nombre ya lo usa otra finca distinta a la actual
    private var nameUsedElsewhere: Bool {
        let trimmed = saveName.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return false }
        return persistence.savedParcels.contains {
            $0.customName.trimmingCharacters(in: .whitespaces).lowercased() == trimmed
            && $0.id != vm.currentSavedParcelID
        }
    }
}

// MARK: - Helper view modifier

private extension Image {
    func iconStyle(active: Bool = false) -> some View {
        self
            .foregroundStyle(active ? .orange : .white)
            .padding(10)
            .background(.ultraThinMaterial, in: Circle())
    }
}

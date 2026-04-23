import SwiftUI
import MapKit

struct SavedParcelsView: View {
    @Environment(PersistenceController.self) private var persistence
    @Environment(MapViewModel.self) private var mapVM

    var onNavigateToMap: () -> Void

    @State private var selectedParcel: SavedParcel?

    var body: some View {
        NavigationStack {
            Group {
                if persistence.savedParcels.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Mis Fincas")
        }
        .sheet(item: $selectedParcel) { parcel in
            ParcelDetailView(parcel: parcel) {
                // Cargar en el mapa (ambas capas)
                mapVM.loadSaved(parcel)
                selectedParcel = nil
                onNavigateToMap()
            } onDelete: {
                persistence.delete(parcel)
                selectedParcel = nil
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Sin fincas guardadas",
            systemImage: "map.fill",
            description: Text("Busca una parcela catastral y guárdala desde el mapa.")
        )
    }

    private var list: some View {
        List {
            ForEach(persistence.savedParcels) { parcel in
                Button { selectedParcel = parcel } label: { row(parcel) }
                    .buttonStyle(.plain)
            }
            .onDelete { offsets in persistence.deleteAt(offsets: offsets) }
        }
    }

    private func row(_ parcel: SavedParcel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(parcel.customName)
                    .font(.headline)
                Spacer()
                // Indicador de si tiene medición propia
                if parcel.hasUserDrawing {
                    Label("Medición", systemImage: "pencil.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Text(parcel.cadastralRef)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Capa catastral
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2).fill(.blue).frame(width: 8, height: 8)
                Text(parcel.formattedCadastralArea)
                    .font(.caption2)
                Text("·")
                Text(parcel.formattedCadastralPerimeter)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)

            // Capa propia (si existe)
            if parcel.hasUserDrawing, let uArea = parcel.formattedUserArea, let uPerim = parcel.formattedUserPerimeter {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(.red).frame(width: 8, height: 8)
                    Text(uArea).font(.caption2)
                    Text("·").font(.caption2)
                    Text(uPerim).font(.caption2)
                }
                .foregroundStyle(.secondary)
            }

            Text(parcel.savedDate, style: .date)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detalle de finca

struct ParcelDetailView: View {
    let parcel: SavedParcel
    let onViewInMap: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Información") {
                    LabeledContent("Nombre",         value: parcel.customName)
                    LabeledContent("Ref. catastral", value: parcel.cadastralRef)
                    LabeledContent("Guardada",       value: parcel.savedDate, format: .dateTime)
                }

                Section {
                    LabeledContent("Área",      value: parcel.formattedCadastralArea)
                    LabeledContent("Perímetro", value: parcel.formattedCadastralPerimeter)
                    LabeledContent("Vértices",  value: "\(parcel.cadastralCoordinates.count)")
                } header: {
                    Label("Polígono catastral (oficial)", systemImage: "building.columns")
                        .foregroundStyle(.blue)
                }

                if parcel.hasUserDrawing,
                   let uArea = parcel.formattedUserArea,
                   let uPerim = parcel.formattedUserPerimeter {
                    Section {
                        LabeledContent("Área",      value: uArea)
                        LabeledContent("Perímetro", value: uPerim)
                        let diff = (parcel.userArea ?? 0) - parcel.cadastralArea
                        let pct  = diff / max(parcel.cadastralArea, 1) * 100
                        LabeledContent("Diferencia",
                                       value: String(format: "%+.1f m² (%+.1f%%)", diff, pct))
                        LabeledContent("Vértices",
                                       value: "\(parcel.userCoordinates?.count ?? 0)")
                    } header: {
                        Label("Mi medición", systemImage: "pencil.circle.fill")
                            .foregroundStyle(.red)
                    }
                } else {
                    Section {
                        Label("Aún no has añadido tu propia medición.\nAbre el mapa y usa el lápiz para dibujarla.",
                              systemImage: "pencil.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Mi medición")
                    }
                }

                Section {
                    Button {
                        dismiss()
                        onViewInMap()
                    } label: {
                        Label("Abrir en el mapa", systemImage: "map")
                            .fontWeight(.semibold)
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Eliminar finca", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(parcel.customName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .confirmationDialog("¿Eliminar esta finca?",
                                isPresented: $showDeleteConfirm,
                                titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) { onDelete() }
                Button("Cancelar", role: .cancel) {}
            }
        }
    }
}

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
                mapVM.loadSaved(parcel)
                selectedParcel = nil
                onNavigateToMap()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Sin fincas guardadas",
            systemImage: "map.fill",
            description: Text("Busca una parcela o dibuja un polígono y guárdalo desde el mapa.")
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
                Image(systemName: parcel.isManualDrawing ? "pencil.circle" : "building.columns")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Text(parcel.cadastralRef)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Label(parcel.formattedArea, systemImage: "square.dashed")
                Spacer()
                Label(parcel.formattedPerimeter, systemImage: "ruler")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            Text(parcel.savedDate, style: .date)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail

struct ParcelDetailView: View {
    let parcel: SavedParcel
    let onViewInMap: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Información") {
                    LabeledContent("Nombre", value: parcel.customName)
                    LabeledContent("Ref. catastral", value: parcel.cadastralRef)
                    LabeledContent("Tipo", value: parcel.isManualDrawing ? "Dibujo libre" : "Parcela catastral")
                    LabeledContent("Guardada", value: parcel.savedDate, format: .dateTime)
                }

                Section("Métricas") {
                    LabeledContent("Área", value: parcel.formattedArea)
                    LabeledContent("Perímetro", value: parcel.formattedPerimeter)
                    LabeledContent("Vértices", value: "\(parcel.coordinates.count)")
                }

                Section {
                    Button {
                        dismiss()
                        onViewInMap()
                    } label: {
                        Label("Ver en el mapa", systemImage: "map")
                            .fontWeight(.semibold)
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
        }
    }
}

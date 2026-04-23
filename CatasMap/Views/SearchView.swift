import SwiftUI

struct SearchView: View {
    @Environment(SearchViewModel.self) private var vm
    @Environment(MapViewModel.self) private var mapVM

    // Tab selection binding passed from MainTabView
    var onNavigateToMap: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                selectionSection
                referenceSection
                if vm.isLoading { loadingSection }
                if let err = vm.errorMessage { errorSection(err) }
                if let parcel = vm.foundParcel { resultSection(parcel) }
            }
            .navigationTitle("Buscar Parcela")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Limpiar") { vm.clear() }
                        .disabled(vm.cadastralRef.isEmpty && vm.foundParcel == nil)
                }
            }
        }
    }

    // MARK: Sections

    private var selectionSection: some View {
        Section("Localización (referencia)") {
            if vm.provinces.isEmpty {
                Text("Cargando municipios…")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Provincia", selection: Bindable(vm).selectedProvince) {
                    Text("Seleccionar provincia").tag(nil as Province?)
                    ForEach(vm.provinces) { prov in
                        Text(prov.nombre).tag(Optional(prov))
                    }
                }
                .onChange(of: vm.selectedProvince) { _, newVal in
                    vm.selectProvince(newVal)
                }

                Picker("Municipio", selection: Bindable(vm).selectedMunicipality) {
                    Text("Seleccionar municipio").tag(nil as Municipality?)
                    ForEach(vm.municipalities) { mun in
                        Text(mun.nombre).tag(Optional(mun))
                    }
                }
                .disabled(vm.selectedProvince == nil)
            }
        }
    }

    private var referenceSection: some View {
        Section {
            HStack {
                TextField("Ej: 27038A01800039", text: Bindable(vm).cadastralRef)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .keyboardType(.asciiCapable)
                if !vm.cadastralRef.isEmpty {
                    Button {
                        Bindable(vm).cadastralRef.wrappedValue = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
        } header: {
            Text("Referencia catastral")
        } footer: {
            Text("Código de 14-20 caracteres que identifica la parcela en España.")
                .font(.caption)
        }

        Section {
            Button {
                Task { await vm.searchParcel() }
            } label: {
                HStack {
                    Spacer()
                    Label("Buscar parcela", systemImage: "magnifyingglass")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .disabled(vm.isLoading || vm.cadastralRef.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var loadingSection: some View {
        Section {
            HStack {
                Spacer()
                ProgressView("Buscando en el catastro…")
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    private func errorSection(_ message: String) -> some View {
        Section {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }

    private func resultSection(_ parcel: CadastralFeature) -> some View {
        Section("Resultado") {
            LabeledContent("Referencia", value: parcel.cadastralRef)

            let ring = parcel.coordinates.first ?? []
            if !ring.isEmpty {
                let area = SphericalUtils.computeArea(path: ring)
                let perim = SphericalUtils.computePerimeter(path: ring)
                LabeledContent("Área", value: SphericalUtils.formatArea(area))
                LabeledContent("Perímetro", value: String(format: "%.1f m", perim))
                LabeledContent("Vértices", value: "\(ring.count)")
            }

            Button {
                mapVM.setParcel(parcel)
                onNavigateToMap()
            } label: {
                Label("Ver en el mapa", systemImage: "map")
                    .fontWeight(.semibold)
            }
        }
    }
}

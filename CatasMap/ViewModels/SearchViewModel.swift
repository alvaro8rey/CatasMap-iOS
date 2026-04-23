import Foundation
import Observation

@Observable
class SearchViewModel {
    var provinces: [Province] = []
    var selectedProvince: Province?
    var selectedMunicipality: Municipality?
    var cadastralRef: String = ""

    var isLoading = false
    var errorMessage: String?
    var foundParcel: CadastralFeature?

    var municipalities: [Municipality] {
        selectedProvince?.municipios ?? []
    }

    init() {
        loadMunicipios()
    }

    func loadMunicipios() {
        guard
            let url  = Bundle.main.url(forResource: "municipios", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(MunicipiosData.self, from: data)
        else { return }
        provinces = decoded.provincias
    }

    func selectProvince(_ province: Province?) {
        selectedProvince = province
        selectedMunicipality = nil
    }

    func searchParcel() async {
        let ref = cadastralRef.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ref.isEmpty else {
            errorMessage = "Introduce una referencia catastral"
            return
        }

        // Pass selected names in lowercase as required by the catastro API.
        // Empty strings are accepted by the API when the refcat is provided.
        let municipio = selectedMunicipality?.nombre.lowercased() ?? ""
        let provincia = selectedProvince?.nombre.lowercased() ?? ""

        isLoading = true
        errorMessage = nil
        foundParcel = nil

        do {
            foundParcel = try await CadastroService.shared.searchParcel(
                ref: ref,
                municipio: municipio,
                provincia: provincia
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func clear() {
        cadastralRef = ""
        foundParcel = nil
        errorMessage = nil
    }
}

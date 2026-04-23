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
            let url = Bundle.main.url(forResource: "municipios", withExtension: "json"),
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
        isLoading = true
        errorMessage = nil
        foundParcel = nil

        do {
            foundParcel = try await CadastroService.shared.searchParcel(ref: ref)
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

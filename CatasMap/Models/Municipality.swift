import Foundation

struct Province: Codable, Identifiable, Hashable {
    var id: String { codigo }
    let codigo: String
    let nombre: String
    let municipios: [Municipality]
}

struct Municipality: Codable, Identifiable, Hashable {
    var id: String { codigo }
    let codigo: String
    let nombre: String
}

struct MunicipiosData: Codable {
    let provincias: [Province]
}

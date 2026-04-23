import Foundation
import CoreLocation

struct CadastralFeature {
    let cadastralRef: String
    let coordinates: [[CLLocationCoordinate2D]]
}

class CadastroService {
    static let shared = CadastroService()

    // Official catastro INSPIRE WFS endpoints (tried in order)
    private let endpoints = [
        "https://ovc.catastro.meh.es/INSPIRE/wfscatastro.aspx",
        "https://www.catastro.minhap.es/INSPIRE/CadastralParcels/wfs",
    ]

    func searchParcel(ref: String) async throws -> CadastralFeature {
        let cleanRef = ref.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanRef.isEmpty else { throw CadastroError.emptyReference }

        var lastError: Error = CadastroError.serverError

        for base in endpoints {
            do {
                return try await fetchFromEndpoint(base, ref: cleanRef)
            } catch CadastroError.notFound {
                throw CadastroError.notFound          // definitive: parcel doesn't exist
            } catch CadastroError.parseError {
                throw CadastroError.parseError        // definitive: bad data
            } catch {
                lastError = error                      // network/DNS: try next endpoint
            }
        }

        throw lastError
    }

    // MARK: Private

    private func fetchFromEndpoint(_ base: String, ref: String) async throws -> CadastralFeature {
        // Use URLComponents so single quotes in CQL_FILTER are percent-encoded automatically
        var comps = URLComponents(string: base)!
        comps.queryItems = [
            URLQueryItem(name: "SERVICE",     value: "WFS"),
            URLQueryItem(name: "VERSION",     value: "2.0.0"),
            URLQueryItem(name: "REQUEST",     value: "GetFeature"),
            URLQueryItem(name: "TYPENAMES",   value: "cp:CadastralParcel"),
            URLQueryItem(name: "CQL_FILTER",  value: "nationalCadastralReference='\(ref)'"),
            URLQueryItem(name: "outputFormat",value: "application/json"),
            URLQueryItem(name: "SRSNAME",     value: "EPSG:4326"),   // get WGS84 directly
        ]

        guard let url = comps.url else { throw CadastroError.invalidURL }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CadastroError.serverError
        }

        return try parseGeoJSON(data: data, ref: ref)
    }

    private func parseGeoJSON(data: Data, ref: String) throws -> CadastralFeature {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let features = json["features"] as? [[String: Any]],
            !features.isEmpty
        else {
            throw CadastroError.notFound
        }

        guard
            let feature  = features.first,
            let geometry = feature["geometry"] as? [String: Any],
            let geomType = geometry["type"] as? String
        else {
            throw CadastroError.parseError
        }

        // SRSNAME=EPSG:4326 → coordinates arrive as [longitude, latitude]
        var rings: [[CLLocationCoordinate2D]] = []

        switch geomType {
        case "Polygon":
            guard let rawRings = geometry["coordinates"] as? [[[Double]]] else {
                throw CadastroError.parseError
            }
            rings = rawRings.map { ring in
                ring.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
            }

        case "MultiPolygon":
            guard let rawPolygons = geometry["coordinates"] as? [[[[Double]]]] else {
                throw CadastroError.parseError
            }
            for polygon in rawPolygons {
                for ring in polygon {
                    rings.append(ring.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) })
                }
            }

        default:
            throw CadastroError.unsupportedGeometry
        }

        guard !rings.isEmpty else { throw CadastroError.noCoordinates }
        return CadastralFeature(cadastralRef: ref, coordinates: rings)
    }
}

enum CadastroError: LocalizedError {
    case emptyReference, invalidURL, serverError, parseError
    case unsupportedGeometry, noCoordinates, notFound

    var errorDescription: String? {
        switch self {
        case .emptyReference:      return "Introduce una referencia catastral"
        case .invalidURL:          return "URL de búsqueda no válida"
        case .serverError:         return "Error en el servidor del catastro"
        case .parseError:          return "Error al procesar la respuesta"
        case .unsupportedGeometry: return "Geometría no soportada"
        case .noCoordinates:       return "La parcela no tiene coordenadas"
        case .notFound:            return "Referencia catastral no encontrada"
        }
    }
}

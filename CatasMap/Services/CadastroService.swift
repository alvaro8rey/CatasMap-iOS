import Foundation
import CoreLocation

struct CadastralFeature {
    let cadastralRef: String
    let coordinates: [[CLLocationCoordinate2D]]  // outer ring first; inner rings are holes
}

class CadastroService {
    static let shared = CadastroService()

    // WFS endpoint for polygon geometry (coordinates in UTM EPSG:25830)
    private let wfsBase = "https://www.catastro.minhap.es/wfs/DNPRC_BT_Polygon"

    func searchParcel(ref: String) async throws -> CadastralFeature {
        let cleanRef = ref.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanRef.isEmpty else { throw CadastroError.emptyReference }

        let encodedRef = cleanRef.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanRef
        let urlString = "\(wfsBase)?service=WFS&version=2.0.0&request=GetFeature&typeName=DNPRC_BT_Polygon&CQL_FILTER=refcat='\(encodedRef)'&outputFormat=application/json"

        guard let url = URL(string: urlString) else { throw CadastroError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CadastroError.serverError
        }

        return try parseGeoJSON(data: data, ref: cleanRef)
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
            let feature = features.first,
            let geometry = feature["geometry"] as? [String: Any],
            let geomType = geometry["type"] as? String
        else {
            throw CadastroError.parseError
        }

        var rings: [[CLLocationCoordinate2D]] = []

        switch geomType {
        case "Polygon":
            guard let rawRings = geometry["coordinates"] as? [[[Double]]] else {
                throw CadastroError.parseError
            }
            rings = rawRings.map { ring in
                ring.map { CoordinateConverter.utmToLatLon(easting: $0[0], northing: $0[1]) }
            }

        case "MultiPolygon":
            guard let rawPolygons = geometry["coordinates"] as? [[[[Double]]]] else {
                throw CadastroError.parseError
            }
            for polygon in rawPolygons {
                for ring in polygon {
                    rings.append(ring.map { CoordinateConverter.utmToLatLon(easting: $0[0], northing: $0[1]) })
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

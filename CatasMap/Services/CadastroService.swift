import Foundation
import CoreLocation

struct CadastralFeature {
    let cadastralRef: String
    let coordinates: [[CLLocationCoordinate2D]]   // outer ring first; inner rings are holes
    let centerCoordinate: CLLocationCoordinate2D? // from API 1 (optional, for fallback)
}

class CadastroService {
    static let shared = CadastroService()

    // API 1 – Centro de la parcela (valida la referencia)
    private let coordBase = "https://ovc.catastro.meh.es/OVCServWeb/OVCWcfCallejero/COVCCoordenadas.svc/rest/Consulta_CPMRC"

    // API 2 – Geometría GML del polígono catastral
    private let wfsBase   = "https://ovc.catastro.meh.es/INSPIRE/wfsCP.aspx"

    // MARK: Public

    func searchParcel(ref: String, municipio: String, provincia: String) async throws -> CadastralFeature {
        let cleanRef = ref.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanRef.isEmpty else { throw CadastroError.emptyReference }

        // Step 1: validate reference and get center coord
        let (center, _) = try await fetchCenter(ref: cleanRef, municipio: municipio, provincia: provincia)

        // Step 2: get polygon geometry
        let rings = try await fetchPolygon(ref: cleanRef)

        return CadastralFeature(cadastralRef: cleanRef, coordinates: rings, centerCoordinate: center)
    }

    // MARK: Step 1 – Consulta_CPMRC

    private func fetchCenter(ref: String, municipio: String, provincia: String) async throws -> (CLLocationCoordinate2D, Int) {
        var comps = URLComponents(string: coordBase)!
        comps.queryItems = [
            URLQueryItem(name: "RefCat",    value: ref),
            URLQueryItem(name: "Municipio", value: municipio.lowercased()),
            URLQueryItem(name: "Provincia", value: provincia.lowercased()),
        ]
        guard let url = comps.url else { throw CadastroError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            throw CadastroError.notFound
        }

        let xml = String(data: data, encoding: .utf8) ?? ""

        // Detect error response (catastro returns <lerr> or <des> with error text)
        if xml.contains("<lerr>") || xml.contains("<err>") {
            throw CadastroError.notFound
        }

        guard
            let xcenStr = xmlValue(xml, tag: "xcen"), let xcen = Double(xcenStr),
            let ycenStr = xmlValue(xml, tag: "ycen"), let ycen = Double(ycenStr),
            let srsStr  = xmlValue(xml, tag: "srs")
        else {
            throw CadastroError.notFound
        }

        // srs looks like "EPSG:25829" or "EPSG:25830"
        let epsg = Int(srsStr.replacingOccurrences(of: "EPSG:", with: "")) ?? 25830
        let coord = CoordinateConverter.utmToLatLon(easting: xcen, northing: ycen, epsg: epsg)
        return (coord, epsg)
    }

    // MARK: Step 2 – wfsCP.aspx (GML)

    private func fetchPolygon(ref: String) async throws -> [[CLLocationCoordinate2D]] {
        var comps = URLComponents(string: wfsBase)!
        comps.queryItems = [
            URLQueryItem(name: "service",          value: "wfs"),
            URLQueryItem(name: "version",          value: "2"),
            URLQueryItem(name: "request",          value: "getfeature"),
            URLQueryItem(name: "STOREDQUERIE_ID",  value: "GetParcel"),
            URLQueryItem(name: "refcat",           value: ref),
            URLQueryItem(name: "srsname",          value: "EPSG:25830"),
        ]
        guard let url = comps.url else { throw CadastroError.invalidURL }

        let (data, _) = try await URLSession.shared.data(from: url)
        let gml = String(data: data, encoding: .utf8) ?? ""
        return try parseGML(gml)
    }

    // MARK: GML parser

    private func parseGML(_ gml: String) throws -> [[CLLocationCoordinate2D]] {
        // Match <gml:posList ...>...</gml:posList>  (or without namespace prefix)
        let pattern = #"<(?:gml:)?posList[^>]*>([\s\S]*?)</(?:gml:)?posList>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            throw CadastroError.parseError
        }

        let nsGml = gml as NSString
        let matches = regex.matches(in: gml, range: NSRange(location: 0, length: nsGml.length))

        var rings: [[CLLocationCoordinate2D]] = []

        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let captureRange = match.range(at: 1)
            guard captureRange.location != NSNotFound else { continue }
            let posListStr = nsGml.substring(with: captureRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Values are space-separated; pairs are (Easting, Northing) in EPSG:25830
            let values = posListStr
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .compactMap(Double.init)

            guard values.count >= 6 else { continue }   // need at least 3 points (2 coords each)

            var ring: [CLLocationCoordinate2D] = []
            var i = 0
            while i + 1 < values.count {
                let coord = CoordinateConverter.utmToLatLon(
                    easting:  values[i],
                    northing: values[i + 1],
                    epsg:     25830
                )
                ring.append(coord)
                i += 2
            }

            // The GML polygon is already closed (first == last); drop the duplicate
            if ring.count > 1,
               ring.first!.latitude  == ring.last!.latitude,
               ring.first!.longitude == ring.last!.longitude {
                ring.removeLast()
            }

            if !ring.isEmpty { rings.append(ring) }
        }

        guard !rings.isEmpty else { throw CadastroError.noCoordinates }
        return rings
    }

    // MARK: XML helper

    private func xmlValue(_ xml: String, tag: String) -> String? {
        guard
            let start = xml.range(of: "<\(tag)>"),
            let end   = xml.range(of: "</\(tag)>", range: start.upperBound..<xml.endIndex)
        else { return nil }
        return String(xml[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: Errors

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
        case .noCoordinates:       return "La parcela no tiene coordenadas en el WFS"
        case .notFound:            return "Referencia catastral no encontrada. Verifica provincia y municipio."
        }
    }
}

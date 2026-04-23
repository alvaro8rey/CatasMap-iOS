import Foundation
import Observation

@Observable
class PersistenceController {
    static let shared = PersistenceController()

    var savedParcels: [SavedParcel] = []

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("catasmap_parcels.json")
    }

    init() {
        load()
    }

    func load() {
        guard
            let data = try? Data(contentsOf: fileURL),
            let parcels = try? JSONDecoder().decode([SavedParcel].self, from: data)
        else {
            savedParcels = []
            return
        }
        savedParcels = parcels
    }

    func save(_ parcel: SavedParcel) {
        if let idx = savedParcels.firstIndex(where: { $0.id == parcel.id }) {
            savedParcels[idx] = parcel
        } else {
            savedParcels.insert(parcel, at: 0)
        }
        persist()
    }

    func delete(_ parcel: SavedParcel) {
        savedParcels.removeAll { $0.id == parcel.id }
        persist()
    }

    func deleteAt(offsets: IndexSet) {
        savedParcels.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(savedParcels) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

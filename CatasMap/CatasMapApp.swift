import SwiftUI

@main
struct CatasMapApp: App {
    @State private var searchViewModel = SearchViewModel()
    @State private var mapViewModel = MapViewModel()
    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(searchViewModel)
                .environment(mapViewModel)
                .environment(persistence)
        }
    }
}

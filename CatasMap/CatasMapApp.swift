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
                // Ocultar teclado al tocar en cualquier otro sitio
                .simultaneousGesture(
                    TapGesture().onEnded {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                )
        }
    }
}

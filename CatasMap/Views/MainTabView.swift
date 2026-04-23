import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Buscar", systemImage: "magnifyingglass", value: 0) {
                SearchView(onNavigateToMap: { selectedTab = 1 })
            }

            Tab("Mapa", systemImage: "map", value: 1) {
                MapContainerView()
            }

            Tab("Mis Fincas", systemImage: "building.columns", value: 2) {
                SavedParcelsView(onNavigateToMap: { selectedTab = 1 })
            }
        }
    }
}

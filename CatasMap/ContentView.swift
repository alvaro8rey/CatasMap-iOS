import SwiftUI

// Root view — delegates directly to MainTabView via App scene.
// Kept for Xcode preview compatibility.
struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .environment(SearchViewModel())
        .environment(MapViewModel())
        .environment(PersistenceController())
}

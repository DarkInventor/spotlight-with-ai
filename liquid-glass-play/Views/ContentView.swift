import CoreFoundation
import SwiftUI

struct ContentView: View {
    @State private var searchText: String = ""
    
    var body: some View {
        SearchBar(text: $searchText)
    }
}

#Preview {
    ContentView()
        .environmentObject(WindowManager())
}

import SwiftUI

struct StatusLabel: View {
    let state: AppState

    var body: some View {
        Label(state.menuBarTitle, systemImage: state.systemImageName)
            .labelStyle(.titleAndIcon)
    }
}

#Preview {
    StatusLabel(state: .ready)
}

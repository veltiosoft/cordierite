import SwiftUI

@main
struct CordieriteApp: App {
  @State private var appModel = AppModel()

  var body: some Scene {
    MenuBarExtra {
      MenuBarView()
        .environment(appModel)
    } label: {
      StatusLabel(
        state: appModel.state,
        recordingFeedback: appModel.recordingFeedback
      )
    }
    .menuBarExtraStyle(.menu)

    Settings {
      SettingsView()
        .environment(appModel)
    }

    Window("Permission Doctor", id: "permissionDoctor") {
      PermissionDoctorView()
        .environment(appModel)
    }
    .defaultSize(width: 520, height: 440)

    Window("Acknowledgements", id: "acknowledgements") {
      AcknowledgementsView()
    }
    .defaultSize(width: 560, height: 480)
  }
}

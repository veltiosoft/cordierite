import SwiftUI

struct AcknowledgementsView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text(
          """
          Cordierite uses the following third-party open-source software. \
          The MIT licenses below apply only to the listed components, not to Cordierite as a whole.
          """
        )
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

        ForEach(ThirdPartyLicenses.components) { component in
          componentSection(component)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(24)
    }
    .frame(minWidth: 520, minHeight: 420)
  }

  @ViewBuilder
  private func componentSection(_ component: ThirdPartyComponent) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(component.name)
        .font(.headline)

      Text(component.copyright)
        .font(.subheadline)

      Text(component.licenseName)
        .font(.subheadline)
        .foregroundStyle(.secondary)

      if let notice = component.notice {
        Text(notice)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Text(component.licenseText)
        .font(.system(.caption, design: .monospaced))
        .textSelection(.enabled)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

#Preview {
  AcknowledgementsView()
}

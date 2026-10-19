import SwiftUI

struct GreetingView: View {
    let layout: IslandLayout

    @Environment(\.themeAppearance) private var appearance

    var body: some View {
        PanelRow(layout: layout, subtitle: Text("Pasa el ratón por el notch cuando quieras"), subtitleLines: 2, showsBar: false) {
            PanelTile(layout: layout) {
                Image(nsImage: MenuBarIcon.image)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: layout.artworkSide * 0.42)
                    .foregroundStyle(appearance.text)
            }
        } title: {
            Text("Esto es Notchy")
        } accessory: {
            EmptyView()
        } bar: {
            EmptyView()
        } trailing: {
            Color.clear
        }
    }
}

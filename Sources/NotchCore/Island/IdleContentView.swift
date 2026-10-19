import SwiftUI

struct IdleContentView: View {
    let layout: IslandLayout

    var body: some View {
        PanelRow(layout: layout, showsBar: false) {
            ArtworkView(image: nil, size: layout.artworkSide, cornerRadius: layout.artworkCorner)
        } title: {
            Text("Nada sonando")
        } accessory: {
            EmptyView()
        } bar: {
            EmptyView()
        } trailing: {
            Color.clear
        }
    }
}

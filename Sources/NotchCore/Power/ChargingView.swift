import SwiftUI

struct ChargingView: View {
    let layout: IslandLayout
    let event: PowerEvent

    @Environment(\.themeAppearance) private var appearance

    private var level: Double { Double(event.percent).clamped(to: 0...100) / 100 }

    var body: some View {
        PanelRow(layout: layout, subtitle: Text(detail)) {
            PanelSymbol(layout: layout, systemName: symbol)
        } title: {
            Text("\(event.percent) %")
                .monospacedDigit()
                .foregroundStyle(appearance.hasRetroDigits ? appearance.accentText : appearance.text)
        } accessory: {
            EmptyView()
        } bar: {
            PanelLevel(layout: layout, fraction: level, fill: isCritical ? .systemRed : nil)
        } trailing: {
            Color.clear
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(detail), \(event.percent) %")
    }

    private var isCritical: Bool {
        if case .low = event { return true }
        return false
    }

    private var symbol: String {
        switch event {
        case .connected: "battery.100percent.bolt"
        case .full: "battery.100percent"
        case .low: "battery.25percent"
        case .disconnected: level > 0.5 ? "battery.75percent" : "battery.50percent"
        }
    }

    private var detail: String {
        switch event {
        case .connected: String(localized: "Cargando")
        case .disconnected: String(localized: "Cargador desconectado")
        case .low: String(localized: "Conecta el cargador pronto")
        case .full: String(localized: "Puedes desconectar el cargador")
        }
    }
}

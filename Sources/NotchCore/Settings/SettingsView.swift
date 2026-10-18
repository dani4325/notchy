import SwiftUI

public struct SettingsView: View {
    @AppStorage(Preferences.Key.nonNotchMode) private var nonNotchMode = NonNotchMode.pill.rawValue
    @AppStorage(Preferences.Key.showCalibrationOutline) private var showOutline = false


    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(NotchyStyle.accent.opacity(0.4))
            Form {
                Section {
                    Picker("Pantallas sin notch", selection: $nonNotchMode) {
                        Text("Píldora flotante").tag(NonNotchMode.pill.rawValue)
                        Text("Nada").tag(NonNotchMode.hidden.rawValue)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("Monitores externos y Macs sin notch.")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Toggle("Contorno de calibración", isOn: $showOutline)
                } footer: {
                    Text("Dibuja el borde del panel para comprobar que encaja con el notch.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
        }
        .frame(width: 440)
        .tint(NotchyStyle.accent)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: MenuBarIcon.image)
                .renderingMode(.template)
                .foregroundStyle(NotchyStyle.accent)
                .scaleEffect(1.6)
                .frame(width: 36, height: 36)
                .background(.black, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(AppInfo.name.uppercased())
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .tracking(2)
                Text("v\(AppInfo.version) · ajustes generales")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }
}

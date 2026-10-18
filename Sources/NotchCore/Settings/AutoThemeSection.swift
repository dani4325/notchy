import SwiftUI

struct AutoThemeSection: View {
    let controller: AutoThemeController
    let themes: ThemeStore

    var body: some View {
        Section {
            Toggle("Cambiar de tema automáticamente", isOn: Binding(
                get: { controller.rules.isEnabled },
                set: { controller.setEnabled($0) }
            ))
            if controller.rules.isEnabled {
                ForEach(controller.rules.schedule.sorted { $0.startMinute < $1.startMinute }) { rule in
                    HStack {
                        Text("Desde")
                        DatePicker("Desde", selection: timeBinding(rule), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        themePicker(Binding(get: { rule.themeID }, set: { controller.updateSchedule(rule.id, themeID: $0) }))
                        removeButton { controller.removeSchedule(rule.id) }
                    }
                }
                Button("Añadir franja horaria", systemImage: "plus.circle", action: controller.addScheduleRule)
                    .buttonStyle(.borderless)

                ForEach(controller.rules.apps) { rule in
                    HStack {
                        Label(rule.appName, systemImage: "app")
                            .frame(minWidth: 120, alignment: .leading)
                        themePicker(Binding(get: { rule.themeID }, set: { controller.updateApp(rule.id, themeID: $0) }))
                        removeButton { controller.removeApp(rule.id) }
                    }
                }
                Button("Añadir app…", systemImage: "plus.app", action: controller.addAppFromPanel)
                    .buttonStyle(.borderless)
            }
        } header: {
            Text("Temas automáticos")
        } footer: {
            Text("Cada franja empieza a su hora y dura hasta la siguiente. Si la app en primer plano tiene regla, gana sobre el horario. El tema elegido en la galería vuelve cuando ninguna regla aplica.")
                .foregroundStyle(.secondary)
        }
    }

    private func themePicker(_ selection: Binding<String>) -> some View {
        Picker("Tema", selection: selection) {
            ForEach(themes.themes) { theme in
                Text(theme.name).tag(theme.id)
            }
        }
        .labelsHidden()
    }

    private func removeButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Quitar regla")
    }

    private func timeBinding(_ rule: ScheduleRule) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: rule.startMinute / 60, minute: rule.startMinute % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                controller.updateSchedule(rule.id, startMinute: AutoThemeResolver.minuteOfDay(date, calendar: .current))
            }
        )
    }
}

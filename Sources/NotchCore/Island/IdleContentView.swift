import SwiftUI

struct IdleContentView: View {
    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    NotchyStyle.accent.opacity(0.55),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                )
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(NotchyStyle.accent)
                }

            VStack(alignment: .leading, spacing: 5) {
                Text("NADA SONANDO")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(2.5)
                    .foregroundStyle(NotchyStyle.accent)
                Text("Pon algo de música y aparecerá aquí")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(AppInfo.name.lowercased())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

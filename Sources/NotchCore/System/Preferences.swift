import Foundation

public enum Preferences {
    public enum Key {
        public static let nonNotchMode = "nonNotchMode"
        public static let showCalibrationOutline = "showCalibrationOutline"
        public static let musicSourceMode = "musicSourceMode"
        public static let wingsMode = "wingsMode"
    }

    public static var nonNotchMode: NonNotchMode {
        UserDefaults.standard.string(forKey: Key.nonNotchMode).flatMap(NonNotchMode.init) ?? .pill
    }

    public static var musicSourceMode: MusicSourceMode {
        UserDefaults.standard.string(forKey: Key.musicSourceMode).flatMap(MusicSourceMode.init) ?? .automatic
    }

    public static var wingsMode: WingsMode {
        UserDefaults.standard.string(forKey: Key.wingsMode).flatMap(WingsMode.init) ?? .withMusic
    }
}

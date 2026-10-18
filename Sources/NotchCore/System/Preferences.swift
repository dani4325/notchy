import Foundation

public enum Preferences {
    public enum Key {
        public static let nonNotchMode = "nonNotchMode"
        public static let showCalibrationOutline = "showCalibrationOutline"
    }

    public static var nonNotchMode: NonNotchMode {
        UserDefaults.standard.string(forKey: Key.nonNotchMode).flatMap(NonNotchMode.init) ?? .pill
    }
}

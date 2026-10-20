import Foundation

public enum Preferences {
    public enum Key {
        public static let nonNotchMode = "nonNotchMode"
        public static let showCalibrationOutline = "showCalibrationOutline"
        public static let musicSourceMode = "musicSourceMode"
        public static let wingsMode = "wingsMode"
        public static let chargingAnimation = "chargingAnimation"
        public static let volumeHUD = "volumeHUD"
        public static let visualizer = "visualizer"
        public static let audioCaptureConfirmed = "audioCaptureConfirmed"
        public static let shelf = "shelf"
        public static let shelfLimit = "shelfLimit"
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

    public static var chargingAnimation: Bool {
        UserDefaults.standard.object(forKey: Key.chargingAnimation) as? Bool ?? true
    }

    public static var volumeHUD: Bool {
        UserDefaults.standard.object(forKey: Key.volumeHUD) as? Bool ?? true
    }

    public static var visualizer: Bool {
        UserDefaults.standard.object(forKey: Key.visualizer) as? Bool ?? true
    }

    public static var shelf: Bool {
        UserDefaults.standard.object(forKey: Key.shelf) as? Bool ?? true
    }

    public static var shelfLimit: Int {
        let stored = UserDefaults.standard.integer(forKey: Key.shelfLimit)
        return stored == 0 ? ShelfStore.defaultLimit : stored
    }
}

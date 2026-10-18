import Foundation

enum AdapterPayload {
    private static let microsPerSecond = 1_000_000.0

    static func parse(line: Data) -> [String: Any]? {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              object["type"] as? String == "data",
              object["payload"] is [String: Any]
        else { return nil }
        return object
    }

    static func merge(_ state: [String: Any], with message: [String: Any]) -> [String: Any] {
        let payload = message["payload"] as? [String: Any] ?? [:]
        let isDiff = message["diff"] as? Bool ?? false
        let base = isDiff ? state : [:]

        return payload.reduce(into: base) { result, entry in
            result[entry.key] = entry.value is NSNull ? nil : entry.value
        }
    }

    static func info(from fields: [String: Any], now: Date) -> NowPlayingInfo? {
        guard let title = fields["title"] as? String, !title.isEmpty,
              let bundleID = (fields["parentApplicationBundleIdentifier"] ?? fields["bundleIdentifier"]) as? String,
              let isPlaying = fields["playing"] as? Bool
        else { return nil }

        let timestamp = (fields["timestampEpochMicros"] as? Double)
            .map { Date(timeIntervalSince1970: $0 / microsPerSecond) } ?? now

        return NowPlayingInfo(
            title: title,
            artist: nonEmpty(fields["artist"]),
            album: nonEmpty(fields["album"]),
            duration: (fields["durationMicros"] as? Double).map { $0 / microsPerSecond },
            elapsed: ((fields["elapsedTimeMicros"] as? Double) ?? 0) / microsPerSecond,
            timestamp: timestamp,
            playbackRate: (fields["playbackRate"] as? Double) ?? (isPlaying ? 1 : 0),
            isPlaying: isPlaying,
            appBundleID: bundleID,
            artworkData: (fields["artworkData"] as? String).flatMap { Data(base64Encoded: $0) }
        )
    }

    private static func nonEmpty(_ value: Any?) -> String? {
        guard let string = value as? String, !string.isEmpty else { return nil }
        return string
    }
}

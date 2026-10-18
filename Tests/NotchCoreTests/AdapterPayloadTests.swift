import Foundation
import Testing
@testable import NotchCore

struct AdapterPayloadTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    let fullLine = """
    {"type":"data","diff":false,"payload":{"title":"Hacking to the Gate","artist":"Kanako Itō","album":"OST",\
    "bundleIdentifier":"com.spotify.client","playing":true,"playbackRate":1,"durationMicros":245000000,\
    "elapsedTimeMicros":12500000,"timestampEpochMicros":1800000000000000,"artworkData":"AQID","artworkMimeType":"image/png"}}
    """

    @Test func parsesFullPayloadIntoInfo() throws {
        let message = try #require(AdapterPayload.parse(line: Data(fullLine.utf8)))
        let fields = AdapterPayload.merge([:], with: message)

        let info = try #require(AdapterPayload.info(from: fields, now: now))

        #expect(info.title == "Hacking to the Gate")
        #expect(info.artist == "Kanako Itō")
        #expect(info.appBundleID == "com.spotify.client")
        #expect(info.isPlaying)
        #expect(info.duration == 245)
        #expect(info.elapsed == 12.5)
        #expect(info.timestamp == now)
        #expect(info.artworkData == Data([1, 2, 3]))
    }

    @Test func diffUpdatesOnlyChangedKeysAndNullRemovesThem() throws {
        let first = try #require(AdapterPayload.parse(line: Data(fullLine.utf8)))
        let diffLine = #"{"type":"data","diff":true,"payload":{"playing":false,"artworkData":null}}"#
        let diff = try #require(AdapterPayload.parse(line: Data(diffLine.utf8)))

        let fields = AdapterPayload.merge(AdapterPayload.merge([:], with: first), with: diff)
        let info = try #require(AdapterPayload.info(from: fields, now: now))

        #expect(!info.isPlaying)
        #expect(info.title == "Hacking to the Gate")
        #expect(info.artworkData == nil)
    }

    @Test func nonDiffPayloadReplacesPreviousState() throws {
        let first = try #require(AdapterPayload.parse(line: Data(fullLine.utf8)))
        let empty = try #require(AdapterPayload.parse(line: Data(#"{"type":"data","diff":false,"payload":{}}"#.utf8)))

        let fields = AdapterPayload.merge(AdapterPayload.merge([:], with: first), with: empty)

        #expect(fields.isEmpty)
        #expect(AdapterPayload.info(from: fields, now: now) == nil)
    }

    @Test func prefersParentBundleIDForBrowserPlayback() throws {
        let line = #"{"type":"data","diff":false,"payload":{"title":"Clip","bundleIdentifier":"com.apple.WebKit.GPU","parentApplicationBundleIdentifier":"com.apple.Safari","playing":true}}"#
        let message = try #require(AdapterPayload.parse(line: Data(line.utf8)))

        let info = try #require(AdapterPayload.info(from: AdapterPayload.merge([:], with: message), now: now))

        #expect(info.appBundleID == "com.apple.Safari")
        #expect(info.elapsed == 0)
        #expect(info.timestamp == now)
    }

    @Test func rejectsMalformedOrForeignLines() {
        #expect(AdapterPayload.parse(line: Data("not json".utf8)) == nil)
        #expect(AdapterPayload.parse(line: Data(#"{"type":"log","payload":{}}"#.utf8)) == nil)
    }

    @Test func infoRequiresTitle() {
        let fields: [String: Any] = ["bundleIdentifier": "com.spotify.client", "playing": true, "title": ""]

        #expect(AdapterPayload.info(from: fields, now: now) == nil)
    }
}

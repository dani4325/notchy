import Foundation
import Testing
@testable import NotchCore

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

enum ZipMutation: CaseIterable {
    case flipBytes, truncate, insertGarbage, overwriteField, pathCharacters, randomBytes, duplicateTail

    func apply(to seed: [UInt8], using rng: inout SeededGenerator) -> [UInt8] {
        var bytes = seed
        switch self {
        case .flipBytes:
            for _ in 0..<Int.random(in: 1...12, using: &rng) {
                let index = Int.random(in: 0..<bytes.count, using: &rng)
                bytes[index] ^= UInt8.random(in: 1...255, using: &rng)
            }
        case .truncate:
            bytes = Array(bytes.prefix(Int.random(in: 0..<bytes.count, using: &rng)))
        case .insertGarbage:
            let index = Int.random(in: 0...bytes.count, using: &rng)
            let garbage = (0..<Int.random(in: 1...64, using: &rng)).map { _ in UInt8.random(in: 0...255, using: &rng) }
            bytes.insert(contentsOf: garbage, at: index)
        case .overwriteField:
            let extremes: [UInt32] = [0, 1, 0xFFFF, 0xFFFF_FFFF, 0x7FFF_FFFF, UInt32(bytes.count), UInt32.random(in: 0...UInt32.max, using: &rng)]
            for _ in 0..<Int.random(in: 1...4, using: &rng) {
                let index = Int.random(in: 0..<(bytes.count - 4), using: &rng)
                let value = extremes.randomElement(using: &rng)!
                withUnsafeBytes(of: value.littleEndian) { bytes.replaceSubrange(index..<index + 4, with: $0) }
            }
        case .pathCharacters:
            let alphabet = Array("./\\\u{0}..//".utf8)
            for _ in 0..<Int.random(in: 1...10, using: &rng) {
                let index = Int.random(in: 0..<bytes.count, using: &rng)
                bytes[index] = alphabet.randomElement(using: &rng)!
            }
        case .randomBytes:
            bytes = (0..<Int.random(in: 0...2048, using: &rng)).map { _ in UInt8.random(in: 0...255, using: &rng) }
        case .duplicateTail:
            let start = Int.random(in: 0..<bytes.count, using: &rng)
            bytes.append(contentsOf: bytes[start...])
        }
        return bytes
    }
}

struct ZipFuzzTests {
    static let cases = 600
    static let perCaseTimeout: DispatchTimeInterval = .seconds(5)
    static let limit = 4 * 1024 * 1024

    func seedArchive(in parent: URL) throws -> [UInt8] {
        let source = parent.appendingPathComponent("seed-source")
        try FileManager.default.createDirectory(at: source.appendingPathComponent("media"), withIntermediateDirectories: true)
        try JSONEncoder().encode(Theme.notchyDefault).write(to: source.appendingPathComponent("theme.json"))
        try Data((0..<20_000).map { UInt8($0 % 251) }).write(to: source.appendingPathComponent("media/big.bin"))
        let archive = parent.appendingPathComponent("seed.notchytheme")
        try ThemeArchive.compress(folder: source, to: archive)
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: archive)
        }
        return [UInt8](try Data(contentsOf: archive))
    }

    func finishes(within timeout: DispatchTimeInterval, _ work: @escaping @Sendable () -> Void) -> Bool {
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            work()
            done.signal()
        }
        return done.wait(timeout: .now() + timeout) == .success
    }

    func allPaths(under folder: URL) -> [String] {
        FileManager.default.enumerator(atPath: folder.path)?.compactMap { $0 as? String } ?? []
    }

    @Test func malformedArchivesNeverHangEscapeOrLeaveFilesBehind() throws {
        let sandbox = FileManager.default.temporaryDirectory.appendingPathComponent("zipfuzz-\(UUID().uuidString)")
        let workspace = sandbox.appendingPathComponent("workspace")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let storedSeed = ZipBuilder(entries: [
            .init("theme.json", try JSONEncoder().encode(Theme.notchyDefault)),
            .init("media/"),
            .init("media/raw.bin", Data((0..<4_000).map { UInt8($0 % 241) })),
        ]).data()
        let seeds = [try seedArchive(in: sandbox), [UInt8](storedSeed)]
        var rng = SeededGenerator(seed: 0x6E6F_7463_6879)
        var failures: [String] = []

        for index in 0..<Self.cases {
            let mutation = ZipMutation.allCases.randomElement(using: &rng)!
            let archive = sandbox.appendingPathComponent("case-\(index).notchytheme")
            try Data(mutation.apply(to: seeds[index % seeds.count], using: &rng)).write(to: archive)
            let label = "caso \(index) (\(mutation))"

            let direct = workspace.appendingPathComponent("direct")
            try FileManager.default.createDirectory(at: direct, withIntermediateDirectories: true)
            let directFinished = finishes(within: Self.perCaseTimeout) {
                var extractor = try? ZipExtractor(archive: archive, maximumBytes: Self.limit, maximumEntries: ThemeArchive.maximumEntries)
                try? extractor?.extract(into: direct)
            }
            if !directFinished { failures.append("\(label): el extractor no termina") }
            try FileManager.default.removeItem(at: direct)

            let result = LockedResult()
            let importFinished = finishes(within: Self.perCaseTimeout) {
                result.value = try? ThemeArchive.extract(archive, maximumBytes: Self.limit, workingDirectory: workspace).folder
            }
            if !importFinished { failures.append("\(label): la importación no termina") }

            let leftovers = try FileManager.default.contentsOfDirectory(atPath: workspace.path)
            if let folder = result.value {
                if leftovers != [folder.lastPathComponent] { failures.append("\(label): restos junto a la importación \(leftovers)") }
                try FileManager.default.removeItem(at: folder)
            } else if !leftovers.isEmpty {
                failures.append("\(label): no limpia al fallar \(leftovers)")
            }

            try FileManager.default.removeItem(at: archive)
            let outside = try FileManager.default.contentsOfDirectory(atPath: sandbox.path).filter { $0 != "workspace" }
            if !outside.isEmpty { failures.append("\(label): escribió fuera de la carpeta temporal \(outside)") }
        }

        #expect(failures.isEmpty, "\(failures.prefix(10).joined(separator: "\n"))")
        #expect(allPaths(under: workspace).isEmpty)
    }
}

final class LockedResult: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: URL?

    var value: URL? {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

struct ZipBuilder {
    struct Entry {
        var name: [UInt8]
        var payload: Data
        var declaredSize: UInt32?
        var unixMode: UInt32 = 0o100644

        init(_ name: String, _ payload: Data = Data(), declaredSize: UInt32? = nil) {
            self.name = Array(name.utf8)
            self.payload = payload
            self.declaredSize = declaredSize
        }
    }

    var entries: [Entry]

    func data() -> Data {
        var local = Data()
        var central = Data()
        for entry in entries {
            let offset = UInt32(local.count)
            let size = UInt32(entry.payload.count)
            local.append(le32(0x0403_4B50)); local.append(le16(20)); local.append(le16(0)); local.append(le16(0))
            local.append(le32(0)); local.append(le32(0)); local.append(le32(size)); local.append(le32(entry.declaredSize ?? size))
            local.append(le16(UInt16(entry.name.count))); local.append(le16(0))
            local.append(contentsOf: entry.name); local.append(entry.payload)

            central.append(le32(0x0201_4B50)); central.append(le16(0x031E)); central.append(le16(20)); central.append(le16(0))
            central.append(le16(0)); central.append(le32(0)); central.append(le32(0)); central.append(le32(size))
            central.append(le32(entry.declaredSize ?? size)); central.append(le16(UInt16(entry.name.count)))
            central.append(le16(0)); central.append(le16(0)); central.append(le16(0)); central.append(le16(0))
            central.append(le32(entry.unixMode << 16)); central.append(le32(offset)); central.append(contentsOf: entry.name)
        }
        var end = Data()
        end.append(le32(0x0605_4B50)); end.append(le16(0)); end.append(le16(0))
        end.append(le16(UInt16(entries.count))); end.append(le16(UInt16(entries.count)))
        end.append(le32(UInt32(central.count))); end.append(le32(UInt32(local.count))); end.append(le16(0))
        return local + central + end
    }

    func write(in folder: URL) throws -> URL {
        let url = folder.appendingPathComponent("\(UUID().uuidString).notchytheme")
        try data().write(to: url)
        return url
    }

    private func le16(_ value: UInt16) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
    private func le32(_ value: UInt32) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
}

struct ZipAdversarialTests {
    let themeJSON = try! JSONEncoder().encode(Theme.notchyDefault)

    func workspace() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("zipadv-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func expectRejected(_ error: ThemeArchive.ArchiveError, _ entries: [ZipBuilder.Entry], maximumBytes: Int = ThemeArchive.maximumBytes) throws {
        let folder = try workspace()
        defer { try? FileManager.default.removeItem(at: folder) }
        let work = folder.appendingPathComponent("work")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let archive = try ZipBuilder(entries: entries).write(in: folder)

        #expect(throws: error) {
            _ = try ThemeArchive.extract(archive, maximumBytes: maximumBytes, workingDirectory: work)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: work.path).isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted() == [archive.lastPathComponent, "work"].sorted())
    }

    @Test func handBuiltThemeArchiveIsAccepted() throws {
        let folder = try workspace()
        defer { try? FileManager.default.removeItem(at: folder) }
        let archive = try ZipBuilder(entries: [.init("theme.json", themeJSON)]).write(in: folder)

        let (theme, extracted) = try ThemeArchive.extract(archive, workingDirectory: folder)

        #expect(theme.name == Theme.notchyDefault.name)
        #expect(extracted.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL)
    }

    @Test func archiveLargerThanTheLimitOnDiskIsRejectedWithoutReadingIt() throws {
        let folder = try workspace()
        defer { try? FileManager.default.removeItem(at: folder) }
        let archive = folder.appendingPathComponent("enorme.notchytheme")
        try Data(count: 2 * 1024 * 1024).write(to: archive)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: archive.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: archive.path) }

        #expect(throws: ThemeArchive.ArchiveError.tooLarge) {
            _ = try ThemeArchive.extract(archive, maximumBytes: 1024 * 1024, workingDirectory: folder)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == ["enorme.notchytheme"])
    }

    @Test func declaredSizesNearTheIntegerLimitAreRejectedWithoutCrashing() throws {
        let entries = (0..<4).map { ZipBuilder.Entry("media/\($0).bin", Data("x".utf8), declaredSize: UInt32.max) }
        try expectRejected(.tooLarge, [.init("theme.json", themeJSON)] + entries)
    }

    @Test func storedEntryLargerThanTheBudgetIsRejectedBeforeCopying() throws {
        let big = ZipBuilder.Entry("media/big.bin", Data(count: 2 * 1024 * 1024), declaredSize: 10)
        try expectRejected(.tooLarge, [.init("theme.json", themeJSON), big], maximumBytes: 1024 * 1024 + 4096)
    }

    @Test func tooManyEntriesAreRejected() throws {
        let entries = (0...ThemeArchive.maximumEntries).map { ZipBuilder.Entry("media/\($0).txt", Data("x".utf8)) }
        try expectRejected(.tooLarge, entries)
    }

    @Test func dangerousNamesAreRejectedBeforeWritingAnything() throws {
        let names = ["../fuera.txt", "media/../../fuera.txt", "/tmp/fuera.txt", "media\\fuera.txt",
                     "media/a\u{0}b", "media/a\u{7}b", "../\u{301}fuera.txt", "./theme.json", "media/./x", "media//x"]
        for name in names {
            try expectRejected(.unsafeContent, [.init("theme.json", themeJSON), .init(name, Data("x".utf8))])
        }
    }

    @Test func symlinkEntriesAreRejected() throws {
        var link = ZipBuilder.Entry("media/enlace", Data("/etc/hosts".utf8))
        link.unixMode = 0o120755
        try expectRejected(.unsafeContent, [.init("theme.json", themeJSON), link])
    }
}

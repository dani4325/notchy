import Compression
import Foundation

struct ZipExtractor {
    struct Entry {
        let name: String
        let method: UInt16
        let flags: UInt16
        let compressedSize: Int
        let declaredSize: Int
        let localHeaderOffset: Int
        let unixMode: UInt32

        var isDirectory: Bool { name.hasSuffix("/") }
        var isSymlink: Bool { unixMode & 0o170000 == 0o120000 }
        var isEncrypted: Bool { flags & 1 != 0 }
    }

    private static let endRecordSignature: UInt32 = 0x0605_4B50
    private static let centralHeaderSignature: UInt32 = 0x0201_4B50
    private static let localHeaderSignature: UInt32 = 0x0403_4B50
    private static let stored: UInt16 = 0
    private static let deflated: UInt16 = 8
    private static let chunkSize = 8 * 1024
    private static let maximumCommentLength = 0xFFFF

    let data: Data
    let maximumBytes: Int
    let maximumEntries: Int
    private(set) var writtenBytes = 0

    init(archive: URL, maximumBytes: Int, maximumEntries: Int) throws {
        let size = try archive.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size <= maximumBytes else { throw ThemeArchive.ArchiveError.tooLarge }
        data = try Data(contentsOf: archive)
        guard data.count <= maximumBytes else { throw ThemeArchive.ArchiveError.tooLarge }
        self.maximumBytes = maximumBytes
        self.maximumEntries = maximumEntries
    }

    mutating func extract(into folder: URL) throws {
        for entry in try entries() {
            try write(entry, into: folder)
        }
    }

    func entries() throws -> [Entry] {
        let end = try endRecordOffset()
        let count = Int(try u16(end + 10))
        let directoryOffset = Int(try u32(end + 16))
        guard count <= maximumEntries else { throw ThemeArchive.ArchiveError.tooLarge }

        var result: [Entry] = []
        var declaredTotal = 0
        var cursor = directoryOffset
        for _ in 0..<count {
            guard try u32(cursor) == Self.centralHeaderSignature else { throw ThemeArchive.ArchiveError.unsafeContent }
            let nameLength = Int(try u16(cursor + 28))
            let extraLength = Int(try u16(cursor + 30))
            let commentLength = Int(try u16(cursor + 32))
            let entry = Entry(
                name: String(decoding: try bytes(cursor + 46, nameLength), as: UTF8.self),
                method: try u16(cursor + 10),
                flags: try u16(cursor + 8),
                compressedSize: Int(try u32(cursor + 20)),
                declaredSize: Int(try u32(cursor + 24)),
                localHeaderOffset: Int(try u32(cursor + 42)),
                unixMode: try u32(cursor + 38) >> 16
            )
            guard ThemeArchive.isSafeEntry(entry.name), !entry.isSymlink, !entry.isEncrypted else {
                throw ThemeArchive.ArchiveError.unsafeContent
            }
            declaredTotal += entry.declaredSize
            guard declaredTotal <= maximumBytes else { throw ThemeArchive.ArchiveError.tooLarge }
            result.append(entry)
            cursor += 46 + nameLength + extraLength + commentLength
        }
        return result
    }

    private mutating func write(_ entry: Entry, into folder: URL) throws {
        let destination = folder.appendingPathComponent(entry.name)
        guard destination.standardizedFileURL.path.hasPrefix(folder.standardizedFileURL.path + "/") else {
            throw ThemeArchive.ArchiveError.unsafeContent
        }
        if entry.isDirectory {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            return
        }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            throw ThemeArchive.ArchiveError.toolFailed
        }
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }

        switch entry.method {
        case Self.stored:
            guard entry.compressedSize <= maximumBytes - writtenBytes else { throw ThemeArchive.ArchiveError.tooLarge }
            try copy(try compressedPayload(of: entry), to: handle)
        case Self.deflated:
            try inflate(try compressedPayload(of: entry), to: handle)
        default:
            throw ThemeArchive.ArchiveError.unsafeContent
        }
    }

    private mutating func copy(_ payload: Data, to handle: FileHandle) throws {
        var offset = payload.startIndex
        while offset < payload.endIndex {
            let next = min(offset + Self.chunkSize, payload.endIndex)
            try append(payload[offset..<next], to: handle)
            offset = next
        }
    }

    private mutating func inflate(_ payload: Data, to handle: FileHandle) throws {
        var output: [Data] = []
        let filter = try OutputFilter(.decompress, using: .zlib) { chunk in
            if let chunk { output.append(chunk) }
        }
        var offset = payload.startIndex
        while offset < payload.endIndex {
            let next = min(offset + Self.chunkSize, payload.endIndex)
            try filter.write(payload[offset..<next])
            offset = next
            try output.forEach { try append($0, to: handle) }
            output.removeAll()
        }
        try filter.finalize()
        try output.forEach { try append($0, to: handle) }
    }

    private mutating func append(_ chunk: Data, to handle: FileHandle) throws {
        writtenBytes += chunk.count
        guard writtenBytes <= maximumBytes else { throw ThemeArchive.ArchiveError.tooLarge }
        try handle.write(contentsOf: chunk)
    }

    private func compressedPayload(of entry: Entry) throws -> Data {
        let header = entry.localHeaderOffset
        guard try u32(header) == Self.localHeaderSignature else { throw ThemeArchive.ArchiveError.unsafeContent }
        let start = header + 30 + Int(try u16(header + 26)) + Int(try u16(header + 28))
        return try bytes(start, entry.compressedSize)
    }

    private func endRecordOffset() throws -> Int {
        let lowest = max(0, data.count - 22 - Self.maximumCommentLength)
        var offset = data.count - 22
        while offset >= lowest {
            if try u32(offset) == Self.endRecordSignature { return offset }
            offset -= 1
        }
        throw ThemeArchive.ArchiveError.unsafeContent
    }

    private func bytes(_ offset: Int, _ count: Int) throws -> Data {
        guard offset >= 0, count >= 0, offset + count <= data.count else { throw ThemeArchive.ArchiveError.unsafeContent }
        return data[data.startIndex + offset..<data.startIndex + offset + count]
    }

    private func u16(_ offset: Int) throws -> UInt16 {
        try bytes(offset, 2).withUnsafeBytes { UInt16(littleEndian: $0.loadUnaligned(as: UInt16.self)) }
    }

    private func u32(_ offset: Int) throws -> UInt32 {
        try bytes(offset, 4).withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
    }
}

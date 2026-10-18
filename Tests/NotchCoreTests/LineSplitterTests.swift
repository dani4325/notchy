import Foundation
import Testing
@testable import NotchCore

struct LineSplitterTests {
    @Test func joinsLineSplitAcrossManyChunks() {
        let splitter = LineSplitter()
        let longLine = String(repeating: "a", count: 200_000)

        let first = splitter.feed(Data(longLine.prefix(70_000).utf8))
        let second = splitter.feed(Data(longLine.dropFirst(70_000).prefix(70_000).utf8))
        let third = splitter.feed(Data((longLine.dropFirst(140_000) + "\n").utf8))

        #expect(first.isEmpty)
        #expect(second.isEmpty)
        #expect(third == [Data(longLine.utf8)])
    }

    @Test func returnsSeveralLinesFromOneChunkInOrder() {
        let splitter = LineSplitter()

        let lines = splitter.feed(Data("one\ntwo\nthr".utf8))
        let rest = splitter.feed(Data("ee\n".utf8))

        #expect(lines == [Data("one".utf8), Data("two".utf8)])
        #expect(rest == [Data("three".utf8)])
    }

    @Test func skipsEmptyLines() {
        #expect(LineSplitter().feed(Data("\n\nx\n".utf8)) == [Data("x".utf8)])
    }
}

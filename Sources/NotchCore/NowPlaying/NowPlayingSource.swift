@MainActor
protocol NowPlayingSource: AnyObject {
    var onUpdate: ((NowPlayingInfo?) -> Void)? { get set }
    var onFailure: (() -> Void)? { get set }

    func start()
    func stop()
    func send(_ command: MediaCommand)
}

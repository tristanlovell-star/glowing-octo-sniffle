import Foundation
import MediaPlayer
import UIKit

/// What was playing when a set was logged.
struct TrackInfo: Codable, Hashable {
    var title: String
    var artist: String
    var genre: String?
    var bpm: Int?
}

/// Controls the Apple Music app from inside a workout and reports what's playing.
@MainActor
final class MusicController: ObservableObject {
    static let shared = MusicController()

    @Published var authorized = MPMediaLibrary.authorizationStatus() == .authorized
    @Published var track: TrackInfo?
    @Published var artwork: UIImage?
    @Published var isPlaying = false

    private var player: MPMusicPlayerController?
    private var observers: [NSObjectProtocol] = []

    /// The track to record against a set: only while music is actually playing.
    var playingTrack: TrackInfo? { isPlaying ? track : nil }

    /// Asks for Apple Music access (first time only) and starts following playback.
    func connect() async {
        let status = await MPMediaLibrary.requestAuthorization()
        authorized = status == .authorized
        attach()
    }

    /// Starts following the Music app if access was already granted.
    func attach() {
        guard authorized, player == nil else { return }
        #if targetEnvironment(simulator)
        return
        #else
        let player = MPMusicPlayerController.systemMusicPlayer
        self.player = player
        player.beginGeneratingPlaybackNotifications()
        let names: [Notification.Name] = [.MPMusicPlayerControllerNowPlayingItemDidChange,
                                          .MPMusicPlayerControllerPlaybackStateDidChange]
        for name in names {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: player, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
        refresh()
        #endif
    }

    func refresh() {
        guard let player else { return }
        isPlaying = player.playbackState == .playing
        guard let item = player.nowPlayingItem, let title = item.title else {
            track = nil
            artwork = nil
            return
        }
        let bpm = item.beatsPerMinute
        let genre = item.genre.flatMap { $0.isEmpty ? nil : $0 }
        let next = TrackInfo(title: title, artist: item.artist ?? "Unknown artist", genre: genre, bpm: bpm > 0 ? bpm : nil)
        if next != track {
            track = next
            artwork = item.artwork?.image(at: CGSize(width: 120, height: 120))
        }
    }

    func togglePlay() {
        guard let player else { return }
        if player.playbackState == .playing { player.pause() } else { player.play() }
    }

    func next() { player?.skipToNextItem() }
    func previous() { player?.skipToPreviousItem() }

    /// Sample state for screenshots.
    func showDemo() {
        authorized = true
        isPlaying = true
        track = TrackInfo(title: "Lose Yourself to Dance", artist: "Daft Punk", genre: "Electronic", bpm: 100)
    }
}

/// Works out which music goes with your best lifting.
enum MusicStats {
    struct Row: Identifiable, Hashable {
        var name: String
        var sets: Int
        /// Average performance on sets logged to this music, relative to your overall average (0.03 = 3% better).
        var edge: Double
        /// Share of those sets you rated Hard or Max.
        var pushed: Double
        var id: String { name }
    }

    struct Summary {
        var trackedSets = 0
        var artists: [Row] = []
        var genres: [Row] = []
        /// Performance with music relative to without, when there's enough of both.
        var musicEdge: Double?

        var hasEnough: Bool { trackedSets >= 20 }
    }

    private struct Sample {
        var index: Double
        var effort: Effort
        var track: TrackInfo?
    }

    /// Each set is scored against your previous best on the same exercise, so heavy and light
    /// exercises can be compared, then averaged per artist and genre.
    static func summarise(sessions: [WorkoutSession], library: ExerciseLibrary = .shared, minimumSets: Int = 6) -> Summary {
        let ordered = sessions.filter { $0.endedAt != nil }.sorted { $0.startedAt < $1.startedAt }
        var best: [String: Double] = [:]
        var samples: [Sample] = []
        for session in ordered {
            var sessionBest: [String: Double] = [:]
            for item in session.exercises {
                guard let exercise = library[item.exerciseID] else { continue }
                for set in item.sets {
                    let value = exercise.loadType == .weighted ? Coach.estimatedMax(set) : Double(set.reps)
                    guard value > 0 else { continue }
                    if let previous = best[exercise.id], previous > 0 {
                        samples.append(Sample(index: value / previous, effort: set.effort, track: set.track))
                    }
                    sessionBest[exercise.id] = max(sessionBest[exercise.id] ?? 0, value)
                }
            }
            for (id, value) in sessionBest { best[id] = max(best[id] ?? 0, value) }
        }

        var summary = Summary()
        let withMusic = samples.filter { $0.track != nil }
        summary.trackedSets = withMusic.count
        guard !samples.isEmpty, !withMusic.isEmpty else { return summary }
        let overall = samples.map(\.index).reduce(0, +) / Double(samples.count)

        func rows(_ key: (TrackInfo) -> String?) -> [Row] {
            var groups: [String: [Sample]] = [:]
            for sample in withMusic {
                guard let track = sample.track, let name = key(track) else { continue }
                groups[name, default: []].append(sample)
            }
            return groups.compactMap { name, group -> Row? in
                guard group.count >= minimumSets else { return nil }
                let mean = group.map(\.index).reduce(0, +) / Double(group.count)
                let pushed = Double(group.filter { $0.effort.rawValue >= Effort.hard.rawValue }.count) / Double(group.count)
                return Row(name: name, sets: group.count, edge: mean / overall - 1, pushed: pushed)
            }
            .sorted { ($0.edge, $0.name) > ($1.edge, $1.name) }
        }
        summary.artists = rows { $0.artist }
        summary.genres = rows { $0.genre }

        let without = samples.filter { $0.track == nil }
        if withMusic.count >= 10, without.count >= 10 {
            let a = withMusic.map(\.index).reduce(0, +) / Double(withMusic.count)
            let b = without.map(\.index).reduce(0, +) / Double(without.count)
            summary.musicEdge = a / b - 1
        }
        return summary
    }

    /// A few lines for the AI coach.
    static func coachLines(_ summary: Summary) -> [String] {
        guard summary.hasEnough else { return [] }
        var lines: [String] = ["\(summary.trackedSets) sets logged with music playing."]
        if let edge = summary.musicEdge {
            lines.append(String(format: "Sets with music vs without: %+.1f%% performance.", edge * 100))
        }
        for row in summary.artists.prefix(5) {
            lines.append(String(format: "Artist %@: %d sets, %+.1f%% vs average, %.0f%% rated hard/max", row.name, row.sets, row.edge * 100, row.pushed * 100))
        }
        for row in summary.genres.prefix(4) {
            lines.append(String(format: "Genre %@: %d sets, %+.1f%% vs average", row.name, row.sets, row.edge * 100))
        }
        return lines
    }
}

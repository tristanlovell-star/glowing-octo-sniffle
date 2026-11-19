import SwiftUI

final class RaceSession: ObservableObject {
    @Published var controller: RaceController?
    @Published var paused = false {
        didSet { controller?.paused = paused }
    }
    private var started = false

    func load(track: TrackInfo, settings: RaceSettings, car: CarConfig, name: String, onFinish: @escaping ([RaceResult]) -> Void) {
        guard !started else { return }
        started = true
        DispatchQueue.global(qos: .userInitiated).async {
            let c = RaceController(trackInfo: track, settings: settings, playerCar: car, playerName: name)
            DispatchQueue.main.async {
                c.onFinish = onFinish
                self.controller = c
            }
        }
    }

    func stop() {
        controller?.stop()
    }
}

struct RaceView: View {
    let track: TrackInfo
    @EnvironmentObject var model: AppModel
    @StateObject private var session = RaceSession()

    var body: some View {
        ZStack {
            if let c = session.controller {
                SceneHost(scene: c.scene, pointOfView: c.cameraNode, delegate: c, overlay: c.hud)
                    .ignoresSafeArea()
            } else {
                loading
            }
            if session.paused {
                pauseMenu
            }
        }
        .focusable(!session.paused)
        .focusEffectDisabled()
        .onExitCommand { session.paused.toggle() }
        .onAppear {
            session.load(track: track, settings: model.settings, car: model.car, name: model.driverName) { results in
                model.screen = .results(results, track)
            }
        }
        .onDisappear { session.stop() }
    }

    private var loading: some View {
        VStack(spacing: 30) {
            TrackMap(info: track, lineWidth: 8)
                .frame(width: 520, height: 520)
            Text("\(track.flag)  \(track.name)")
                .font(.system(size: 60, weight: .black).italic())
            Text(track.fullName).font(.system(size: 28)).foregroundStyle(.secondary)
            ProgressView().scaleEffect(1.5)
        }
    }

    private var pauseMenu: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 30) {
                Text("Paused").font(.system(size: 72, weight: .black).italic())
                Button("Resume") { session.paused = false }
                Button("Restart") { model.startRace(track) }
                Button("Change Circuit") { model.screen = .tracks }
                Button("Main Menu") { model.screen = .menu }
            }
            .font(.system(size: 34, weight: .bold))
            .frame(width: 600)
        }
    }
}

struct ResultsView: View {
    let results: [RaceResult]
    let track: TrackInfo
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 60) {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(track.flag) \(track.name)")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(headline)
                    .font(.system(size: 80, weight: .black).italic())
                    .foregroundStyle(playerPosition == 1 ? Color.apexGold : .white)
                TrackMap(info: track, lineWidth: 6)
                    .frame(width: 380, height: 380)
                    .padding(.vertical, 20)
                Button("Race Again") { model.startRace(track) }
                Button("Choose Circuit") { model.screen = .tracks }
                Button("Garage") { model.screen = .garage }
            }
            .font(.system(size: 30, weight: .bold))
            .frame(width: 560, alignment: .leading)

            VStack(spacing: 10) {
                ForEach(results) { r in
                    HStack(spacing: 20) {
                        Text("\(r.position)")
                            .font(.system(size: 34, weight: .black).italic())
                            .frame(width: 60)
                            .foregroundStyle(r.position <= 3 ? Color.apexGold : .white)
                        RoundedRectangle(cornerRadius: 4).fill(Color(uiColor: r.color)).frame(width: 12, height: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.name).font(.system(size: 28, weight: .bold))
                            Text(r.car).font(.system(size: 20)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(r.time.map { RaceHUD.format($0) } ?? "Racing")
                                .font(.system(size: 26, weight: .semibold)).monospacedDigit()
                            Text(r.bestLap.map { "Best \(RaceHUD.format($0))" } ?? "")
                                .font(.system(size: 19)).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(r.isPlayer ? Color.apexRed.opacity(0.55) : Color.white.opacity(0.07)))
                }
            }
            .frame(width: 900)
        }
        .padding(80)
        .onExitCommand { model.screen = .menu }
    }

    private var playerPosition: Int { results.first { $0.isPlayer }?.position ?? 0 }

    private var headline: String {
        switch playerPosition {
        case 1: return "You win!"
        case 2: return "2nd place"
        case 3: return "3rd place"
        default: return "\(playerPosition)th place"
        }
    }
}

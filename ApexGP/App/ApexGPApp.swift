import SwiftUI

@main
struct ApexGPApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}

enum Screen: Equatable {
    case menu
    case garage
    case tracks
    case race(TrackInfo, UUID)
    case results([RaceResult], TrackInfo)

    static func == (a: Screen, b: Screen) -> Bool {
        switch (a, b) {
        case (.menu, .menu), (.garage, .garage), (.tracks, .tracks): return true
        case let (.race(t1, u1), .race(t2, u2)): return t1 == t2 && u1 == u2
        case let (.results(_, t1), .results(_, t2)): return t1 == t2
        default: return false
        }
    }
}

final class AppModel: ObservableObject {
    @Published var screen: Screen = .menu
    @Published var car: CarConfig { didSet { car.save() } }
    @Published var settings: RaceSettings { didSet { settings.save() } }
    @Published var driverName: String { didSet { UserDefaults.standard.set(driverName, forKey: "ApexGP.driverName") } }

    init() {
        car = CarConfig.load()
        settings = RaceSettings.load()
        driverName = UserDefaults.standard.string(forKey: "ApexGP.driverName") ?? "Austin"
    }

    func startRace(_ track: TrackInfo) {
        screen = .race(track, UUID())
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch model.screen {
            case .menu:
                MenuView()
            case .garage:
                GarageView()
            case .tracks:
                TrackSelectView()
            case let .race(track, id):
                RaceView(track: track).id(id)
            case let .results(results, track):
                ResultsView(results: results, track: track)
            }
        }
    }
}

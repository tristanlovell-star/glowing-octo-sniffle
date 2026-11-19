import SwiftUI

struct TrackSelectView: View {
    @EnvironmentObject var model: AppModel
    private let columns = Array(repeating: GridItem(.fixed(390), spacing: 40), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Choose a circuit")
                        .font(.system(size: 56, weight: .black).italic())
                    Spacer()
                    Text("\(model.car.model.displayName) · \(model.car.trim.name)")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)

                HStack(alignment: .top, spacing: 30) {
                    ChipRow(title: "Laps", items: [1, 2, 3, 5, 10], id: \.self, isSelected: { $0 == model.settings.laps },
                            label: { ("\($0)", nil, nil) }, choose: { model.settings.laps = $0 })
                        .frame(width: 520)
                    ChipRow(title: "Rivals", items: [0, 3, 5, 7, 9], id: \.self, isSelected: { $0 == model.settings.opponents },
                            label: { ("\($0)", nil, nil) }, choose: { model.settings.opponents = $0 })
                        .frame(width: 520)
                }
                HStack(alignment: .top, spacing: 30) {
                    ChipRow(title: "Difficulty", items: Difficulty.allCases, id: \.self, isSelected: { $0 == model.settings.difficulty },
                            label: { ($0.rawValue, nil, nil) }, choose: { model.settings.difficulty = $0 })
                        .frame(width: 720)
                    ChipRow(title: "Driving help", items: [true, false], id: \.self, isSelected: { $0 == model.settings.drivingHelp },
                            label: { ($0 ? "On" : "Off", $0 ? "Steers & brakes for corners" : "All up to you", nil) },
                            choose: { model.settings.drivingHelp = $0 })
                        .frame(width: 820)
                }

                LazyVGrid(columns: columns, spacing: 50) {
                    ForEach(TrackLibrary.all) { t in
                        TrackCard(info: t) { model.startRace(t) }
                    }
                }
                .padding(.top, 10)
                .focusSection()
            }
            .padding(.horizontal, 70)
            .padding(.vertical, 50)
        }
        .onExitCommand { model.screen = .menu }
    }
}

struct TrackCard: View {
    let info: TrackInfo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                TrackMap(info: info, lineWidth: 5)
                    .frame(height: 180)
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Text(info.flag).font(.system(size: 30))
                        Text(info.name).font(.system(size: 28, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    Text("\(info.country) · \(info.lengthText)")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(BestLaps.get(info.id).map { "Best lap \(RaceHUD.format($0))" } ?? " ")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.apexGold)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
            .frame(width: 390, height: 340, alignment: .topLeading)
        }
        .buttonStyle(.card)
    }
}

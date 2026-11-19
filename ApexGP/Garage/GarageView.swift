import SwiftUI

struct GarageView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var preview = GaragePreview()

    private var car: CarConfig { model.car }

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                SceneHost(scene: preview.scene, pointOfView: preview.camera)
                    .ignoresSafeArea()
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(car.model.make.uppercased())
                            .font(.system(size: 26, weight: .bold)).foregroundStyle(.secondary)
                        Text("\(car.model.model) \(car.trim.name == car.model.model ? "" : car.trim.name)")
                            .font(.system(size: 52, weight: .black).italic())
                        Text(car.paint.name).font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Color(car.paint.color))
                    }
                    stats
                }
                .padding(36)
                .frame(width: 640, alignment: .leading)
                .background(LinearGradient(colors: [.black.opacity(0.85), .black.opacity(0.0)], startPoint: .bottom, endPoint: .top))
                .padding(.leading, 40)
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Garage")
                        .font(.system(size: 56, weight: .black).italic())
                        .padding(.leading, 8)
                    options
                    Button("Done") { model.screen = .menu }
                        .font(.system(size: 30, weight: .bold))
                        .padding(.top, 20)
                }
                .padding(.vertical, 50)
                .padding(.horizontal, 30)
            }
            .frame(width: 820)
            .background(Color(white: 0.07))
        }
        .ignoresSafeArea()
        .onAppear { preview.show(car) }
        .onChange(of: model.car) { _, new in preview.show(new) }
        .onExitCommand { model.screen = .menu }
    }

    private var stats: some View {
        let perf = car.performance
        let trim = car.trim
        return VStack(spacing: 14) {
            StatBar(label: "Power", value: "\(Int(trim.powerKW)) kW", fraction: trim.powerKW / 700)
            StatBar(label: "Weight", value: "\(Int(trim.massKg)) kg", fraction: 1 - (trim.massKg - 900) / 1800)
            StatBar(label: "0–100 km/h", value: String(format: "%.1f s", perf.zeroToHundred), fraction: (9 - perf.zeroToHundred) / 7)
            StatBar(label: "Top speed", value: "\(Int(perf.topSpeed * 3.6)) km/h", fraction: (perf.topSpeed * 3.6 - 150) / 200)
            StatBar(label: "Grip", value: String(format: "%.2f g", perf.grip), fraction: (perf.grip - 0.8) / 0.45)
            HStack {
                Text(trim.drive.rawValue).font(.system(size: 22, weight: .bold))
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
                Text("Specs are approximate").font(.system(size: 18)).foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    @ViewBuilder private var options: some View {
        ChipRow(title: "Car", items: CarCatalog.all, id: \.id, isSelected: { $0.id == car.modelID },
                label: { ($0.model, $0.make, nil) },
                choose: { m in if m.id != car.modelID { model.car.switchModel(to: m) } })

        ChipRow(title: "Trim", items: car.model.trims, id: \.name, isSelected: { $0.name == car.trimName },
                label: { ($0.name, "\(Int($0.powerKW)) kW · \($0.drive.rawValue)", nil) },
                choose: { model.car.trimName = $0.name })

        ChipRow(title: "Paint", items: car.model.paints + specialPaints, id: \.name, isSelected: { $0 == car.paint },
                label: { ($0.name, $0.finish.rawValue.capitalized, Color($0.color)) },
                choose: { model.car.paint = $0 })

        ChipRow(title: "Wheels", items: WheelStyle.allCases, id: \.self, isSelected: { $0 == car.wheelStyle },
                label: { ($0.rawValue, nil, nil) },
                choose: { model.car.wheelStyle = $0 })

        ChipRow(title: "Wheel size", items: CarConfig.wheelSizes, id: \.self, isSelected: { $0 == car.wheelInches },
                label: { ("\($0)-inch", nil, nil) },
                choose: { model.car.wheelInches = $0 })

        ChipRow(title: "Wheel colour", items: WheelFinish.allCases, id: \.self, isSelected: { $0 == car.wheelFinish },
                label: { ($0.rawValue, nil, GarageView.wheelSwatch($0, paint: car.paint)) },
                choose: { model.car.wheelFinish = $0 })

        ChipRow(title: "Brake calipers", items: CaliperColor.allCases, id: \.self, isSelected: { $0 == car.caliper },
                label: { ($0.rawValue, nil, Color($0.rgb)) },
                choose: { model.car.caliper = $0 })

        ChipRow(title: "Rear wing", items: WingStyle.allCases, id: \.self, isSelected: { $0 == car.wing },
                label: { w in (w.rawValue, w == .factory ? (car.trim.factoryWing ? "Wing" : "No wing") : nil, nil) },
                choose: { model.car.wing = $0 })

        ChipRow(title: "Stripes", items: StripeStyle.allCases, id: \.self, isSelected: { $0 == car.stripes },
                label: { ($0.rawValue, nil, nil) },
                choose: { model.car.stripes = $0 })

        if car.stripes != .none {
            ChipRow(title: "Stripe colour", items: AccentColor.allCases, id: \.self, isSelected: { $0 == car.stripeColor },
                    label: { ($0.rawValue, nil, Color($0.rgb)) },
                    choose: { model.car.stripeColor = $0 })
        }

        ChipRow(title: "Roof & mirrors", items: RoofStyle.allCases, id: \.self, isSelected: { $0 == car.roof },
                label: { ($0.rawValue, nil, nil) },
                choose: { model.car.roof = $0 })

        ChipRow(title: "Racing number", items: Array(stride(from: 1, through: 99, by: 1)), id: \.self,
                isSelected: { $0 == car.number },
                label: { ("\($0)", nil, nil) },
                choose: { model.car.number = $0 })

        VStack(alignment: .leading, spacing: 10) {
            Text("DRIVER NAME")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
            TextField("Your name", text: $model.driverName)
                .font(.system(size: 28))
                .frame(width: 520)
        }
        .padding(.top, 10)
    }

    static func wheelSwatch(_ f: WheelFinish, paint: Paint) -> Color {
        switch f {
        case .silver: return Color(RGB(0xC3C7CC))
        case .gloss: return Color(RGB(0x141414))
        case .gunmetal: return Color(RGB(0x3E4248))
        case .bronze: return Color(RGB(0x8C6A3F))
        case .gold: return Color(RGB(0xC9A23A))
        case .chrome: return Color(RGB(0xEDEFF2))
        case .white: return Color(RGB(0xF0F0F0))
        case .body: return Color(paint.color)
        }
    }
}

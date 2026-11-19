import SwiftUI

struct MenuView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var preview = GaragePreview()

    var body: some View {
        ZStack(alignment: .leading) {
            SceneHost(scene: preview.scene, pointOfView: preview.camera)
                .ignoresSafeArea()
                .offset(x: 260)
            LinearGradient(colors: [.black.opacity(0.95), .black.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 34) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("APEX GP")
                        .font(.system(size: 110, weight: .black).italic())
                        .foregroundStyle(LinearGradient(colors: [.white, .apexGold], startPoint: .top, endPoint: .bottom))
                    Text("Real road cars. Real Grand Prix circuits.")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 30)

                menuButton("Race", icon: "flag.checkered") { model.screen = .tracks }
                menuButton("Quick Race", icon: "bolt.fill") {
                    if let t = TrackLibrary.all.randomElement() { model.startRace(t) }
                }
                menuButton("Garage", icon: "wrench.and.screwdriver.fill") { model.screen = .garage }

                Spacer().frame(height: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.driverName.isEmpty ? "Your car" : "\(model.driverName)'s car")
                        .font(.system(size: 24, weight: .semibold)).foregroundStyle(.secondary)
                    Text("\(model.car.model.displayName) \(model.car.trim.name)")
                        .font(.system(size: 34, weight: .bold))
                    Text(model.car.paint.name).font(.system(size: 24)).foregroundStyle(Color(model.car.paint.color))
                }
            }
            .padding(.leading, 110)
        }
        .onAppear { preview.show(model.car) }
    }

    private func menuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 40, weight: .bold))
                .frame(width: 520, alignment: .leading)
                .padding(.vertical, 8)
        }
    }
}

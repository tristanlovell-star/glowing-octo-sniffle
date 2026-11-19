import SwiftUI

extension Color {
    init(_ rgb: RGB) { self.init(red: rgb.r, green: rgb.g, blue: rgb.b) }
    static let apexRed = Color(red: 0.88, green: 0.1, blue: 0.12)
    static let apexGold = Color(red: 1, green: 0.8, blue: 0.2)
}

/// A selectable option in the garage and race setup.
struct Chip: View {
    var title: String
    var subtitle: String? = nil
    var swatch: Color? = nil
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let s = swatch {
                    Circle()
                        .fill(s)
                        .frame(width: 38, height: 38)
                        .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 2))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 26, weight: .semibold))
                        .lineLimit(1)
                    if let sub = subtitle {
                        Text(sub)
                            .font(.system(size: 19))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.apexGold)
                        .font(.system(size: 26))
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color.apexGold : Color.clear, lineWidth: 4)
            )
        }
        .buttonStyle(.card)
    }
}

/// A titled row of chips that scrolls sideways.
struct ChipRow<Item, ID: Hashable>: View {
    var title: String
    var items: [Item]
    var id: KeyPath<Item, ID>
    var isSelected: (Item) -> Bool
    var label: (Item) -> (title: String, subtitle: String?, swatch: Color?)
    var choose: (Item) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    ForEach(items, id: id) { item in
                        let l = label(item)
                        Chip(title: l.title, subtitle: l.subtitle, swatch: l.swatch, selected: isSelected(item)) {
                            choose(item)
                        }
                    }
                }
                .padding(.vertical, 22)
                .padding(.horizontal, 12)
            }
            .focusSection()
        }
    }
}

/// Draws a circuit's outline.
struct TrackMap: View {
    let info: TrackInfo
    var lineWidth: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            let pts = Track.outline(info)
            let size = min(geo.size.width, geo.size.height) - lineWidth * 2
            let ox = (geo.size.width - size) / 2, oy = (geo.size.height - size) / 2
            let mapped = pts.map { CGPoint(x: ox + $0.x * size, y: oy + $0.y * size) }
            ZStack {
                Path { p in
                    guard let first = mapped.first else { return }
                    p.move(to: first)
                    for q in mapped.dropFirst() { p.addLine(to: q) }
                    p.closeSubpath()
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                if let start = mapped.first {
                    Circle().fill(Color.apexRed).frame(width: lineWidth * 2.6, height: lineWidth * 2.6).position(start)
                }
            }
        }
    }
}

struct StatBar: View {
    var label: String
    var value: String
    var fraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.system(size: 22, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Text(value).font(.system(size: 24, weight: .bold)).monospacedDigit()
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(LinearGradient(colors: [.apexRed, .apexGold], startPoint: .leading, endPoint: .trailing))
                        .frame(width: g.size.width * max(0.03, min(1, fraction)))
                }
            }
            .frame(height: 10)
        }
    }
}

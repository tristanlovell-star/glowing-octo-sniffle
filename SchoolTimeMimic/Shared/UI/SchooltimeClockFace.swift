import SwiftUI

/// The Schooltime look: a stark black face, a big amber ring, and the time
/// in heavy rounded digits in the middle. Used full-screen on the watch and as
/// a live preview on the iPhone.
struct SchooltimeClockFace: View {
    var date: Date
    /// Shown small under the date, e.g. "until 3:00 PM".
    var detail: String?
    /// 0…1 progress through the school day; draws a thin inner arc when set.
    var dayProgress: Double?
    /// Dims everything for the Always-On (wrist-down) state.
    var isDimmed = false
    var isActive = true

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let ringWidth = max(size * 0.055, 4)
            let ringColor = isActive ? (isDimmed ? SchoolTheme.amberDim : SchoolTheme.amber) : Color.gray.opacity(0.5)

            ZStack {
                // Main ring
                Circle()
                    .stroke(ringColor, lineWidth: isDimmed ? ringWidth * 0.6 : ringWidth)
                    .shadow(color: isDimmed || !isActive ? .clear : SchoolTheme.amber.opacity(0.45), radius: size * 0.04)

                // School-day progress arc
                if let dayProgress, isActive {
                    Circle()
                        .inset(by: ringWidth * 1.9)
                        .trim(from: 0, to: min(max(dayProgress, 0), 1))
                        .stroke(ringColor.opacity(0.55), style: StrokeStyle(lineWidth: max(ringWidth * 0.3, 1.5), lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }

                VStack(spacing: size * 0.015) {
                    Text(date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                        .font(.system(size: size * 0.30, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isDimmed ? Color.white.opacity(0.6) : .white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Text(date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(.system(size: size * 0.085, weight: .semibold, design: .rounded))
                        .textCase(.uppercase)
                        .foregroundStyle(ringColor)

                    if let detail, !isDimmed {
                        Text(detail)
                            .font(.system(size: size * 0.065, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(.horizontal, size * 0.12)
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Schooltime. \(date.formatted(date: .complete, time: .shortened))"))
    }
}

extension SchoolSchedule {
    /// 0…1 progress through today's interval, or nil outside school hours.
    func dayProgress(at date: Date = .now) -> Double? {
        guard isActive(at: date) else { return nil }
        let total = Double(endMinuteOfDay - startMinuteOfDay)
        let elapsed = Double(SchoolSchedule.minuteOfDay(date) - startMinuteOfDay)
        return total > 0 ? elapsed / total : nil
    }
}

#Preview {
    SchooltimeClockFace(date: .now, detail: "until 3:00 PM", dayProgress: 0.4)
        .padding()
        .background(.black)
}

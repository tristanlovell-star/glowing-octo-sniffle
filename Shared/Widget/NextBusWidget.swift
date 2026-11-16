import AppIntents
import SwiftUI
import WidgetKit

struct NextBusWidget: Widget {
    let kind = "NextBusWidget"

    private var families: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline]
        #else
        [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline]
        #endif
    }

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: BusStopIntent.self, provider: DepartureProvider()) { entry in
            DepartureWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Bus")
        .description("Live bus times and when to leave so you make it.")
        .supportedFamilies(families)
    }
}

struct DepartureWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DepartureEntry

    var body: some View {
        content
            .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        #if os(iOS)
        case .systemSmall:
            SmallDepartureView(entry: entry)
        case .systemMedium, .systemLarge:
            MediumDepartureView(entry: entry)
        #endif
        #if os(watchOS)
        case .accessoryCorner:
            CornerDepartureView(entry: entry)
        #endif
        case .accessoryCircular:
            CircularDepartureView(entry: entry)
        case .accessoryInline:
            InlineDepartureView(entry: entry)
        default:
            RectangularDepartureView(entry: entry)
        }
    }
}

// MARK: - Building blocks

struct RouteBadge: View {
    let route: String
    var compact = false

    var body: some View {
        Text(route)
            .font(compact ? .caption2.weight(.bold) : .caption.weight(.bold))
            .monospacedDigit()
            .padding(.horizontal, compact ? 4 : 6)
            .padding(.vertical, 2)
            .background(RouteColors.color(for: route).opacity(0.25), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(RouteColors.color(for: route), lineWidth: 1.5))
    }
}

enum RouteColors {
    static func color(for route: String) -> Color {
        switch route {
        case "199": return Color(red: 0.89, green: 0.39, blue: 0.64) // Translink's 199 pink
        case "195": return .orange
        case "196": return .teal
        default: return .accentColor
        }
    }
}

/// Shown when there's nothing to list.
private struct EmptyDeparturesText: View {
    let entry: DepartureEntry

    var body: some View {
        Text(entry.errorMessage ?? "No buses in the next hour")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

// MARK: - iPhone Home Screen

#if os(iOS)
private struct RefreshButton: View {
    var body: some View {
        Button(intent: RefreshDeparturesIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(.caption2.weight(.semibold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}

private struct UpdatedFooter: View {
    let entry: DepartureEntry

    var body: some View {
        HStack(spacing: 4) {
            if entry.errorMessage != nil {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            if let fetchedAt = entry.fetchedAt {
                Text("Updated \(TimeFormatting.clock(fetchedAt))")
            } else {
                Text(entry.errorMessage ?? "")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

struct SmallDepartureView: View {
    let entry: DepartureEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(entry.config.stopName, systemImage: "bus.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                RefreshButton()
            }

            if let next = entry.nextCatchable {
                VStack(alignment: .leading, spacing: 0) {
                    Text(TimeFormatting.leaveText(for: next, walkMinutes: entry.config.walkMinutes, now: entry.date))
                        .font(.headline)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("for the \(next.route) at \(TimeFormatting.clock(next.time))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if entry.upcoming.isEmpty {
                EmptyDeparturesText(entry: entry)
            } else {
                VStack(spacing: 3) {
                    ForEach(entry.upcoming.prefix(3)) { departure in
                        HStack {
                            RouteBadge(route: departure.route, compact: true)
                            Spacer()
                            Text(TimeFormatting.countdown(to: departure.time, from: entry.date))
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(departure.isLate ? Color.orange : Color.primary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct MediumDepartureView: View {
    let entry: DepartureEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label(entry.config.stopName, systemImage: "bus.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let next = entry.nextCatchable {
                    Text(TimeFormatting.leaveText(for: next, walkMinutes: entry.config.walkMinutes, now: entry.date))
                        .font(.title3.weight(.bold))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("Catch the \(next.route) at \(TimeFormatting.clock(next.time))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(entry.config.walkMinutes) min walk")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    EmptyDeparturesText(entry: entry)
                }
                Spacer(minLength: 0)
                HStack {
                    UpdatedFooter(entry: entry)
                    RefreshButton()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 5) {
                ForEach(entry.upcoming.prefix(4)) { departure in
                    HStack(spacing: 6) {
                        RouteBadge(route: departure.route)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(TimeFormatting.clock(departure.time))
                                .font(.caption.weight(.medium))
                            if let delay = departure.delayDescription {
                                Text(delay)
                                    .font(.caption2)
                                    .foregroundStyle(departure.isLate ? Color.orange : Color.secondary)
                            }
                        }
                        Spacer(minLength: 2)
                        Text(TimeFormatting.countdown(to: departure.time, from: entry.date))
                            .font(.callout.weight(.semibold))
                            .monospacedDigit()
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
#endif

// MARK: - Lock Screen and Apple Watch

struct RectangularDepartureView: View {
    let entry: DepartureEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let next = entry.nextCatchable {
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                    Text(TimeFormatting.leaveText(for: next, walkMinutes: entry.config.walkMinutes, now: entry.date))
                }
                .font(.headline)
                .widgetAccentable()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            } else {
                Label(entry.config.stopName, systemImage: "bus.fill")
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
            }

            if entry.upcoming.isEmpty {
                EmptyDeparturesText(entry: entry)
            } else {
                ForEach(entry.upcoming.prefix(2)) { departure in
                    HStack(spacing: 4) {
                        Text(departure.route)
                            .fontWeight(.semibold)
                        Text(TimeFormatting.clock(departure.time))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 2)
                        Text(TimeFormatting.countdown(to: departure.time, from: entry.date))
                            .fontWeight(.semibold)
                    }
                    .font(.caption)
                    .monospacedDigit()
                    .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CircularDepartureView: View {
    let entry: DepartureEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let next = entry.nextCatchable {
                VStack(spacing: -2) {
                    Text(next.route)
                        .font(.system(size: 11, weight: .semibold))
                        .widgetAccentable()
                    Text("\(TimeFormatting.minutes(until: next.leaveTime(walkMinutes: entry.config.walkMinutes), from: entry.date))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                    Text("LEAVE")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "bus.fill")
                    .font(.title3)
            }
        }
    }
}

struct InlineDepartureView: View {
    let entry: DepartureEntry

    var body: some View {
        if let next = entry.nextCatchable {
            let minutes = TimeFormatting.minutes(until: next.leaveTime(walkMinutes: entry.config.walkMinutes), from: entry.date)
            Text("\(Image(systemName: "bus.fill")) \(next.route) · \(minutes == 0 ? "leave now" : "leave in \(minutes)m")")
        } else {
            Text("\(Image(systemName: "bus.fill")) No buses soon")
        }
    }
}

#if os(watchOS)
struct CornerDepartureView: View {
    let entry: DepartureEntry

    var body: some View {
        if let next = entry.nextCatchable {
            let minutes = TimeFormatting.minutes(until: next.leaveTime(walkMinutes: entry.config.walkMinutes), from: entry.date)
            Text(minutes == 0 ? "Go" : "\(minutes)m")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .widgetAccentable()
                .widgetLabel {
                    Text("Leave · \(next.route) at \(TimeFormatting.clock(next.time))")
                }
        } else {
            Image(systemName: "bus.fill")
                .font(.title3)
                .widgetLabel { Text("No buses soon") }
        }
    }
}
#endif

#if os(iOS)
#Preview(as: .systemSmall) {
    NextBusWidget()
} timeline: {
    DepartureEntry.preview
}

#Preview(as: .systemMedium) {
    NextBusWidget()
} timeline: {
    DepartureEntry.preview
}
#endif

#Preview(as: .accessoryRectangular) {
    NextBusWidget()
} timeline: {
    DepartureEntry.preview
}

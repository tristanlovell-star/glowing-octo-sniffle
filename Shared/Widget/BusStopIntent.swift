import AppIntents
import WidgetKit

extension StopSelection: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Stop"
    static let caseDisplayRepresentations: [StopSelection: DisplayRepresentation] = [
        .nearest: DisplayRepresentation(title: "Nearest", subtitle: "Home or work, by location"),
        .home: DisplayRepresentation(title: "Home stop"),
        .work: DisplayRepresentation(title: "Work stop"),
    ]
}

/// The options you see under "Edit Widget" (iPhone) or when editing a watch face complication.
struct BusStopIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Bus Stop"
    static let description = IntentDescription("Shows the bus stop nearest to you (home or work), or always the one you pick.")

    @Parameter(title: "Show", default: .nearest)
    var selection: StopSelection

    @Parameter(title: "Home stop ID", description: "Merthyr Rd at Alford St, stop 12 (city-bound) is 725.", default: "725")
    var homeStopID: String

    @Parameter(title: "Walk to home stop (min)", default: 3)
    var homeWalkMinutes: Int

    @Parameter(title: "Home stop routes", description: "Comma-separated, e.g. 199. Leave blank for every route.", default: "")
    var homeRoutes: String

    @Parameter(title: "Work stop ID", description: "Adelaide St Stop 30 is 000030.", default: "000030")
    var workStopID: String

    @Parameter(title: "Walk to work stop (min)", default: 5)
    var workWalkMinutes: Int

    @Parameter(title: "Work stop routes", description: "Comma-separated, e.g. 195, 199. Leave blank for every route.", default: "")
    var workRoutes: String

    init() {}

    init(selection: StopSelection) {
        self.selection = selection
    }

    var commute: CommuteConfig {
        CommuteConfig(
            selection: selection,
            home: StopConfig(rawStopID: homeStopID, walkMinutes: homeWalkMinutes, rawRoutes: homeRoutes),
            work: StopConfig(rawStopID: workStopID, walkMinutes: workWalkMinutes, rawRoutes: workRoutes)
        )
    }
}

/// Lets you tap the refresh button on the iPhone widget. Running any app intent
/// from a widget makes WidgetKit reload that widget's timeline.
struct RefreshDeparturesIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Bus Times"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

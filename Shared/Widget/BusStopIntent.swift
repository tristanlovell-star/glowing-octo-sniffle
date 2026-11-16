import AppIntents
import WidgetKit

/// The options you see under "Edit Widget" (iPhone) or when editing a watch face complication.
struct BusStopIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Bus Stop"
    static let description = IntentDescription("Pick the stop, how long it takes you to walk there, and which routes to show.")

    @Parameter(title: "Stop ID", description: "The number at the end of the Translink stop page URL, e.g. 000030.", default: "000030")
    var stopID: String

    @Parameter(title: "Walk to stop (minutes)", default: 5)
    var walkMinutes: Int

    @Parameter(title: "Routes", description: "Comma-separated, e.g. 195, 199. Leave blank for every route.", default: "")
    var routes: String

    init() {}

    init(stopID: String, walkMinutes: Int, routes: String) {
        self.stopID = stopID
        self.walkMinutes = walkMinutes
        self.routes = routes
    }

    var config: StopConfig {
        StopConfig(rawStopID: stopID, walkMinutes: walkMinutes, rawRoutes: routes)
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

import Foundation

/// One bus's predicted arrival at the stop we care about.
struct StopArrival: Sendable {
    let tripID: String
    let routeID: String
    /// Predicted departure (or arrival) time from the stop.
    let time: Date
    /// Seconds behind (+) or ahead of (-) the timetable, if the feed says.
    let delaySeconds: Int?
}

/// Pulls just the fields we need out of a GTFS-Realtime `FeedMessage`.
///
/// Field numbers follow the official gtfs-realtime.proto:
///   FeedMessage    { 1 header, 2 entity }
///   FeedHeader     { 3 timestamp }
///   FeedEntity     { 1 id, 2 is_deleted, 3 trip_update }
///   TripUpdate     { 1 trip, 2 stop_time_update }
///   TripDescriptor { 1 trip_id, 4 schedule_relationship, 5 route_id }
///   StopTimeUpdate { 2 arrival, 3 departure, 4 stop_id, 5 schedule_relationship }
///   StopTimeEvent  { 1 delay, 2 time }
enum GTFSRealtimeParser {
    private static let tripCanceled: UInt64 = 3   // TripDescriptor.ScheduleRelationship.CANCELED
    private static let stopSkipped: UInt64 = 1    // StopTimeUpdate.ScheduleRelationship.SKIPPED

    static func arrivals(in data: Data, stopID: String) throws -> (feedTimestamp: Date?, arrivals: [StopArrival]) {
        var reader = ProtobufReader(data: data)
        var feedTimestamp: Date?
        var arrivals: [StopArrival] = []

        while !reader.isAtEnd {
            let tag = try reader.readTag()
            switch (tag.field, tag.wireType) {
            case (1, 2):
                var header = try reader.readMessage()
                feedTimestamp = try parseHeaderTimestamp(&header)
            case (2, 2):
                var entity = try reader.readMessage()
                if let arrival = try parseEntity(&entity, stopID: stopID) {
                    arrivals.append(arrival)
                }
            default:
                try reader.skipField(wireType: tag.wireType)
            }
        }
        return (feedTimestamp, arrivals)
    }

    private static func parseHeaderTimestamp(_ reader: inout ProtobufReader) throws -> Date? {
        var timestamp: Date?
        while !reader.isAtEnd {
            let tag = try reader.readTag()
            if tag.field == 3 && tag.wireType == 0 {
                timestamp = Date(timeIntervalSince1970: TimeInterval(try reader.readVarint()))
            } else {
                try reader.skipField(wireType: tag.wireType)
            }
        }
        return timestamp
    }

    private static func parseEntity(_ reader: inout ProtobufReader, stopID: String) throws -> StopArrival? {
        var isDeleted = false
        var arrival: StopArrival?
        while !reader.isAtEnd {
            let tag = try reader.readTag()
            switch (tag.field, tag.wireType) {
            case (2, 0):
                isDeleted = try reader.readBool()
            case (3, 2):
                var tripUpdate = try reader.readMessage()
                arrival = try parseTripUpdate(&tripUpdate, stopID: stopID)
            default:
                try reader.skipField(wireType: tag.wireType)
            }
        }
        return isDeleted ? nil : arrival
    }

    private static func parseTripUpdate(_ reader: inout ProtobufReader, stopID: String) throws -> StopArrival? {
        var tripID = ""
        var routeID = ""
        var isCanceled = false
        var match: (time: Int64, delay: Int32?)?

        while !reader.isAtEnd {
            let tag = try reader.readTag()
            switch (tag.field, tag.wireType) {
            case (1, 2):
                var trip = try reader.readMessage()
                while !trip.isAtEnd {
                    let tripTag = try trip.readTag()
                    switch (tripTag.field, tripTag.wireType) {
                    case (1, 2): tripID = try trip.readString()
                    case (4, 0): isCanceled = try trip.readVarint() == tripCanceled
                    case (5, 2): routeID = try trip.readString()
                    default: try trip.skipField(wireType: tripTag.wireType)
                    }
                }
            case (2, 2) where match == nil:
                var update = try reader.readMessage()
                match = try parseStopTimeUpdate(&update, stopID: stopID)
            default:
                try reader.skipField(wireType: tag.wireType)
            }
        }

        guard !isCanceled, let match else { return nil }
        return StopArrival(
            tripID: tripID,
            routeID: routeID,
            time: Date(timeIntervalSince1970: TimeInterval(match.time)),
            delaySeconds: match.delay.map(Int.init)
        )
    }

    private static func parseStopTimeUpdate(_ reader: inout ProtobufReader, stopID: String) throws -> (time: Int64, delay: Int32?)? {
        var updateStopID = ""
        var relationship: UInt64 = 0
        var arrival: (time: Int64?, delay: Int32?) = (nil, nil)
        var departure: (time: Int64?, delay: Int32?) = (nil, nil)

        while !reader.isAtEnd {
            let tag = try reader.readTag()
            switch (tag.field, tag.wireType) {
            case (2, 2):
                var event = try reader.readMessage()
                arrival = try parseStopTimeEvent(&event)
            case (3, 2):
                var event = try reader.readMessage()
                departure = try parseStopTimeEvent(&event)
            case (4, 2):
                updateStopID = try reader.readString()
            case (5, 0):
                relationship = try reader.readVarint()
            default:
                try reader.skipField(wireType: tag.wireType)
            }
        }

        guard updateStopID == stopID, relationship != stopSkipped else { return nil }
        // Prefer departure time: that's when the bus leaves the stop.
        if let time = departure.time { return (time, departure.delay ?? arrival.delay) }
        if let time = arrival.time { return (time, arrival.delay) }
        return nil
    }

    private static func parseStopTimeEvent(_ reader: inout ProtobufReader) throws -> (time: Int64?, delay: Int32?) {
        var time: Int64?
        var delay: Int32?
        while !reader.isAtEnd {
            let tag = try reader.readTag()
            switch (tag.field, tag.wireType) {
            case (1, 0): delay = try reader.readInt32()
            case (2, 0): time = try reader.readInt64()
            default: try reader.skipField(wireType: tag.wireType)
            }
        }
        return (time, delay)
    }
}

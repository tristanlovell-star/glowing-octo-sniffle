import Foundation

/// Talks to the Claude API directly from the phone, using the user's own API key.
/// Powers the three things that need real intelligence: recognising equipment in photos,
/// designing a program around the person, and the conversational coach.
struct ClaudeClient {
    enum ClaudeError: LocalizedError {
        case noKey
        case http(Int, String)
        case declined
        case truncated
        case badResponse

        var errorDescription: String? {
            switch self {
            case .noKey:
                return "Add your Claude API key in Settings to use the AI coach."
            case .http(401, _):
                return "Your Claude API key was rejected. Check it in Settings."
            case .http(429, _):
                return "The AI coach is rate-limited right now. Try again in a minute."
            case .http(let code, let message) where code >= 500:
                return "The AI coach is temporarily unavailable (\(code)). \(message)"
            case .http(_, let message):
                return message
            case .declined:
                return "The AI coach declined that request."
            case .truncated:
                return "The AI coach's answer was cut off. Try again."
            case .badResponse:
                return "Couldn't read the AI coach's answer. Try again."
            }
        }
    }

    static let model = "claude-opus-5-5"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    static let persona = """
    You are Spotter, a personal strength coach inside an iPhone gym app. You coach one person, whose \
    profile, gym equipment, program and training log are given to you. Be specific to them: refer to \
    their actual numbers, their actual equipment, and their goal. Be direct and practical, like a good \
    coach on the gym floor — say what to do and why in a sentence, without lectures or disclaimers. \
    If something they describe sounds like an injury rather than normal training soreness, say so plainly \
    and suggest they get it looked at.
    """

    // MARK: - Transport

    /// Sends one request and returns the full text of the reply. `onText` receives the reply as it streams.
    private func send(system: String, messages: [[String: Any]], schema: [String: Any]? = nil,
                      effort: String, maxTokens: Int = 16000,
                      onText: (@MainActor (String) -> Void)? = nil) async throws -> String {
        guard let key = Keychain.apiKey else { throw ClaudeError.noKey }

        var outputConfig: [String: Any] = ["effort": effort]
        if let schema {
            let format: [String: Any] = ["type": "json_schema", "schema": schema]
            outputConfig["format"] = format
        }
        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": maxTokens,
            "stream": true,
            "system": system,
            "messages": messages,
            "output_config": outputConfig,
            // If a safety classifier declines, let the API retry on its recommended fallback model.
            "fallbacks": "default",
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 600
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClaudeError.badResponse }
        if http.statusCode != 200 {
            var raw = Data()
            for try await byte in bytes { raw.append(byte) }
            throw ClaudeError.http(http.statusCode, Self.errorMessage(from: raw))
        }

        var text = ""
        var stopReason: String?
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let data = payload.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = event["type"] as? String else { continue }
            switch type {
            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any], delta["type"] as? String == "text_delta",
                   let piece = delta["text"] as? String {
                    text += piece
                    if let onText {
                        let snapshot = text
                        await onText(snapshot)
                    }
                }
            case "message_delta":
                if let delta = event["delta"] as? [String: Any], let reason = delta["stop_reason"] as? String {
                    stopReason = reason
                }
            case "error":
                let message = (event["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
                throw ClaudeError.http(http.statusCode == 200 ? 500 : http.statusCode, message)
            default:
                break
            }
        }

        if stopReason == "refusal" { throw ClaudeError.declined }
        if stopReason == "max_tokens" { throw ClaudeError.truncated }
        guard !text.isEmpty else { throw ClaudeError.badResponse }
        return text
    }

    private static func errorMessage(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = object["error"] as? [String: Any], let message = error["message"] as? String {
            return message
        }
        return String(data: data, encoding: .utf8) ?? "Request failed."
    }

    private static func imageBlock(_ jpeg: Data) -> [String: Any] {
        let source: [String: Any] = ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()]
        return ["type": "image", "source": source]
    }

    private static func textBlock(_ text: String) -> [String: Any] {
        ["type": "text", "text": text]
    }

    private static func userMessage(_ content: Any) -> [String: Any] {
        ["role": "user", "content": content]
    }

    // MARK: - Equipment recognition

    struct DetectedEquipment: Decodable, Hashable {
        var type: String
        var label: String
        var notes: String
        var photo: Int
    }

    struct EquipmentScan: Decodable {
        var items: [DetectedEquipment]
        var unrecognised: [String]
    }

    /// Looks at photos of a gym and lists the equipment in them.
    func identifyEquipment(photos: [Data]) async throws -> EquipmentScan {
        let catalogue = EquipmentType.allCases.map { "\($0.rawValue): \($0.displayName)" }.joined(separator: "\n")
        var content: [[String: Any]] = []
        for (index, photo) in photos.enumerated() {
            content.append(Self.textBlock("Photo \(index):"))
            content.append(Self.imageBlock(photo))
        }
        content.append(Self.textBlock("""
        These are photos I took walking around a gym. List every distinct piece of training equipment \
        you can see, so a workout app knows what this gym has.

        Classify each one as exactly one of these types:
        \(catalogue)

        For each item give:
        - type: the type id from the list
        - label: a short description that would help me find this exact thing in the room \
        (brand or colour if visible, e.g. "Black Life Fitness chest press")
        - notes: one sentence on anything worth knowing about using this particular unit — weight range \
        visible on the stack or rack, plate-loaded vs pin-loaded, which attachments are there. Empty string if nothing.
        - photo: the number of the photo that shows it best

        One entry per type is enough unless there are clearly different machines of the same type. \
        A dual-function machine (e.g. leg extension / leg curl, pec fly / rear delt) should be listed once \
        per function. A multi-station tower should be listed as each station it provides. \
        A bench press station counts as barbell + flatBench; a rack of fixed-weight barbells counts as barbell.

        Put anything that is training equipment but fits none of the types into "unrecognised" as short \
        plain descriptions. Ignore non-equipment (mirrors, lockers, people, TVs).
        """))

        let schema = Schema.object([
            "items": Schema.array(Schema.object([
                "type": Schema.oneOf(EquipmentType.allCases.map(\.rawValue)),
                "label": Schema.string,
                "notes": Schema.string,
                "photo": Schema.integer,
            ])),
            "unrecognised": Schema.array(Schema.string),
        ])

        let text = try await send(
            system: "You identify gym equipment in photos for a workout-planning app. Only list what you can actually see.",
            messages: [Self.userMessage(content)],
            schema: schema, effort: "medium")
        guard let data = text.data(using: .utf8),
              let scan = try? JSONDecoder().decode(EquipmentScan.self, from: data) else {
            throw ClaudeError.badResponse
        }
        return scan
    }

    // MARK: - Program design

    private struct ProgramDraft: Decodable {
        struct Day: Decodable {
            struct Item: Decodable {
                var exerciseId: String
                var sets: Int
                var repMin: Int
                var repMax: Int
                var restSeconds: Int
                var note: String
            }
            var name: String
            var focus: String
            var exercises: [Item]
        }
        var name: String
        var rationale: String
        var days: [Day]
    }

    /// Designs a program for this person in this gym, choosing only from exercises the gym can support.
    /// `brief` is the coach context; `request` says what kind of program is wanted.
    func designProgram(brief: String, request: String, gym: Gym, library: ExerciseLibrary) async throws -> Program {
        let options = library.available(in: gym.available)
        guard !options.isEmpty else { throw ClaudeError.badResponse }
        let catalogue = options.map { exercise -> String in
            let load = exercise.loadType == .timed ? ", timed hold (reps = seconds)" : (exercise.loadType == .bodyweight ? ", bodyweight" : "")
            return "\(exercise.id) | \(exercise.name) | \(exercise.pattern.title) | \(exercise.muscleSummary) | difficulty \(exercise.difficulty)/3\(load)"
        }.joined(separator: "\n")

        let prompt = """
        \(brief)

        REQUEST
        \(request)

        EXERCISES POSSIBLE WITH THIS GYM'S EQUIPMENT (id | name | movement | main muscles | difficulty)
        \(catalogue)

        Design the program. One entry in "days" per distinct session in the weekly rotation, in the order \
        they should be done; the app cycles through them. Fit each session to the time they have, counting \
        warm-up sets and rest. Put the most demanding compound lifts first. Choose rep ranges and rest to \
        suit the goal and experience level, and work around any injuries or limitations they mention.

        Where the equipment list describes a specific unit (in brackets), prefer exercises that make good \
        use of what this gym actually has. This gym gets busy, so within a session avoid stacking several \
        exercises on the same single machine.

        For each exercise, "note" is one short coaching cue specific to this person (or an empty string). \
        For timed holds, repMin and repMax are seconds. "rationale" is 2–4 sentences, addressed to them, \
        explaining why this plan suits them — it's shown at the top of their program screen.
        """

        let schema = Schema.object([
            "name": Schema.string,
            "rationale": Schema.string,
            "days": Schema.array(Schema.object([
                "name": Schema.string,
                "focus": Schema.string,
                "exercises": Schema.array(Schema.object([
                    "exerciseId": Schema.oneOf(options.map(\.id)),
                    "sets": Schema.integer,
                    "repMin": Schema.integer,
                    "repMax": Schema.integer,
                    "restSeconds": Schema.integer,
                    "note": Schema.string,
                ])),
            ])),
        ])

        let text = try await send(system: Self.persona, messages: [Self.userMessage(prompt)],
                                  schema: schema, effort: "high", maxTokens: 32000)
        guard let data = text.data(using: .utf8),
              let draft = try? JSONDecoder().decode(ProgramDraft.self, from: data) else {
            throw ClaudeError.badResponse
        }

        let valid = Set(options.map(\.id))
        let days: [ProgramDay] = draft.days.compactMap { day in
            let items = day.exercises.filter { valid.contains($0.exerciseId) }.map { item in
                PlannedExercise(exerciseID: item.exerciseId,
                                sets: min(max(item.sets, 1), 8),
                                repMin: max(item.repMin, 1),
                                repMax: max(item.repMax, max(item.repMin, 1)),
                                restSeconds: min(max(item.restSeconds, 15), 300),
                                note: item.note)
            }
            return items.isEmpty ? nil : ProgramDay(name: day.name, focus: day.focus, exercises: items)
        }
        guard !days.isEmpty else { throw ClaudeError.badResponse }
        return Program(name: draft.name, gymID: gym.id, days: days, rationale: draft.rationale, source: .ai)
    }

    // MARK: - Coach chat

    /// Continues the coach conversation. Photos attached to the most recent messages are included.
    func chat(history: [ChatMessage], context: String,
              onText: @escaping @MainActor (String) -> Void) async throws -> String {
        let recent = Array(history.suffix(24))
        let withPhotos = Set(recent.filter { $0.photoFile != nil }.suffix(2).map(\.id))
        var messages: [[String: Any]] = []
        for message in recent {
            var content: [[String: Any]] = []
            if withPhotos.contains(message.id), let jpeg = AppStore.photoData(message.photoFile) {
                content.append(Self.imageBlock(jpeg))
            } else if message.photoFile != nil {
                content.append(Self.textBlock("[photo sent earlier]"))
            }
            content.append(Self.textBlock(message.text.isEmpty ? "(photo)" : message.text))
            let role = message.role == .user ? "user" : "assistant"
            // The API needs alternating turns starting with the user.
            if messages.isEmpty && role == "assistant" { continue }
            if let last = messages.last, last["role"] as? String == role,
               var merged = last["content"] as? [[String: Any]] {
                merged.append(contentsOf: content)
                let combined: [String: Any] = ["role": role, "content": merged]
                messages[messages.count - 1] = combined
            } else {
                let turn: [String: Any] = ["role": role, "content": content]
                messages.append(turn)
            }
        }
        guard !messages.isEmpty else { throw ClaudeError.badResponse }

        let system = """
        \(Self.persona)

        You're chatting in the app's Coach tab. Replies appear in a chat bubble on a phone, often read \
        between sets: keep them short, lead with the answer, and write plain sentences. You can use \
        **bold** for a key number or cue and simple "- " lists; no headings or tables. If they send a \
        photo of a machine, tell them what it is, how to set it up for their body, and how it fits their program.

        Here is everything the app knows about them right now:

        \(context)
        """
        return try await send(system: system, messages: messages, effort: "medium", onText: onText)
    }
}

/// Small builders for the JSON Schemas used with structured outputs.
private enum Schema {
    static let string: [String: Any] = ["type": "string"]
    static let integer: [String: Any] = ["type": "integer"]

    static func oneOf(_ values: [String]) -> [String: Any] {
        ["type": "string", "enum": values]
    }

    static func array(_ items: [String: Any]) -> [String: Any] {
        ["type": "array", "items": items]
    }

    /// An object where every property is required and nothing else is allowed.
    static func object(_ properties: [String: [String: Any]]) -> [String: Any] {
        [
            "type": "object",
            "properties": properties,
            "required": properties.keys.sorted(),
            "additionalProperties": false,
        ]
    }
}

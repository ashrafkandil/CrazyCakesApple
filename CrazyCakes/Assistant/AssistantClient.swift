import Foundation

struct ChatTurn {
    let role: String
    let text: String
}

struct AssistantRequest {
    let messages: [ChatTurn]
    let audio: VoiceClip?
    let page: AssistantPage
    let lang: Lang
}

enum AssistantAction {
    case navigate(AssistantPage)
    case showGalleryCategory(slug: String, title: String)
    case prefillQuote([String: String])
}

struct AssistantReply {
    let reply: String
    let actions: [AssistantAction]
    let suggestions: [String]
    let heard: String?
}

enum AssistantError: LocalizedError {
    case notConfigured
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "The assistant isn't set up yet. Add your Gemini API key to AppConfig.plist and rebuild the app."
        case .message(let text):
            return text
        }
    }
}

/// Calls Google Gemini directly from the device and turns the model's flat JSON into a
/// validated AssistantReply - the native twin of src/assistant/client.ts.
enum AssistantClient {
    /// Tried in order; Google retires model versions over time.
    private static let defaultModels = [
        "gemini-flash-lite-latest",
        "gemini-3.5-flash-lite",
        "gemini-flash-latest",
        "gemini-3.8-flash",
    ]

    private static let none = "none"
    private static let maxTurns = 12

    private static let voicePrompt = """
    This is a voice message from the visitor. Write exactly what they said in "heard" (in the language they spoke), then reply to it. If it is silent or unclear, set "heard" to "" and kindly ask them to repeat.
    """

    // MARK: - Configuration

    static func isConfigured() -> Bool {
        !AppConfig.geminiAPIKey.isEmpty
    }

    private static func modelChain() -> [String] {
        var models: [String] = []
        if let configured = AppConfig.geminiModel {
            models.append(configured)
        }
        models.append(contentsOf: defaultModels)
        var seen = Set<String>()
        return models.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    // MARK: - Request

    /// Sends the conversation (text or a short voice clip) to Gemini and returns the reply.
    static func ask(_ request: AssistantRequest, snapshot: ContentSnapshot) async throws -> AssistantReply {
        guard isConfigured() else { throw AssistantError.notConfigured }

        let turns = request.messages
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .suffix(maxTurns)

        var contents: [[String: Any]] = turns.map { turn -> [String: Any] in
            [
                "role": turn.role == "assistant" ? "model" : "user",
                "parts": [["text": turn.text]],
            ]
        }
        if let audio = request.audio {
            contents.append([
                "role": "user",
                "parts": [
                    ["inlineData": ["mimeType": audio.mimeType, "data": audio.data]],
                    ["text": voicePrompt],
                ],
            ])
        }

        let prompt = AssistantKnowledge.systemPrompt(snapshot: snapshot, page: request.page, lang: request.lang)
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": prompt]]],
            "contents": contents,
            "generationConfig": [
                "temperature": 0.5,
                "maxOutputTokens": 1000,
                "responseMimeType": "application/json",
                "responseSchema": responseSchema(
                    categorySlugs: snapshot.categories.map { $0.slug },
                    eventTypes: snapshot.eventTypes
                ),
            ],
        ]

        var lastError: Error?
        for model in modelChain() {
            do {
                let text = try await generate(model: model, body: body)
                if let reply = normalize(text, withAudio: request.audio != nil, snapshot: snapshot) {
                    return reply
                }
                lastError = AssistantError.message("Unusable response")
            } catch {
                if (error as NSError).code == NSURLErrorTimedOut { throw error }
                lastError = error
            }
        }

        let message = lastError?.localizedDescription ?? ""
        if message.range(of: "free-tier|quota|429|RESOURCE_EXHAUSTED", options: [.regularExpression, .caseInsensitive]) != nil {
            throw AssistantError.message("I'm a little busy right now. Please try again in a minute.")
        }
        throw AssistantError.message("Sorry, I couldn't get an answer just now. Please try again.")
    }

    /// A flat schema: nested objects made small models loop, so every field is top-level.
    private static func responseSchema(categorySlugs: [String], eventTypes: [String]) -> [String: Any] {
        let text: [String: Any] = ["type": "STRING"]
        let order = [
            "heard", "reply", "navigate_to", "gallery_category", "update_quote",
            "quote_name", "quote_email", "quote_phone", "quote_event_type", "quote_event_date",
            "quote_servings", "quote_location", "quote_theme", "suggestions",
        ]
        let properties: [String: Any] = [
            "heard": ["type": "STRING", "description": "Transcript of a voice message, otherwise empty"],
            "reply": ["type": "STRING", "description": "Spoken reply, 1-3 short sentences"],
            "navigate_to": ["type": "STRING", "enum": [none] + AssistantPage.allCases.map { $0.rawValue }],
            "gallery_category": ["type": "STRING", "enum": [none] + categorySlugs],
            "update_quote": ["type": "BOOLEAN"],
            "quote_name": text,
            "quote_email": text,
            "quote_phone": text,
            "quote_event_type": ["type": "STRING", "enum": [none] + eventTypes],
            "quote_event_date": ["type": "STRING", "description": "YYYY-MM-DD or empty"],
            "quote_servings": ["type": "STRING", "description": "Digits only or empty"],
            "quote_location": text,
            "quote_theme": ["type": "STRING", "description": "Design idea only, max 2 sentences, or empty"],
            "suggestions": ["type": "ARRAY", "items": text],
        ]
        return [
            "type": "OBJECT",
            "properties": properties,
            "required": order,
            "propertyOrdering": order,
        ]
    }

    private static func generate(model: String, body: [String: Any]) async throws -> String {
        guard let url = URL(string: "\(AppConfig.geminiBaseURL)/v1beta/models/\(model):generateContent") else {
            throw AssistantError.message("Invalid Gemini endpoint.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 35
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(AppConfig.geminiAPIKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = ((object?["error"] as? [String: Any])?["message"] as? String) ?? "HTTP \(http.statusCode)"
            throw AssistantError.message(message)
        }

        let candidates = object?["candidates"] as? [[String: Any]]
        let parts = (candidates?.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]]
        let text = (parts ?? [])
            .compactMap { $0["text"] as? String }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw AssistantError.message("Empty response") }
        return text
    }

    // MARK: - Response handling

    private static func stringField(_ object: [String: Any], _ key: String) -> String {
        (object[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }

    private static func cleanQuote(_ object: [String: Any], eventTypes: [String]) -> [String: String] {
        let mapping: [(String, QuoteDraftStore.Field)] = [
            ("quote_name", .name),
            ("quote_email", .email),
            ("quote_phone", .phone),
            ("quote_event_type", .eventType),
            ("quote_event_date", .eventDate),
            ("quote_servings", .servings),
            ("quote_location", .location),
            ("quote_theme", .theme),
        ]

        var draft: [String: String] = [:]
        for (key, field) in mapping {
            var value = stringField(object, key)
            if value.isEmpty { continue }
            value = String(value.prefix(300))
            switch field {
            case .eventType where !eventTypes.contains(value):
                continue
            case .eventDate where !matches(value, #"^\d{4}-\d{2}-\d{2}$"#):
                continue
            case .servings where !matches(value, #"^\d{1,4}$"#):
                continue
            case .email where !matches(value, #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#):
                continue
            default:
                break
            }
            draft[field.rawValue] = value
        }
        return draft
    }

    /// Returns nil when the model output is unusable (truncated, wrong shape).
    private static func normalize(_ raw: String, withAudio: Bool, snapshot: ContentSnapshot) -> AssistantReply? {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let fence = String(repeating: "\u{60}", count: 3)
        if cleaned.hasPrefix(fence) {
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[cleaned.index(after: firstNewline)...])
            }
            if cleaned.hasSuffix(fence) {
                cleaned = String(cleaned.dropLast(fence.count))
            }
        }

        guard let data = cleaned.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        let reply = stringField(object, "reply")
        guard !reply.isEmpty else { return nil }

        let eventTypes = snapshot.eventTypes
        let categories = Dictionary(uniqueKeysWithValues: snapshot.categories.map { ($0.slug, $0.title) })
        var actions: [AssistantAction] = []

        let quote = object["update_quote"] as? Bool == true ? cleanQuote(object, eventTypes: eventTypes) : [:]
        let galleryCategory = stringField(object, "gallery_category")
        let categoryTitle = galleryCategory.isEmpty ? nil : categories[galleryCategory]
        let navigateTo = stringField(object, "navigate_to")
        let page = AssistantPage.from(path: navigateTo)

        if !quote.isEmpty {
            actions.append(.prefillQuote(quote))
        } else if let categoryTitle, !galleryCategory.isEmpty {
            actions.append(.showGalleryCategory(slug: galleryCategory, title: categoryTitle))
        } else if let page {
            actions.append(.navigate(page))
        }

        let heard = withAudio ? String(stringField(object, "heard").prefix(500)) : ""
        let suggestions = ((object["suggestions"] as? [Any]) ?? [])
            .compactMap { $0 as? String }
            .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60)) }
            .filter { !$0.isEmpty }
            .prefix(3)

        return AssistantReply(
            reply: String(reply.prefix(600)),
            actions: actions,
            suggestions: Array(suggestions),
            heard: heard.isEmpty ? nil : heard
        )
    }
}

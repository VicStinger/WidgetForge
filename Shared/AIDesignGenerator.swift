import Foundation

/// Asks the Claude API — using the person's own API key, sent directly from this device — to
/// write a WidgetForge design as JSON. The reply is handed to `DesignExchange` exactly like a
/// pasted Design Code, so a confused or partial reply fails the same friendly way a bad paste
/// would. Nothing about this reaches another app or any part of iOS beyond the network; it's
/// the same kind of ordinary HTTPS request any app makes to a web API.
enum AIDesignGenerator {
    struct GenerationError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Sends the prompt and returns the model's raw reply text (expected to be, or contain,
    /// one JSON object describing a design). Throws a message meant to be shown as-is.
    static func generate(prompt: String, size: WidgetSize, model: String, apiKey: String) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw GenerationError(message: "Couldn't build the request URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 3000,
            "system": systemPrompt(size: size),
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GenerationError(message: "Couldn't reach the Anthropic API: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw GenerationError(message: "Didn't get a usable response from the API.")
        }
        guard (200...299).contains(http.statusCode) else {
            throw GenerationError(message: apiErrorMessage(status: http.statusCode, data: data))
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]]
        else {
            throw GenerationError(message: "Got a response, but couldn't read it.")
        }
        let text = content.compactMap { $0["text"] as? String }.joined()
        guard !text.isEmpty else {
            throw GenerationError(message: "The model didn't return any text.")
        }
        return text
    }

    private static func apiErrorMessage(status: Int, data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorInfo = json["error"] as? [String: Any],
           let message = errorInfo["message"] as? String {
            return message
        }
        switch status {
        case 401: return "That API key was rejected. Check it below and try again."
        case 403: return "That API key isn't allowed to do this (403)."
        case 404: return "The model name wasn't found (404). Check the model field below."
        case 429: return "Rate limit or quota reached (429). Wait a moment and try again."
        case 500...599: return "Anthropic's API had a problem (\(status)). Try again shortly."
        default: return "The API returned an error (\(status))."
        }
    }

    /// Teaches the model WidgetForge's own schema (kept in step with `Shared/Models.swift`) so
    /// its reply decodes straight into a real design.
    private static func systemPrompt(size: WidgetSize) -> String {
        let ref = size.referenceSize
        return """
        You write a WidgetForge design as a single JSON object — nothing else. No markdown \
        fences, no explanation before or after, just the object.

        Top level: "name" (short string), "size" (always exactly "\(size.rawValue)"), \
        "background", and "elements" (an array, drawn in order — later ones sit on top of \
        earlier ones).

        "background": { "kind": "solid" | "linear" | "radial" | "glow", "colors": [ \
        {"r":0-1,"g":0-1,"b":0-1,"a":0-1}, ... ] (1 to 3 colors), "angle": 0-360 }. "glow" \
        draws soft blurred color blobs on black, good for a moody glowing look. "linear" and \
        "radial" are plain gradients. "solid" uses only colors[0].

        Each entry in "elements" has "kind" plus geometry: "x","y" (the element's CENTER, 0 to \
        1 of the canvas), "width","height" (0 to 1 of the canvas), "rotation" (degrees, usually \
        0), "opacity" (0 to 1, usually 1), and a short "name". "kind" is one of:
        - "text": "text" (the string to show), plus the text styling fields below.
        - "date": "dateFormat" one of time, timeCompact, weekday, weekdayShort, day, monthDay, \
        fullDate, month, year, custom (set "customFormat" to a DateFormatter pattern such as \
        "EEEE, MMM d" when using custom), dayYesterday, dayTomorrow.
        - "countdown": "targetDate" (an ISO 8601 date string), "text" as a label template using \
        {n} for the days left, e.g. "{n} days to go".
        - "progress": "progressSource" one of manual, day, week, month, year, storage, battery; \
        "progressValue" (0-1, only read when source is manual); "progressKind" one of ring, \
        bar, dial; "showsLabel" (bool, shows a percentage); "lineWidth" (points, e.g. 10); \
        "color" (the filled part) and "secondaryColor" (the dim track behind it).
        - "symbol": "symbolName", a real SF Symbols name (stick to common ones you're sure \
        exist, e.g. "star.fill", "sun.max.fill", "moon.stars.fill", "bolt.fill", "heart.fill", \
        "airplane", "battery.75", "wifi").
        - "shape": "shape" one of rectangle, rounded, ellipse, capsule; "cornerRadius"; \
        "isFilled" (bool); "lineWidth" (used only when not filled); "isGlass" (bool — a \
        frosted translucent glass-panel look; when true it draws as glass regardless of \
        isFilled).
        - "image": avoid this kind — there is no real photo to attach, so it would only show \
        an empty placeholder.
        - "device": "deviceStat" one of battery, storage, uptime, network, deviceInfo — this \
        device's own live stats, never another app's data.
        - "formula": "formulaSource", a short template string with {...} spans, e.g. \
        "{battery}% battery" or "{percent(dayProgress)} through today". Inside {...} you can \
        use the values battery, charging, storageUsedPercent, storageFreeGB, uptimeHours, \
        uptimeDays, online, day, month, year, weekday, dayProgress, weekProgress, \
        monthProgress, yearProgress, combined with + - * / %, comparisons (== != < <= > >=), \
        && || !, a ternary cond ? a : b, "string literals", and the functions round(x), \
        floor(x), ceil(x), abs(x), min(a,b), max(a,b), percent(x), date("pattern"). A formula \
        can only use these values — never the network, the filesystem, or any other app.

        Text styling (on text, date, countdown, device and formula elements): "fontSize" \
        (points — roughly 13-18 for a caption, 28-56 for a headline, 70-190 for a giant \
        numeral), "weight" one of light, regular, medium, semibold, bold, heavy, black; \
        "fontDesign" one of standard, rounded, serif, monospaced; "alignment" one of leading, \
        center, trailing; "color"; "isUppercase" (bool).

        This is a \(size.title) widget, about \(Int(ref.width))×\(Int(ref.height)) points, so \
        keep margins and give large text enough width and height that it won't be clipped. \
        Prefer a small number of well-placed elements over clutter, with a clear focal element \
        and considered, cohesive colors — a genuinely good-looking design, not a generic \
        default.

        Reply with ONLY the JSON object.
        """
    }
}

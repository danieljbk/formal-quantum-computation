import Foundation

/// Escalating cry: the longer the alarm rings, the fussier the baby gets.
enum CryEscalation {
    /// Calmest to most intense.
    static let intensityOrder = ["cry_fussy", "cry_hungry", "cry_nursery", "cry_newborn"]
    static let stageSeconds: TimeInterval = 45

    struct Stage: Equatable {
        let voice: BabyVoice
        let startsAt: TimeInterval
    }

    static func stages(startingWith voice: BabyVoice, enabled: Bool) -> [Stage] {
        guard enabled, let start = intensityOrder.firstIndex(of: voice.id) else {
            return [Stage(voice: voice, startsAt: 0)]
        }
        return intensityOrder[start...].enumerated().compactMap { i, id in
            BabyVoiceCatalog.voice(id: id).map { Stage(voice: $0, startsAt: Double(i) * stageSeconds) }
        }
    }

    static func stage(at elapsed: TimeInterval, in stages: [Stage]) -> Stage? {
        stages.last { $0.startsAt <= elapsed } ?? stages.first
    }
}

enum Zodiac: String, Codable, CaseIterable, Identifiable {
    case aries, taurus, gemini, cancer, leo, virgo, libra, scorpio, sagittarius, capricorn, aquarius, pisces
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        ["♈️", "♉️", "♊️", "♋️", "♌️", "♍️", "♎️", "♏️", "♐️", "♑️", "♒️", "♓️"][Zodiac.allCases.firstIndex(of: self)!]
    }
}

/// Morning briefing content that doesn't need the network.
enum MorningContent {
    static let quotes: [(text: String, author: String)] = [
        ("The secret of getting ahead is getting started.", "Mark Twain"),
        ("Well begun is half done.", "Aristotle"),
        ("It does not matter how slowly you go as long as you do not stop.", "Confucius"),
        ("Every morning we are born again. What we do today is what matters most.", "Buddha (attributed)"),
        ("Lose an hour in the morning, and you will spend all day looking for it.", "Richard Whately"),
        ("Act as if what you do makes a difference. It does.", "William James"),
        ("Do what you can, with what you have, where you are.", "Theodore Roosevelt"),
        ("Quality is not an act, it is a habit.", "Will Durant"),
        ("Little by little, one travels far.", "J. R. R. Tolkien"),
        ("Begin at the beginning, and go on till you come to the end: then stop.", "Lewis Carroll"),
        ("Nothing will work unless you do.", "Maya Angelou"),
        ("The best time to plant a tree was 20 years ago. The second best time is now.", "Proverb"),
    ]

    /// Light-hearted daily fortunes (for fun, not astrology).
    static let fortunes = [
        "A small task you finish before noon makes the whole day lighter.",
        "Someone will be glad you replied quickly today.",
        "Your patience is your superpower this morning.",
        "A good idea arrives while you are making coffee.",
        "Today rewards the plan you write down, not the one in your head.",
        "Drink some water before anything else; future you says thanks.",
        "Take the stairs; a lucky thought is waiting on the way up.",
        "Say yes to the walk outside, even if it is short.",
        "An old friend is about to cross your mind. Message them.",
        "Your best work today happens in the first quiet hour.",
        "Be kind to the sleepy person in the mirror.",
        "A tidy desk opens a door you forgot about.",
    ]

    static func dayIndex(_ date: Date, calendar: Calendar = .current) -> Int {
        calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    }

    static func quote(for date: Date, calendar: Calendar = .current) -> (text: String, author: String) {
        quotes[dayIndex(date, calendar: calendar) % quotes.count]
    }

    static func fortune(for sign: Zodiac, on date: Date, calendar: Calendar = .current) -> String {
        let i = dayIndex(date, calendar: calendar) + (Zodiac.allCases.firstIndex(of: sign) ?? 0) * 5
        return fortunes[i % fortunes.count]
    }

    static func greeting(for date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 4..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello, night owl"
        }
    }
}

/// Today's weather from the Open-Meteo forecast API (no key needed).
struct WeatherReport: Equatable {
    let temperature: Double
    let high: Double
    let low: Double
    let precipitationChance: Int?
    let code: Int

    var summary: String { WeatherCode.describe(code).text }
    var emoji: String { WeatherCode.describe(code).emoji }

    static func url(latitude: Double, longitude: Double) -> URL? {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        c?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.2f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.2f", longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        return c?.url
    }

    static func decode(_ data: Data) -> WeatherReport? {
        struct Response: Decodable {
            struct Current: Decodable {
                let temperature_2m: Double
                let weather_code: Int
            }
            struct Daily: Decodable {
                let temperature_2m_max: [Double]
                let temperature_2m_min: [Double]
                let precipitation_probability_max: [Int?]?
            }
            let current: Current
            let daily: Daily
        }
        guard let r = try? JSONDecoder().decode(Response.self, from: data),
              let hi = r.daily.temperature_2m_max.first, let lo = r.daily.temperature_2m_min.first else { return nil }
        return WeatherReport(temperature: r.current.temperature_2m, high: hi, low: lo,
                             precipitationChance: r.daily.precipitation_probability_max?.first ?? nil,
                             code: r.current.weather_code)
    }
}

enum WeatherCode {
    /// WMO weather interpretation codes, as used by Open-Meteo.
    static func describe(_ code: Int) -> (text: String, emoji: String) {
        switch code {
        case 0: return ("Clear sky", "☀️")
        case 1, 2: return ("Partly cloudy", "🌤️")
        case 3: return ("Overcast", "☁️")
        case 45, 48: return ("Fog", "🌫️")
        case 51, 53, 55, 56, 57: return ("Drizzle", "🌦️")
        case 61, 63, 65, 66, 67, 80, 81, 82: return ("Rain", "🌧️")
        case 71, 73, 75, 77, 85, 86: return ("Snow", "🌨️")
        case 95, 96, 99: return ("Thunderstorm", "⛈️")
        default: return ("Weather", "🌡️")
        }
    }
}

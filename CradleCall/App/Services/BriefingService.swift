import CoreLocation
import EventKit
import Foundation

struct WeatherSnapshot: Equatable {
    var temperature: Double
    var high: Double
    var low: Double
    var precipitationChance: Int
    var code: Int

    var description: String { WeatherCode.description(code) }
    var symbol: String { WeatherCode.symbol(code) }
}

/// WMO weather interpretation codes used by Open-Meteo.
enum WeatherCode {
    static func description(_ code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1, 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51...57: return "Drizzle"
        case 61...67, 80...82: return "Rain"
        case 71...77, 85, 86: return "Snow"
        case 95...99: return "Thunderstorm"
        default: return "Mixed weather"
        }
    }

    static func symbol(_ code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.sun.fill"
        }
    }
}

struct BriefingEvent: Identifiable, Equatable {
    var id: String
    var title: String
    var start: Date
    var isAllDay: Bool
}

/// Gathers the morning briefing: weather, today's calendar and an encouraging line.
@MainActor
final class BriefingService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var weather: WeatherSnapshot?
    @Published private(set) var weatherError: String?
    @Published private(set) var events: [BriefingEvent] = []
    @Published private(set) var calendarError: String?
    @Published private(set) var isLoading = false

    private let locationManager = CLLocationManager()
    private let eventStore = EKEventStore()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func refresh(settings: AppSettings) async {
        isLoading = true
        defer { isLoading = false }
        if settings.briefingUsesLocation { await loadWeather(celsius: settings.useCelsius) }
        if settings.briefingUsesCalendar { await loadEvents() }
    }

    static func quote(for date: Date) -> String {
        let quotes = [
            "You got up. That's the hardest part done.",
            "Babies don't snooze, and today neither did you.",
            "Drink a glass of water before anything else.",
            "Open the curtains: daylight resets your body clock.",
            "One small win before 9 a.m. sets the tone for the day.",
            "Make the bed. Future you will be grateful.",
            "Stretch for a minute. Your back will thank you.",
        ]
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        return quotes[day % quotes.count]
    }

    static func greeting(for date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 4..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: Weather

    private func loadWeather(celsius: Bool) async {
        weatherError = nil
        guard let location = await currentLocation() else {
            weatherError = "Allow location access to see today's weather."
            return
        }
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.3f", location.coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", location.coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
            URLQueryItem(name: "temperature_unit", value: celsius ? "celsius" : "fahrenheit"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1"),
        ]
        do {
            let (data, _) = try await URLSession.shared.data(from: components.url!)
            weather = try Self.parseWeather(data)
        } catch {
            weatherError = "Weather is unavailable right now."
        }
    }

    nonisolated static func parseWeather(_ data: Data) throws -> WeatherSnapshot {
        struct Response: Decodable {
            struct Current: Decodable {
                var temperature_2m: Double
                var weather_code: Int
            }
            struct Daily: Decodable {
                var temperature_2m_max: [Double]
                var temperature_2m_min: [Double]
                var precipitation_probability_max: [Int?]
            }
            var current: Current
            var daily: Daily
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        return WeatherSnapshot(
            temperature: response.current.temperature_2m,
            high: response.daily.temperature_2m_max.first ?? response.current.temperature_2m,
            low: response.daily.temperature_2m_min.first ?? response.current.temperature_2m,
            precipitationChance: (response.daily.precipitation_probability_max.first ?? nil) ?? 0,
            code: response.current.weather_code)
    }

    private func currentLocation() async -> CLLocation? {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return nil
        default:
            break
        }
        return await withCheckedContinuation { continuation in
            locationContinuation?.resume(returning: nil)
            locationContinuation = continuation
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            } else {
                locationManager.requestLocation()
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard self.locationContinuation != nil else { return }
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .denied, .restricted:
                self.finishLocation(nil)
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in self.finishLocation(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finishLocation(nil) }
    }

    private func finishLocation(_ location: CLLocation?) {
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    // MARK: Calendar

    private func loadEvents() async {
        calendarError = nil
        let granted: Bool
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            granted = true
        case .notDetermined:
            granted = (try? await eventStore.requestFullAccessToEvents()) ?? false
        default:
            granted = false
        }
        guard granted else {
            calendarError = "Allow calendar access to see today's plans."
            events = []
            return
        }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(6)
            .map { BriefingEvent(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "Event",
                                 start: $0.startDate, isAllDay: $0.isAllDay) }
    }
}

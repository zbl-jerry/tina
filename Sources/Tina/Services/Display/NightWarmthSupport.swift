// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// What the schedule is asking for right now. `paused` is a state the service
/// adds on top of the schedule, never something the schedule works out itself.
enum NightWarmthPhase: String, Equatable {
    case day, evening, bedtime, paused
}

/// How the night window is decided. `sun` follows the sun for the configured
/// coordinates; `custom` uses two clock times and never needs a location.
enum NightWarmthScheduleMode: String, CaseIterable, Equatable {
    case sun, custom
}

/// The two transition speeds Luz offers. A full range fade takes the whole
/// duration, so a slow fade moves a few kelvin a second and a fast one is
/// visibly quick without stepping.
enum NightWarmthTransition: Int, CaseIterable, Equatable {
    case slow = 3600
    case fast = 20

    var seconds: TimeInterval { TimeInterval(rawValue) }
}

/// The temperatures the panel offers as one-tap presets, warmest last. They
/// are the f.lux/Luz steps, which users already recognise.
enum NightWarmthPreset {
    static let kelvins: [Double] = [6500, 5500, 4200, 3400, 2700, 1900, 1200]
    static let warmest: Double = 1200
    static let neutral: Double = 6500
}

/// Everything the schedule needs, read out of preferences once per tick so a
/// change lands on the next second instead of needing a restart.
struct NightWarmthModel: Equatable {
    var mode: NightWarmthScheduleMode = .sun
    var dayKelvin: Double = NightWarmthPreset.neutral
    var eveningKelvin: Double = 3400
    var bedtimeKelvin: Double = 2700
    var bedtimeEnabled = false
    /// Minutes after local midnight. The bedtime window may wrap midnight.
    var bedtimeMinutes = 23 * 60
    var wakeMinutes = 7 * 60
    /// Custom mode's night window, also allowed to wrap midnight.
    var nightStartMinutes = 21 * 60
    var nightEndMinutes = 7 * 60
    var latitude: Double = 0
    var longitude: Double = 0
    var hasLocation = false
}

struct SolarEvents: Equatable {
    let sunrise: Date?
    let sunset: Date?

    static let none = SolarEvents(sunrise: nil, sunset: nil)
}

/// What the schedule wants at one instant, with the next boundary so the panel
/// can say what happens next.
struct NightWarmthState: Equatable {
    let phase: NightWarmthPhase
    let targetKelvin: Double
    let nextChange: Date?
    let nextPhase: NightWarmthPhase?
}

/// One set of gamma tables: the identity at the neutral temperature, the
/// configured warmth further down the scale.
/// CoreGraphics takes the table as `Float` (`CGGammaValue`), not `CGFloat`.
struct NightWarmthRamp: Equatable {
    let red: [Float]
    let green: [Float]
    let blue: [Float]
}

/// Pure decisions for the night warmth layer, kept free of AppKit and of any
/// display so the unit tests can pin the schedule, the solar maths and the
/// gamma ramp without a Mac attached to a monitor.
///
/// The warmth is a gamma table per display, the same public CoreGraphics path
/// f.lux and Night Shift-style tools use. It tintes every pixel, needs no
/// permission, writes nothing to disk, and dies with the process; restoring
/// the identity table is therefore the whole cleanup.
enum NightWarmthSupport {
    /// A table this size is what the window server expects and what keeps the
    /// ramp smooth enough that a gradient does not band.
    static let tableSize = 256

    /// The schedule never asks for anything outside the preset range.
    static func clampedKelvin(_ kelvin: Double) -> Double {
        min(max(kelvin, NightWarmthPreset.warmest), NightWarmthPreset.neutral)
    }

    // MARK: - Mired interpolation

    /// Warmth is interpolated in mireds, not kelvin: the visible change between
    /// 6500 K and 6000 K is far smaller than between 2000 K and 1500 K, and a
    /// kelvin-linear fade looks like it stalls and then lurches.
    static func mired(_ kelvin: Double) -> Double {
        1_000_000 / max(kelvin, 1)
    }

    static func kelvin(_ mired: Double) -> Double {
        1_000_000 / max(mired, 1)
    }

    static func interpolateKelvin(from: Double, to: Double, progress: Double) -> Double {
        let t = min(max(progress, 0), 1)
        let fromMired = mired(clampedKelvin(from))
        let toMired = mired(clampedKelvin(to))
        return kelvin(fromMired + (toMired - fromMired) * t)
    }

    // MARK: - Color

    /// Linear sRGB of a Planckian radiator at `kelvin`, normalised so 6500 K
    /// is exactly white and the brightest channel is 1. Relative to 6500 K
    /// rather than to the raw blackbody, because the neutral end must leave
    /// the display untouched instead of tinting it slightly red.
    ///
    /// Uses the Kim et al. cubic approximation of the Planckian locus, which
    /// is accurate over the whole 1200–6500 K range this feature uses.
    static func whitePoint(kelvin: Double) -> (red: Double, green: Double, blue: Double) {
        let raw = planckianRGB(kelvin: clampedKelvin(kelvin))
        let neutral = planckianRGB(kelvin: NightWarmthPreset.neutral)
        var red = raw.red / neutral.red
        var green = raw.green / neutral.green
        var blue = raw.blue / neutral.blue
        let peak = max(red, green, blue)
        guard peak > 0 else { return (1, 1, 1) }
        red /= peak
        green /= peak
        blue /= peak
        return (red, green, blue)
    }

    private static func planckianRGB(kelvin: Double) -> (red: Double, green: Double, blue: Double) {
        let t = min(max(kelvin, 1000), 40_000)
        let x: Double
        if t <= 4000 {
            x = -0.2661239e9 / (t * t * t) - 0.2343589e6 / (t * t) + 0.8776956e3 / t + 0.179910
        } else {
            x = -3.0258469e9 / (t * t * t) + 2.1070379e6 / (t * t) + 0.2226347e3 / t + 0.240390
        }
        let y: Double
        if t <= 2222 {
            y = -1.1063814 * x * x * x - 1.34811020 * x * x + 2.18555832 * x - 0.20219683
        } else if t <= 4000 {
            y = -0.9549476 * x * x * x - 1.37418593 * x * x + 2.09137015 * x - 0.16748867
        } else {
            y = 3.0817580 * x * x * x - 5.87338670 * x * x + 3.75112997 * x - 0.37001483
        }
        guard y > 0 else { return (1, 1, 1) }
        // XYZ with Y = 1, converted to linear sRGB.
        let capitalX = x / y
        let capitalZ = (1 - x - y) / y
        let red = max(0, 3.2404542 * capitalX - 1.5371385 - 0.4985314 * capitalZ)
        let green = max(0, -0.9692660 * capitalX + 1.8760108 + 0.0415560 * capitalZ)
        let blue = max(0, 0.0556434 * capitalX - 0.2040259 + 1.0572252 * capitalZ)
        return (red, green, blue)
    }

    /// The three tables for one display. `strength` blends the tint back
    /// toward the identity, so a partial strength dims the effect without
    /// changing its colour temperature.
    static func ramp(kelvin: Double,
                     strength: Double = 1,
                     tableSize: Int = tableSize) -> NightWarmthRamp {
        let size = max(tableSize, 2)
        let point = whitePoint(kelvin: kelvin)
        let amount = min(max(strength, 0), 1)
        let redScale = 1 + (point.red - 1) * amount
        let greenScale = 1 + (point.green - 1) * amount
        let blueScale = 1 + (point.blue - 1) * amount
        var red = [Float](repeating: 0, count: size)
        var green = [Float](repeating: 0, count: size)
        var blue = [Float](repeating: 0, count: size)
        for index in 0..<size {
            let input = Double(index) / Double(size - 1)
            red[index] = Float(input * redScale)
            green[index] = Float(input * greenScale)
            blue[index] = Float(input * blueScale)
        }
        return NightWarmthRamp(red: red, green: green, blue: blue)
    }

    static var identityRamp: NightWarmthRamp {
        ramp(kelvin: NightWarmthPreset.neutral)
    }

    // MARK: - Schedule

    /// The state at one instant. `pausedUntil` is folded in here, so the
    /// service and the panel cannot disagree about whether a pause has ended.
    static func state(at date: Date,
                      model: NightWarmthModel,
                      timeZone: TimeZone,
                      pausedUntil: Date? = nil) -> NightWarmthState {
        let base = baseState(at: date, model: model, timeZone: timeZone)
        guard let pausedUntil, pausedUntil > date else { return base }
        let resumePhase = base.phase
        if let nextChange = base.nextChange, nextChange < pausedUntil {
            return NightWarmthState(phase: .paused, targetKelvin: model.dayKelvin,
                                    nextChange: nextChange, nextPhase: base.nextPhase)
        }
        return NightWarmthState(phase: .paused, targetKelvin: model.dayKelvin,
                                nextChange: pausedUntil, nextPhase: resumePhase)
    }

    private static func baseState(at date: Date,
                                  model: NightWarmthModel,
                                  timeZone: TimeZone) -> NightWarmthState {
        let calendar = calendar(timeZone)
        let events = effectiveEvents(for: date, model: model, calendar: calendar)
        let phase = basePhase(at: date, model: model, calendar: calendar, events: events)
        let target = targetKelvin(for: phase, model: model)
        let next = nextBoundary(after: date, model: model, calendar: calendar, events: events)
        return NightWarmthState(phase: phase, targetKelvin: target,
                                nextChange: next?.date, nextPhase: next?.phase)
    }

    static func targetKelvin(for phase: NightWarmthPhase, model: NightWarmthModel) -> Double {
        switch phase {
        case .day, .paused: return clampedKelvin(model.dayKelvin)
        case .evening: return clampedKelvin(model.eveningKelvin)
        case .bedtime: return clampedKelvin(model.bedtimeKelvin)
        }
    }

    private static func basePhase(at date: Date,
                                  model: NightWarmthModel,
                                  calendar: Calendar,
                                  events: SolarEvents) -> NightWarmthPhase {
        if model.bedtimeEnabled {
            let bedtime = Self.date(on: date, minutes: model.bedtimeMinutes, calendar: calendar)
            let wake = Self.date(on: date, minutes: model.wakeMinutes, calendar: calendar)
            if isWithin(date, start: bedtime, end: wake) { return .bedtime }
        }
        let sunrise = events.sunrise ?? fallbackTime(6 * 60, on: date, calendar: calendar)
        let sunset = events.sunset ?? fallbackTime(18 * 60, on: date, calendar: calendar)
        let isNight: Bool
        switch model.mode {
        case .sun:
            isNight = date < sunrise || date >= sunset
        case .custom:
            let start = Self.date(on: date, minutes: model.nightStartMinutes, calendar: calendar)
            let end = Self.date(on: date, minutes: model.nightEndMinutes, calendar: calendar)
            isNight = isWithin(date, start: start, end: end)
        }
        return isNight ? .evening : .day
    }

    /// The next instant the schedule changes, with the phase it changes into.
    /// Boundaries are collected for yesterday, today and tomorrow, which
    /// covers every window that wraps midnight without special cases.
    private static func nextBoundary(after date: Date,
                                     model: NightWarmthModel,
                                     calendar: Calendar,
                                     events: SolarEvents) -> (date: Date, phase: NightWarmthPhase)? {
        var boundaries: [Date] = []
        for offset in -1...1 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            switch model.mode {
            case .sun:
                let dayEvents = solarEvents(for: day, latitude: model.latitude,
                                            longitude: model.longitude, timeZone: calendar.timeZone)
                if let sunrise = dayEvents.sunrise {
                    boundaries.append(sunrise)
                } else {
                    boundaries.append(fallbackTime(6 * 60, on: day, calendar: calendar))
                }
                if let sunset = dayEvents.sunset {
                    boundaries.append(sunset)
                } else {
                    boundaries.append(fallbackTime(18 * 60, on: day, calendar: calendar))
                }
            case .custom:
                boundaries.append(Self.date(on: day, minutes: model.nightStartMinutes, calendar: calendar))
                boundaries.append(Self.date(on: day, minutes: model.nightEndMinutes, calendar: calendar))
            }
            if model.bedtimeEnabled {
                boundaries.append(Self.date(on: day, minutes: model.bedtimeMinutes, calendar: calendar))
                boundaries.append(Self.date(on: day, minutes: model.wakeMinutes, calendar: calendar))
            }
        }
        let upcoming = boundaries.filter { $0 > date }.sorted()
        guard let next = upcoming.first else { return nil }
        let after = basePhase(at: next.addingTimeInterval(1), model: model,
                              calendar: calendar, events: events)
        return (next, after)
    }

    // MARK: - Solar

    /// Sunrise and sunset for the local day containing `day`. Nil each when the
    /// sun does not cross the horizon, which the caller replaces with a plain
    /// evening schedule rather than pretending to know.
    static func solarEvents(for day: Date,
                            latitude: Double,
                            longitude: Double,
                            timeZone: TimeZone) -> SolarEvents {
        let calendar = calendar(timeZone)
        guard let start = calendar.dateInterval(of: .day, for: day)?.start else { return .none }
        let noon = start.addingTimeInterval(12 * 3600)
        let julianDay = noon.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let n = (julianDay - 2_451_545.0 + 0.0008).rounded(.down)
        // J* moves the day's transit to the observer's meridian: solar noon
        // arrives earlier east of Greenwich, so an east longitude subtracts.
        let jStar = n - longitude / 360
        let meanAnomaly = normalize(357.5291 + 0.98560028 * jStar)
        let equation = 1.9148 * sine(meanAnomaly)
            + 0.02 * sine(2 * meanAnomaly)
            + 0.0003 * sine(3 * meanAnomaly)
        let eclipticLongitude = normalize(meanAnomaly + equation + 180 + 102.9372)
        let transit = 2_451_545.0 + jStar
            + 0.0053 * sine(meanAnomaly)
            - 0.0069 * sine(2 * eclipticLongitude)
        let declination = asin(sine(eclipticLongitude) * sine(23.4397))
        let latitudeRadians = radians(latitude)
        let numerator = sine(-0.833) - sin(latitudeRadians) * sin(declination)
        let denominator = cos(latitudeRadians) * cos(declination)
        guard abs(denominator) > 1e-9 else { return .none }
        let cosHourAngle = numerator / denominator
        guard cosHourAngle >= -1, cosHourAngle <= 1 else { return .none }
        let hourAngle = degrees(acos(cosHourAngle))
        return SolarEvents(sunrise: julianDate(transit - hourAngle / 360),
                           sunset: julianDate(transit + hourAngle / 360))
    }

    /// A day whose sun never rises or never sets still needs a schedule the
    /// user can predict, so it falls back to 18:00–06:00 local.
    private static func effectiveEvents(for date: Date,
                                        model: NightWarmthModel,
                                        calendar: Calendar) -> SolarEvents {
        guard model.mode == .sun else { return .none }
        return solarEvents(for: date, latitude: model.latitude,
                           longitude: model.longitude, timeZone: calendar.timeZone)
    }

    private static func julianDate(_ julianDay: Double) -> Date {
        Date(timeIntervalSince1970: (julianDay - 2_440_587.5) * 86_400)
    }

    // MARK: - Location

    /// A representative coordinate for a time zone, so the sun schedule works
    /// on first launch without asking for location access or touching the
    /// network. The manual coordinates in Settings replace it when the zone
    /// spans a region whose sunset is far from its anchor city.
    static func suggestedLocation(for timeZone: TimeZone) -> (latitude: Double, longitude: Double) {
        let anchors: [String: (Double, Double)] = [
            "Asia/Shanghai": (31.23, 121.47),
            "Asia/Hong_Kong": (22.32, 114.17),
            "Asia/Taipei": (25.03, 121.57),
            "Asia/Tokyo": (35.68, 139.69),
            "Asia/Seoul": (37.57, 126.98),
            "Asia/Singapore": (1.35, 103.82),
            "Asia/Bangkok": (13.76, 100.50),
            "Asia/Jakarta": (-6.21, 106.85),
            "Asia/Kolkata": (19.08, 72.88),
            "Asia/Dubai": (25.20, 55.27),
            "Europe/London": (51.51, -0.13),
            "Europe/Paris": (48.86, 2.35),
            "Europe/Berlin": (52.52, 13.41),
            "Europe/Madrid": (40.42, -3.70),
            "Europe/Rome": (41.90, 12.50),
            "Europe/Warsaw": (52.23, 21.01),
            "Europe/Bratislava": (48.15, 17.11),
            "Europe/Kyiv": (50.45, 30.52),
            "Europe/Istanbul": (41.01, 28.98),
            "Europe/Moscow": (55.76, 37.62),
            "America/New_York": (40.71, -74.01),
            "America/Chicago": (41.88, -87.63),
            "America/Denver": (39.74, -104.99),
            "America/Los_Angeles": (34.05, -118.24),
            "America/Sao_Paulo": (-23.55, -46.63),
            "Australia/Sydney": (-33.87, 151.21),
            "Australia/Perth": (-31.95, 115.86),
            "Pacific/Auckland": (-36.85, 174.76),
            "Africa/Cairo": (30.04, 31.24),
        ]
        if let anchor = anchors[timeZone.identifier] { return anchor }
        // A zone with no anchor city still gets a plausible meridian: solar
        // noon sits roughly at the zone's standard meridian, and the equator
        // keeps the error seasonal rather than minute-exact.
        let hours = Double(timeZone.secondsFromGMT()) / 3600
        return (0, hours * 15)
    }

    // MARK: - Helpers

    static func calendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func date(on day: Date, minutes: Int, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: day)
        return start.addingTimeInterval(TimeInterval(minutes * 60))
    }

    private static func fallbackTime(_ minutes: Int, on day: Date, calendar: Calendar) -> Date {
        Self.date(on: day, minutes: minutes, calendar: calendar)
    }

    /// Whether `date` falls in a window that may wrap midnight. The end is
    /// exclusive, so the boundary instant itself belongs to the next phase
    /// and the service never shows two phases at once.
    static func isWithin(_ date: Date, start: Date, end: Date) -> Bool {
        if start <= end {
            return date >= start && date < end
        }
        return date >= start || date < end
    }

    private static func normalize(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
    private static func sine(_ degrees: Double) -> Double { sin(radians(degrees)) }
}

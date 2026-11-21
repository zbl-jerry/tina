// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// The night warmth schedule, the solar maths and the gamma ramp are pure
/// decisions, so they are pinned here without touching a display.
enum NightWarmthTests {
    private static func date(_ year: Int, _ month: Int, _ day: Int,
                             _ hour: Int, _ minute: Int, timeZone: TimeZone) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: components)!
    }

    private static func minutes(_ date: Date, timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    static func run(_ suite: TestSuite) {
        let shanghai = TimeZone(identifier: "Asia/Shanghai")!
        let tromso = TimeZone(identifier: "Europe/Oslo")!

        // MARK: Mired interpolation

        suite.expect(abs(NightWarmthSupport.mired(6500) - 153.8) < 0.1,
                     "6500 K is 153.8 mired")
        suite.expect(abs(NightWarmthSupport.kelvin(NightWarmthSupport.mired(2700)) - 2700) < 0.001,
                     "mired round-trips")
        let midpoint = NightWarmthSupport.interpolateKelvin(from: 6500, to: 2700, progress: 0.5)
        suite.expect(midpoint > 3000 && midpoint < 4300,
                     "mired midpoint of 6500 and 2700 lands near 3600 K, got \(midpoint)")
        suite.expect(abs(NightWarmthSupport.interpolateKelvin(from: 6500, to: 2700, progress: 0) - 6500) < 0.001,
                     "progress 0 is the start temperature")
        suite.expect(abs(NightWarmthSupport.interpolateKelvin(from: 6500, to: 2700, progress: 1) - 2700) < 0.001,
                     "progress 1 is the end temperature")
        suite.expect(NightWarmthSupport.interpolateKelvin(from: 6500, to: 2700, progress: 2) == 2700,
                     "progress past 1 clamps")

        // MARK: White point and ramps

        let neutral = NightWarmthSupport.whitePoint(kelvin: 6500)
        suite.expect(abs(neutral.red - 1) < 0.0001 && abs(neutral.green - 1) < 0.0001
                     && abs(neutral.blue - 1) < 0.0001,
                     "6500 K is the identity")
        let evening = NightWarmthSupport.whitePoint(kelvin: 3400)
        suite.expect(evening.blue < 0.6 && evening.blue > 0.15,
                     "3400 K lowers blue without removing it, got \(evening.blue)")
        suite.expect(evening.red >= evening.green - 0.01, "warmth keeps red at or above green")
        let bedtimePoint = NightWarmthSupport.whitePoint(kelvin: 1900)
        suite.expect(bedtimePoint.blue < evening.blue,
                     "warmer temperatures lower blue further")
        suite.expect(NightWarmthSupport.clampedKelvin(800) == 1200
                     && NightWarmthSupport.clampedKelvin(12_000) == 6500,
                     "temperatures clamp to the preset range")

        let identityRamp = NightWarmthSupport.ramp(kelvin: 6500)
        suite.expect(identityRamp.red.count == NightWarmthSupport.tableSize,
                     "the ramp has the table size the window server expects")
        suite.expect(abs(identityRamp.red[128] - Float(128) / Float(255)) < 0.0001,
                     "the neutral ramp is the identity")
        suite.expect(identityRamp.red == identityRamp.green && identityRamp.green == identityRamp.blue,
                     "identity channels are equal")
        let warm = NightWarmthSupport.ramp(kelvin: 2700)
        suite.expect(warm.blue.last! < warm.red.last!,
                     "a warm ramp ends lower in blue than in red")
        suite.expect(warm.red.last! >= 0.99, "the brightest channel is preserved")
        let muted = NightWarmthSupport.ramp(kelvin: 2700, strength: 0)
        suite.expect(muted == identityRamp, "zero strength is the identity")

        // MARK: Solar

        let june = date(2026, 6, 21, 12, 0, timeZone: shanghai)
        let juneEvents = NightWarmthSupport.solarEvents(for: june, latitude: 31.23,
                                                        longitude: 121.47, timeZone: shanghai)
        if let sunrise = juneEvents.sunrise {
            let value = minutes(sunrise, timeZone: shanghai)
            suite.expect(value >= 4 * 60 + 20 && value <= 5 * 60 + 20,
                         "Shanghai sunrise on the solstice is near 04:50, got \(value / 60):\(value % 60)")
        } else {
            suite.expect(false, "Shanghai has a sunrise on the solstice")
        }
        if let sunset = juneEvents.sunset {
            let value = minutes(sunset, timeZone: shanghai)
            suite.expect(value >= 18 * 60 + 40 && value <= 19 * 60 + 20,
                         "Shanghai sunset on the solstice is near 19:00, got \(value / 60):\(value % 60)")
        } else {
            suite.expect(false, "Shanghai has a sunset on the solstice")
        }
        let december = date(2026, 12, 21, 12, 0, timeZone: shanghai)
        let decemberEvents = NightWarmthSupport.solarEvents(for: december, latitude: 31.23,
                                                            longitude: 121.47, timeZone: shanghai)
        if let sunrise = decemberEvents.sunrise, let sunset = decemberEvents.sunset {
            suite.expect(minutes(sunset, timeZone: shanghai) < 17 * 60 + 30,
                         "Shanghai sunset in December is before 17:30")
            suite.expect(minutes(sunrise, timeZone: shanghai) > 6 * 60,
                         "Shanghai sunrise in December is after 06:00")
        }
        let polar = NightWarmthSupport.solarEvents(for: december, latitude: 69.65,
                                                   longitude: 18.96, timeZone: tromso)
        suite.expect(polar.sunrise == nil && polar.sunset == nil,
                     "a polar night reports no sunrise or sunset")

        // MARK: Custom schedule

        let custom = NightWarmthModel(
            mode: .custom,
            dayKelvin: 6500,
            eveningKelvin: 3400,
            bedtimeKelvin: 2700,
            bedtimeEnabled: false,
            nightStartMinutes: 21 * 60,
            nightEndMinutes: 7 * 60
        )
        let noon = date(2026, 6, 21, 12, 0, timeZone: shanghai)
        let lateEvening = date(2026, 6, 21, 22, 0, timeZone: shanghai)
        let earlyMorning = date(2026, 6, 21, 3, 0, timeZone: shanghai)
        let noonState = NightWarmthSupport.state(at: noon, model: custom, timeZone: shanghai)
        suite.expect(noonState.phase == .day && noonState.targetKelvin == 6500,
                     "noon is daytime at the daytime temperature")
        let eveningState = NightWarmthSupport.state(at: lateEvening, model: custom, timeZone: shanghai)
        suite.expect(eveningState.phase == .evening && eveningState.targetKelvin == 3400,
                     "22:00 is the evening at the evening temperature")
        let morningState = NightWarmthSupport.state(at: earlyMorning, model: custom, timeZone: shanghai)
        suite.expect(morningState.phase == .evening,
                     "03:00 still belongs to the night that started yesterday")
        if let next = eveningState.nextChange {
            suite.expect(minutes(next, timeZone: shanghai) == 7 * 60 && eveningState.nextPhase == .day,
                         "the next change after 22:00 is 07:00, back to daytime")
        } else {
            suite.expect(false, "the evening has a next change")
        }

        // MARK: Bedtime

        var bedtime = custom
        bedtime.bedtimeEnabled = true
        bedtime.bedtimeMinutes = 23 * 60
        bedtime.wakeMinutes = 7 * 60
        let bedtimeState = NightWarmthSupport.state(
            at: date(2026, 6, 21, 23, 30, timeZone: shanghai),
            model: bedtime, timeZone: shanghai)
        suite.expect(bedtimeState.phase == .bedtime && bedtimeState.targetKelvin == 2700,
                     "23:30 is bedtime")
        let beforeWake = NightWarmthSupport.state(
            at: date(2026, 6, 22, 6, 30, timeZone: shanghai),
            model: bedtime, timeZone: shanghai)
        suite.expect(beforeWake.phase == .bedtime,
                     "the bedtime window wraps midnight")
        let afterWake = NightWarmthSupport.state(
            at: date(2026, 6, 22, 8, 0, timeZone: shanghai),
            model: bedtime, timeZone: shanghai)
        suite.expect(afterWake.phase == .day,
                     "after the wake time the daytime temperature returns")

        // MARK: Pause

        let paused = NightWarmthSupport.state(
            at: lateEvening, model: custom, timeZone: shanghai,
            pausedUntil: lateEvening.addingTimeInterval(3600))
        suite.expect(paused.phase == .paused && paused.targetKelvin == 6500,
                     "a pause returns the neutral temperature")
        suite.expect(paused.nextChange == lateEvening.addingTimeInterval(3600),
                     "the pause ends at its own deadline")
        let expired = NightWarmthSupport.state(
            at: lateEvening, model: custom, timeZone: shanghai,
            pausedUntil: lateEvening.addingTimeInterval(-1))
        suite.expect(expired.phase == .evening,
                     "an expired pause is ignored")

        // MARK: Location

        let suggested = NightWarmthSupport.suggestedLocation(for: shanghai)
        suite.expect(abs(suggested.latitude - 31.23) < 0.01
                     && abs(suggested.longitude - 121.47) < 0.01,
                     "Shanghai maps to its anchor city")
        let unanchored = NightWarmthSupport.suggestedLocation(
            for: TimeZone(secondsFromGMT: 3 * 3600)!)
        suite.expect(unanchored.longitude == 45,
                     "an unknown zone falls back to its standard meridian")
        suite.expect(abs(unanchored.latitude) < 0.001,
                     "the meridian fallback uses the equator")
    }
}

import Foundation
import Testing

@testable import EyeCareCore

private let origin = Date(timeIntervalSince1970: 1_800_000_000)
private var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(identifier: "Europe/Sofia")!
    return value
}
private func date(
    _ year: Int = 2026, _ month: Int = 11, _ day: Int = 2, _ hour: Int = 12, _ minute: Int = 0
) -> Date {
    calendar.date(
        from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

@Test func aDueReminderDoesNotCountAsARest() {
    var clock = BreakClock(now: origin)
    let completed1 = clock.advance(to: origin.addingTimeInterval(1200))
    #expect(!completed1)
    #expect(clock.phase == .due)
    let completed2 = clock.advance(to: origin.addingTimeInterval(5000))
    #expect(!completed2)
    #expect(clock.phase == .due)
}

@Test func explicitRestCompletesOnlyAfterTwentySeconds() {
    var clock = BreakClock(now: origin)
    clock.startRest(at: origin)
    let completed3 = clock.advance(to: origin.addingTimeInterval(19.99))
    #expect(!completed3)
    let completed4 = clock.advance(to: origin.addingTimeInterval(20))
    #expect(completed4)
    #expect(clock.phase == .focus)
    #expect(clock.remaining(at: origin.addingTimeInterval(20)) == 1200)
    let completed5 = clock.advance(to: origin.addingTimeInterval(21))
    #expect(!completed5)
}

@Test func sleepOrPauseDoesNotFinishARest() {
    var clock = BreakClock(now: origin)
    clock.startRest(at: origin)
    clock.pause(at: origin.addingTimeInterval(7))
    #expect(clock.remaining(at: origin.addingTimeInterval(300)) == 13)
    let completed6 = clock.advance(to: origin.addingTimeInterval(300))
    #expect(!completed6)
    clock.pause(at: origin.addingTimeInterval(301))  // repeated pause is idempotent
    clock.resume(at: origin.addingTimeInterval(600))
    let completed7 = clock.advance(to: origin.addingTimeInterval(612))
    #expect(!completed7)
    let completed8 = clock.advance(to: origin.addingTimeInterval(613))
    #expect(completed8)
}

@Test func pausePreservesWorkAndSnoozeStartsFiveMinutes() {
    var clock = BreakClock(now: origin)
    clock.pause(at: origin.addingTimeInterval(100))
    clock.resume(at: origin.addingTimeInterval(1000))
    #expect(clock.remaining(at: origin.addingTimeInterval(1000)) == 1100)
    clock.reset(at: origin.addingTimeInterval(1000), duration: 300)
    #expect(clock.remaining(at: origin.addingTimeInterval(1000)) == 300)
}

@Test func scheduleUsesFixedTimesAndSkipsPastOrCompletedSlots() {
    var data = CareData()
    data.settings.dropsEnabled = true
    data.events.append(
        CareEvent(
            date: date(2026, 11, 2, 13, 45), kind: .drops,
            scheduledTime: DropTime(hour: 14, minute: 0)))
    let schedule = DropSchedule.upcoming(data: data, after: date(), days: 2, calendar: calendar)
    #expect(
        schedule.map(\.date) == [
            date(2026, 11, 2, 19), date(2026, 11, 3, 9), date(2026, 11, 3, 14),
            date(2026, 11, 3, 19),
        ])
    #expect(Set(schedule.map(\.id)).count == schedule.count)
}

@Test func disabledRemindersAndDuplicateSlots() {
    var data = CareData()
    #expect(DropSchedule.upcoming(data: data, after: date(), calendar: calendar).isEmpty)
    data.settings.dropsEnabled = true
    data.settings.dropTimes = [DropTime(hour: 14, minute: 0), DropTime(hour: 14, minute: 0)]
    #expect(
        DropSchedule.upcoming(data: data, after: date(), days: 1, calendar: calendar).count == 1)
    #expect(DropSchedule.upcoming(data: data, after: date(), days: 0, calendar: calendar).isEmpty)
}

@Test func recurrenceKeepsLocalTimeAcrossDaylightSaving() {
    var data = CareData()
    data.settings.dropsEnabled = true
    data.settings.dropTimes = [DropTime(hour: 9, minute: 0)]
    let schedule = DropSchedule.upcoming(
        data: data, after: date(2026, 10, 24, 8), days: 3, calendar: calendar)
    #expect(schedule.count == 3)
    #expect(schedule.allSatisfy { calendar.component(.hour, from: $0.date) == 9 })
    #expect(schedule[1].date.timeIntervalSince(schedule[0].date) == 25 * 3600)
}

@Test func logMatchesDueSlotAndUndoRestoresIt() {
    var data = CareData()
    data.settings.dropsEnabled = true
    let slot = data.slotToLog(at: date(), calendar: calendar)
    #expect(slot == DropTime(hour: 9, minute: 0))
    let event = CareEvent(date: date(), kind: .drops, scheduledTime: slot)
    data.events.append(event)
    #expect(data.isCompleted(slot!, on: date(), calendar: calendar))
    #expect(data.slotToLog(at: date(), calendar: calendar) == nil)
    data.removeEvent(id: event.id)
    #expect(!data.isCompleted(slot!, on: date(), calendar: calendar))
}

@Test func lateNotificationActionCompletesItsOriginalDay() {
    var data = CareData()
    let slot = DropTime(hour: 19, minute: 0)
    data.events.append(
        CareEvent(
            date: date(2026, 11, 3, 0, 5), kind: .drops, scheduledTime: slot,
            scheduledDay: date(2026, 11, 2, 19)))
    #expect(data.isCompleted(slot, on: date(2026, 11, 2), calendar: calendar))
    #expect(!data.isCompleted(slot, on: date(2026, 11, 3), calendar: calendar))
    #expect(data.events(on: date(2026, 11, 3), kind: .drops, calendar: calendar).count == 1)
}

@Test func persistenceRoundTripAndMalformedDataPreserved() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = DataStore(url: folder.appendingPathComponent("nested/data.json"))
    #expect(try store.load() == CareData())
    var data = CareData()
    data.settings.dropsEnabled = true
    data.events.append(CareEvent(date: origin, kind: .drops))
    try store.save(data)
    #expect(try store.load() == data)
    let malformed = Data("broken".utf8)
    try malformed.write(to: store.url)
    #expect(throws: (any Error).self) { try store.load() }
    #expect(try Data(contentsOf: store.url) == malformed)
}

@Test func existingSettingsEnableRestSoundWithoutChangingReminderSound() throws {
    let legacy = Data(
        #"{"dropsEnabled":true,"dropTimes":[{"hour":14,"minute":0}],"soundEnabled":false,"showCountdown":true}"#
            .utf8)
    let settings = try JSONDecoder().decode(Settings.self, from: legacy)
    #expect(settings.restSoundEnabled)
    #expect(!settings.soundEnabled)
    #expect(settings.dropsEnabled)
    #expect(settings.showCountdown)
    #expect(settings.dropTimes == [DropTime(hour: 14, minute: 0)])

    var muted = settings
    muted.restSoundEnabled = false
    let encoded = try JSONEncoder().encode(muted)
    #expect(try JSONDecoder().decode(Settings.self, from: encoded) == muted)
}

@Test func endingRestEarlyDoesNotTriggerCompletion() {
    var clock = BreakClock(now: origin)
    clock.startRest(at: origin)
    clock.reset(at: origin.addingTimeInterval(7))
    let completed = clock.advance(to: origin.addingTimeInterval(20))
    #expect(!completed)
    #expect(clock.phase == .focus)
}

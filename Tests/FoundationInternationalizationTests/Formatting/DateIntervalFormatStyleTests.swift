// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// RUN: %target-run-simple-swift
// REQUIRES: executable_test
// REQUIRES: objc_intero

#if canImport(TestSupport)
import TestSupport
#endif

#if canImport(FoundationInternationalization)
@testable import FoundationInternationalization
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

final class DateIntervalFormatStyleTests: XCTestCase {

    let minute: TimeInterval = 60
    let hour: TimeInterval = 60 * 60
    let day: TimeInterval = 60 * 60 * 24
    let enUSLocale = Locale(identifier: "en_US")
    let calendar = Calendar(identifier: .gregorian)
    let timeZone = TimeZone(abbreviation: "GMT")!

    let date = Date(timeIntervalSinceReferenceDate: 0)

    func testDefaultFormatStyle() throws {
        var style = Date.IntervalFormatStyle()
        style.timeZone = timeZone
        // Make sure the default style does produce some output
        XCTAssertGreaterThan(style.format(date ..< date + hour).count, 0)
    }

    func testBasicFormatStyle() throws {
#if FIXED_106570987
        let style = Date.IntervalFormatStyle(locale: enUSLocale, calendar: calendar, timeZone: timeZone)
        XCTAssertEqual(style.format(date..<date + hour), "1/1/01, 12:00 – 1:00\u{202f}AM")
        XCTAssertEqual(style.format(date..<date + day), "1/1/01, 12:00\u{202f}AM – 1/2/01, 12:00\u{202f}AM")
        XCTAssertEqual(style.format(date..<date + day * 32), "1/1/01, 12:00\u{202f}AM – 2/2/01, 12:00\u{202f}AM")
#endif
        let dayStyle = Date.IntervalFormatStyle(date: .long, locale: enUSLocale, calendar: calendar, timeZone: timeZone)
        XCTAssertEqual(dayStyle.format(date..<date + hour), "January 1, 2001")
        XCTAssertEqual(dayStyle.format(date..<date + day), "January 1 – 2, 2001")
        XCTAssertEqual(dayStyle.format(date..<date + day * 32), "January 1 – February 2, 2001")

#if FIXED_106570987
        let timeStyle = Date.IntervalFormatStyle(time: .standard, locale: enUSLocale, calendar: calendar, timeZone: timeZone)
        XCTAssertEqual(timeStyle.format(date..<date + hour), "12:00:00\u{202f}AM – 1:00:00\u{202f}AM")
        XCTAssertEqual(timeStyle.format(date..<date + day), "1/1/2001, 12:00:00\u{202f}AM – 1/2/2001, 12:00:00\u{202f}AM")
        XCTAssertEqual(timeStyle.format(date..<date + day * 32), "1/1/2001, 12:00:00\u{202f}AM – 2/2/2001, 12:00:00\u{202f}AM")

        let dateTimeStyle = Date.IntervalFormatStyle(date:.numeric, time: .shortened, locale: enUSLocale, calendar: calendar, timeZone: timeZone)
        XCTAssertEqual(dateTimeStyle.format(date..<date + hour), "1/1/2001, 12:00 – 1:00\u{202f}AM")
        XCTAssertEqual(dateTimeStyle.format(date..<date + day), "1/1/2001, 12:00\u{202f}AM – 1/2/2001, 12:00\u{202f}AM")
        XCTAssertEqual(dateTimeStyle.format(date..<date + day * 32), "1/1/2001, 12:00\u{202f}AM – 2/2/2001, 12:00\u{202f}AM")
#endif
    }

    func testCustomFields() throws {
        let fullDayStyle = Date.IntervalFormatStyle(locale: enUSLocale, calendar: calendar, timeZone: timeZone).year().month().weekday().day()
        XCTAssertEqual(fullDayStyle.format(date..<date + hour), "Mon, Jan 1, 2001")
        XCTAssertEqual(fullDayStyle.format(date..<date + day), "Mon, Jan 1 – Tue, Jan 2, 2001")
        XCTAssertEqual(fullDayStyle.format(date..<date + day * 32), "Mon, Jan 1 – Fri, Feb 2, 2001")
#if FIXED_106570987
        let timeStyle = Date.IntervalFormatStyle(locale: enUSLocale, calendar: calendar, timeZone: timeZone).hour().timeZone()
        XCTAssertEqual(timeStyle.format(date..<date + hour * 0.5), "12\u{202f}AM GMT")
        XCTAssertEqual(timeStyle.format(date..<date + hour), "12 – 1\u{202f}AM GMT")
        XCTAssertEqual(timeStyle.format(date..<date + hour * 1.5), "12 – 1\u{202f}AM GMT")
        // The date interval range (day) is larger than the specified unit (hour), so ICU fills the missing day parts to ambiguate.
        XCTAssertEqual(timeStyle.format(date..<date + day), "1/1/2001, 12\u{202f}AM GMT – 1/2/2001, 12\u{202f}AM GMT")
        XCTAssertEqual(timeStyle.format(date..<date + day * 32), "1/1/2001, 12\u{202f}AM GMT – 2/2/2001, 12\u{202f}AM GMT")
#endif
        let weekDayStyle = Date.IntervalFormatStyle(locale: enUSLocale, calendar: calendar, timeZone: timeZone).weekday()
        XCTAssertEqual(weekDayStyle.format(date..<date + hour), "Mon")
        XCTAssertEqual(weekDayStyle.format(date..<date + day), "Mon – Tue")
        XCTAssertEqual(weekDayStyle.format(date..<date + day * 32), "Mon – Fri")

#if FIXED_106570987
        // This style doesn't really make sense since the gap between `weekDay` and `hour` makes the result ambiguous. ICU fills the missing pieces on our behalf.
        let weekDayHourStyle = Date.IntervalFormatStyle(locale: enUSLocale, calendar: calendar, timeZone: timeZone).weekday().hour()
        XCTAssertEqual(weekDayHourStyle.format(date..<date + hour), "Mon, 12 – 1\u{202f}AM")
        XCTAssertEqual(weekDayHourStyle.format(date..<date + day), "Mon 1, 12\u{202f}AM – Tue 2, 12\u{202f}AM")
        XCTAssertEqual(weekDayHourStyle.format(date..<date + day * 32), "Mon, 1/1, 12\u{202f}AM – Fri, 2/2, 12\u{202f}AM")
#endif
    }

    func testStyleWithCustomFields() throws {
#if FIXED_106570987
        let dateHourStyle = Date.IntervalFormatStyle(date: .numeric, locale: enUSLocale, calendar: calendar, timeZone: timeZone).hour()
        XCTAssertEqual(dateHourStyle.format(date..<date + hour), "1/1/2001, 12 – 1\u{202f}AM")
        XCTAssertEqual(dateHourStyle.format(date..<date + day), "1/1/2001, 12\u{202f}AM – 1/2/2001, 12\u{202f}AM")
        XCTAssertEqual(dateHourStyle.format(date..<date + day * 32), "1/1/2001, 12\u{202f}AM – 2/2/2001, 12\u{202f}AM")

        let timeMonthDayStyle = Date.IntervalFormatStyle(time: .shortened, locale: enUSLocale, calendar: calendar, timeZone: timeZone).month(.defaultDigits).day()
        XCTAssertEqual(timeMonthDayStyle.format(date..<date + hour), "1/1, 12:00 – 1:00\u{202f}AM")
        XCTAssertEqual(timeMonthDayStyle.format(date..<date + day), "1/1, 12:00\u{202f}AM – 1/2, 12:00\u{202f}AM")
        XCTAssertEqual(timeMonthDayStyle.format(date..<date + day * 32), "1/1, 12:00\u{202f}AM – 2/2, 12:00\u{202f}AM")
#endif
        let noAMPMStyle = Date.IntervalFormatStyle(date: .numeric, time: .shortened, locale: enUSLocale, calendar: calendar, timeZone: timeZone).hour(.defaultDigits(amPM: .omitted))
        XCTAssertEqual(noAMPMStyle.format(date..<date + hour), "1/1/2001, 12:00 – 1:00")
        XCTAssertEqual(noAMPMStyle.format(date..<date + day), "1/1/2001, 12:00 – 1/2/2001, 12:00")
        XCTAssertEqual(noAMPMStyle.format(date..<date + day * 32), "1/1/2001, 12:00 – 2/2/2001, 12:00")
    }

#if FOUNDATION_FRAMWORK
    func testLeadingDotSyntax() {
        let _ = (date..<date + hour).formatted(.interval)
        let _ = (date..<date + hour).formatted()
    }
#endif

    func testForcedHourCycle() {
        let default12 = enUSLocale
        let default12force24 = Locale.localeAsIfCurrent(name: "en_US", overrides: .init(force24Hour: true))
        let default12force12 = Locale.localeAsIfCurrent(name: "en_US", overrides: .init(force12Hour: true))
        let default24 = Locale(identifier: "en_GB")
        let default24force24 = Locale.localeAsIfCurrent(name: "en_GB", overrides: .init(force24Hour: true))
        let default24force12 = Locale.localeAsIfCurrent(name: "en_GB", overrides: .init(force12Hour: true))

        let range = (date..<date + hour)
        let afternoon = (Date(timeIntervalSince1970: 13 * 3600)..<Date(timeIntervalSince1970: 15 * 3600))
        func verify(date: Date.IntervalFormatStyle.DateStyle? = nil, time: Date.IntervalFormatStyle.TimeStyle, locale: Locale, expected: String, file: StaticString = #file, line: UInt = #line) {
            let style = Date.IntervalFormatStyle(date: date, time: time, locale: locale, calendar: calendar, timeZone: timeZone)

            XCTAssertEqual(style.format(range), expected, file: file, line: line)
        }
#if FIXED_106570987
        verify(time: .shortened, locale: default12,        expected: "12:00 – 1:00\u{202f}AM")
#endif
        verify(time: .shortened, locale: default12force24, expected: "00:00 – 01:00")
#if FIXED_106570987
        verify(time: .shortened, locale: default12force12, expected: "12:00 – 1:00\u{202f}AM")
#endif
        verify(time: .shortened, locale: default24,        expected: "00:00–01:00")
        verify(time: .shortened, locale: default24force24, expected: "00:00–01:00")
#if FIXED_106570987
        verify(time: .shortened, locale: default24force12, expected: "12:00–1:00\u{202f}am")
        verify(time: .complete, locale: default12,        expected: "12:00:00\u{202f}AM GMT – 1:00:00\u{202f}AM GMT")
#endif
        verify(time: .complete, locale: default12force24, expected: "00:00:00 GMT – 01:00:00 GMT")
#if FIXED_106570987
        verify(time: .complete, locale: default12force12, expected: "12:00:00\u{202f}AM GMT – 1:00:00\u{202f}AM GMT")
#endif
        verify(time: .complete, locale: default24,        expected: "00:00:00 GMT – 01:00:00 GMT")
        verify(time: .complete, locale: default24force24, expected: "00:00:00 GMT – 01:00:00 GMT")
#if FIXED_106570987
        verify(time: .complete, locale: default24force12, expected: "12:00:00\u{202f}am GMT – 1:00:00\u{202f}am GMT")

        verify(date: .numeric, time: .standard, locale: default12,        expected: "1/1/2001, 12:00:00\u{202f}AM – 1:00:00\u{202f}AM")
#endif
        verify(date: .numeric, time: .standard, locale: default12force24, expected: "1/1/2001, 00:00:00 – 01:00:00")
#if FIXED_106570987
        verify(date: .numeric, time: .standard, locale: default12force12, expected: "1/1/2001, 12:00:00\u{202f}AM – 1:00:00\u{202f}AM")
#endif
        verify(date: .numeric, time: .standard, locale: default24,        expected: "01/01/2001, 00:00:00 – 01:00:00")
        verify(date: .numeric, time: .standard, locale: default24force24, expected: "01/01/2001, 00:00:00 – 01:00:00")
#if FIXED_106570987
        verify(date: .numeric, time: .standard, locale: default24force12, expected: "01/01/2001, 12:00:00\u{202f}am – 1:00:00\u{202f}am")
#endif
        func verify(_ tests: (locale: Locale, expected: String, expectedAfternoon: String)..., file: StaticString = #file, line: UInt = #line, customStyle: (Date.IntervalFormatStyle) -> (Date.IntervalFormatStyle)) {

            let style = customStyle(Date.IntervalFormatStyle(locale: enUSLocale, calendar: calendar, timeZone: timeZone))
            for (i, (locale, expected, expectedAfternoon)) in tests.enumerated() {
                let localizedStyle = style.locale(locale)
                XCTAssertEqual(localizedStyle.format(range), expected, file: file, line: line + UInt(i))
                XCTAssertEqual(localizedStyle.format(afternoon), expectedAfternoon, file: file, line: line + UInt(i))
            }
        }
#if FIXED_106570987
        verify((default12,        "12:00 – 1:00\u{202f}AM", "1:00 – 3:00 PM"),
               (default12force24, "00:00 – 01:00", "13:00 – 15:00"),
               (default24,        "00:00–01:00", "13:00–15:00"),
               (default24force12, "12:00–1:00\u{202f}am", "1:00–3:00\u{202f}pm")) { style in
            style.hour().minute()
        }
#endif

#if FIXED_96909465
        // ICU does not yet support two-digit hour configuration
        verify((default12,        "12:00 – 1:00\u{202f}AM", "01:00 – 03:00 PM"),
               (default12force24, "00:00 – 01:00", "13:00 – 15:00"),
               (default24,        "00:00–01:00", "13:00–15:00"),
               (default24force12, "12:00–1:00\u{202f}am", "01:00–03:00\u{202f}pm")) { style in
            style.hour(.twoDigits(amPM: .abbreviated)).minute()
        }
#endif

        verify((default12,        "12:00 – 1:00", "1:00 – 3:00"),
               (default12force24, "00:00 – 01:00", "13:00 – 15:00"),
               (default24,        "00:00–01:00", "13:00–15:00")) { style in
            style.hour(.twoDigits(amPM: .omitted)).minute()
        }

#if FIXED_97447020
        verify((default24force12, "12:00–1:00", "1:00–3:00")) { style in
            style.hour(.twoDigits(amPM: .omitted)).minute()
        }
#endif

#if FIXED_106570987
        verify((default12,        "Jan 1, 12:00 – 1:00\u{202f}AM", "Jan 1, 1:00 – 3:00 PM"),
               (default12force24, "Jan 1, 00:00 – 01:00", "Jan 1, 13:00 – 15:00"),
               (default24,        "1 Jan, 00:00–01:00", "1 Jan, 13:00–15:00"),
               (default24force12, "1 Jan, 12:00–1:00\u{202f}am", "1 Jan, 1:00–3:00\u{202f}pm")) { style in
            style.month().day().hour().minute()
        }
#endif
    }

}

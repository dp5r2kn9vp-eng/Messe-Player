import Testing
@testable import MessePlayer

struct TimeFormatTests {
    @Test(arguments: [
        (0.0, "0:00.00"), (42.3, "0:42.30"), (65, "1:05.00"), (59.999, "1:00.00"),
        (0.004, "0:00.00"), (0.006, "0:00.01"), (3725.5, "62:05.50"), (-3, "0:00.00"),
    ])
    func formats(seconds: Double, expected: String) {
        #expect(TimeFormat.string(from: seconds) == expected)
    }

    @Test(arguments: [
        ("42", 42.0), ("42.5", 42.5), ("42,5", 42.5), ("1:05", 65), ("0:42.3", 42.3),
        (" 0:42.30 ", 42.3), ("1:02:03", 3723), ("90", 90), ("0", 0), (":30", nil),
    ] as [(String, Double?)])
    func parses(text: String, expected: Double?) {
        #expect(TimeFormat.seconds(from: text) == expected)
    }

    @Test(arguments: ["", "abc", "-5", "1:60", "1:-2", "1:2:3:4", "1:75:00", "x:10", "nan", "inf"])
    func rejectsInvalidInput(text: String) {
        #expect(TimeFormat.seconds(from: text) == nil)
    }

    @Test func formatAndParseRoundTrip() {
        for value in [0.0, 1.25, 42.3, 599.99, 3600] {
            #expect(abs((TimeFormat.seconds(from: TimeFormat.string(from: value)) ?? -1) - value) < 0.000_001)
        }
    }
}

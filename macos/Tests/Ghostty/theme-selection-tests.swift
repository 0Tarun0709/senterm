import Foundation
import Testing
@testable import Ghostty

struct ThemeSelectionTests {
    @Test func saveReplaceAndClearTheme() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let destination = directory.appendingPathComponent("selected-theme.conf")
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(ThemeSelection.savedName(in: destination) == nil)
        try ThemeSelection.save(URL(fileURLWithPath: "/themes/abyssal-trench"), to: destination)
        #expect(ThemeSelection.savedName(in: destination) == "abyssal-trench")
        try ThemeSelection.save(URL(fileURLWithPath: "/themes/3024 Day"), to: destination)
        #expect(ThemeSelection.savedName(in: destination) == "3024 Day")
        #expect(throws: CocoaError.self) {
            try ThemeSelection.save(URL(fileURLWithPath: "/themes/bad\nname"), to: destination)
        }
        #expect(ThemeSelection.savedName(in: destination) == "3024 Day")
        try ThemeSelection.save(nil, to: destination)
        #expect(ThemeSelection.savedName(in: destination) == nil)
    }
}

// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

enum WindowTilingTests {
    static func run(_ suite: TestSuite) {
        layoutTests(suite)
        geometryTests(suite)
        cycleTests(suite)
        actionTests(suite)
    }

    private static func layoutTests(_ suite: TestSuite) {
        suite.expect(WindowTilingLayout.layouts(mode: .all, windowCount: 5) ==
                        [[5], [3, 2], [2, 3], [2, 2, 1], [1, 2, 2]],
                     "tile all starts with one row and cycles distinct five-window grids")
        suite.expect(WindowTilingLayout.layouts(mode: .rows, windowCount: 5) ==
                        [[1, 1, 1, 1, 1], [2, 2, 1], [3, 2]],
                     "rows start one window per row and stop at the per-row limit")
        suite.expect(WindowTilingLayout.layouts(mode: .columns, windowCount: 6) ==
                        [[1, 1, 1, 1, 1, 1], [2, 2, 2], [3, 3]],
                     "columns mirror rows across the vertical axis")
        suite.expect(WindowTilingLayout.layouts(mode: .rows, windowCount: 4) ==
                        [[1, 1, 1, 1], [2, 2]],
                     "two limits describing the same grouping collapse into one layout")
        suite.expect(WindowTilingLayout.layouts(mode: .rows, windowCount: 6, maxPerRow: 1) ==
                        [[1, 1, 1, 1, 1, 1]],
                     "a limit of one keeps the original one-window-per-row behavior")
        suite.expect(WindowTilingLayout.layouts(mode: .all, windowCount: 4) ==
                        [[4], [2, 2], [2, 1, 1], [1, 1, 2]],
                     "tile all includes top-heavy and bottom-heavy grids when they differ, "
                        + "within the default row ceiling")
        suite.expect(WindowTilingLayout.layouts(mode: .all, windowCount: 4,
                                                maxPerRow: 4, maxPerColumn: 4).last
                        == [1, 1, 1, 1],
                     "raising either limit lets tile all use more rows")
        suite.expect(WindowTilingLayout.layouts(mode: .all, windowCount: 1) == [[1]]
                        && WindowTilingLayout.layouts(mode: .rows, windowCount: 1) == [[1]]
                        && WindowTilingLayout.layouts(mode: .rows, windowCount: 0).isEmpty,
                     "a single window fills the display and an empty set has no layout")
        suite.expect(WindowTilingLayout.sanitizedLimit(0) == 1
                        && WindowTilingLayout.sanitizedLimit(2) == 2
                        && WindowTilingLayout.sanitizedLimit(9) == 6,
                     "stored limits are clamped to the offered range")
        suite.expect(WindowTilingLayout.balancedPopulations(count: 5, bands: 2) == [3, 2]
                        && WindowTilingLayout.balancedPopulations(count: 5, bands: 2,
                                                                  extrasAtEnd: true) == [2, 3],
                     "the extra window moves from the first band to the last")
        suite.expect(WindowTilingLayout.balancedPopulations(count: 9, bands: 4) == [3, 2, 2, 2],
                     "unbalanced counts put the remainder in the leading bands")
    }

    private static func geometryTests(_ suite: TestSuite) {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 600)
        let rows = WindowTilingGeometry.frames(in: bounds, populations: [2, 1],
                                               direction: .rows, windowGap: 0)
        suite.expect(rows.count == 3
                        && rows[0] == CGRect(x: 0, y: 300, width: 500, height: 300)
                        && rows[1] == CGRect(x: 500, y: 300, width: 500, height: 300)
                        && rows[2] == CGRect(x: 0, y: 0, width: 1000, height: 300),
                     "rows fill the first row left to right and the last row full width")

        let columns = WindowTilingGeometry.frames(in: bounds, populations: [2, 1],
                                                  direction: .columns, windowGap: 0)
        suite.expect(columns.count == 3
                        && columns[0] == CGRect(x: 0, y: 300, width: 500, height: 300)
                        && columns[1] == CGRect(x: 0, y: 0, width: 500, height: 300)
                        && columns[2] == CGRect(x: 500, y: 0, width: 500, height: 600),
                     "columns fill the first column top to bottom and the last column full height")

        let thirds = WindowTilingGeometry.frames(in: bounds, populations: [3, 2],
                                                 direction: .rows, windowGap: 0)
        suite.expect(thirds.count == 5
                        && thirds[0].maxX == thirds[1].minX
                        && thirds[1].maxX == thirds[2].minX
                        && thirds[2].maxX == bounds.maxX
                        && thirds[0].width + thirds[1].width + thirds[2].width == bounds.width,
                     "shared rounded edges leave no gap or overlap between neighbours")

        let gapped = WindowTilingGeometry.frames(in: bounds, populations: [1, 2],
                                                 direction: .rows, windowGap: 8)
        suite.expect(gapped[0].minY - gapped[1].maxY == 8,
                     "the configured gap is the total distance between two rows")
        suite.expect(gapped[0].minX == bounds.minX && gapped[0].maxX == bounds.maxX
                        && gapped[1].minX == bounds.minX
                        && gapped[2].maxX == bounds.maxX,
                     "the gap is not taken from edges shared with the display")

        let oddBounds = CGRect(x: 0, y: 0, width: 999, height: 601)
        let integral = WindowTilingGeometry.frames(in: oddBounds,
                                                   populations: [3, 3], direction: .rows,
                                                   windowGap: 0)
        suite.expect(integral.allSatisfy { $0 == $0.integral },
                     "every tile lands on whole points")
        suite.expect(integral.allSatisfy { oddBounds.contains($0) }
                        && integral.allSatisfy { $0.width >= 1 && $0.height >= 1 },
                     "rounding never produces an empty or overflowing tile")
    }

    private static func cycleTests(_ suite: TestSuite) {
        let first = CGRect(x: 0, y: 0, width: 500, height: 600)
        let second = CGRect(x: 500, y: 0, width: 500, height: 600)
        let layouts = [[first, second], [first, first], [second, second]]

        suite.expect(WindowTilingCycle.advancedIndex(from: 0, frames: layouts) == 1
                        && WindowTilingCycle.advancedIndex(from: 1, frames: layouts) == 2
                        && WindowTilingCycle.advancedIndex(from: 2, frames: layouts) == 0,
                     "a repeated press advances through the grids in order")
        suite.expect(WindowTilingCycle.advancedIndex(from: 0, frames: [layouts[0], layouts[0]]) == 0,
                     "identical grids never make a press look stuck")
        suite.expect(WindowTilingCycle.matchingIndex(for: [first, second], in: layouts) == 0
                        && WindowTilingCycle.matchingIndex(for: [second, first], in: layouts) == nil,
                     "an intact grid is recognised and a hand-moved window restarts the cycle")
        suite.expect(WindowTilingCycle.matchingIndex(for: [CGRect(x: 2, y: 2, width: 500, height: 600),
                                                           CGRect(x: 502, y: 2, width: 500, height: 600)],
                                                     in: layouts, tolerance: 8) == 0,
                     "the settle tolerance also applies when recognising a grid")

        let sorted = WindowTilingLayout.sortedForTiling([0, 1, 2, 3]) { index in
            switch index {
            case 0: return CGRect(x: 400, y: 0, width: 10, height: 10)
            case 1: return CGRect(x: 0, y: 0, width: 10, height: 10)
            case 2: return CGRect(x: 0, y: 400, width: 10, height: 10)
            default: return CGRect(x: 400, y: 400, width: 10, height: 10)
            }
        }
        suite.expect(sorted == [1, 0, 2, 3],
                     "windows are ordered top to bottom, then left to right")
    }

    private static func actionTests(_ suite: TestSuite) {
        suite.expect(WindowLayoutAction.tileAll.tilingMode == .all
                        && WindowLayoutAction.tileRows.tilingMode == .rows
                        && WindowLayoutAction.tileColumns.tilingMode == .columns
                        && WindowLayoutAction.leftHalf.tilingMode == nil,
                     "only the three tiling actions take the multi-window path")
        suite.expect(WindowLayoutAction.shortcutActions.contains(.tileAll)
                        && WindowLayoutAction.shortcutActions.contains(.tileRows)
                        && WindowLayoutAction.shortcutActions.contains(.tileColumns),
                     "tiling actions can be assigned global shortcuts")
        suite.expect(WindowLayoutAction.tileAll.defaultShortcut == nil
                        && WindowLayoutAction.tileRows.defaultShortcut == nil
                        && WindowLayoutAction.tileColumns.defaultShortcut == nil,
                     "tiling never claims a system-wide shortcut without a choice")
        suite.expect(Set(WindowLayoutAction.allCases.map(\.shortcutID)).count
                        == WindowLayoutAction.allCases.count,
                     "every action has a unique Carbon hotkey identifier")
        suite.expect(WindowLayoutAction.allCases.allSatisfy { !$0.title(FeatureStrings.windowLayout(.enUS))
                .isEmpty && !$0.symbolName.isEmpty },
                     "tiling actions carry a title and a symbol like every other action")

        for language in AppLanguage.allCases {
            let text = WindowTilingStrings.localized(language)
            let fields = [text.title, text.caption, text.tileAll, text.tileRows,
                          text.tileColumns, text.maxPerRow, text.maxPerColumn,
                          text.limitsCaption, text.arrangedFormat, text.partialFormat]
            suite.expect(fields.allSatisfy { !$0.isEmpty },
                         "tiling text is present in \(language.rawValue)")
            suite.expect(TestFormat.parse(text.arrangedFormat)?.arguments == [1: "d"]
                            && TestFormat.parse(text.partialFormat)?.arguments
                                == [1: "d", 2: "d", 3: "d"],
                         "tiling formats keep their argument identities in \(language.rawValue)")
        }
    }
}

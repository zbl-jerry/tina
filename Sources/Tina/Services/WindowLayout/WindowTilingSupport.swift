// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// The three multi-window arrangements. They share one layout engine; the
/// mode only decides how the window count is split into bands and which axis
/// the bands run along.
enum WindowTilingMode: String, CaseIterable {
    /// Balanced rows, fewest rows first. Repeated presses add rows.
    case all
    /// Rows stacked top to bottom, one window per row first.
    case rows
    /// Columns left to right, one window per column first.
    case columns

    var bandDirection: WindowTilingDirection {
        self == .columns ? .columns : .rows
    }
}

enum WindowTilingDirection: Equatable {
    case rows
    case columns
}

extension WindowLayoutAction {
    var tilingMode: WindowTilingMode? {
        switch self {
        case .tileAll: return .all
        case .tileRows: return .rows
        case .tileColumns: return .columns
        default: return nil
        }
    }
}

/// Pure layout generation. No Accessibility, no windows: the service maps the
/// populations returned here onto window identities, so the cycle can be
/// pinned down in tests without a desktop.
enum WindowTilingLayout {
    static let defaultLimit = 3
    static let limitRange: [Int] = [1, 2, 3, 4, 5, 6]

    static func sanitizedLimit(_ value: Int) -> Int {
        min(max(value, limitRange.first ?? 1), limitRange.last ?? defaultLimit)
    }

    static var maxPerRow: Int {
        let stored = UserDefaults.standard.object(forKey: DefaultsKey.windowTilingMaxWindowsPerRow) as? Int
        return sanitizedLimit(stored ?? defaultLimit)
    }

    static var maxPerColumn: Int {
        let stored = UserDefaults.standard.object(forKey: DefaultsKey.windowTilingMaxWindowsPerColumn) as? Int
        return sanitizedLimit(stored ?? defaultLimit)
    }

    /// Candidate band populations for an action, in press order.
    static func layouts(mode: WindowTilingMode,
                        windowCount: Int,
                        maxPerRow: Int = defaultLimit,
                        maxPerColumn: Int = defaultLimit) -> [[Int]] {
        switch mode {
        case .rows:
            return bandLayouts(windowCount: windowCount, limit: maxPerRow)
        case .columns:
            return bandLayouts(windowCount: windowCount, limit: maxPerColumn)
        case .all:
            // Tile all starts from the fewest rows and may use as many rows as
            // the larger of the two limits, so either limit can widen it.
            let ceiling = max(sanitizedLimit(maxPerRow), sanitizedLimit(maxPerColumn))
            return tileAllLayouts(windowCount: windowCount, rowCeiling: ceiling)
        }
    }

    /// Rectangle's band cycle: one window per band first, then fewer bands as
    /// the per-band limit rises. Duplicate band counts (two limits that
    /// describe the same grouping) collapse into one layout.
    static func bandLayouts(windowCount: Int, limit: Int) -> [[Int]] {
        guard windowCount > 0 else { return [] }
        let limit = sanitizedLimit(limit)
        var bandCounts: [Int] = []
        for subdivision in 1...min(windowCount, limit) {
            let bands = 1 + (windowCount - 1) / subdivision
            if bandCounts.last != bands {
                bandCounts.append(bands)
            }
        }
        return bandCounts.map { balancedPopulations(count: windowCount, bands: $0) }
    }

    /// Tile all: fewest rows first, with the extra windows at the top and then
    /// at the bottom where those describe different grids. For five windows
    /// this is one row, 3+2, 2+3, 2+2+1, 1+2+2.
    static func tileAllLayouts(windowCount: Int, rowCeiling: Int) -> [[Int]] {
        guard windowCount > 0 else { return [] }
        let ceiling = min(windowCount, sanitizedLimit(rowCeiling))
        var result: [[Int]] = []
        for rows in 1...ceiling {
            let topHeavy = balancedPopulations(count: windowCount, bands: rows)
            let bottomHeavy = balancedPopulations(count: windowCount, bands: rows, extrasAtEnd: true)
            if result.last != topHeavy { result.append(topHeavy) }
            if topHeavy != bottomHeavy, result.last != bottomHeavy { result.append(bottomHeavy) }
        }
        return result
    }

    /// Split `count` windows across `bands` as evenly as possible. With
    /// `extrasAtEnd` the larger bands come last, which is what makes 2+3 and
    /// 3+2 two distinct grids instead of one.
    static func balancedPopulations(count: Int, bands: Int, extrasAtEnd: Bool = false) -> [Int] {
        guard count > 0, bands > 0 else { return [] }
        let base = count / bands
        let extras = count % bands
        return (0..<bands).map { index in
            let takesExtra = extrasAtEnd ? index >= bands - extras : index < extras
            return base + (takesExtra ? 1 : 0)
        }
    }

    /// Reading order from the upper-left corner. Frames are in the AX
    /// coordinate space (origin at the top-left of the main display), which
    /// is also what the service reads back for its cycle checks.
    static func sortedForTiling<T>(_ windows: [T], frame: (T) -> CGRect) -> [T] {
        windows.sorted { first, second in
            let firstFrame = frame(first)
            let secondFrame = frame(second)
            if firstFrame.minY != secondFrame.minY {
                return firstFrame.minY < secondFrame.minY
            }
            return firstFrame.minX < secondFrame.minX
        }
    }
}

/// Turns band populations into window frames inside a work area. Edges are
/// rounded once and shared, so neighbouring windows meet exactly and the
/// configured gap is the total distance between them.
enum WindowTilingGeometry {
    static func frames(in bounds: CGRect,
                       populations: [Int],
                       direction: WindowTilingDirection,
                       windowGap: CGFloat) -> [CGRect] {
        guard bounds.width > 0, bounds.height > 0,
              !populations.isEmpty, populations.allSatisfy({ $0 > 0 })
        else { return [] }

        var result: [CGRect] = []
        switch direction {
        case .rows:
            let rowEdges = edges(from: bounds.maxY, length: bounds.height,
                                 count: populations.count, descending: true)
            for (row, population) in populations.enumerated() {
                let rowTop = rowEdges[row]
                let rowBottom = rowEdges[row + 1]
                let columnEdges = edges(from: bounds.minX, length: bounds.width,
                                        count: population, descending: false)
                for column in 0..<population {
                    result.append(CGRect(x: columnEdges[column],
                                         y: rowBottom,
                                         width: columnEdges[column + 1] - columnEdges[column],
                                         height: rowTop - rowBottom))
                }
            }
        case .columns:
            let columnEdges = edges(from: bounds.minX, length: bounds.width,
                                    count: populations.count, descending: false)
            for (column, population) in populations.enumerated() {
                let columnLeft = columnEdges[column]
                let columnRight = columnEdges[column + 1]
                let rowEdges = edges(from: bounds.maxY, length: bounds.height,
                                     count: population, descending: true)
                for row in 0..<population {
                    result.append(CGRect(x: columnLeft,
                                         y: rowEdges[row + 1],
                                         width: columnRight - columnLeft,
                                         height: rowEdges[row] - rowEdges[row + 1]))
                }
            }
        }
        return result.map { gapped($0, in: bounds, windowGap: windowGap) }
    }

    /// `count + 1` rounded edges, so every pair of neighbours shares one edge.
    /// Heights and widths then differ by at most one point.
    private static func edges(from start: CGFloat, length: CGFloat,
                              count: Int, descending: Bool) -> [CGFloat] {
        guard count > 0 else { return [start] }
        return (0...count).map { index in
            let offset = (length * CGFloat(index) / CGFloat(count)).rounded()
            return descending ? start - offset : start + offset
        }
    }

    /// Half the gap comes off each shared edge, matching single-window
    /// placements: the gap is the total distance between two windows, not
    /// something both sides add.
    static func gapped(_ rect: CGRect, in bounds: CGRect, windowGap: CGFloat) -> CGRect {
        var result = rect
        if windowGap > 0 {
            let half = windowGap / 2
            if result.minX - bounds.minX > 0.5 {
                result.origin.x += half
                result.size.width -= half
            }
            if bounds.maxX - result.maxX > 0.5 {
                result.size.width -= half
            }
            if result.minY - bounds.minY > 0.5 {
                result.origin.y += half
                result.size.height -= half
            }
            if bounds.maxY - result.maxY > 0.5 {
                result.size.height -= half
            }
        }
        result.size.width = max(1, result.size.width)
        result.size.height = max(1, result.size.height)
        return result.integral
    }

    static func isClose(_ first: CGRect, _ second: CGRect, tolerance: CGFloat) -> Bool {
        abs(first.minX - second.minX) <= tolerance
            && abs(first.minY - second.minY) <= tolerance
            && abs(first.width - second.width) <= tolerance
            && abs(first.height - second.height) <= tolerance
    }

    static func framesMatch(_ first: [CGRect], _ second: [CGRect],
                            tolerance: CGFloat = 8) -> Bool {
        guard first.count == second.count else { return false }
        return zip(first, second).allSatisfy { isClose($0, $1, tolerance: tolerance) }
    }
}

/// What a display's last tiling press left behind. Kept per display and mode
/// only in memory, like Rectangle's grid state; the next press advances only
/// while the tracked windows still sit where this press put them.
struct WindowTilingCycleKey: Hashable {
    let displayID: CGDirectDisplayID
    let mode: WindowTilingMode
}

struct WindowTilingCycleRecord {
    var bounds: CGRect
    var order: [WindowLayoutWindowKey]
    /// Actual frames read back after the press, in AX coordinates. Windows
    /// that refused the write are recorded but not `tracked`.
    var frames: [WindowLayoutWindowKey: CGRect]
    var tracked: Set<WindowLayoutWindowKey>
    var index: Int
}

enum WindowTilingCycle {
    /// Advance to the next distinct grid. Duplicate frame sets are skipped so
    /// a press never leaves the desktop unchanged.
    static func advancedIndex(from index: Int, frames: [[CGRect]]) -> Int {
        guard !frames.isEmpty else { return 0 }
        let start = ((index % frames.count) + frames.count) % frames.count
        var next = (start + 1) % frames.count
        while next != start && frames[next] == frames[start] {
            next = (next + 1) % frames.count
        }
        return next
    }

    /// The grid the windows currently describe, if any. Moving or resizing a
    /// window by hand makes this nil, which restarts the cycle.
    static func matchingIndex(for current: [CGRect], in frames: [[CGRect]],
                              tolerance: CGFloat = 8) -> Int? {
        frames.firstIndex { WindowTilingGeometry.framesMatch($0, current, tolerance: tolerance) }
    }
}

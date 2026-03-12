import Foundation

enum ZoneSelectionPreset: String, CaseIterable, Identifiable, Codable {
    case all = "All"
    case threeByThree = "3x3"
    case centerTwoByTwo = "2x2 Center"
    case corners = "Corners"
    case crossPlus = "Cross +"
    case xShape = "X"
    case diagonalDown = "Diag \\"
    case diagonalUp = "Diag /"
    case bothDiagonals = "Both Diags"
    case topRow = "Top Row"
    case midRow = "Mid Row"
    case bottomRow = "Bottom Row"
    case leftColumn = "Left Col"
    case rightColumn = "Right Col"
    case outerRing = "Outer Ring"
    case centerOne = "Center 1"
    case custom = "Custom"

    var id: String { rawValue }

    var commandName: String {
        rawValue.replacingOccurrences(of: " ", with: "_").lowercased()
    }

    static let browserColumns: [[ZoneSelectionPreset]] = [
        [
            .all,
            .centerTwoByTwo,
            .xShape,
            .diagonalDown,
            .bothDiagonals,
            .midRow,
            .leftColumn,
            .outerRing,
            .custom
        ],
        [
            .threeByThree,
            .corners,
            .crossPlus,
            .diagonalUp,
            .topRow,
            .bottomRow,
            .rightColumn,
            .centerOne
        ]
    ]
}

enum ZonePresetResolver {
    static func zoneIDs(for preset: ZoneSelectionPreset, grid: GridConfiguration) -> Set<Int>? {
        let rows = grid.rows
        let cols = grid.cols
        guard rows > 0, cols > 0 else { return [] }

        func zoneID(row: Int, col: Int) -> Int {
            GridManager.zoneID(row: row, column: col, cols: cols)
        }

        func diagonalColumn(for row: Int) -> Int {
            if rows == 1 { return 0 }
            let position = Double(row) / Double(rows - 1)
            return Int((position * Double(max(cols - 1, 0))).rounded())
        }

        func centerRow() -> Int { (rows - 1) / 2 }
        func centerCol() -> Int { (cols - 1) / 2 }

        switch preset {
        case .all:
            return Set(1...grid.zoneCount)
        case .threeByThree:
            guard rows >= 3, cols >= 3 else { return zoneIDs(for: .centerOne, grid: grid) }
            let startRow = (rows - 3) / 2
            let startCol = (cols - 3) / 2
            var ids: Set<Int> = []
            for row in startRow..<(startRow + 3) {
                for col in startCol..<(startCol + 3) {
                    ids.insert(zoneID(row: row, col: col))
                }
            }
            return ids
        case .centerTwoByTwo:
            guard rows >= 2, cols >= 2 else { return zoneIDs(for: .centerOne, grid: grid) }
            let startRow = (rows - 2) / 2
            let startCol = (cols - 2) / 2
            var ids: Set<Int> = []
            for row in startRow..<(startRow + 2) {
                for col in startCol..<(startCol + 2) {
                    ids.insert(zoneID(row: row, col: col))
                }
            }
            return ids
        case .corners:
            return Set([
                zoneID(row: 0, col: 0),
                zoneID(row: 0, col: cols - 1),
                zoneID(row: rows - 1, col: 0),
                zoneID(row: rows - 1, col: cols - 1)
            ])
        case .crossPlus:
            var ids: Set<Int> = []
            let midR = centerRow()
            let midC = centerCol()
            for col in 0..<cols {
                ids.insert(zoneID(row: midR, col: col))
            }
            for row in 0..<rows {
                ids.insert(zoneID(row: row, col: midC))
            }
            return ids
        case .xShape, .bothDiagonals:
            let main = zoneIDs(for: .diagonalDown, grid: grid) ?? []
            let anti = zoneIDs(for: .diagonalUp, grid: grid) ?? []
            return main.union(anti)
        case .diagonalDown:
            var ids: Set<Int> = []
            for row in 0..<rows {
                ids.insert(zoneID(row: row, col: diagonalColumn(for: row)))
            }
            return ids
        case .diagonalUp:
            var ids: Set<Int> = []
            for row in 0..<rows {
                let col = (cols - 1) - diagonalColumn(for: row)
                ids.insert(zoneID(row: row, col: col))
            }
            return ids
        case .topRow:
            return Set((0..<cols).map { zoneID(row: 0, col: $0) })
        case .midRow:
            let row = centerRow()
            return Set((0..<cols).map { zoneID(row: row, col: $0) })
        case .bottomRow:
            return Set((0..<cols).map { zoneID(row: rows - 1, col: $0) })
        case .leftColumn:
            return Set((0..<rows).map { zoneID(row: $0, col: 0) })
        case .rightColumn:
            return Set((0..<rows).map { zoneID(row: $0, col: cols - 1) })
        case .outerRing:
            var ids: Set<Int> = []
            for col in 0..<cols {
                ids.insert(zoneID(row: 0, col: col))
                ids.insert(zoneID(row: rows - 1, col: col))
            }
            for row in 0..<rows {
                ids.insert(zoneID(row: row, col: 0))
                ids.insert(zoneID(row: row, col: cols - 1))
            }
            return ids
        case .centerOne:
            return Set([zoneID(row: centerRow(), col: centerCol())])
        case .custom:
            return nil
        }
    }
}

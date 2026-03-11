import Foundation

enum GridManager {
    static func zoneID(row: Int, column: Int, cols: Int) -> Int {
        (row * cols) + column + 1
    }

    static func zones(rows: Int, cols: Int) -> [Zone] {
        guard rows > 0, cols > 0 else { return [] }
        var output: [Zone] = []
        output.reserveCapacity(rows * cols)

        for row in 0..<rows {
            for column in 0..<cols {
                output.append(
                    Zone(
                        id: zoneID(row: row, column: column, cols: cols),
                        row: row,
                        column: column
                    )
                )
            }
        }

        return output
    }
}

import SwiftUI

struct GridOverlayView: View {
    let grid: GridConfiguration
    let selectedZoneIDs: Set<Int>
    let onToggleZone: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<grid.rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<grid.cols, id: \.self) { column in
                        let zoneID = GridManager.zoneID(row: row, column: column, cols: grid.cols)
                        let selected = selectedZoneIDs.contains(zoneID)

                        Rectangle()
                            .fill(selected ? Color.orange.opacity(0.32) : Color.clear)
                            .overlay(
                                Rectangle()
                                    .stroke(
                                        Color.white.opacity(selected ? 0.95 : 0.4),
                                        lineWidth: selected ? 1.4 : 0.8
                                    )
                            )
                            .overlay(alignment: .topLeading) {
                                Text("\(zoneID)")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(selected ? .white : .white.opacity(0.65))
                                    .padding(2)
                            }
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onTapGesture {
                                onToggleZone(zoneID)
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

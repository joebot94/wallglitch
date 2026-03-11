import Foundation

struct ZoneSelectionModel: Equatable {
    private(set) var selectedZoneIDs: Set<Int> = []

    var sortedIDs: [Int] {
        selectedZoneIDs.sorted()
    }

    func isSelected(_ id: Int) -> Bool {
        selectedZoneIDs.contains(id)
    }

    mutating func toggle(_ id: Int) {
        if selectedZoneIDs.contains(id) {
            selectedZoneIDs.remove(id)
        } else {
            selectedZoneIDs.insert(id)
        }
    }

    mutating func enable(_ id: Int) {
        selectedZoneIDs.insert(id)
    }

    mutating func disable(_ id: Int) {
        selectedZoneIDs.remove(id)
    }

    mutating func clear() {
        selectedZoneIDs.removeAll()
    }

    mutating func set(ids: Set<Int>, maxZoneID: Int) {
        selectedZoneIDs = ids.filter { $0 >= 1 && $0 <= maxZoneID }
    }

    mutating func selectAll(totalZones: Int) {
        guard totalZones > 0 else {
            clear()
            return
        }
        selectedZoneIDs = Set(1...totalZones)
    }

    mutating func clamp(maxZoneID: Int) {
        selectedZoneIDs = selectedZoneIDs.filter { $0 >= 1 && $0 <= maxZoneID }
    }
}

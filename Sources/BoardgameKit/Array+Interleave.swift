import Foundation

extension Array {
    func interleaved(with other: Array) -> Array {
        let maxIndex = Swift.max(count, other.count)
        var mergedArray: Array = []
        for index in 0 ..< maxIndex {
            if index < count {
                mergedArray.append(self[index])
            }
            if index < other.count {
                mergedArray.append(other[index])
            }
        }
        return mergedArray
    }
}

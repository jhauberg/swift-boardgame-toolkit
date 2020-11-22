import Foundation

public struct Size {
    public let width: Distance
    public let height: Distance

    public static let zero = Size(width: 0.inches, height: 0.inches)

    static func containingOffsets(_ offsets: [Size]) -> Size {
        guard let minX = offsets.min(by: { $0.width < $1.width })?.width,
              let minY = offsets.min(by: { $0.height < $1.height })?.height,
              let maxX = offsets.max(by: { $0.width < $1.width })?.width,
              let maxY = offsets.max(by: { $0.height < $1.height })?.height
        else {
            return .zero
        }

        // the size needed to cover the largest collection of components on a single page;
        // note that this must always be smaller than, or equal to, the page bounds
        return Size(width: maxX - minX,
                    height: maxY - minY)
    }
}

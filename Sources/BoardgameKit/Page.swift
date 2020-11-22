import Foundation

enum PageCoordinateSystem {
    case relativeToPageMargins
    case relativeToBoundingBox
}

final class Page {
    let bounds: Size
    let mode: PageCoordinateSystem

    var elements: [Element] = []

    init(size: Size, mode: PageCoordinateSystem = .relativeToBoundingBox) {
        bounds = size
        self.mode = mode
    }

    var boundingBox: Size {
        var offsets: [Size] = []
        for case let .component(component, x, y, _) in elements {
            offsets.append(Size(width: x, height: y))
            offsets.append(Size(width: x + component.portraitOrientedBounds.width,
                                height: y + component.portraitOrientedBounds.height))
        }

        return .containingOffsets(offsets)
    }

    var components: [Element] {
        elements.filter { if case .component = $0 {
            return true
        } else {
            return false
        }}
    }

    func component(
        _ component: Component,
        x: Measurement<UnitLength>,
        y: Measurement<UnitLength>,
        rotatedBy rotation: Layout.Turn? = nil
    ) {
        elements.append(
            .component(component.withOverlays(), x: x, y: y, turned: rotation)
        )
    }

    func fold(
        x: Measurement<UnitLength>,
        y: Measurement<UnitLength>,
        distance: Measurement<UnitLength>,
        vertically: Bool = false
    ) {
        // inserting at start to appear below any printable content;
        // this assumes call happening _after_ a page has been fully laid out
        elements.insert(
            contentsOf:
            Fold(x: x, y: y, distance: distance, width: 0.5.millimeters, vertically: vertically)
                .elements(),
            at: elements.startIndex
        )
    }

    func cut(
        x: Measurement<UnitLength>,
        y: Measurement<UnitLength>,
        distance: Measurement<UnitLength>,
        vertically: Bool = false
    ) {
        // inserting at start to appear below any printable content;
        // this assumes call happening _after_ a page has been fully laid out
        elements.insert(
            contentsOf: Cut(
                x: x,
                y: y,
                distance: distance,
                width: 0.25.millimeters,
                vertically: vertically
            ).elements(),
            at: elements.startIndex
        )
    }
}

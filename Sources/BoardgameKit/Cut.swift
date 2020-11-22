import Foundation

struct Cut: Feature {
    private var bounds: Size
    private var offset: Size

    init(x: Units, y: Units, distance: Distance, width: Distance, vertically: Bool = false) {
        let horizontally = !vertically

        // width is thickness of the guide; centered by the given coordinate
        let centerAdjustment = width / 2
        let length = distance

        if horizontally {
            offset = Size(width: x, height: y - centerAdjustment)
            bounds = Size(width: length, height: width)
        } else {
            offset = Size(width: x - centerAdjustment, height: y)
            bounds = Size(width: width, height: length)
        }
    }

    var form: Feature? {
        Box(width: bounds.width, height: bounds.height)
            .top(offset.height)
            .left(offset.width)
            .background("grey")
            .classed("guide")
    }
}

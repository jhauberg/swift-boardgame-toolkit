import Foundation

struct HTMLAttributes {
    var classes: [String] = []
}

struct RotationAttributes {
    var anchor: Anchor
    var angle: Angle
}

enum Element {
    case rect(inset: Inset,
              bounds: Size,
              attributes: BoxAttributes,
              additional: HTMLAttributes)
    case text(_ content: String,
              inset: Inset,
              width: Distance?,
              height: Distance?,
              attributes: TextAttributes,
              additional: HTMLAttributes)
    case image(_ path: String,
               inset: Inset,
               width: Distance?,
               height: Distance?,
               attributes: ImageAttributes,
               additional: HTMLAttributes)
    case freeform(_ content: String,
                  inset: Inset,
                  width: Distance?,
                  height: Distance?,
                  attributes: FreeformAttributes,
                  additional: HTMLAttributes)

    case component(_ component: Component,
                   x: Units,
                   y: Units,
                   turned: Layout.Turn? = nil)
    case page(_ page: Page,
              margin: Margin)
    case document(template: String,
                  paper: Paper,
                  pages: [Page])
}

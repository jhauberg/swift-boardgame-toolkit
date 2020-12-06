import Foundation

struct Inset {
    let mutuallyExclusiveOpposites: Bool

    init(allowingOppositeInsets: Bool = false) {
        mutuallyExclusiveOpposites = !allowingOppositeInsets
    }

    var top: Distance? {
        didSet {
            if top != nil && mutuallyExclusiveOpposites {
                bottom = nil
            }
        }
    }

    var left: Distance? {
        didSet {
            if left != nil && mutuallyExclusiveOpposites {
                right = nil
            }
        }
    }

    var right: Distance? {
        didSet {
            if right != nil && mutuallyExclusiveOpposites {
                left = nil
            }
        }
    }

    var bottom: Distance? {
        didSet {
            if bottom != nil && mutuallyExclusiveOpposites {
                top = nil
            }
        }
    }
}

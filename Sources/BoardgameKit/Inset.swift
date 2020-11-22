import Foundation

struct Inset {
    var top: Distance? {
        didSet {
            if top != nil {
                bottom = nil
            }
        }
    }

    var left: Distance? {
        didSet {
            if left != nil {
                right = nil
            }
        }
    }

    var right: Distance? {
        didSet {
            if right != nil {
                left = nil
            }
        }
    }

    var bottom: Distance? {
        didSet {
            if bottom != nil {
                top = nil
            }
        }
    }
}

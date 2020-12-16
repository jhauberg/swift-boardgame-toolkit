import Foundation

public enum Guide {
    public enum Distribution {
        case front
        case back
        case frontAndBack
    }

    public enum Style {
        case boxed(color: String)
        case extendedEdges(color: String)
        case crosshair(color: String)
    }
}

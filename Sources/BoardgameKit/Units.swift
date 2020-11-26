import Foundation

public typealias Units = Measurement<UnitLength>
public typealias Angle = Measurement<UnitAngle>

public typealias Distance = Units

public extension Double {
    var centimeters: Measurement<UnitLength> {
        Measurement(value: self, unit: .centimeters)
    }

    var millimeters: Measurement<UnitLength> {
        Measurement(value: self, unit: .millimeters)
    }

    /**
     Physical inches.
     */
    var inches: Measurement<UnitLength> {
        Measurement(value: self, unit: .inches)
    }

    var points: Measurement<UnitLength> {
        Measurement(value: self / 72, unit: .inches)
    }
}

public extension Double {
    var degrees: Measurement<UnitAngle> {
        Measurement(value: self, unit: .degrees)
    }

    var radians: Measurement<UnitAngle> {
        Measurement(value: self, unit: .radians)
    }
}

public extension Int {
    var centimeters: Measurement<UnitLength> {
        Measurement(value: Double(self), unit: .centimeters)
    }

    var millimeters: Measurement<UnitLength> {
        Measurement(value: Double(self), unit: .millimeters)
    }

    /**
     Physical inches.
     */
    var inches: Measurement<UnitLength> {
        Measurement(value: Double(self), unit: .inches)
    }

    var points: Measurement<UnitLength> {
        Measurement(value: Double(self) / 72, unit: .inches)
    }
}

public extension Int {
    var degrees: Measurement<UnitAngle> {
        Measurement(value: Double(self), unit: .degrees)
    }

    var radians: Measurement<UnitAngle> {
        Measurement(value: Double(self), unit: .radians)
    }
}

public extension Measurement where UnitType: Dimension {
    static var zero: Measurement {
        Measurement(value: 0, unit: .baseUnit())
    }
}

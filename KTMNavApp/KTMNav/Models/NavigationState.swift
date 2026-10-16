//
//  NavigationState.swift
//  KTMNav
//
//  Live navigation status tracking for iOS and TFT Dash.
//

import Foundation
import CoreLocation

public struct NavigationState {
    public var isNavigating: Bool
    public var currentManeuver: KTMManeuver
    public var nextManeuverDistanceMeters: UInt32
    public var totalDistanceRemainingMeters: UInt32
    public var estimatedTimeRemainingSeconds: UInt32
    public var nextStreetName: String
    public var currentStreetName: String
    public var currentSpeedKmh: Double
    public var isOffRoute: Bool
    public var arrivalDate: Date?

    public init(
        isNavigating: Bool = false,
        currentManeuver: KTMManeuver = .straight,
        nextManeuverDistanceMeters: UInt32 = 0,
        totalDistanceRemainingMeters: UInt32 = 0,
        estimatedTimeRemainingSeconds: UInt32 = 0,
        nextStreetName: String = "",
        currentStreetName: String = "",
        currentSpeedKmh: Double = 0.0,
        isOffRoute: Bool = false,
        arrivalDate: Date? = nil
    ) {
        self.isNavigating = isNavigating
        self.currentManeuver = currentManeuver
        self.nextManeuverDistanceMeters = nextManeuverDistanceMeters
        self.totalDistanceRemainingMeters = totalDistanceRemainingMeters
        self.estimatedTimeRemainingSeconds = estimatedTimeRemainingSeconds
        self.nextStreetName = nextStreetName
        self.currentStreetName = currentStreetName
        self.currentSpeedKmh = currentSpeedKmh
        self.isOffRoute = isOffRoute
        self.arrivalDate = arrivalDate
    }

    /// Formatted turn distance for rider view
    public func formattedTurnDistance(metric: Bool = true) -> String {
        if metric {
            if nextManeuverDistanceMeters >= 1000 {
                return String(format: "%.1f km", Double(nextManeuverDistanceMeters) / 1000.0)
            } else {
                return "\(nextManeuverDistanceMeters) m"
            }
        } else {
            let feet = Double(nextManeuverDistanceMeters) * 3.28084
            if feet >= 1000 {
                let miles = feet / 5280.0
                return String(format: "%.1f mi", miles)
            } else {
                return "\(Int(feet)) ft"
            }
        }
    }

    /// Formatted total distance remaining
    public func formattedTotalDistance(metric: Bool = true) -> String {
        if metric {
            return String(format: "%.1f km", Double(totalDistanceRemainingMeters) / 1000.0)
        } else {
            let miles = (Double(totalDistanceRemainingMeters) * 3.28084) / 5280.0
            return String(format: "%.1f mi", miles)
        }
    }

    /// Formatted ETA time string
    public var formattedETA: String {
        guard let arrival = arrivalDate else {
            let minutes = (estimatedTimeRemainingSeconds + 59) / 60
            let hours = minutes / 60
            let remMinutes = minutes % 60
            if hours > 0 {
                return "\(hours)h \(remMinutes)m"
            } else {
                return "\(remMinutes) min"
            }
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: arrival)
    }
}

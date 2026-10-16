//
//  KTMManeuver.swift
//  KTMNav
//
//  Reverse-engineered KTM Gen2/Gen3 TFT Dashboard Maneuver Icons & Encoding.
//

import Foundation
import MapKit

/// Represents the visual turn maneuver icons rendered natively by KTM TFT instrument clusters.
public enum KTMManeuver: UInt8, CaseIterable, Identifiable {
    case unknown            = 0x00
    case straight           = 0x01
    case turnSlightRight    = 0x02
    case turnRight          = 0x03
    case turnSharpRight     = 0x04
    case uTurnRight         = 0x05
    case uTurnLeft          = 0x06
    case turnSharpLeft      = 0x07
    case turnLeft           = 0x08
    case turnSlightLeft     = 0x09
    case keepRight          = 0x0A
    case keepLeft           = 0x0B
    case forkRight          = 0x0C
    case forkLeft           = 0x0D
    case highwayEnterRight  = 0x0E
    case highwayEnterLeft   = 0x0F
    case highwayExitRight   = 0x10
    case highwayExitLeft    = 0x11
    case roundaboutExit1    = 0x12
    case roundaboutExit2    = 0x13
    case roundaboutExit3    = 0x14
    case roundaboutExit4    = 0x15
    case roundaboutExit5    = 0x16
    case roundaboutExit6    = 0x17
    case roundaboutExit7    = 0x18
    case roundaboutExit8    = 0x19
    case roundaboutUTurn    = 0x1A
    case destinationReached = 0x1F
    case recalculatingRoute = 0x20
    case offRouteAlert      = 0x21

    public var id: UInt8 { rawValue }

    /// Human-readable description of maneuver
    public var title: String {
        switch self {
        case .unknown: return "Continue Straight"
        case .straight: return "Straight Ahead"
        case .turnSlightRight: return "Slight Right"
        case .turnRight: return "Turn Right"
        case .turnSharpRight: return "Sharp Right"
        case .uTurnRight: return "U-Turn Right"
        case .uTurnLeft: return "U-Turn Left"
        case .turnSharpLeft: return "Sharp Left"
        case .turnLeft: return "Turn Left"
        case .turnSlightLeft: return "Slight Left"
        case .keepRight: return "Keep Right"
        case .keepLeft: return "Keep Left"
        case .forkRight: return "Take Fork Right"
        case .forkLeft: return "Take Fork Left"
        case .highwayEnterRight: return "Merge Highway (Right)"
        case .highwayEnterLeft: return "Merge Highway (Left)"
        case .highwayExitRight: return "Take Exit Right"
        case .highwayExitLeft: return "Take Exit Left"
        case .roundaboutExit1: return "Roundabout (1st Exit)"
        case .roundaboutExit2: return "Roundabout (2nd Exit)"
        case .roundaboutExit3: return "Roundabout (3rd Exit)"
        case .roundaboutExit4: return "Roundabout (4th Exit)"
        case .roundaboutExit5: return "Roundabout (5th Exit)"
        case .roundaboutExit6: return "Roundabout (6th Exit)"
        case .roundaboutExit7: return "Roundabout (7th Exit)"
        case .roundaboutExit8: return "Roundabout (8th Exit)"
        case .roundaboutUTurn: return "Roundabout (U-Turn)"
        case .destinationReached: return "Arrived at Destination"
        case .recalculatingRoute: return "Recalculating..."
        case .offRouteAlert: return "Off Route"
        }
    }

    /// SF Symbol for preview rendering in iOS app
    public var sfSymbolName: String {
        switch self {
        case .unknown, .straight: return "arrow.up"
        case .turnSlightRight: return "arrow.up.right"
        case .turnRight: return "arrow.turn.up.right"
        case .turnSharpRight: return "arrow.uturn.right"
        case .uTurnRight, .uTurnLeft, .roundaboutUTurn: return "arrow.uturn.backward"
        case .turnSharpLeft: return "arrow.uturn.left"
        case .turnLeft: return "arrow.turn.up.left"
        case .turnSlightLeft: return "arrow.up.left"
        case .keepRight: return "arrow.triangle.merge"
        case .keepLeft: return "arrow.triangle.merge"
        case .forkRight: return "arrow.triangle.branch"
        case .forkLeft: return "arrow.triangle.branch"
        case .highwayEnterRight, .highwayEnterLeft: return "arrow.triangle.merge"
        case .highwayExitRight, .highwayExitLeft: return "arrow.triangle.turn.up.right.diamond"
        case .roundaboutExit1, .roundaboutExit2, .roundaboutExit3,
             .roundaboutExit4, .roundaboutExit5, .roundaboutExit6,
             .roundaboutExit7, .roundaboutExit8: return "arrow.triangle.2.circlepath"
        case .destinationReached: return "flag.checkered"
        case .recalculatingRoute: return "arrow.triangle.2.circlepath.circle"
        case .offRouteAlert: return "exclamationmark.triangle.fill"
        }
    }

    /// Map Apple MapKit instruction to KTM TFT Maneuver ID
    public static func from(step: MKRoute.Step) -> KTMManeuver {
        let text = step.instructions.lowercased()

        if text.contains("arrive") || text.contains("destination") {
            return .destinationReached
        } else if text.contains("u-turn") {
            return text.contains("right") ? .uTurnRight : .uTurnLeft
        } else if text.contains("roundabout") {
            if text.contains("1st") || text.contains("first") { return .roundaboutExit1 }
            if text.contains("2nd") || text.contains("second") { return .roundaboutExit2 }
            if text.contains("3rd") || text.contains("third") { return .roundaboutExit3 }
            if text.contains("4th") || text.contains("fourth") { return .roundaboutExit4 }
            if text.contains("5th") || text.contains("fifth") { return .roundaboutExit5 }
            return .roundaboutExit1
        } else if text.contains("sharp right") {
            return .turnSharpRight
        } else if text.contains("sharp left") {
            return .turnSharpLeft
        } else if text.contains("slight right") || text.contains("bear right") {
            return .turnSlightRight
        } else if text.contains("slight left") || text.contains("bear left") {
            return .turnSlightLeft
        } else if text.contains("turn right") {
            return .turnRight
        } else if text.contains("turn left") {
            return .turnLeft
        } else if text.contains("keep right") {
            return .keepRight
        } else if text.contains("keep left") {
            return .keepLeft
        } else if text.contains("exit") {
            return text.contains("left") ? .highwayExitLeft : .highwayExitRight
        } else if text.contains("merge") || text.contains("ramp") {
            return text.contains("left") ? .highwayEnterLeft : .highwayEnterRight
        } else if text.contains("fork") {
            return text.contains("left") ? .forkLeft : .forkRight
        }

        return .straight
    }
}

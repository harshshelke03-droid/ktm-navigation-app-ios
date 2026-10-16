//
//  KTMBikeDevice.swift
//  KTMNav
//
//  Represents a discovered or paired KTM motorcycle instrument cluster.
//

import Foundation
import CoreBluetooth

public struct KTMBikeDevice: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let peripheral: CBPeripheral
    public var rssi: Int
    public var lastSeen: Date
    public var isBonded: Bool

    public init(peripheral: CBPeripheral, rssi: Int = 0, isBonded: Bool = false) {
        self.id = peripheral.identifier
        self.name = peripheral.name ?? "KTM Motorcycle"
        self.peripheral = peripheral
        self.rssi = rssi
        self.lastSeen = Date()
        self.isBonded = isBonded
    }

    public static func == (lhs: KTMBikeDevice, rhs: KTMBikeDevice) -> Bool {
        lhs.id == rhs.id
    }
}

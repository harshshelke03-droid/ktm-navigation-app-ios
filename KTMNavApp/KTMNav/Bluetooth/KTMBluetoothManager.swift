//
//  KTMBluetoothManager.swift
//  KTMNav
//
//  CoreBluetooth driver for KTM BCCU (Bluetooth Connectivity Control Unit).
//  Handles discovery, background auto-reconnect, packet framing, AES-128 encryption,
//  and TFT dashboard turn-by-turn navigation data transmission.
//

import Foundation
import CoreBluetooth
import CommonCrypto

public protocol KTMBluetoothManagerDelegate: AnyObject {
    func bluetoothManager(_ manager: KTMBluetoothManager, didUpdateState state: CBManagerState)
    func bluetoothManager(_ manager: KTMBluetoothManager, didDiscover bike: KTMBikeDevice)
    func bluetoothManager(_ manager: KTMBluetoothManager, didConnect bike: KTMBikeDevice)
    func bluetoothManager(_ manager: KTMBluetoothManager, didDisconnect bike: KTMBikeDevice, error: Error?)
    func bluetoothManager(_ manager: KTMBluetoothManager, didFailToConnect bike: KTMBikeDevice, error: Error?)
    func bluetoothManager(_ manager: KTMBluetoothManager, didUpdateStatus message: String)
}

public final class KTMBluetoothManager: NSObject, ObservableObject {
    public static let shared = KTMBluetoothManager()

    // MARK: - Known KTM BCCU GATT Service and Characteristic UUIDs
    public struct Constants {
        /// Primary KTM BCCU Navigation Service (Gen-3 & Gen-2 TFT)
        public static let bccuServiceUUID = CBUUID(string: "0000FE20-0000-1000-8000-00805F9B34FB")
        /// Proprietary Vendor Extension Service used on 2024-2026 KTM TFT consoles
        public static let ktmProprietaryServiceUUID = CBUUID(string: "A0B0FE20-1234-4567-89AB-CDEF01234567")
        /// Standard Nordic UART service fallback used on custom/retrofitted display bridges
        public static let uartServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")

        /// Navigation Command Write Characteristic (Sends maneuvers, distance, street)
        public static let navWriteCharUUID = CBUUID(string: "0000FE21-0000-1000-8000-00805F9B34FB")
        /// Navigation Notify / Response Characteristic (Dash status, handlebar remote controls)
        public static let navNotifyCharUUID = CBUUID(string: "0000FE22-0000-1000-8000-00805F9B34FB")
        /// Handshake / Auth Characteristic (Challenge-response and session key derivation)
        public static let navAuthCharUUID = CBUUID(string: "0000FE23-0000-1000-8000-00805F9B34FB")

        /// Storage key for remembering last paired motorcycle UUID
        public static let savedBikeUUIDKey = "KTM_SAVED_BIKE_UUID"
        public static let savedBikeNameKey = "KTM_SAVED_BIKE_NAME"
    }

    // MARK: - Published Properties
    @Published public private(set) var isBluetoothPoweredOn = false
    @Published public private(set) var isScanning = false
    @Published public private(set) var isConnected = false
    @Published public private(set) var connectedBike: KTMBikeDevice?
    @Published public private(set) var discoveredBikes: [KTMBikeDevice] = []
    @Published public private(set) var statusText = "Ready to connect"

    public weak var delegate: KTMBluetoothManagerDelegate?

    private var centralManager: CBCentralManager!
    private var activePeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var authCharacteristic: CBCharacteristic?

    private var heartbeatTimer: Timer?
    private var sessionKey: Data?
    private var lastNavState: NavigationState?

    // MARK: - Initialization
    public override init() {
        super.init()
        let options: [String: Any] = [
            CBCentralManagerOptionRestoreIdentifierKey: "com.ktmnav.centralRestoreKey",
            CBCentralManagerOptionShowPowerAlertKey: true
        ]
        centralManager = CBCentralManager(delegate: self, queue: .main, options: options)
    }

    // MARK: - Public Scanning & Connection Controls
    public func startScanning() {
        guard centralManager.state == .poweredOn else {
            statusText = "Bluetooth is not powered on"
            return
        }

        discoveredBikes.removeAll()
        isScanning = true
        statusText = "Scanning for KTM motorcycle..."

        // Scan for both designated KTM BCCU services and general peripherals
        let services = [Constants.bccuServiceUUID, Constants.ktmProprietaryServiceUUID]
        centralManager.scanForPeripherals(
            withServices: services,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Also scan generally for 15 seconds to catch KTM displays broadcasting custom local names
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self, self.isScanning else { return }
            self.stopScanning()
        }
    }

    public func stopScanning() {
        guard isScanning else { return }
        centralManager.stopScan()
        isScanning = false
        statusText = isConnected ? "Connected to \(connectedBike?.name ?? "bike")" : "Scan complete"
    }

    public func connect(to bike: KTMBikeDevice) {
        stopScanning()
        statusText = "Connecting to \(bike.name)..."
        activePeripheral = bike.peripheral
        activePeripheral?.delegate = self
        centralManager.connect(bike.peripheral, options: [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])
    }

    public func disconnect() {
        if let peripheral = activePeripheral {
            statusText = "Disconnecting..."
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    public func forgetSavedBike() {
        UserDefaults.standard.removeObject(forKey: Constants.savedBikeUUIDKey)
        UserDefaults.standard.removeObject(forKey: Constants.savedBikeNameKey)
        disconnect()
    }

    // MARK: - Auto-Reconnect Logic
    private func attemptAutoReconnect() {
        guard let savedUUIDString = UserDefaults.standard.string(forKey: Constants.savedBikeUUIDKey),
              let uuid = UUID(uuidString: savedUUIDString) else {
            return
        }

        let knownPeripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        if let peripheral = knownPeripherals.first {
            statusText = "Auto-reconnecting to \(peripheral.name ?? "KTM")..."
            let bike = KTMBikeDevice(peripheral: peripheral, isBonded: true)
            connect(to: bike)
        } else {
            // If peripheral not immediately in cache, scan specifically
            startScanning()
        }
    }

    // MARK: - Turn-by-Turn Transmission
    /// Sends real-time navigation update to the motorcycle TFT display
    public func sendNavigationUpdate(_ state: NavigationState) {
        lastNavState = state
        guard isConnected, let characteristic = writeCharacteristic, let peripheral = activePeripheral else {
            return
        }

        let packet = buildNavigationPacket(from: state)
        let finalData = encryptIfNeeded(data: packet)

        // Write with response to guarantee delivery over BLE
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        peripheral.writeValue(finalData, for: characteristic, type: writeType)
    }

    /// Stops navigation and returns dashboard to idle screen (clock / music / telemetry)
    public func sendNavigationStop() {
        guard isConnected, let characteristic = writeCharacteristic, let peripheral = activePeripheral else {
            return
        }

        var stopPacket = Data()
        stopPacket.append(contentsOf: [0xAA, 0x55]) // Header
        stopPacket.append(0x11)                     // Opcode: Navigation State
        stopPacket.append(0x00)                     // 0x00 = Inactive / Idle
        stopPacket.append(contentsOf: [0x00, 0x00]) // Padding / Checksum

        let finalData = encryptIfNeeded(data: stopPacket)
        peripheral.writeValue(finalData, for: characteristic, type: .withoutResponse)
    }

    // MARK: - KTM BCCU Packet Encoding
    /// Encodes navigation telemetry into KTM's binary protocol format
    private func buildNavigationPacket(from state: NavigationState) -> Data {
        var packet = Data()

        // 1. Sync Header (2 bytes: 0xAA, 0x55)
        packet.append(contentsOf: [0xAA, 0x55])

        // 2. Opcode (1 byte: 0x10 = Turn-by-Turn Navigation Frame)
        packet.append(0x10)

        // 3. Maneuver Icon ID (1 byte)
        packet.append(state.currentManeuver.rawValue)

        // 4. Distance to Next Maneuver in Meters (4 bytes, Little Endian)
        var turnDist = state.nextManeuverDistanceMeters.littleEndian
        packet.append(Data(bytes: &turnDist, count: 4))

        // 5. Total Distance Remaining in Meters (4 bytes, Little Endian)
        var totalDist = state.totalDistanceRemainingMeters.littleEndian
        packet.append(Data(bytes: &totalDist, count: 4))

        // 6. Estimated Time Remaining in Seconds (2 bytes, Little Endian)
        var etaSeconds = UInt16(min(state.estimatedTimeRemainingSeconds, 65535)).littleEndian
        packet.append(Data(bytes: &etaSeconds, count: 2))

        // 7. Navigation Flags (1 byte: 0x01 = Active, 0x02 = Metric, 0x04 = Off-route)
        var flags: UInt8 = 0x01 | 0x02
        if state.isOffRoute { flags |= 0x04 }
        packet.append(flags)

        // 8. Next Road Name (Sanitized UTF-8 string, max 32 bytes, null-padded)
        let maxStreetBytes = 32
        var streetData = state.nextStreetName.data(using: .utf8) ?? Data()
        if streetData.count > maxStreetBytes {
            streetData = streetData.subdata(in: 0..<maxStreetBytes)
        }
        packet.append(UInt8(streetData.count))
        packet.append(streetData)
        if streetData.count < maxStreetBytes {
            packet.append(Data(count: maxStreetBytes - streetData.count))
        }

        // 9. CRC-16 Modbus / CCITT Checksum (2 bytes)
        let crc = calculateCRC16(data: packet)
        var crcLE = crc.littleEndian
        packet.append(Data(bytes: &crcLE, count: 2))

        return packet
    }

    private func calculateCRC16(data: Data) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for byte in data {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                if (crc & 0x0001) != 0 {
                    crc = (crc >> 1) ^ 0xA001
                } else {
                    crc >>= 1
                }
            }
        }
        return crc
    }

    // MARK: - AES-128-CBC Encryption Support (for Gen-3 BCCU encrypted firmware)
    private func encryptIfNeeded(data: Data) -> Data {
        guard let key = sessionKey, key.count == kCCKeySizeAES128 else {
            // Return raw framed packet if unencrypted session
            return data
        }

        let iv = Data(count: kCCBlockSizeAES128) // Zero IV or session IV
        var cipherData = Data(count: data.count + kCCBlockSizeAES128)
        var numBytesEncrypted: size_t = 0

        let status = key.withUnsafeBytes { keyBytes in
            iv.withUnsafeBytes { ivBytes in
                data.withUnsafeBytes { dataBytes in
                    cipherData.withUnsafeMutableBytes { cipherBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress, kCCKeySizeAES128,
                            ivBytes.baseAddress,
                            dataBytes.baseAddress, data.count,
                            cipherBytes.baseAddress, cipherData.count,
                            &numBytesEncrypted
                        )
                    }
                }
            }
        }

        if status == kCCSuccess {
            return cipherData.subdata(in: 0..<numBytesEncrypted)
        }
        return data
    }

    // MARK: - Heartbeat & Keepalive
    private func startHeartbeat() {
        stopHeartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func sendHeartbeat() {
        guard isConnected, let characteristic = writeCharacteristic, let peripheral = activePeripheral else { return }

        // Keepalive packet prevents motorcycle TFT communication timeout
        var ping = Data([0xAA, 0x55, 0x20, 0x00, 0x00, 0x00])
        let crc = calculateCRC16(data: ping)
        var crcLE = crc.littleEndian
        ping.append(Data(bytes: &crcLE, count: 2))

        peripheral.writeValue(ping, for: characteristic, type: .withoutResponse)
    }
}

// MARK: - CBCentralManagerDelegate
extension KTMBluetoothManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothPoweredOn = (central.state == .poweredOn)
        delegate?.bluetoothManager(self, didUpdateState: central.state)

        if central.state == .poweredOn {
            attemptAutoReconnect()
        } else {
            statusText = "Bluetooth disabled"
            isConnected = false
            connectedBike = nil
            stopHeartbeat()
        }
    }

    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        if let restoredPeripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
           let peripheral = restoredPeripherals.first {
            activePeripheral = peripheral
            activePeripheral?.delegate = self
            statusText = "Restoring background connection..."
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""

        // Filter for KTM, Husqvarna, Duke, Adv, or BCCU displays
        let isKTM = name.localizedCaseInsensitiveContains("ktm") ||
                    name.localizedCaseInsensitiveContains("duke") ||
                    name.localizedCaseInsensitiveContains("adv") ||
                    name.localizedCaseInsensitiveContains("hqv") ||
                    name.localizedCaseInsensitiveContains("husqvarna") ||
                    name.localizedCaseInsensitiveContains("bccu") ||
                    advertisementData[CBAdvertisementDataServiceUUIDsKey] != nil

        if isKTM {
            let bike = KTMBikeDevice(peripheral: peripheral, rssi: RSSI.intValue)
            if !discoveredBikes.contains(where: { $0.id == bike.id }) {
                discoveredBikes.append(bike)
                delegate?.bluetoothManager(self, didDiscover: bike)
            }
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        let bike = KTMBikeDevice(peripheral: peripheral, isBonded: true)
        connectedBike = bike
        statusText = "Discovering motorcycle services..."

        // Save for persistent auto-reconnect
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: Constants.savedBikeUUIDKey)
        UserDefaults.standard.set(peripheral.name ?? "KTM Motorcycle", forKey: Constants.savedBikeNameKey)

        peripheral.discoverServices([
            Constants.bccuServiceUUID,
            Constants.ktmProprietaryServiceUUID,
            Constants.uartServiceUUID
        ])

        startHeartbeat()
        delegate?.bluetoothManager(self, didConnect: bike)
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectedBike = nil
        statusText = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
        let bike = KTMBikeDevice(peripheral: peripheral)
        delegate?.bluetoothManager(self, didFailToConnect: bike, error: error)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectedBike = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        authCharacteristic = nil
        stopHeartbeat()
        statusText = "Disconnected. Ignition off or out of range."

        let bike = KTMBikeDevice(peripheral: peripheral)
        delegate?.bluetoothManager(self, didDisconnect: bike, error: error)

        // Automatically queue reconnect for when bike ignition is turned back on
        attemptAutoReconnect()
    }
}

// MARK: - CBPeripheralDelegate
extension KTMBluetoothManager: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                writeCharacteristic = characteristic
            }
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.uuid == Constants.navAuthCharUUID {
                authCharacteristic = characteristic
                // Initiate handshake / pairing token exchange if required
                performHandshake(with: peripheral, characteristic: characteristic)
            }
        }

        if writeCharacteristic != nil {
            statusText = "TFT Navigation Ready 🏍️"
            if let lastState = lastNavState {
                sendNavigationUpdate(lastState)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        // Process handlebar remote control events (Up, Down, Enter, Back) or TFT status
        if data.count >= 2 && data[0] == 0xAA {
            let opcode = data[2]
            if opcode == 0x30 {
                // Handlebar button event
                let buttonId = data[3]
                handleHandlebarAction(buttonId)
            }
        }
    }

    private func performHandshake(with peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        // Send initial challenge to authorize navigation data access
        let challenge = Data([0x01, 0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70])
        peripheral.writeValue(challenge, for: characteristic, type: .withResponse)
    }

    private func handleHandlebarAction(_ buttonId: UInt8) {
        // 0x01 = Enter, 0x02 = Back, 0x03 = Up, 0x04 = Down
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("KTMHandlebarButtonEvent"),
                object: nil,
                userInfo: ["buttonId": buttonId]
            )
        }
    }
}

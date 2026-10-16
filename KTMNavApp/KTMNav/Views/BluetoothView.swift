//
//  BluetoothView.swift
//  KTMNav
//
//  Bluetooth device discovery, pairing, and connection management for KTM bikes.
//

import SwiftUI

public struct BluetoothView: View {
    @ObservedObject var btManager = KTMBluetoothManager.shared
    private let ktmOrange = Color(red: 1.0, green: 0.40, blue: 0.0)
    private let darkBg = Color(red: 0.08, green: 0.08, blue: 0.10)
    private let cardBg = Color(red: 0.14, green: 0.14, blue: 0.16)

    public var body: some View {
        NavigationView {
            ZStack {
                darkBg.ignoresSafeArea()

                VStack(spacing: 16) {
                    // Status Banner
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("STATUS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                            Text(btManager.statusText)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        if btManager.isScanning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: ktmOrange))
                        }
                    }
                    .padding()
                    .background(cardBg)
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Connected Bike Card
                    if let bike = btManager.connectedBike {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CONNECTED MOTORCYCLE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(ktmOrange)

                            HStack {
                                Image(systemName: "motorcycle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(ktmOrange)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bike.name)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("UUID: \(bike.id.uuidString.prefix(8))...")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Button(action: {
                                    btManager.disconnect()
                                }) {
                                    Text("Disconnect")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.red.opacity(0.15))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                        .background(cardBg)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Scan Controls
                    HStack(spacing: 12) {
                        Button(action: {
                            if btManager.isScanning {
                                btManager.stopScanning()
                            } else {
                                btManager.startScanning()
                            }
                        }) {
                            HStack {
                                Image(systemName: btManager.isScanning ? "stop.fill" : "antenna.radiowaves.left.and.right")
                                Text(btManager.isScanning ? "Stop Scanning" : "Scan for Bikes")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(ktmOrange)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)

                    // Discovered Peripherals List
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DISCOVERED MOTORCYCLES")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal)

                        if btManager.discoveredBikes.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "wifi.exclamationmark")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("No KTM bikes found nearby.\nEnsure bike ignition is ON and 'Add Device' is selected in TFT menu.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List(btManager.discoveredBikes) { bike in
                                HStack {
                                    Image(systemName: "motorcycle")
                                        .foregroundColor(ktmOrange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bike.name)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("Signal: \(bike.rssi) dBm")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Button(action: {
                                        btManager.connect(to: bike)
                                    }) {
                                        Text("Connect")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(ktmOrange)
                                            .cornerRadius(8)
                                    }
                                }
                                .listRowBackground(cardBg)
                            }
                            .listStyle(PlainListStyle())
                        }
                    }
                }
            }
            .navigationTitle("Bluetooth Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

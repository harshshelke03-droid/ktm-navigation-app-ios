//
//  SettingsView.swift
//  KTMNav
//
//  Rider preferences, audio guidance, units, and background mode settings.
//

import SwiftUI

public struct SettingsView: View {
    @ObservedObject var navEngine = NavigationEngine.shared
    @ObservedObject var btManager = KTMBluetoothManager.shared
    @AppStorage("useMetricUnits") private var useMetricUnits = true
    @AppStorage("autoReconnectOnIgnition") private var autoReconnect = true

    private let ktmOrange = Color(red: 1.0, green: 0.40, blue: 0.0)
    private let darkBg = Color(red: 0.08, green: 0.08, blue: 0.10)
    private let cardBg = Color(red: 0.14, green: 0.14, blue: 0.16)

    public var body: some View {
        NavigationView {
            ZStack {
                darkBg.ignoresSafeArea()

                Form {
                    Section(header: Text("RIDE AUDIO & VOICE").foregroundColor(ktmOrange)) {
                        Toggle("Voice Guidance in Helmet", isOn: $navEngine.voiceGuidanceEnabled)
                        Toggle("Directional Turn Beeps", isOn: $navEngine.audioBeepsEnabled)
                    }
                    .listRowBackground(cardBg)

                    Section(header: Text("UNITS & DISPLAY").foregroundColor(ktmOrange)) {
                        Toggle("Metric Units (km & meters)", isOn: $useMetricUnits)
                        Toggle("Auto-Reconnect on Bike Ignition", isOn: $autoReconnect)
                    }
                    .listRowBackground(cardBg)

                    Section(header: Text("NO SUBSCRIPTION / PRIVACY").foregroundColor(ktmOrange)) {
                        HStack {
                            Text("Service Tier")
                            Spacer()
                            Text("100% Free Forever")
                                .foregroundColor(.green)
                                .bold()
                        }
                        HStack {
                            Text("Data Collection")
                            Spacer()
                            Text("Zero (On-Device)")
                                .foregroundColor(.gray)
                        }
                        HStack {
                            Text("Offline Navigation")
                            Spacer()
                            Text("Active")
                                .foregroundColor(.green)
                        }
                    }
                    .listRowBackground(cardBg)

                    Section(header: Text("BIKE CONNECTION").foregroundColor(ktmOrange)) {
                        Button(role: .destructive, action: {
                            btManager.forgetSavedBike()
                        }) {
                            Text("Forget Saved Motorcycle")
                        }
                    }
                    .listRowBackground(cardBg)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

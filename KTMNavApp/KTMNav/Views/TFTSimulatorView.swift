//
//  TFTSimulatorView.swift
//  KTMNav
//
//  Allows riders to test turn maneuvers on the physical bike TFT display while parked.
//

import SwiftUI

public struct TFTSimulatorView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var btManager = KTMBluetoothManager.shared

    private let ktmOrange = Color(red: 1.0, green: 0.40, blue: 0.0)
    private let darkBg = Color(red: 0.08, green: 0.08, blue: 0.10)
    private let cardBg = Color(red: 0.14, green: 0.14, blue: 0.16)

    public var body: some View {
        NavigationView {
            ZStack {
                darkBg.ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("Select a turn icon below to push immediately to your KTM dashboard.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 14) {
                            ForEach(KTMManeuver.allCases) { maneuver in
                                Button(action: {
                                    sendTestManeuver(maneuver)
                                }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: maneuver.sfSymbolName)
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(ktmOrange)

                                        Text(maneuver.title)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 90)
                                    .background(cardBg)
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("TFT Icon Tester")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(ktmOrange))
        }
    }

    private func sendTestManeuver(_ maneuver: KTMManeuver) {
        let testState = NavigationState(
            isNavigating: true,
            currentManeuver: maneuver,
            nextManeuverDistanceMeters: 250,
            totalDistanceRemainingMeters: 4500,
            estimatedTimeRemainingSeconds: 360,
            nextStreetName: "Highway 1",
            currentStreetName: "Testing TFT"
        )
        btManager.sendNavigationUpdate(testState)
    }
}

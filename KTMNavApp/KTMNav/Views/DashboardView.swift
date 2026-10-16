//
//  DashboardView.swift
//  KTMNav
//
//  High-contrast, outdoor-readable rider HUD matching KTM TFT signature styling.
//

import SwiftUI
import MapKit

public struct DashboardView: View {
    @ObservedObject var btManager = KTMBluetoothManager.shared
    @ObservedObject var navEngine = NavigationEngine.shared
    @State private var showingSearch = false
    @State private var showingSimSheet = false

    // KTM Ready to Race signature orange
    private let ktmOrange = Color(red: 1.0, green: 0.40, blue: 0.0)
    private let darkBg = Color(red: 0.08, green: 0.08, blue: 0.10)
    private let cardBg = Color(red: 0.14, green: 0.14, blue: 0.16)

    public var body: some View {
        NavigationView {
            ZStack {
                darkBg.ignoresSafeArea()

                VStack(spacing: 16) {
                    // Top Bike Status Bar
                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(btManager.isConnected ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(btManager.isConnected ? (btManager.connectedBike?.name ?? "KTM Connected") : "Bike Disconnected")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        if btManager.isConnected {
                            Label("TFT Live", systemImage: "display")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ktmOrange)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if navEngine.isNavigating {
                        // ACTIVE NAVIGATION HUD
                        VStack(spacing: 20) {
                            // Big Turn Maneuver Icon
                            ZStack {
                                Circle()
                                    .fill(cardBg)
                                    .frame(width: 140, height: 140)
                                    .overlay(
                                        Circle().stroke(ktmOrange, lineWidth: 3)
                                    )

                                Image(systemName: navEngine.currentState.currentManeuver.sfSymbolName)
                                    .font(.system(size: 64, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 10)

                            // Distance to Turn
                            VStack(spacing: 4) {
                                Text(navEngine.currentState.formattedTurnDistance())
                                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                                    .foregroundColor(ktmOrange)

                                Text(navEngine.currentState.currentManeuver.title.uppercased())
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.gray)
                            }

                            // Next Road Name
                            Text(navEngine.currentState.nextStreetName.isEmpty ? "Continue on Route" : navEngine.currentState.nextStreetName)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .lineLimit(2)

                            // Trip Metrics Strip
                            HStack(spacing: 16) {
                                MetricCard(title: "REMAINING", value: navEngine.currentState.formattedTotalDistance())
                                MetricCard(title: "ETA", value: navEngine.currentState.formattedETA)
                                MetricCard(title: "SPEED", value: "\(Int(navEngine.currentState.currentSpeedKmh)) km/h")
                            }
                            .padding(.horizontal)

                            Spacer()

                            // Stop Navigation Button
                            Button(action: {
                                navEngine.stopNavigation()
                            }) {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("END NAVIGATION")
                                }
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.red.opacity(0.85))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 12)
                        }
                    } else {
                        // IDLE DASHBOARD (Search Destination & Favorites)
                        ScrollView {
                            VStack(spacing: 20) {
                                // Search Bar Trigger
                                Button(action: { showingSearch = true }) {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(ktmOrange)
                                        Text("Search destination or paste route...")
                                            .foregroundColor(.gray)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(cardBg)
                                    .cornerRadius(14)
                                }
                                .padding(.horizontal)

                                // Quick Ride Favorites
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("QUICK RIDE FAVORITES")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(ktmOrange)
                                        .padding(.horizontal)

                                    ForEach(RouteManager.shared.savedFavorites) { fav in
                                        Button(action: {
                                            startRouteTo(fav: fav)
                                        }) {
                                            HStack(spacing: 16) {
                                                Image(systemName: fav.icon)
                                                    .font(.system(size: 20))
                                                    .foregroundColor(ktmOrange)
                                                    .frame(width: 32)

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(fav.name)
                                                        .font(.system(size: 16, weight: .semibold))
                                                        .foregroundColor(.white)
                                                    Text("Ready to navigate")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.gray)
                                                }
                                                Spacer()
                                                Image(systemName: "arrow.right.circle.fill")
                                                    .foregroundColor(ktmOrange)
                                            }
                                            .padding()
                                            .background(cardBg)
                                            .cornerRadius(12)
                                        }
                                        .padding(.horizontal)
                                    }
                                }

                                // TFT Preview & Simulator Card
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("TFT DASHBOARD TESTER")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(ktmOrange)
                                        .padding(.horizontal)

                                    Button(action: { showingSimSheet = true }) {
                                        HStack {
                                            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                                                .font(.system(size: 24))
                                                .foregroundColor(ktmOrange)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Test TFT Icons on Bike")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                Text("Send test turns to your KTM dash while parked")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.gray)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.gray)
                                        }
                                        .padding()
                                        .background(cardBg)
                                        .cornerRadius(12)
                                    }
                                    .padding(.horizontal)
                                }

                                Spacer(minLength: 40)
                            }
                        }
                    }
                }
            }
            .navigationTitle("KTM TFT Nav")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingSearch) {
                DestinationSearchView()
            }
            .sheet(isPresented: $showingSimSheet) {
                TFTSimulatorView()
            }
        }
    }

    private func startRouteTo(fav: RouteManager.SavedDestination) {
        let coord = CLLocationCoordinate2D(latitude: fav.latitude, longitude: fav.longitude)
        let placemark = MKPlacemark(coordinate: coord)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = fav.name

        navEngine.calculateRoute(to: mapItem) { result in
            switch result {
            case .success(let route):
                navEngine.startNavigation(with: route)
            case .failure(let error):
                print("Failed to start route: \(error.localizedDescription)")
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(red: 0.14, green: 0.14, blue: 0.16))
        .cornerRadius(10)
    }
}

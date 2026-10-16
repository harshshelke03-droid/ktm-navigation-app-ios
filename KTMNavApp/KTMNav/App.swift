//
//  App.swift
//  KTMNav
//
//  Application entry point and main tab shell.
//

import SwiftUI

@main
struct KTMNavApp: App {
    init() {
        // Request background location and Bluetooth permissions on launch
        NavigationEngine.shared.requestPermissions()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
    }
}

struct MainTabView: View {
    private let ktmOrange = Color(red: 1.0, green: 0.40, blue: 0.0)

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge.with.needle")
                }

            BluetoothView()
                .tabItem {
                    Label("Bluetooth", systemImage: "antenna.radiowaves.left.and.right")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .accentColor(ktmOrange)
    }
}

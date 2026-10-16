# KTMNav iOS — Free KTM TFT Turn-by-Turn Companion

**KTMNav** is an independent, 100% free, open-source companion app for iPhone that streams real-time turn-by-turn navigation directly to your KTM (and Husqvarna) TFT instrument cluster over Bluetooth Low Energy (BLE) — **without any subscription, Tech Pack navigation fees, or cloud account requirements**.

---

## 🚀 Key Features

- **Zero Subscriptions / 100% Free**: No recurring monthly fees, in-app purchases, or KTMconnect navigation paywalls.
- **Native KTM TFT Dash Integration**: Mirrors turn icons (left, right, slight, sharp, roundabouts 1-8, U-turns), distance to next turn, street names, remaining distance, and ETA directly on your bike's screen.
- **Runs with Phone Locked & in Pocket**: Full background execution (`UIBackgroundModes: location, bluetooth-central`). Your phone stays safely stored in your jacket — no expensive phone mount risking vibration damage to your iPhone camera OIS.
- **On-Device Apple MapKit Navigation**: Route calculations, search, and GPS tracking run completely on-device. Works offline once routes are calculated.
- **Fast Auto-Reconnect**: Remembers your bike's Bluetooth identifier and reconnects automatically within ~1 second whenever you cycle the ignition key.
- **Zero Data Harvesting**: No user tracking, no analytics, no third-party servers. All data stays strictly on your device.

---

## 🏍️ Compatible Motorcycle Models

Tested and architected for motorcycles equipped with the **KTM / Husqvarna Gen-3 and Gen-2 TFT Dashboards** (via the BCCU Bluetooth Connectivity Control Unit):
- **KTM Duke 390** (Gen 3: 2024–2026, Gen 2: 2017–2023)
- **KTM Duke 250** (Gen 3: 2024–2026)
- **KTM 390 Adventure** (2020–2026)
- **KTM 250 Adventure** (2021–2026)
- **KTM 890 Adventure / Duke** (2021–2026)
- **KTM 1290 Super Adventure S / R / GT**
- **Husqvarna Norden 901 / Svartpilen / Vitpilen 401**

---

## 🛠️ Project Structure

```
KTMNavApp/
├── Package.swift                  # Swift Package Manager manifest
├── KTMNav/
│   ├── App.swift                  # App entry point & TabView
│   ├── Info.plist                 # Permissions & Background Modes
│   ├── Models/
│   │   ├── KTMManeuver.swift       # 58 TFT icon codes & MapKit mapping
│   │   ├── NavigationState.swift   # Live navigation status model
│   │   └── KTMBikeDevice.swift     # Motorcycle peripheral representation
│   ├── Bluetooth/
│   │   └── KTMBluetoothManager.swift # CoreBluetooth BCCU driver & packet framing
│   ├── Navigation/
│   │   ├── NavigationEngine.swift   # On-device GPS turn-by-turn tracker
│   │   └── RouteManager.swift       # POI search & route importer
│   └── Views/
│       ├── DashboardView.swift      # High-contrast outdoor rider HUD
│       ├── BluetoothView.swift      # BLE scanner & pairing UI
│       ├── DestinationSearchView.swift # Map search & route loader
│       ├── TFTSimulatorView.swift   # Dashboard icon bench-tester
│       └── SettingsView.swift       # Rider audio & unit settings
```

---

## 📱 How to Build and Install on Your iPhone (Free)

You **do not** need a paid Apple Developer Account ($99/year). You can install KTMNav using a free standard Apple ID.

### Option A: Direct via Xcode (Mac)
1. Clone or copy the `KTMNavApp` folder to your Mac.
2. Open the project in Xcode.
3. Connect your iPhone via USB / Wi-Fi.
4. In Xcode under **Signing & Capabilities**, select your **Personal Team** (your free Apple ID).
5. Click **Run (Cmd + R)**. Xcode will compile and install KTMNav onto your iPhone.
6. On your iPhone, go to **Settings → General → VPN & Device Management** and tap **Trust** on your developer certificate.

### Option B: Sideloading (Windows / Mac via Sideloadly or AltStore)
1. Build or export the `.ipa` using Xcode or Swift CLI.
2. Open **Sideloadly** or **AltStore**, drag in the `.ipa`, enter your Apple ID, and install.

---

## 🔗 Step-by-Step Motorcycle Pairing Guide

1. **Turn on Bike Ignition**: Turn on your KTM motorcycle key so the TFT dash illuminates.
2. **Access Dash Menu**:
   - Using the 4-way handlebar switchgear (Left switch cube), navigate to:
     `Menu → Settings → Bluetooth → Phone → Pairing` (or `Add Device`).
   - The dash will enter discoverable pairing mode and display its pairing prompt.
3. **Open KTMNav on iPhone**:
   - Go to the **Bluetooth** tab and tap **Scan for Bikes**.
   - Your bike will appear in the list (e.g. `KTM DUKE 390` or `KTM ADV`).
   - Tap **Connect**.
4. **Confirm Pairing on TFT**:
   - The bike's screen will ask to confirm the 6-digit passkey or confirm connection.
   - Press **SET / ENTER** on the handlebar switch.
5. **Start Navigating**:
   - Search any destination or tap a Quick Favorite.
   - Lock your iPhone and put it in your pocket. The turn arrows, distance, and road names will immediately mirror on your bike's TFT display!

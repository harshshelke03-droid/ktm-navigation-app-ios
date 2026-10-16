//
//  NavigationEngine.swift
//  KTMNav
//
//  Native on-device GPS turn-by-turn guidance engine built on Apple MapKit and CoreLocation.
//  Completely free, runs 100% offline once route is computed, with zero subscriptions.
//

import Foundation
import CoreLocation
import MapKit
import AVFoundation

public protocol NavigationEngineDelegate: AnyObject {
    func navigationEngine(_ engine: NavigationEngine, didUpdateState state: NavigationState)
    func navigationEngine(_ engine: NavigationEngine, didArriveAt destination: String)
    func navigationEngineDidStartRerouting(_ engine: NavigationEngine)
}

public final class NavigationEngine: NSObject, ObservableObject {
    public static let shared = NavigationEngine()

    @Published public private(set) var currentState = NavigationState()
    @Published public private(set) var currentRoute: MKRoute?
    @Published public private(set) var routeSteps: [MKRoute.Step] = []
    @Published public private(set) var currentStepIndex: Int = 0
    @Published public private(set) var isNavigating = false
    @Published public var voiceGuidanceEnabled: Bool = true
    @Published public var audioBeepsEnabled: Bool = true

    public weak var delegate: NavigationEngineDelegate?

    private let locationManager = CLLocationManager()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var lastSpokenStepIndex: Int = -1
    private var destinationCoordinate: CLLocationCoordinate2D?
    private var destinationName: String = "Destination"

    public override init() {
        super.init()
        setupLocationManager()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 2.0 // updates every 2 meters
        locationManager.activityType = .automotiveNavigation
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
    }

    public func requestPermissions() {
        locationManager.requestAlwaysAuthorization()
    }

    // MARK: - Route Planning (Free Apple MapKit Routing)
    public func calculateRoute(to destination: MKMapItem, completion: @escaping (Result<MKRoute, Error>) -> Void) {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = destination
        request.transportType = .automobile // optimal for motorcycle road routes

        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let route = response?.routes.first else {
                let noRouteError = NSError(domain: "KTMNav", code: -1, userInfo: [NSLocalizedDescriptionKey: "No route found"])
                completion(.failure(noRouteError))
                return
            }

            self?.destinationCoordinate = destination.placemark.coordinate
            self?.destinationName = destination.name ?? "Destination"
            completion(.success(route))
        }
    }

    // MARK: - Navigation Life Cycle
    public func startNavigation(with route: MKRoute) {
        currentRoute = route
        routeSteps = route.steps.filter { !$0.instructions.isEmpty }
        currentStepIndex = 0
        lastSpokenStepIndex = -1
        isNavigating = true

        locationManager.startUpdatingLocation()

        let initialManeuver = routeSteps.first.map { KTMManeuver.from(step: $0) } ?? .straight
        let nextStreet = routeSteps.first?.instructions ?? ""

        currentState = NavigationState(
            isNavigating: true,
            currentManeuver: initialManeuver,
            nextManeuverDistanceMeters: UInt32(routeSteps.first?.distance ?? 0),
            totalDistanceRemainingMeters: UInt32(route.distance),
            estimatedTimeRemainingSeconds: UInt32(route.expectedTravelTime),
            nextStreetName: nextStreet,
            currentStreetName: "Starting Route",
            arrivalDate: Date().addingTimeInterval(route.expectedTravelTime)
        )

        // Push initial state to motorcycle TFT screen
        KTMBluetoothManager.shared.sendNavigationUpdate(currentState)
        speakManeuver(instruction: "Starting route to \(destinationName). \(nextStreet)")
    }

    public func stopNavigation() {
        isNavigating = false
        currentRoute = nil
        routeSteps.removeAll()
        currentStepIndex = 0

        currentState = NavigationState(isNavigating: false)
        locationManager.stopUpdatingLocation()

        // Inform TFT to clear navigation symbols
        KTMBluetoothManager.shared.sendNavigationStop()
    }

    // MARK: - Off-Route Detection & Auto-Reroute
    private func checkOffRoute(riderLocation: CLLocation) {
        guard let route = currentRoute, isNavigating else { return }

        // Find distance to closest point on polyline
        let points = route.polyline.points()
        let count = route.polyline.pointCount
        var minDistance = Double.greatestFiniteMagnitude

        for i in 0..<count {
            let coord = points[i].coordinate
            let ptLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let dist = riderLocation.distance(from: ptLoc)
            if dist < minDistance { minDistance = dist }
        }

        // If rider is > 45 meters away from calculated route, trigger auto-reroute
        if minDistance > 45.0 {
            triggerReroute(from: riderLocation)
        }
    }

    private func triggerReroute(from location: CLLocation) {
        guard let destCoord = destinationCoordinate else { return }
        currentState.isOffRoute = true
        currentState.currentManeuver = .recalculatingRoute
        currentState.nextStreetName = "Recalculating..."
        KTMBluetoothManager.shared.sendNavigationUpdate(currentState)

        delegate?.navigationEngineDidStartRerouting(self)

        let destPlacemark = MKPlacemark(coordinate: destCoord)
        let destItem = MKMapItem(placemark: destPlacemark)
        destItem.name = destinationName

        calculateRoute(to: destItem) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let newRoute):
                self.startNavigation(with: newRoute)
                self.speakManeuver(instruction: "New route calculated.")
            case .failure(let error):
                print("Reroute failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Speech Audio Guidance
    private func speakManeuver(instruction: String) {
        guard voiceGuidanceEnabled else { return }
        let utterance = AVSpeechUtterance(string: instruction)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynthesizer.speak(utterance)
    }
}

// MARK: - CLLocationManagerDelegate
extension NavigationEngine: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let riderLocation = locations.last, isNavigating, !routeSteps.isEmpty else { return }

        let speedKmh = max(0, riderLocation.speed * 3.6)
        checkOffRoute(riderLocation: riderLocation)

        guard currentStepIndex < routeSteps.count else {
            // Destination reached
            currentState.currentManeuver = .destinationReached
            currentState.nextManeuverDistanceMeters = 0
            currentState.totalDistanceRemainingMeters = 0
            currentState.nextStreetName = "Arrived!"
            KTMBluetoothManager.shared.sendNavigationUpdate(currentState)
            speakManeuver(instruction: "You have arrived at your destination.")
            delegate?.navigationEngine(self, didArriveAt: destinationName)
            stopNavigation()
            return
        }

        let step = routeSteps[currentStepIndex]
        let stepEndCoord = step.polyline.points()[step.polyline.pointCount - 1].coordinate
        let stepEndLoc = CLLocation(latitude: stepEndCoord.latitude, longitude: stepEndCoord.longitude)

        let distanceToTurn = UInt32(max(0, riderLocation.distance(from: stepEndLoc)))

        // Advance to next step when within 20 meters of maneuver
        if distanceToTurn < 20 {
            currentStepIndex += 1
            if currentStepIndex < routeSteps.count {
                let nextStep = routeSteps[currentStepIndex]
                speakManeuver(instruction: nextStep.instructions)
            }
        }

        // Calculate total remaining distance across future steps
        var remainingMeters: UInt32 = distanceToTurn
        if currentStepIndex + 1 < routeSteps.count {
            for i in (currentStepIndex + 1)..<routeSteps.count {
                remainingMeters += UInt32(routeSteps[i].distance)
            }
        }

        // Compute updated ETA
        let speedMps = max(5.0, riderLocation.speed) // Fallback to 18 km/h if stopped
        let timeRemainingSeconds = UInt32(Double(remainingMeters) / speedMps)
        let arrival = Date().addingTimeInterval(TimeInterval(timeRemainingSeconds))

        let maneuver = KTMManeuver.from(step: step)
        let street = step.instructions

        currentState = NavigationState(
            isNavigating: true,
            currentManeuver: maneuver,
            nextManeuverDistanceMeters: distanceToTurn,
            totalDistanceRemainingMeters: remainingMeters,
            estimatedTimeRemainingSeconds: timeRemainingSeconds,
            nextStreetName: street,
            currentStreetName: "En Route",
            currentSpeedKmh: speedKmh,
            isOffRoute: false,
            arrivalDate: arrival
        )

        // Stream real-time update to KTM TFT screen
        KTMBluetoothManager.shared.sendNavigationUpdate(currentState)
        delegate?.navigationEngine(self, didUpdateState: currentState)
    }
}

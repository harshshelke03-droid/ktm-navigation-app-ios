//
//  RouteManager.swift
//  KTMNav
//
//  Route discovery, GPX track parsing, and Google Maps URL import.
//

import Foundation
import MapKit

public final class RouteManager: ObservableObject {
    public static let shared = RouteManager()

    @Published public var searchResults: [MKMapItem] = []
    @Published public var savedFavorites: [SavedDestination] = []

    public struct SavedDestination: Identifiable, Codable {
        public let id: UUID
        public let name: String
        public let latitude: Double
        public let longitude: Double
        public let icon: String

        public init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double, icon: String = "mappin") {
            self.id = id
            self.name = name
            self.latitude = latitude
            self.longitude = longitude
            self.icon = icon
        }
    }

    public init() {
        loadDefaultFavorites()
    }

    private func loadDefaultFavorites() {
        savedFavorites = [
            SavedDestination(name: "Home", latitude: 19.0760, longitude: 72.8777, icon: "house.fill"),
            SavedDestination(name: "Work", latitude: 19.0178, longitude: 72.8478, icon: "briefcase.fill"),
            SavedDestination(name: "Favorite Twisty Pass", latitude: 18.7546, longitude: 73.4062, icon: "mountain.2.fill")
        ]
    }

    /// Search destinations via Apple MapKit local search (completely free)
    public func search(query: String, completion: @escaping ([MKMapItem]) -> Void) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            let items = response?.mapItems ?? []
            DispatchQueue.main.async {
                self.searchResults = items
                completion(items)
            }
        }
    }

    /// Import shared route or destination link from Google Maps or Apple Maps
    public func parseSharedRouteURL(_ url: URL) -> CLLocationCoordinate2D? {
        let urlString = url.absoluteString

        // Match Google Maps coordinates: @latitude,longitude or ?q=latitude,longitude
        if let regex = try? NSRegularExpression(pattern: #"([-+]?\d{1,2}\.\d+),\s*([-+]?\d{1,3}\.\d+)"#) {
            let nsString = urlString as NSString
            let results = regex.matches(in: urlString, range: NSRange(location: 0, length: nsString.length))
            if let match = results.first {
                let lat = Double(nsString.substring(with: match.range(at: 1))) ?? 0.0
                let lon = Double(nsString.substring(with: match.range(at: 2))) ?? 0.0
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
        return nil
    }
}

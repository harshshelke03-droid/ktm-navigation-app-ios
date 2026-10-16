//
//  DestinationSearchView.swift
//  KTMNav
//
//  Search points of interest or paste Google Maps shared links.
//

import SwiftUI
import MapKit

public struct DestinationSearchView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var queryText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false

    private let ktmOrange = Color(red: 1.0, green: 0.40, blue: 0.0)
    private let darkBg = Color(red: 0.08, green: 0.08, blue: 0.10)
    private let cardBg = Color(red: 0.14, green: 0.14, blue: 0.16)

    public var body: some View {
        NavigationView {
            ZStack {
                darkBg.ignoresSafeArea()

                VStack(spacing: 12) {
                    // Search Textfield
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(ktmOrange)
                        TextField("Enter place, city, or paste Maps link", text: $queryText, onCommit: performSearch)
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        if !queryText.isEmpty {
                            Button(action: { queryText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(cardBg)
                    .cornerRadius(12)
                    .padding(.horizontal)

                    if isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ktmOrange))
                            .padding()
                    }

                    List(searchResults, id: \.self) { item in
                        Button(action: {
                            selectDestination(item)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name ?? "Destination")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Text(item.placemark.title ?? "")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                        .listRowBackground(cardBg)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Choose Destination")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(ktmOrange))
        }
    }

    private func performSearch() {
        guard !queryText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Check if query is a shared Google Maps URL
        if let url = URL(string: queryText), let coord = RouteManager.shared.parseSharedRouteURL(url) {
            let placemark = MKPlacemark(coordinate: coord)
            let item = MKMapItem(placemark: placemark)
            item.name = "Shared Route Target"
            searchResults = [item]
            return
        }

        isSearching = true
        RouteManager.shared.search(query: queryText) { items in
            isSearching = false
            searchResults = items
        }
    }

    private func selectDestination(_ item: MKMapItem) {
        NavigationEngine.shared.calculateRoute(to: item) { result in
            switch result {
            case .success(let route):
                NavigationEngine.shared.startNavigation(with: route)
                presentationMode.wrappedValue.dismiss()
            case .failure(let error):
                print("Failed: \(error.localizedDescription)")
            }
        }
    }
}

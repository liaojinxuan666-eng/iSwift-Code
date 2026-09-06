import Foundation

/// Built-in source fixtures that exercise the complete portable custom
/// Identifiable item preview pipeline.
///
/// These are intentionally source strings rather than executable SwiftUI view
/// types. The preview system must lower them through the same provider stack as
/// user-authored files.
enum PreviewIdentifiableDemoCatalog {
    static let sheetSource =
        """
        import SwiftUI

        struct DetailItem: Identifiable {
            let id: Int
            let title: String
            let subtitle: String
        }

        struct ContentView: View {
            @State private var selectedItem: DetailItem? = nil

            var body: some View {
                VStack(spacing: 16) {
                    Text("Identifiable Sheet Demo")

                    Button("Open Details") {
                        selectedItem = DetailItem(
                            id: 1,
                            title: "Details",
                            subtitle: "Portable preview item"
                        )
                    }
                }
                .sheet(item: $selectedItem) { item in
                    VStack(spacing: 12) {
                        Text(item.title)
                        Text("ID: \\(item.id)")
                        Text("Subtitle: \\(item.subtitle)")

                        Button("Close") {
                            selectedItem = nil
                        }
                    }
                }
            }
        }
        """

    static let fullScreenSource =
        """
        import SwiftUI

        struct ProfileItem: Identifiable {
            let id: String
            let name: String
            let enabled: Bool
        }

        struct ContentView: View {
            @State private var selectedProfile: ProfileItem? = nil

            var body: some View {
                VStack(spacing: 16) {
                    Text("Identifiable Full Screen Demo")

                    Button("Open Profile") {
                        selectedProfile = ProfileItem(
                            id: "primary",
                            name: "iSwift Code",
                            enabled: true
                        )
                    }
                }
                .fullScreenCover(item: $selectedProfile) { item in
                    VStack(spacing: 12) {
                        Text(item.name)
                        Text("ID: \\(item.id)")
                        Text("Enabled: \\(item.enabled)")

                        Button("Close Profile") {
                            selectedProfile = nil
                        }
                    }
                }
            }
        }
        """

    static let invalidMemberSource =
        """
        import SwiftUI

        struct DetailItem: Identifiable {
            let id: Int
            let title: String
        }

        struct ContentView: View {
            @State private var selectedItem: DetailItem? = nil

            var body: some View {
                VStack {
                    Text("Invalid Member Demo")
                }
                .sheet(item: $selectedItem) { item in
                    Text(item.notExist)
                }
            }
        }
        """
}

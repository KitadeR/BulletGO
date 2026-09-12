import SwiftUI

struct PlaceSearchField: View {
    var title: LocalizedStringKey
    @Binding var text: String
    var search: (any PlaceSearching)?
    var accessibilityID: String = ""
    var onSelect: (PlaceReference) -> Void

    @State private var completions: [PlaceSearchCompletion] = []
    @State private var isSearching = false

    var body: some View {
        Section {
            TextField(title, text: $text)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier(accessibilityID)
                .onChange(of: text) { _, newValue in
                    Task { await refresh(newValue) }
                }
            if isSearching {
                ProgressView()
            }
            ForEach(completions) { completion in
                Button {
                    Task { await choose(completion) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: completion.title)
                        if !completion.subtitle.isEmpty {
                            Text(verbatim: completion.subtitle)
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Color.secondaryText)
                        }
                    }
                }
            }
        }
    }

    private func refresh(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let search, trimmed.count >= 2 else {
            completions = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            completions = try await search.completions(for: trimmed)
        } catch {
            completions = []
        }
    }

    private func choose(_ completion: PlaceSearchCompletion) async {
        guard let search else { return }
        do {
            let place = try await search.lookup(completion)
            text = place.name
            onSelect(place)
            completions = []
        } catch {
            text = completion.title
            onSelect(.manual(name: completion.title))
            completions = []
        }
    }
}

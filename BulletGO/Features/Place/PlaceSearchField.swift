import SwiftUI

struct PlaceSearchField: View {
    var title: LocalizedStringKey
    @Binding var text: String
    var search: (any PlaceSearching)?
    var accessibilityID: String = ""
    var onSelect: (PlaceReference) -> Void
    var onClear: (() -> Void)? = nil

    @State private var completions: [PlaceSearchCompletion] = []
    @State private var isSearching = false
    @State private var selectedName: String?
    @State private var generation = 0
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        Section {
            TextField(title, text: $text)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier(accessibilityID)
                .onChange(of: text) { _, newValue in
                    if let selectedName, newValue != selectedName {
                        onClear?()
                        self.selectedName = nil
                    }
                    debounceTask?.cancel()
                    generation += 1
                    let current = generation
                    debounceTask = Task {
                        try? await Task.sleep(for: .milliseconds(280))
                        guard !Task.isCancelled, current == generation else { return }
                        await refresh(newValue, generation: current)
                    }
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

    private func refresh(_ query: String, generation current: Int) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let search, trimmed.count >= 2 else {
            completions = []
            isSearching = false
            return
        }
        isSearching = true
        defer {
            if current == generation {
                isSearching = false
            }
        }
        do {
            let results = try await search.completions(for: trimmed)
            guard current == generation else { return }
            completions = results
        } catch {
            guard current == generation else { return }
            completions = []
        }
    }

    private func choose(_ completion: PlaceSearchCompletion) async {
        guard let search else { return }
        do {
            let place = try await search.lookup(completion)
            selectedName = place.name
            text = place.name
            onSelect(place)
            completions = []
        } catch {
            selectedName = completion.title
            text = completion.title
            onSelect(.manual(name: completion.title))
            completions = []
        }
    }
}

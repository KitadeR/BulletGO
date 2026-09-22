import SwiftUI

struct PlaceSearchField: View {
    var title: LocalizedStringKey
    @Binding var text: String
    var search: (any PlaceSearching)?
    var accessibilityID: String = ""
    var onSelect: (PlaceReference) -> Void
    var onClear: (() -> Void)? = nil

    @Environment(\.placeSearching) private var environmentSearch
    @State private var model = PlaceSearchModel()

    var body: some View {
        Section {
            TextField(title, text: $text)
                .textInputAutocapitalization(.words)
                .submitLabel(.search)
                .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
                .accessibilityLabel(Text(title))
                .accessibilityHint("Search places")
                .accessibilityIdentifier(accessibilityID)
                .onSubmit {
                    model.searchNow()
                }
                .onChange(of: text) { _, newValue in
                    let hadSelection = model.selected != nil
                    model.updateQuery(newValue)
                    if hadSelection, model.selected == nil {
                        onClear?()
                    }
                }
            if let selected = model.selected {
                selectedRow(selected)
            }
            if model.isSearching || model.isResolving {
                ProgressView()
                    .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
                    .accessibilityLabel("Searching")
            }
            if model.failure != nil {
                failureRow
            } else if model.showsEmptyResults {
                Text("No places found")
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
                    .accessibilityIdentifier(AccessibilityID.placeSearchEmpty)
            }
            ForEach(model.completions) { completion in
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
                    .frame(maxWidth: .infinity, minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
                }
                .disabled(model.isResolving)
                .accessibilityLabel(Text(verbatim: completion.title))
                .accessibilityHint("Choose this place")
                .accessibilityValue(Text(verbatim: completion.subtitle))
                .accessibilityIdentifier(AccessibilityID.placeSearchResult(completion.id))
            }
        }
        .task {
            model.search = search ?? environmentSearch
            if model.query != text {
                model.updateQuery(text)
            }
        }
    }

    @ViewBuilder
    private func selectedRow(_ place: PlaceReference) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DesignTokens.Color.primaryText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Selected place")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                Text(verbatim: place.name)
                if let address = place.displayAddress {
                    Text(verbatim: address)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(selectedAccessibilityLabel(place))
        .accessibilityIdentifier(AccessibilityID.placeSearchSelected)
    }

    private var failureRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Couldn’t search places")
                .foregroundStyle(DesignTokens.Color.secondaryText)
                .accessibilityIdentifier(AccessibilityID.placeSearchFailed)
            Button("Retry") {
                model.retry()
            }
            .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
            .accessibilityIdentifier(AccessibilityID.placeSearchRetry)
        }
    }

    private func choose(_ completion: PlaceSearchCompletion) async {
        await model.select(completion)
        text = model.query
        if let selected = model.selected {
            onSelect(selected)
        }
    }

    private func selectedAccessibilityLabel(_ place: PlaceReference) -> Text {
        if let address = place.displayAddress {
            Text("Selected place, \(place.name), \(address)")
        } else {
            Text("Selected place, \(place.name)")
        }
    }
}

struct GuidedAddPlaceEditor: View {
    var title: LocalizedStringKey
    var fieldTitle: LocalizedStringKey
    @Binding var text: String
    var selected: PlaceReference?
    var accessibilityID: String = ""
    var onSelect: (PlaceReference) -> Void
    var onClear: () -> Void

    @Environment(\.placeSearching) private var environmentSearch
    @State private var model = PlaceSearchModel()
    @FocusState private var focused: Bool

    var body: some View {
        GuidedAddCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Color.primaryText)
                GuidedAddInnerSearchField(
                    title: fieldTitle,
                    text: $text,
                    accessibilityID: accessibilityID,
                    focused: $focused,
                    onSubmit: { model.searchNow() }
                )
                .onChange(of: text) { _, newValue in
                    let hadSelection = model.selected != nil
                    model.updateQuery(newValue)
                    if hadSelection, model.selected == nil {
                        onClear()
                    }
                }
                if model.isSearching || model.isResolving {
                    ProgressView()
                        .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
                }
                ForEach(model.completions) { completion in
                    Button {
                        Task { await choose(completion) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: completion.title)
                                .font(DesignTokens.Typography.headline)
                                .foregroundStyle(DesignTokens.Color.primaryText)
                            if !completion.subtitle.isEmpty {
                                Text(verbatim: completion.subtitle)
                                    .font(DesignTokens.Typography.footnote)
                                    .foregroundStyle(DesignTokens.Color.secondaryText)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
                    }
                    .accessibilityIdentifier(AccessibilityID.placeSearchResult(completion.id))
                }
                if let selected, selected.isSearchResolved {
                    HStack {
                        Text(verbatim: selected.name)
                            .font(DesignTokens.Typography.headline)
                        Spacer()
                        GuidedAddCheck()
                    }
                    .accessibilityIdentifier(AccessibilityID.placeSearchSelected)
                }
            }
            .padding(18)
        }
        .task {
            model.search = environmentSearch
            if let selected {
                model.restoreSelected(selected)
            }
        }
    }

    private func choose(_ completion: PlaceSearchCompletion) async {
        await model.select(completion)
        guard let selected = model.selected else { return }
        text = selected.name
        onSelect(selected)
        focused = false
    }
}

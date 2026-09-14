import SwiftUI

struct DisplayTextLabel: View {
    var text: DisplayText

    var body: some View {
        switch text {
        case .localized(let resource):
            Text(resource)
        case .verbatim(let value):
            Text(verbatim: value)
        }
    }
}

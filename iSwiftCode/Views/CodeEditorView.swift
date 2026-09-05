import SwiftUI

struct CodeEditorView: View {
    @Binding var source: String

    var body: some View {
        TextEditor(text: $source)
            .font(.system(size: 15, design: .monospaced))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .scrollContentBackground(.hidden)
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .accessibilityLabel("Swift source editor")
    }
}

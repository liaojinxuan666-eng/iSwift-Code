import SwiftUI

struct ConsoleView: View {
    let output: String
    let diagnostics: [CompilerDiagnostic]
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Console", systemImage: "terminal")
                    .font(.headline)
                Spacer()
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !diagnostics.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(diagnostics) { diagnostic in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark.octagon.fill")
                                .foregroundStyle(.red)
                            Text("\(diagnostic.location.line):\(diagnostic.location.column)  \(diagnostic.message)")
                                .font(.system(size: 13, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            ScrollView {
                Text(output)
                    .font(.system(size: 14, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(minHeight: 110, maxHeight: 220)
            .padding(12)
            .background(Color.black.opacity(0.88))
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

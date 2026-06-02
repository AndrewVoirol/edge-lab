import SwiftUI

struct ShareOptionsSheet: View {
    @Bindable var viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss
    let onShare: ([ShareExportKind]) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Share sheet") {
                    shareRow("Everything (JSON + report + CSV)", kinds: [.json, .markdown, .csv])
                    shareRow("JSON manifest", kinds: [.json])
                    shareRow("Markdown report", kinds: [.markdown])
                    shareRow("CSV spreadsheet", kinds: [.csv])
                    shareRow("Tweet text", kinds: [.tweet])
                }

                Section("Copy to clipboard") {
                    Button("Copy JSON") { viewModel.copyExport(.json); dismiss() }
                    Button("Copy report") { viewModel.copyExport(.markdown); dismiss() }
                    Button("Copy CSV") { viewModel.copyExport(.csv); dismiss() }
                    Button("Copy tweet") { viewModel.copyExport(.tweet); dismiss() }
                }

                if viewModel.lastArchive != nil {
                    Section {
                        Text("Files are also saved under Files → Edge Lab → EdgeLabRuns for AirDrop from the Files app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Share results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func shareRow(_ title: String, kinds: [ShareExportKind]) -> some View {
        Button(title) {
            onShare(kinds)
            dismiss()
        }
    }
}
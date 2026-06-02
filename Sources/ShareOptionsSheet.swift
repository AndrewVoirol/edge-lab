import SwiftUI

struct ShareOptionsSheet: View {
    @Bindable var viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss
    let onShare: ([ShareExportKind]) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        viewModel.copyExport(.tweet)
                        dismiss()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Copy X post (recommended)")
                                    .font(.body.weight(.semibold))
                                Text("No link in main post — paste into X, then use thread for replies.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "text.quote")
                        }
                    }

                    Button {
                        viewModel.copyExport(.tweetThread)
                        dismiss()
                    } label: {
                        Label("Copy full 3-tweet thread", systemImage: "list.number")
                    }

                    Button {
                        onShare([.tweet])
                        dismiss()
                    } label: {
                        Label("Share X post via sheet", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Post on X")
                } footer: {
                    Text("Attach your JSON screenshot or file in reply 1. Links go in reply 2 (included in full thread). Tag @AI_Andrew.")
                }

                Section("Research exports") {
                    shareRow("Everything (JSON + report + CSV)", kinds: [.json, .markdown, .csv])
                    shareRow("JSON manifest", kinds: [.json])
                    shareRow("Markdown report", kinds: [.markdown])
                    shareRow("CSV spreadsheet", kinds: [.csv])
                }

                Section("Copy to clipboard") {
                    Button("Copy JSON") { viewModel.copyExport(.json); dismiss() }
                    Button("Copy report") { viewModel.copyExport(.markdown); dismiss() }
                    Button("Copy CSV") { viewModel.copyExport(.csv); dismiss() }
                }

                if viewModel.lastArchive != nil {
                    Section {
                        Text("Files saved under Files → Edge Lab → EdgeLabRuns (JSON, MD, CSV).")
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
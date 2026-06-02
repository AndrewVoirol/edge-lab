import SwiftUI

struct MatrixView: View {
    @Bindable var viewModel: LabViewModel
    @State private var showShareSheet = false
    @State private var shareURLs: [URL] = []
    @State private var showExportPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Experiment Matrix")
                .font(.headline)

            HStack(spacing: 12) {
                Button {
                    viewModel.runMatrix()
                } label: {
                    HStack {
                        if viewModel.isRunningMatrix {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(viewModel.isRunningMatrix ? "Running…" : "Run Experiment Matrix")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedModel == nil || viewModel.isRunningMatrix)

                if viewModel.isRunningMatrix {
                    Button(role: .destructive) {
                        viewModel.cancelMatrix()
                    } label: {
                        Image(systemName: "stop.fill")
                            .padding(.vertical, 14)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if viewModel.isRunningMatrix, let detail = viewModel.matrixProgressDetail {
                progressCard(detail)
            } else if !viewModel.matrixProgressLine.isEmpty {
                Text(viewModel.matrixProgressLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !viewModel.matrixResults.isEmpty {
                resultsTable
                shareSection
            }

            if let toast = viewModel.copiedToast {
                Text(toast)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            viewModel.copiedToast = nil
                        }
                    }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if !shareURLs.isEmpty {
                ShareSheet(items: shareURLs)
            }
        }
        .confirmationDialog("Share results", isPresented: $showExportPicker, titleVisibility: .visible) {
            Button("Share everything (JSON + Markdown + CSV)") {
                presentShare(kinds: [.json, .markdown, .csv])
            }
            Button("JSON manifest") { presentShare(kinds: [.json]) }
            Button("Markdown report") { presentShare(kinds: [.markdown]) }
            Button("CSV for spreadsheets") { presentShare(kinds: [.csv]) }
            Button("Tweet text file") { presentShare(kinds: [.tweet]) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func progressCard(_ detail: MatrixProgressUpdate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.matrixProgressLine)
                .font(.caption)
                .foregroundStyle(.secondary)

            if detail.phase == .benchmark {
                ProgressView(
                    value: Double(detail.tokensGenerated),
                    total: Double(detail.decodeCap)
                )
                .tint(.accentColor)
            } else {
                ProgressView()
                    .tint(.accentColor)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private var resultsTable: some View {
        VStack(spacing: 0) {
            tableHeader
            Divider()
            ForEach(viewModel.matrixResults) { row in
                resultRow(row)
                if row.id != viewModel.matrixResults.last?.id {
                    Divider().opacity(0.3)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var tableHeader: some View {
        HStack(spacing: 4) {
            headerCell("Preset", width: 80)
            headerCell("BE", width: 32)
            headerCell("Dec", width: 48)
            headerCell("Wall", width: 40)
            headerCell("Th", width: 32)
        }
        .font(.caption2.bold())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func headerCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .frame(width: width, alignment: .leading)
    }

    private func resultRow(_ row: MatrixRunResult) -> some View {
        let isBest = row.succeeded && row.decodeTokensPerSecond == bestDecode
        return HStack(spacing: 4) {
            Text(row.preset.label)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 80, alignment: .leading)
            Text(backendLabel(row))
                .font(.caption2.monospaced())
                .frame(width: 32, alignment: .leading)
            if row.succeeded {
                Text(String(format: "%.1f", row.decodeTokensPerSecond))
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(isBest ? .green : .primary)
                    .frame(width: 48, alignment: .leading)
                Text(String(format: "%.0fs", row.wallClockSeconds))
                    .font(.caption2.monospacedDigit())
                    .frame(width: 40, alignment: .leading)
                Text(row.thermalEnd.label.prefix(3))
                    .font(.caption2)
                    .frame(width: 32, alignment: .leading)
            } else {
                Text(row.errorMessage.map { String($0.prefix(28)) } ?? "err")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isBest ? Color.green.opacity(0.08) : Color.clear)
    }

    private func backendLabel(_ row: MatrixRunResult) -> String {
        let tag = row.activeBackend.uppercased()
        if row.didFallback { return "↺\(tag)" }
        return tag == "GPU" ? "GPU" : "CPU"
    }

    private var bestDecode: Double {
        viewModel.matrixResults.filter(\.succeeded).map(\.decodeTokensPerSecond).max() ?? 0
    }

    private var shareSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Share results")
                .font(.subheadline.bold())

            if viewModel.lastArchive != nil {
                Label("Saved under Files → On My iPhone → Edge Lab → EdgeLabRuns (JSON, MD, CSV)", systemImage: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                showExportPicker = true
            } label: {
                Label("Share…", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            HStack(spacing: 8) {
                copyButton("JSON", kind: .json)
                copyButton("Report", kind: .markdown)
                copyButton("CSV", kind: .csv)
                copyButton("Tweet", kind: .tweet)
            }
        }
    }

    private func copyButton(_ title: String, kind: ShareExportKind) -> some View {
        Button(title) {
            viewModel.copyExport(kind)
        }
        .buttonStyle(.bordered)
        .font(.caption)
    }

    private func presentShare(kinds: [ShareExportKind]) {
        do {
            shareURLs = try viewModel.shareURLs(for: kinds)
            showShareSheet = true
        } catch {
            viewModel.statusMessage = error.localizedDescription
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
import SwiftUI
import UniformTypeIdentifiers

struct MatrixView: View {
    @Bindable var viewModel: LabViewModel
    @State private var showShareSheet = false
    @State private var exportURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Experiment Matrix")
                .font(.headline)

            Button {
                Task { await viewModel.runMatrix() }
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

            if !viewModel.matrixProgress.isEmpty {
                Text(viewModel.matrixProgress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !viewModel.matrixResults.isEmpty {
                resultsTable
                exportButton
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
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
            headerCell("Preset", width: 88)
            headerCell("BE", width: 36)
            headerCell("Dec", width: 52)
            headerCell("TTFT", width: 44)
            headerCell("Th", width: 36)
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
                .frame(width: 88, alignment: .leading)
            Text(row.activeBackend.uppercased())
                .font(.caption2.monospaced())
                .frame(width: 36, alignment: .leading)
            if row.succeeded {
                Text(String(format: "%.1f", row.decodeTokensPerSecond))
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(isBest ? .green : .primary)
                    .frame(width: 52, alignment: .leading)
                Text(String(format: "%.2f", row.ttftSeconds))
                    .font(.caption2.monospacedDigit())
                    .frame(width: 44, alignment: .leading)
                Text(row.thermalEnd.label.prefix(3))
                    .font(.caption2)
                    .frame(width: 36, alignment: .leading)
            } else {
                Text("err")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isBest ? Color.green.opacity(0.08) : Color.clear)
    }

    private var bestDecode: Double {
        viewModel.matrixResults.filter(\.succeeded).map(\.decodeTokensPerSecond).max() ?? 0
    }

    private var exportButton: some View {
        Button {
            shareManifest()
        } label: {
            Label("Export JSON manifest", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func shareManifest() {
        do {
            let data = try viewModel.exportManifestData()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            let name = "edge-lab-matrix-\(formatter.string(from: Date()).replacingOccurrences(of: ":", with: "")).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try data.write(to: url)
            exportURL = url
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
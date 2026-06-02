import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var viewModel = LabViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    modelSection
                    MatrixView(viewModel: viewModel)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edge Lab")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.refreshModels()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.isFilePickerPresented = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
            .fileImporter(
                isPresented: $viewModel.isFilePickerPresented,
                allowedContentTypes: [UTType(filenameExtension: "litertlm") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                if let url = try? result.get().first {
                    viewModel.handleImport(url)
                }
            }
            .onAppear {
                viewModel.refreshModels()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("On-device experiment matrix")
                .font(.title3.bold())
            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label(DeviceContext.marketingName, systemImage: "iphone")
                Label("LiteRT-LM 0.12.0", systemImage: "cpu")
                Label("\(MatrixBenchmark.decodeCap) decode", systemImage: "gauge.with.dots.needle.67percent")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Models")
                .font(.headline)
            if viewModel.discoveredModels.isEmpty {
                emptyModelsCard
            } else {
                ForEach(viewModel.discoveredModels) { model in
                    ModelRow(
                        model: model,
                        isSelected: viewModel.selectedModel?.id == model.id
                    ) {
                        viewModel.selectModel(model)
                    }
                }
            }
        }
    }

    private var emptyModelsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bring your own `.litertlm`")
                .font(.subheadline.bold())
            Text("Import a file, copy from AI Edge Gallery via Files, or place models in Edge Lab’s Documents folder.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Import model") {
                viewModel.isFilePickerPresented = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ModelRow: View {
    let model: DiscoveredModel
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.filename)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        Text(model.formattedSize)
                        Text(model.source.rawValue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2), in: Capsule())
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding()
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.15)
                    : Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
    }
}
import PDFWerkstattCore
import SwiftUI

struct CompressView: View {
    @State private var files: [PDFFile] = []
    @State private var selection = Set<PDFFile.ID>()
    @State private var preset: CompressionPreset? = .balanced
    @State private var settings = CompressionPreset.balanced.settings
    @State private var isWorking = false
    @State private var results: [String] = []
    @State private var status: StatusMessage?

    var body: some View {
        VStack(spacing: 12) {
            ToolHeader(
                title: "PDFs komprimieren",
                subtitle: "Stärke wählen oder Qualität und Auflösung selbst einstellen."
            )

            List(selection: $selection) {
                ForEach(files) { file in FileRow(file: file) }
                    .onDelete { files.remove(atOffsets: $0) }
            }
            .frame(minHeight: 140)
            .overlay { if files.isEmpty { DropHint(text: "PDFs hierher ziehen") } }
            .dropDestination(for: URL.self) { urls, _ in
                add(urls)
                return true
            }

            settingsForm

            HStack {
                Button("Hinzufügen …") { add(FileDialogs.openPDFs(multiple: true)) }
                Button("Entfernen") {
                    files.removeAll { selection.contains($0.id) }
                    selection.removeAll()
                }
                .disabled(selection.isEmpty)
                Spacer()
                if isWorking { ProgressView().controlSize(.small) }
                Button("Komprimieren …", action: compress)
                    .buttonStyle(.borderedProminent)
                    .disabled(files.isEmpty || isWorking)
                    .keyboardShortcut(.defaultAction)
            }

            if !results.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(results, id: \.self) { Text($0).monospacedDigit() }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            StatusView(status: status)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }

    private var settingsForm: some View {
        GroupBox {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text("Stärke")
                    Picker("Stärke", selection: presetBinding) {
                        ForEach(CompressionPreset.allCases) { Text($0.title).tag(Optional($0)) }
                        Text("Eigene").tag(CompressionPreset?.none)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                GridRow {
                    Text("Modus")
                    Picker("Modus", selection: binding(\.mode)) {
                        ForEach(CompressionMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.radioGroup)
                    .horizontalRadioGroupLayout()
                    .labelsHidden()
                }
                GridRow {
                    Text("Bildqualität")
                    HStack {
                        Slider(value: binding(\.imageQuality), in: CompressionSettings.qualityRange)
                        Text("\(Int((settings.imageQuality * 100).rounded())) %")
                            .monospacedDigit().frame(width: 50, alignment: .trailing)
                    }
                }
                GridRow {
                    Text("Auflösung")
                    HStack {
                        Slider(value: binding(\.resolution), in: CompressionSettings.resolutionRange, step: 1)
                        Text("\(Int(settings.resolution)) DPI")
                            .monospacedDigit().frame(width: 70, alignment: .trailing)
                    }
                }
            }
            .padding(6)

            Text(settings.mode == .preserveText
                 ? "Text bleibt markier- und durchsuchbar; nur Bilder werden verkleinert."
                 : "Höchste Ersparnis, aber Text ist danach nicht mehr markierbar (wie ein Scan).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var presetBinding: Binding<CompressionPreset?> {
        Binding(
            get: { preset },
            set: { newValue in
                preset = newValue
                if let newValue { settings = newValue.settings }
            }
        )
    }

    /// Jede manuelle Änderung macht aus der Voreinstellung „Eigene“.
    private func binding<Value>(_ keyPath: WritableKeyPath<CompressionSettings, Value>) -> Binding<Value> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                settings[keyPath: keyPath] = newValue
                preset = nil
            }
        )
    }

    private func add(_ urls: [URL]) {
        let loaded = loadPDFFiles(urls)
        files.append(contentsOf: loaded.files)
        status = loaded.failures.isEmpty
            ? nil
            : .failure("Nicht lesbar: \(loaded.failures.joined(separator: ", "))")
    }

    private func compress() {
        let jobs: [(input: URL, output: URL)]
        if files.count == 1, let file = files.first {
            guard let output = FileDialogs.savePDF(suggestedName: "\(file.baseName) komprimiert.pdf") else { return }
            jobs = [(file.url, output)]
        } else {
            guard let folder = FileDialogs.chooseFolder() else { return }
            jobs = files.map { ($0.url, folder.appendingPathComponent("\($0.baseName) komprimiert.pdf")) }
        }

        let settings = settings
        isWorking = true
        results = []
        status = nil

        Task {
            let outcomes = await Task.detached(priority: .userInitiated) {
                jobs.map { job in
                    (job.input, Result { try PDFCompressor.compress(input: job.input, output: job.output, settings: settings) })
                }
            }.value

            var written: [URL] = []
            var lines: [String] = []
            var failures = 0
            for (input, outcome) in outcomes {
                switch outcome {
                case .success(let result):
                    written.append(result.outputURL)
                    if result.keptOriginal {
                        lines.append("\(input.lastPathComponent): \(formatBytes(result.originalBytes)) – bereits optimal, Original übernommen")
                    } else {
                        let percent = Int((result.savedFraction * 100).rounded())
                        lines.append("\(input.lastPathComponent): \(formatBytes(result.originalBytes)) → \(formatBytes(result.compressedBytes)) (−\(percent) %)")
                    }
                case .failure(let error):
                    failures += 1
                    lines.append("\(input.lastPathComponent): \(error.localizedDescription)")
                }
            }

            results = lines
            isWorking = false
            status = failures == 0
                ? .success("\(written.count) Datei(en) gespeichert.", written)
                : .failure("\(failures) Datei(en) konnten nicht komprimiert werden.")
        }
    }
}

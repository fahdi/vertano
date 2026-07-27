import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            ModelTierSettingsView()
                .tabItem { Label("Model", systemImage: "cpu") }
            TranslationSettingsView()
                .tabItem { Label("Translation", systemImage: "globe") }
        }
        .frame(width: 460, height: 360)
        .padding(20)
    }
}

private struct ModelTierSettingsView: View {
    @EnvironmentObject var queue: JobQueue
    @StateObject private var downloader = ModelDownloader()
    @State private var activeFilename = WhisperEngine.activeModel.filename
    @State private var readyFilenames: Set<String> = []
    @State private var showAllModels = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose the model used for transcription. Bigger models handle accents, mixed audio, and Indic-language code-switching better — at the cost of a larger download.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("RECOMMENDED")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(ModelTier.allCases) { tier in
                        tierRow(tier)
                        if tier != ModelTier.allCases.last { Divider() }
                    }
                }
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

                DisclosureGroup(isExpanded: $showAllModels) {
                    VStack(spacing: 0) {
                        ForEach(WhisperModel.all) { model in
                            modelRow(model)
                            if model != WhisperModel.all.last { Divider() }
                        }
                    }
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 6)
                } label: {
                    Text("All models (\(WhisperModel.all.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if let error = downloader.error, !downloader.isDownloading {
                    Text(error).font(.caption2).foregroundStyle(.red)
                }
            }
        }
        .onAppear(perform: refreshReady)
        .onChange(of: downloader.isDownloading) { _, downloading in
            if !downloading { refreshReady() }
        }
    }

    // MARK: - Rows

    private func tierRow(_ tier: ModelTier) -> some View {
        HStack(alignment: .top, spacing: 10) {
            selectionIcon(for: tier.model)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(tier.title).fontWeight(.medium)
                    Text(tier.approximateSizeLabel)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(tier.summary).font(.caption).foregroundStyle(.secondary)
                trailingControl(for: tier.model)
            }
            Spacer()
        }
        .padding(12)
    }

    private func modelRow(_ model: WhisperModel) -> some View {
        HStack(spacing: 10) {
            selectionIcon(for: model)
            VStack(alignment: .leading, spacing: 1) {
                Text(model.displayName).font(.callout)
                Text(model.approximateSizeLabel)
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            trailingControl(for: model)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func selectionIcon(for model: WhisperModel) -> some View {
        Image(systemName: isActive(model) ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(isActive(model) ? Color.accentColor : Color.secondary)
            .font(.title3)
            .onTapGesture { if isReady(model) { select(model) } }
    }

    @ViewBuilder
    private func trailingControl(for model: WhisperModel) -> some View {
        if isActive(model) {
            Text("In use").font(.caption2).foregroundStyle(Color.accentColor)
        } else if isReady(model) {
            Button("Use") { select(model) }.controlSize(.small)
        } else if isDownloading(model) {
            ProgressView(value: downloader.progress).frame(width: 90)
        } else {
            Button("Download") { downloader.start(model: model) }
                .controlSize(.small)
                .disabled(downloader.isDownloading)
        }
    }

    // MARK: - State helpers

    private func isActive(_ model: WhisperModel) -> Bool { activeFilename == model.filename }
    private func isReady(_ model: WhisperModel) -> Bool { readyFilenames.contains(model.filename) }
    private func isDownloading(_ model: WhisperModel) -> Bool {
        downloader.isDownloading && downloader.downloadingModel?.filename == model.filename
    }

    private func select(_ model: WhisperModel) {
        activeFilename = model.filename
        WhisperEngine.activeModel = model
    }

    private func refreshReady() {
        readyFilenames = Set(
            WhisperModel.all.filter { WhisperEngine.modelIsReady(for: $0) }.map(\.filename))
    }
}

private struct TranslationSettingsView: View {
    @EnvironmentObject var queue: JobQueue
    @AppStorage(OutputSettings.subtitlesKey) private var subtitlesEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The original spoken-language transcript is always saved. Check additional languages to also save a translated copy of each transcript.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Toggle("Also save subtitle files (.srt and .vtt) next to each transcript", isOn: $subtitlesEnabled)
                .toggleStyle(.checkbox)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(JobQueue.languages.filter { $0.code != "auto" }, id: \.code) { language in
                        Toggle(
                            language.name,
                            isOn: Binding(
                                get: { queue.targetLanguages.contains(language.code) },
                                set: { isOn in
                                    if isOn {
                                        queue.targetLanguages.insert(language.code)
                                    } else {
                                        queue.targetLanguages.remove(language.code)
                                    }
                                }
                            ))
                    }
                }
                .padding(.vertical, 4)
            }
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

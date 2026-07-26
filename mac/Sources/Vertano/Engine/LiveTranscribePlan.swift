import Foundation

/// How the live path should transcribe, resolved once at record-start from
/// what is installed: whether to drive the resident server, which model feeds
/// the live scroll, and how large each chunk is.
struct LiveTranscribePlan: Equatable {
    var useServer: Bool
    var liveModel: LiveModelChoice
    var chunkSampleCount: Int

    static func make(
        serverAvailable: Bool, instantReady: Bool, activeTier: ModelTier, sampleRate: Int
    ) -> LiveTranscribePlan {
        LiveTranscribePlan(
            useServer: serverAvailable,
            liveModel: WhisperEngine.liveModelSelection(
                instantReady: instantReady, activeTier: activeTier),
            chunkSampleCount: LiveChunking.chunkSampleCount(
                residentServer: serverAvailable, sampleRate: sampleRate))
    }
}

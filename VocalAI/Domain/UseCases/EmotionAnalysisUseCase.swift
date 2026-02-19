import Foundation

/// Wraps SentimentAnalyzer as a use case for testability.
struct EmotionAnalysisUseCase: Sendable {
    var analyze: @Sendable (String) -> EmotionType

    static let live = EmotionAnalysisUseCase { text in
        SentimentAnalyzer.analyze(text)
    }
}

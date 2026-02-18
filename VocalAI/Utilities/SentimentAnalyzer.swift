import Foundation

/// Lightweight keyword-based sentiment analysis to determine emotion from text.
enum SentimentAnalyzer {
    /// Analyze text and return the most likely emotion.
    static func analyze(_ text: String) -> EmotionType {
        let lowered = text.lowercased()

        let scores: [EmotionType: Int] = [
            .happy: countMatches(lowered, keywords: happyKeywords),
            .sad: countMatches(lowered, keywords: sadKeywords),
            .surprised: countMatches(lowered, keywords: surprisedKeywords),
            .angry: countMatches(lowered, keywords: angryKeywords),
            .thinking: countMatches(lowered, keywords: thinkingKeywords),
            .empathetic: countMatches(lowered, keywords: empatheticKeywords)
        ]

        // Check for explicit emotion tags from Claude (e.g., "[emotion:happy]")
        if let tagged = parseEmotionTag(text) {
            return tagged
        }

        guard let best = scores.max(by: { $0.value < $1.value }), best.value > 0 else {
            return .neutral
        }

        return best.key
    }

    // MARK: - Emotion Tags

    private static func parseEmotionTag(_ text: String) -> EmotionType? {
        let pattern = #"\[emotion:(\w+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return EmotionType(rawValue: String(text[range]))
    }

    // MARK: - Keyword Matching

    private static func countMatches(_ text: String, keywords: [String]) -> Int {
        keywords.reduce(0) { count, keyword in
            count + (text.contains(keyword) ? 1 : 0)
        }
    }

    // MARK: - Keyword Lists

    private static let happyKeywords = [
        "happy", "glad", "joy", "wonderful", "great", "amazing", "awesome",
        "fantastic", "excellent", "love", "excited", "thrilled", "delighted",
        "pleased", "cheerful", "😊", "😄", "🎉", "haha", "lol",
        "congratulations", "congrats", "celebrate", "fun", "laugh"
    ]

    private static let sadKeywords = [
        "sad", "sorry", "unfortunately", "regret", "miss", "loss", "grief",
        "disappointed", "heartbreak", "cry", "tears", "painful", "hurt",
        "tragic", "mourn", "depressed", "lonely", "sorrow", "😢", "😞",
        "condolences", "sympathy", "difficult time"
    ]

    private static let surprisedKeywords = [
        "wow", "surprising", "unexpected", "incredible", "unbelievable",
        "shocking", "astonishing", "remarkable", "really?", "no way",
        "can't believe", "oh my", "seriously?", "😮", "😲", "whoa",
        "amazing", "suddenly", "out of nowhere"
    ]

    private static let angryKeywords = [
        "angry", "furious", "annoyed", "frustrated", "irritated", "outraged",
        "unacceptable", "terrible", "awful", "horrible", "hate", "disgusting",
        "ridiculous", "infuriating", "😠", "😡", "unfair", "absurd"
    ]

    private static let thinkingKeywords = [
        "think", "consider", "perhaps", "maybe", "interesting question",
        "hmm", "let me", "on one hand", "on the other", "depends",
        "could be", "it's possible", "arguably", "nuanced", "complex",
        "🤔", "well", "that's a good point"
    ]

    private static let empatheticKeywords = [
        "understand", "feel", "must be", "sounds like", "i can see",
        "that's tough", "i hear you", "it's okay", "don't worry",
        "take your time", "i'm here", "support", "care about",
        "completely valid", "makes sense", "🤗", "natural to feel"
    ]
}

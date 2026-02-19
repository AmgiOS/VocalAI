import Dependencies
import Foundation

extension DependencyValues {
    var audioManager: AudioManager {
        get { self[AudioManagerKey.self] }
        set { self[AudioManagerKey.self] = newValue }
    }
}

private struct AudioManagerKey: DependencyKey {
    @MainActor static let liveValue = AudioManager()
}

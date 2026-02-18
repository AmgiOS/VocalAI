# VocalAI

Application iOS de conversation vocale avec un personnage 3D photoréaliste. Synchronisation labiale temps réel, expressions faciales émotionnelles, animations d'attente naturelles.

## Stack technique

- **iOS 26**, Swift 5, SwiftUI, Xcode 26
- **RealityKit** — Rendu 3D non-AR, USDZ, `BlendShapeWeightsComponent`
- **Azure Speech SDK** — TTS + 55 blend shapes FacialExpression à 60 FPS (via package SPM local)
- **Claude API** — Streaming HTTP (`URLSession.bytes`), pas de lib tierce
- **Apple SFSpeechRecognizer** — STT on-device
- **AVAudioEngine** — Capture micro + lecture audio, mode `.voiceChat`

## Architecture

```
VocalAI/
├── App/           AppState (@Observable), Configuration (API keys via UserDefaults)
├── Models/        BlendShapeTarget (52 ARKit shapes), EmotionType, VisemeFrame, ConversationMessage
├── Views/         ConversationView, AvatarContainerView, ChatOverlayView, MicrophoneButton, SettingsView
├── ViewModels/    ConversationViewModel (orchestrateur pipeline)
├── Rendering/     AvatarRenderer (scene RealityKit), BlendShapeController (poids blend shapes)
├── Animation/     LipSyncEngine (CADisplayLink), EmotionEngine, IdleAnimator, AnimationMixer
├── Services/      ClaudeService (actor), AzureSpeechService (actor), SpeechRecognitionService
├── Audio/         AudioManager (AVAudioEngine), AudioSessionConfigurator
├── Utilities/     Interpolation (lerp, smoothstep), SentimentAnalyzer
└── Resources/     avatar.usdz (placeholder — à remplacer par export CC5)
```

## Pipeline conversationnel

```
User parle → AVAudioEngine → SFSpeechRecognizer → texte
  → Claude API streaming → réponse texte
  → SentimentAnalyzer → EmotionEngine
  → Azure TTS (SSML FacialExpression) → audio PCM + visèmes
  → AudioManager (lecture) + LipSyncEngine (animation)
  → AnimationMixer → BlendShapeController → RealityKit
```

## Conventions Swift

- **Async/Await partout** : Tous les appels asynchrones utilisent `async/await`. Pas de callbacks, pas de closures de completion. Les flux continus utilisent `AsyncStream` / `AsyncThrowingStream`.
- **Concurrency** : `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Tous les types sont `@MainActor` par défaut. Marquer `nonisolated` ou utiliser `actor` pour le travail background.
- **Services réseau** : `ClaudeService` et `AzureSpeechService` sont des `actor`.
- **Patterns async utilisés** :
  - `AsyncStream<AVAudioPCMBuffer>` pour la capture micro continue
  - `AsyncStream<SpeechResult>` pour les résultats STT (partial/final)
  - `AsyncThrowingStream<String, Error>` pour le streaming Claude
  - `async func playBuffer()` avec `CheckedContinuation` pour la lecture audio
  - `async func waitForCompletion()` pour la synchronisation lip sync
- **UI** : SwiftUI avec `@Observable` (pas Combine). `@Environment` pour l'injection de `AppState`.
- **Pas de CoreData** — supprimé du scaffold initial.
- **Pas de dépendances tierces** sauf Azure Speech SDK (SPM local dans `Packages/AzureSpeechSDK/`).

## Dépendance Azure Speech SDK

Pas de CocoaPods. Le SDK est intégré via un package SPM local wrappant le xcframework :

```
Packages/AzureSpeechSDK/     → Package.swift avec binaryTarget
Frameworks/                  → MicrosoftCognitiveServicesSpeech.xcframework (gitignored)
scripts/setup-azure-sdk.sh   → Télécharge le xcframework depuis Microsoft
```

Setup : `./scripts/setup-azure-sdk.sh` puis ajouter le package local dans Xcode.

## Blend Shapes

Les 55 positions Azure correspondent directement aux 52 ARKit blend shapes + 3 extras. Le mapping est dans `BlendShapeTarget.azureOrder`. L'avatar CC5 doit être exporté avec les noms ARKit.

## Animation — Priorités du mixer

1. **Lip sync** (haute priorité) — possède les shapes bouche pendant la parole
2. **Émotion** — possède les sourcils, blend avec les yeux
3. **Idle** (basse priorité) — respiration, clignements, micro-mouvements

## Commandes utiles

```bash
# Télécharger le xcframework Azure Speech
./scripts/setup-azure-sdk.sh

# Build (depuis terminal)
xcodebuild -project VocalAI.xcodeproj -scheme VocalAI -sdk iphoneos build
```

## Info.plist

Clés de confidentialité ajoutées via build settings (`INFOPLIST_KEY_*`) :
- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

## Points d'attention

- Le projet cible **iOS 26** (beta). Certaines API peuvent évoluer.
- L'avatar placeholder est une sphère bleue si `avatar.usdz` n'est pas dans Resources.
- Les clés API sont stockées dans UserDefaults (dev). En production, utiliser Keychain.
- `accessibilityReduceMotion` est respecté dans `IdleAnimator`.

# VocalAI

Application iOS de conversation vocale avec un personnage 3D photoréaliste. Synchronisation labiale temps réel, expressions faciales émotionnelles, animations d'attente naturelles.

## Stack technique

- **iOS 26**, Swift 5, SwiftUI, Xcode 26
- **RealityKit** — Rendu 3D non-AR, USDZ, `BlendShapeWeightsComponent`
- **Azure Speech SDK** — TTS + 55 blend shapes FacialExpression à 60 FPS (via package SPM local)
- **Claude API** — Streaming HTTP (`URLSession.bytes`), pas de lib tierce
- **Apple SFSpeechRecognizer** — STT on-device
- **AVAudioEngine** — Capture micro + lecture audio, mode `.voiceChat`
- **TCA Dependencies** (pointfreeco/swift-dependencies) — Injection de dépendances

## Architecture

Clean Architecture + MVVM avec injection de dépendances via TCA Dependencies.

```
VocalAI/
├── App/
│   ├── AppState.swift                            @Observable — permissions, showSettings, isAvatarLoaded
│   └── Configuration.swift                       API keys via UserDefaults (computed properties + UserDefaultsStore)
│
├── Domain/
│   ├── Models/
│   │   ├── BlendShapeTarget.swift                52 ARKit shapes + Azure mapping
│   │   ├── ConversationMessage.swift             MessageRole + message struct
│   │   ├── ConversationPipelineEvent.swift       Events émis par le UseCase (textChunk, responseComplete, synthesisComplete)
│   │   ├── ConversationState.swift               idle, listening, thinking, speaking
│   │   ├── EmotionType.swift                     7 émotions avec presets blend shapes
│   │   ├── SpeechResult.swift                    partial/final recognition results
│   │   └── VisemeFrame.swift                     VisemeFrame, VisemeData, AzureVisemePayload
│   ├── Protocols/
│   │   ├── DataSources/                          ChatDataSourceProtocol, SpeechSynthesis*, SpeechRecognition*
│   │   ├── Repositories/                         ConversationRepositoryProtocol, SpeechRepositoryProtocol
│   │   └── UseCases/                             ConversationUseCaseProtocol
│   └── UseCases/
│       ├── ConversationUseCase.swift             Orchestre : stream Claude → émotion → TTS Azure
│       └── EmotionAnalysisUseCase.swift          Wrap SentimentAnalyzer
│
├── Data/
│   ├── DataSources/
│   │   ├── ClaudeChatDataSource.swift            Wrap ClaudeService
│   │   ├── AzureSpeechSynthesisDataSource.swift  Wrap AzureSpeechService
│   │   └── AppleSpeechRecognitionDataSource.swift Wrap SpeechRecognitionService
│   └── Repositories/
│       ├── ConversationRepository.swift          Absorbe config (systemPrompt, model)
│       └── SpeechRepository.swift                Combine TTS + STT
│
├── DI/
│   ├── DependencyValues+Repositories.swift       conversationRepository, speechRepository
│   ├── DependencyValues+UseCases.swift           conversationUseCase, emotionAnalysis
│   └── DependencyValues+AudioManager.swift       audioManager
│
├── Presentation/
│   ├── ViewModels/
│   │   ├── ConversationViewModel.swift           State struct + @Dependency — orchestre le pipeline
│   │   └── SettingsViewModel.swift               State struct pour les settings
│   ├── Views/
│   │   ├── ConversationView.swift                Vue principale (avatar + chat + mic)
│   │   ├── SettingsView.swift                    Configuration API keys, voix, persona
│   │   └── AvatarContainerView.swift             UIViewRepresentable wrappant ARView
│   └── Components/
│       ├── ChatOverlayView.swift                 Transcript de conversation
│       ├── MessageBubble.swift                   Bulle de message (user/assistant)
│       ├── MicrophoneButton.swift                Bouton micro animé
│       ├── StatusIndicator.swift                 Indicateur d'état (listening/thinking/speaking)
│       └── ErrorBanner.swift                     Bannière d'erreur dismissable
│
├── Mocks/
│   ├── MockConversationRepository.swift          Réponses canned pour previews/tests
│   ├── MockSpeechRepository.swift                No-op TTS/STT
│   ├── MockConversationUseCase.swift             Pipeline simulé
│   └── PreviewData.swift                         Données de conversation d'exemple
│
├── Services/          ClaudeService (actor), AzureSpeechService (actor), SpeechRecognitionService
├── Audio/             AudioManager (AVAudioEngine), AudioSessionConfigurator
├── Animation/         LipSyncEngine (CADisplayLink), EmotionEngine, IdleAnimator, AnimationMixer
├── Rendering/         AvatarRenderer (scene RealityKit), BlendShapeController (poids blend shapes)
├── Utilities/         Interpolation (lerp, smoothstep), SentimentAnalyzer
└── Resources/         avatar.usdz (placeholder — à remplacer par export CC5)
```

## Pipeline conversationnel

```
User parle → AVAudioEngine → SFSpeechRecognizer → texte
  → ConversationUseCase.thinkAndSynthesize() :
    → ConversationRepository → Claude API streaming → textChunk events
    → EmotionAnalysisUseCase → responseComplete event
    → SpeechRepository → Azure TTS → synthesisComplete event
  → ConversationViewModel consomme les events :
    → AudioManager (lecture) + LipSyncEngine (animation)
    → AnimationMixer → BlendShapeController → RealityKit
```

## Conventions Swift

- **Zéro warnings** : Le projet doit compiler sans aucun warning. Corriger tout warning avant de commit.
- **Async/Await partout** : Tous les appels asynchrones utilisent `async/await`. Pas de callbacks, pas de closures de completion. Les flux continus utilisent `AsyncStream` / `AsyncThrowingStream`.
- **Concurrency** : `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Tous les types sont `@MainActor` par défaut. Marquer `nonisolated` ou utiliser `actor` pour le travail background. Les types valeur partagés entre isolations (`Configuration`, `SentimentAnalyzer`, models) doivent être `nonisolated`.
- **Services réseau** : `ClaudeService` et `AzureSpeechService` sont des `actor`.
- **Patterns async utilisés** :
  - `AsyncStream<AVAudioPCMBuffer>` pour la capture micro continue
  - `AsyncStream<SpeechResult>` pour les résultats STT (partial/final)
  - `AsyncThrowingStream<String, Error>` pour le streaming Claude
  - `AsyncThrowingStream<ConversationPipelineEvent, Error>` pour le pipeline UseCase
  - `async func playBuffer()` avec `CheckedContinuation` pour la lecture audio
  - `async func waitForCompletion()` pour la synchronisation lip sync
- **UI** : SwiftUI avec `@Observable` (pas Combine). `@Environment` pour l'injection de `AppState`.
- **Pas de CoreData** — supprimé du scaffold initial.

## Injection de dépendances (TCA Dependencies)

- **`@Dependency(\.key)`** dans les ViewModels pour accéder aux repositories et use cases.
- **`@ObservationIgnored`** sur toutes les `@Dependency` et les propriétés non-UI (tasks, animation mixer).
- **DependencyKey** avec `liveValue` pour la prod. Les mocks sont dans `Mocks/`.
- **`withDependencies`** dans les `#Preview` pour injecter les mocks.

### ViewModel State Pattern

Chaque ViewModel expose un seul `var state = State()` — une struct `Equatable` contenant tout l'état UI observable. Les dépendances sont marquées `@ObservationIgnored`.

```swift
@Observable @MainActor
final class ConversationViewModel {
    struct State: Equatable { ... }
    var state = State()
    @ObservationIgnored @Dependency(\.conversationUseCase) private var conversationUseCase
}
```

Les vues accèdent à l'état via `viewModel.state.conversationState`, `viewModel.state.messages`, etc.

## Dépendances externes

- **Azure Speech SDK** — SPM local wrappant le xcframework :
  ```
  Packages/AzureSpeechSDK/     → Package.swift avec binaryTarget
  Frameworks/                  → MicrosoftCognitiveServicesSpeech.xcframework (gitignored)
  scripts/setup-azure-sdk.sh   → Télécharge le xcframework depuis Microsoft
  ```
  Setup : `./scripts/setup-azure-sdk.sh` puis ajouter le package local dans Xcode.

- **TCA Dependencies** — `pointfreeco/swift-dependencies` via SPM distant.

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
xcodebuild -project VocalAI.xcodeproj -scheme VocalAI -destination 'generic/platform=iOS' build
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
- Les fichiers `Services/`, `Audio/`, `Animation/`, `Rendering/`, `Utilities/` ne sont **pas** modifiés par les DataSources — ceux-ci les wrappent sans changement.

## MCP Blender — Création d'avatar 3D

Un serveur MCP Blender (`ahujasid/blender-mcp`) est configuré pour piloter Blender 4.4 depuis Claude Code.

### Setup

```bash
# Le MCP est déjà configuré dans .claude.json
# Dans Blender : Edit > Preferences > Add-ons > installer addon.py
# Activer "Interface: Blender MCP" > panneau N > BlenderMCP > "Connect to Claude"
# Le serveur tourne sur localhost:9876
```

### Prochaine étape : Création de l'avatar

L'avatar doit répondre à ces exigences pour fonctionner avec l'app :

1. **Format** : Export USDZ avec matériaux PBR embarqués
2. **52 shape keys ARKit** : Nommés exactement comme dans `BlendShapeTarget.swift` :
   - Eye brows : `browDownLeft`, `browDownRight`, `browInnerUp`, `browOuterUpLeft`, `browOuterUpRight`
   - Eyes : `eyeBlinkLeft/Right`, `eyeLookDown/In/Out/Up Left/Right`, `eyeSquint/Wide Left/Right`
   - Jaw : `jawForward`, `jawLeft`, `jawOpen`, `jawRight`
   - Mouth : `mouthClose`, `mouthDimple/Frown/Press/Smile/Stretch Left/Right`, `mouthFunnel`, `mouthLeft/Right`, `mouthLowerDown/UpperUp Left/Right`, `mouthPucker`, `mouthRollLower/Upper`, `mouthShrugLower/Upper`
   - Nose : `noseSneerLeft/Right`
   - Cheek : `cheekPuff`, `cheekSquintLeft/Right`
   - Tongue : `tongueOut`
3. **Cadrage** : L'app scale l'avatar à ~2 unités de haut, caméra à `[0, 1.5, 0.8]`, FOV 30° — cadrage buste/visage
4. **Topology** : Edge loops autour des yeux, bouche, nez pour des déformations propres
5. **Matériaux** : PBR standard (base color, normal, roughness) — le lighting est géré par RealityKit (3 lights : key, fill, rim)
6. **Destination** : `VocalAI/Resources/avatar.usdz`

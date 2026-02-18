# VocalAI — Documentation Technique

## Vue d'ensemble

VocalAI est une application iOS qui permet de converser vocalement avec un personnage 3D photoréaliste. Le personnage synchronise ses lèvres en temps réel avec la parole, affiche des expressions faciales émotionnelles, et produit des animations d'attente naturelles (respiration, clignements).

### Pipeline conversationnel

```
┌─────────────┐    ┌──────────────────┐    ┌─────────────┐
│  Utilisateur │───▶│  AVAudioEngine   │───▶│ SFSpeech    │
│  parle       │    │  (micro capture) │    │ Recognizer  │
└─────────────┘    └──────────────────┘    └──────┬──────┘
                                                   │ texte
                                                   ▼
                                           ┌──────────────┐
                                           │  Claude API   │
                                           │  (streaming)  │
                                           └──────┬───────┘
                                                   │ réponse texte
                                          ┌────────┼────────┐
                                          ▼                  ▼
                                  ┌──────────────┐  ┌──────────────┐
                                  │  Sentiment   │  │  Azure TTS   │
                                  │  Analyzer    │  │  + Visèmes   │
                                  └──────┬───────┘  └──────┬───────┘
                                         │                  │
                                         ▼                  ▼
                                  ┌──────────────┐  ┌──────────────┐
                                  │  Emotion     │  │  LipSync     │
                                  │  Engine      │  │  Engine      │
                                  └──────┬───────┘  └──────┬───────┘
                                         │                  │
                                         └────────┬─────────┘
                                                  ▼
                                         ┌──────────────────┐
                                         │  AnimationMixer   │
                                         │  (lip+émo+idle)   │
                                         └────────┬─────────┘
                                                  ▼
                                         ┌──────────────────┐
                                         │ BlendShape       │
                                         │ Controller       │
                                         └────────┬─────────┘
                                                  ▼
                                         ┌──────────────────┐
                                         │  RealityKit      │
                                         │  (rendu 3D)      │
                                         └──────────────────┘
```

---

## App/ — Noyau applicatif

### `AppState.swift`
**Rôle** : État global observable de l'application.

`AppState` est un `@Observable` injecté dans l'arbre SwiftUI via `.environment()`. Il centralise l'état partagé entre les vues : l'état de la conversation (idle/listening/thinking/speaking), l'émotion courante, les autorisations, et les messages d'erreur.

**Pourquoi `@Observable` et pas `@StateObject`** : iOS 17+ favorise le macro `@Observable` (Observation framework) qui est plus performant que `ObservableObject` — il ne notifie que les propriétés réellement lues par chaque vue.

### `Configuration.swift`
**Rôle** : Toutes les constantes et clés API du projet.

Utilise un property wrapper custom `@AppStorageBacked` qui lit/écrit dans `UserDefaults` via `Codable`. Cela permet d'avoir des propriétés statiques mutables (`Configuration.azureSpeechKey = "..."`) tout en persistant les valeurs entre les lancements.

**Design** : Un `enum` (pas une `struct`) car il n'y a jamais d'instance — c'est un namespace pur. Les constantes d'animation (durée respiration, intervalle clignement) sont aussi centralisées ici pour faciliter le tuning.

---

## Models/ — Types de données

### `BlendShapeTarget.swift`
**Rôle** : Enum des 52 blend shapes ARKit + mapping Azure.

C'est le **fichier clé** du système d'animation. Chaque case correspond à un blend shape ARKit (ex: `jawOpen`, `mouthSmileLeft`, `eyeBlinkRight`). Le fichier contient :

- **L'enum** avec les 52 cases nommées exactement comme ARKit les attend
- **`azureOrder`** : tableau statique de 52 éléments qui mappe l'index Azure → le blend shape ARKit. Azure envoie un tableau de 55 floats ; les indices 0-51 correspondent à ce tableau, les 52-54 (headRoll, eyeRolls) sont ignorés
- **`fromAzureArray()`** : convertit un `[Float]` Azure en `[BlendShapeTarget: Float]`
- **Sets de catégories** (`mouthShapes`, `browShapes`, `eyeShapes`) utilisés par l'`AnimationMixer` pour savoir quel système d'animation a la priorité sur quelle zone du visage

**Découverte clé** : Les noms Azure FacialExpression = les noms ARKit. Si le modèle CC5 est exporté avec le profil ARKit, aucune table de mapping manuelle n'est nécessaire.

### `ConversationMessage.swift`
**Rôle** : Modèle d'un message dans la conversation.

Structure simple `Identifiable` + `Sendable` avec `role` (user/assistant/system), `content`, et `timestamp`. Utilisé à la fois pour l'affichage dans le chat overlay et pour construire le payload envoyé à Claude.

### `EmotionType.swift`
**Rôle** : 7 émotions avec presets de blend shapes.

Chaque émotion (neutral, happy, sad, surprised, angry, thinking, empathetic) définit un dictionnaire `[BlendShapeTarget: Float]` — c'est la "pose cible" du visage pour cette émotion. Par exemple, `happy` active `mouthSmileLeft: 0.6`, `cheekSquintLeft: 0.3`, etc.

**Design** : Les presets sont des données, pas du code procédural. Cela facilite l'ajout d'émotions ou le tuning des valeurs. L'`EmotionEngine` se charge de l'interpolation entre les presets.

### `VisemeFrame.swift`
**Rôle** : Données de visèmes Azure décodées.

- **`VisemeFrame`** : un frame unique (index + dictionnaire de poids blend shapes + offset temporel calculé)
- **`VisemeData`** : conteneur de tous les frames d'une utterance
- **`AzureVisemePayload`** : structure `Decodable` qui parse le JSON brut Azure (`{ FrameIndex, BlendShapes: [[Float]] }`)

**Flux** : Azure envoie des événements `VisemeReceived` avec un JSON contenant un lot de frames. `AzureVisemePayload.toVisemeFrames()` convertit chaque sous-tableau de 55 floats en un `VisemeFrame` typé.

---

## Rendering/ — Rendu 3D

### `AvatarRenderer.swift`
**Rôle** : Configure la scène RealityKit complète.

Crée un `ARView` en mode `.nonAR` (pas besoin de caméra AR), configure :

- **Caméra perspective** : FOV 30°, positionnée face au visage de l'avatar
- **Éclairage 3 points** (technique cinéma) :
  - Key light (lumière principale, chaude, en haut à droite)
  - Fill light (lumière de remplissage, froide, à gauche)
  - Rim light (contre-jour, derrière, pour séparer le sujet du fond)
- **Chargement USDZ** : cherche `avatar.usdz` dans le bundle, sinon crée une sphère placeholder
- **Positionnement auto** : calcule les bounds du modèle et le scale pour qu'il fasse ~2m de haut, centré dans la vue

Après chargement, instancie un `BlendShapeController` attaché à l'entity chargée.

### `BlendShapeController.swift`
**Rôle** : Interface de lecture/écriture des poids blend shapes sur l'entity RealityKit.

Parcourt récursivement l'arbre d'entities pour trouver le premier `ModelEntity` qui possède un `BlendShapeWeightsComponent`. Puis expose des méthodes :

- **`setWeight(_:value:)`** : modifier un seul blend shape
- **`setWeights(_:)`** : modifier plusieurs à la fois
- **`applyFrame(_:)`** : appliquer un frame complet (reset à 0 des shapes non spécifiés)
- **`resetAll()`** : tout remettre à 0

**Comment ça marche** : RealityKit stocke les poids dans un `BlendShapeWeightsComponent`. Le `BlendShapeWeightsMapping` permet de retrouver les indices internes à partir du nom ARKit (`"jawOpen"` → index 12 par exemple). On modifie le composant puis on le re-set sur l'entity.

---

## Animation/ — Système d'animation

### `IdleAnimator.swift`
**Rôle** : Animations de repos — le personnage "vit" même quand personne ne parle.

Utilise un `CADisplayLink` (synchronisé au refresh rate de l'écran) pour calculer chaque frame :

- **Respiration** : onde sinusoïdale sur 4 secondes. Ouvre très légèrement la mâchoire (`jawOpen: 0.015`) et dilate subtilement les narines
- **Clignements** : intervalle aléatoire 3-5 sec, durée 150ms (fermeture + ouverture en smoothstep). 15% de chance de double clignement
- **Micro-mouvements oculaires** : les yeux dérivent légèrement (amplitude 0.02-0.03) vers des cibles aléatoires, lissés par lerp

**Accessibilité** : Si `UIAccessibility.isReduceMotionEnabled` est actif, la respiration et les micro-mouvements sont désactivés (les clignements restent car ils sont naturels).

### `EmotionEngine.swift`
**Rôle** : Transitions douces entre émotions.

Quand `setEmotion(.happy)` est appelé, l'engine :
1. Sauvegarde les poids actuels comme "état de départ"
2. Interpole vers le preset cible avec `smoothLerpWeights` sur 0.5 seconde
3. La méthode `update()` est appelée chaque frame par l'`AnimationMixer`

**Design** : Séparation émotion/lip sync. L'émotion contrôle les sourcils, les joues, le regard. Le lip sync contrôle la bouche. Le mixer combine les deux.

### `LipSyncEngine.swift`
**Rôle** : Lit les frames de visèmes Azure synchronisés avec l'audio.

Fonctionnement :
1. `load()` charge les frames visème
2. `play()` démarre un `CADisplayLink` et note le timestamp de début
3. Chaque frame : calcule le temps écoulé depuis le début de l'audio, trouve les 2 frames visème encadrant ce temps, interpole linéairement entre eux
4. Quand le dernier frame est atteint, la playback se termine

**Synchronisation audio** : Le `play()` doit être appelé au même instant que le début de lecture audio. On utilise `CACurrentMediaTime()` (horloge monotonique du système) pour les deux, ce qui garantit la synchronisation.

**Async** : `waitForCompletion()` suspend l'appelant via une `CheckedContinuation` qui est resumée quand la lecture finit. Pas de callback.

### `AnimationMixer.swift`
**Rôle** : Combine les 3 sources d'animation avec un système de priorité.

Chaque frame (via `CADisplayLink`) :
1. Récupère les poids de `IdleAnimator`, `EmotionEngine`, `LipSyncEngine`
2. Fusionne avec la règle :
   - **Mouth shapes** : lip sync si actif, sinon émotion, sinon idle
   - **Brow shapes** : émotion prend la priorité totale
   - **Eye shapes** : émotion + idle sont additionnés (ex: micro-mouvement + regard triste)
   - **Reste** : émotion si présent, sinon idle
3. Applique le résultat final via `BlendShapeController.applyFrame()`

**Pourquoi un mixer séparé** : Chaque engine produit des poids indépendamment sans connaître les autres. Le mixer est le seul à écrire dans le `BlendShapeController`, évitant les conflits.

---

## Services/ — Communication externe

### `ClaudeService.swift`
**Rôle** : Client HTTP streaming pour l'API Claude.

C'est un `actor` (thread-safe par isolation). Utilise `URLSession.bytes(for:)` pour le streaming SSE — chaque ligne `data: {...}` est parsée en `StreamEvent`. Les chunks de texte sont émis via un `AsyncThrowingStream<String, Error>`.

**Pas de lib tierce** : Tout est fait avec `URLSession` natif. Le parsing SSE est simple : on itère sur `bytes.lines`, on filtre les lignes commençant par `data: `, on décode le JSON.

**Types internes** :
- `RequestBody` : payload JSON envoyé à Claude (model, max_tokens, system, messages, stream)
- `StreamEvent` : événement SSE décodé. `content_block_delta` contient le texte partiel
- `ClaudeError` : erreurs typées (clé manquante, erreur API avec status code)

### `AzureSpeechService.swift`
**Rôle** : TTS Azure avec visèmes FacialExpression à 60 FPS.

Aussi un `actor`. Le flow :
1. `configure()` : crée un `SPXSpeechConfiguration` avec la clé/region Azure
2. `synthesize(text:)` :
   - Construit du SSML avec `<mstts:viseme type="FacialExpression"/>`
   - Lance la synthèse vocale
   - L'event handler `visemeReceived` collecte les frames (JSON → `AzureVisemePayload` → `[VisemeFrame]`)
   - Retourne un `SynthesisResult` contenant l'audio PCM + les frames visème

**SSML** : Le mode `FacialExpression` (pas `Viseme IDs`) est crucial — c'est lui qui fournit les 55 blend shapes à 60 FPS au lieu de simples IDs de phonèmes.

### `SpeechRecognitionService.swift`
**Rôle** : Speech-to-text on-device via Apple `SFSpeechRecognizer`.

`startRecognition()` retourne un `AsyncStream<SpeechResult>` où `SpeechResult` est :
- `.partial(String)` : transcription intermédiaire (mise à jour en temps réel)
- `.final(String)` : transcription finale (le recognizer a détecté une pause)

En interne, le `recognitionTask` de Apple utilise un callback ; la continuation de l'`AsyncStream` fait le pont vers le monde async/await. Les buffers audio sont injectés via `appendBuffer()` depuis le stream micro de l'`AudioManager`.

**On-device** : Si `supportsOnDeviceRecognition` est true, la reconnaissance se fait entièrement sur l'appareil (pas de réseau). Sinon, fallback sur le cloud Apple.

---

## Audio/ — Gestion audio

### `AudioManager.swift`
**Rôle** : Capture micro et lecture audio via `AVAudioEngine`.

Deux fonctionnalités principales, toutes deux async :

**Capture micro** : `startMicCapture()` retourne un `AsyncStream<AVAudioPCMBuffer>`. Installe un tap sur le `inputNode` de l'engine, chaque buffer est yieldé dans le stream. L'appelant consomme avec `for await buffer in stream`.

**Lecture audio** : `playAudioData(_:format:)` est `async` — il suspend l'appelant jusqu'à la fin de la lecture. En interne, `AVAudioPlayerNode.scheduleBuffer` prend un completion handler qui resume une `CheckedContinuation`.

**Gestion du format** : L'engine s'occupe automatiquement de la conversion de format entre l'entrée (format micro de l'appareil) et la sortie (16kHz 16-bit mono pour Azure).

### `AudioSessionConfigurator.swift`
**Rôle** : Configure `AVAudioSession` pour le mode conversation.

Fonctions statiques pures (enum, pas de state). Le mode `.voiceChat` est crucial car il active l'**echo cancellation** matérielle — sans ça, le micro capturerait la voix du personnage qui parle et le STT s'emballerait.

Options activées : `defaultToSpeaker` (haut-parleur principal), `allowBluetooth` (casques BT).

---

## ViewModels/ — Orchestration

### `ConversationViewModel.swift`
**Rôle** : Chef d'orchestre du pipeline complet.

C'est le **cerveau** de l'app. `@Observable` pour que les vues réagissent à ses changements d'état. Il possède toutes les dépendances (audio, services, animation) et orchestre les 4 phases :

**Phase Listening** (`startListening()`) :
```
audioManager.startMicCapture() → AsyncStream<AVAudioPCMBuffer>
  → speechService.appendBuffer()
speechService.startRecognition() → AsyncStream<SpeechResult>
  → for await: met à jour partialTranscript ou lance processUserMessage
```

**Phase Thinking** (`thinkAndSpeak()` partie 1) :
```
claudeService.streamChat() → AsyncThrowingStream<String>
  → for try await: accumule la réponse, met à jour currentResponseText
```

**Phase Speaking** (`thinkAndSpeak()` partie 2) :
```
SentimentAnalyzer.analyze() → EmotionEngine.setEmotion()
azureService.synthesize() → SynthesisResult (audio + visèmes)
lipSyncEngine.play() (fire-and-forget)
await audioManager.playAudioData() (suspend jusqu'à fin)
await lipSyncEngine.waitForCompletion()
```

**Phase Idle** : reset de l'émotion, retour à `.idle`.

Tout est annulable via `stopConversation()` qui cancel les `Task` en cours.

---

## Views/ — Interface utilisateur

### `ConversationView.swift`
**Rôle** : Vue principale, compose tous les éléments.

Layout en `ZStack` :
- Fond noir
- Avatar 3D en plein écran (`AvatarContainerView`)
- Overlay chat semi-transparent en bas
- Indicateur d'état (listening/thinking/speaking)
- Bouton micro
- Bouton settings (engrenage, coin supérieur droit)
- Bannière d'erreur (slide depuis le haut)

Au `.task`, charge l'avatar et setup le ViewModel. Attache l'`AnimationMixer` au `BlendShapeController` une fois l'avatar chargé.

### `AvatarContainerView.swift`
**Rôle** : Pont entre SwiftUI et RealityKit.

`UIViewRepresentable` minimal qui expose l'`ARView` de l'`AvatarRenderer`. Pas de logique — juste le bridge UIKit → SwiftUI.

### `ChatOverlayView.swift`
**Rôle** : Transcript de la conversation.

`ScrollView` + `LazyVStack` avec des bulles de message (bleu pour l'utilisateur, gris pour l'assistant). Affiche en temps réel :
- Le transcript partiel pendant l'écoute (opacité réduite)
- La réponse en cours de streaming pendant la réflexion
- L'historique complet

Auto-scroll vers le bas à chaque nouveau message.

### `MicrophoneButton.swift`
**Rôle** : Bouton micro avec feedback visuel et haptique.

Change de couleur et d'icône selon l'état :
- Idle → bleu, micro
- Listening → vert, micro + anneau pulsant
- Thinking → orange, points de suspension animés
- Speaking → violet, stop

Gère tap (start/stop/cancel) et long press. `sensoryFeedback` pour le retour haptique. Labels d'accessibilité pour VoiceOver.

### `SettingsView.swift`
**Rôle** : Configuration des clés API, voix, et persona.

Formulaire SwiftUI avec sections :
- Azure Speech (clé, région)
- Claude AI (clé, modèle)
- Voice (langue, nom de voix Azure)
- Persona (system prompt éditable)
- Status (indicateurs vert/rouge de configuration)

Les valeurs sont lues/écrites directement dans `Configuration` (qui persiste via `UserDefaults`).

---

## Utilities/ — Outils

### `Interpolation.swift`
**Rôle** : Fonctions mathématiques pour les animations.

- **`lerp`** : interpolation linéaire (`a + (b - a) * t`)
- **`smoothstep`** : Hermite (ease-in/ease-out, pour des transitions naturelles)
- **`smootherstep`** : version Ken Perlin (encore plus lisse)
- **`lerpWeights`** / **`smoothLerpWeights`** : interpolation de dictionnaires `[BlendShapeTarget: Float]`

Utilisé partout : transitions d'émotion, interpolation de frames visème, micro-mouvements oculaires, clignements.

### `SentimentAnalyzer.swift`
**Rôle** : Détecte l'émotion dans le texte de réponse de Claude.

Deux mécanismes :
1. **Tags explicites** : si Claude inclut `[emotion:happy]` dans sa réponse (configurable via le system prompt), c'est parsé en priorité
2. **Mots-clés** : sinon, compte les occurrences de mots associés à chaque émotion (listes de ~20 mots par émotion)

Retourne l'`EmotionType` avec le score le plus élevé, ou `.neutral` si aucun match.

**Design léger** : Pas de ML, pas de dépendance. Suffisant pour un MVP. Le tag explicite `[emotion:X]` est la voie recommandée pour une détection fiable.

---

## Packages/ — Dépendances

### `AzureSpeechSDK/`
**Rôle** : Package SPM local wrappant le xcframework Azure.

Microsoft ne fournit pas de package SPM officiel. Ce wrapper contient :
- `Package.swift` avec un `.binaryTarget` pointant vers `../../Frameworks/MicrosoftCognitiveServicesSpeech.xcframework`
- Un source file avec `@_exported import` pour re-exporter le module

Le xcframework est téléchargé via `scripts/setup-azure-sdk.sh` et n'est pas committé (gitignored, ~200MB).

---

## Flux de données async

Tout le code asynchrone utilise async/await natif Swift :

```
                    AsyncStream<AVAudioPCMBuffer>
AVAudioEngine ─────────────────────────────────────▶ SpeechRecognitionService
     (tap)                                               │
                                                         │ AsyncStream<SpeechResult>
                                                         ▼
                                              ConversationViewModel
                                                         │
                                AsyncThrowingStream      │      async synthesize()
                    ClaudeService ◀──────────────────────┤────────────────▶ AzureSpeechService
                                                         │
                                         async playAudioData()
                                              AudioManager
                                                         │
                                      async waitForCompletion()
                                            LipSyncEngine
```

Aucun callback, aucune closure de completion. Les `for await` consomment les streams, les `await` suspendent jusqu'à complétion. Les `Task` permettent le lancement concurrent et l'annulation via `Task.isCancelled`.

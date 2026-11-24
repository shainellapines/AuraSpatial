# AuraSpatial

An iOS spatial audio app built with SwiftUI. Place sounds around you on a canvas and hear them in 3D, save layouts, run Focus and Sleep session timers, and share soundscapes to the Community feed. It uses an MVC structure with Firebase Authentication and Cloud Firestore, and falls back to on-device storage when Firebase isn't set up.

See [CHANGES.md](CHANGES.md) for everything added since the midterm build.

## How to open and run

1. On a Mac, open `AuraSpatial.xcodeproj` in Xcode (iOS 17.0 or later is required for `@Observable`, `PhaseAnimator` and `.sensoryFeedback`).
2. Wait for Swift Package Manager to finish fetching the Firebase packages.
3. **Firebase (optional):** download `GoogleService-Info.plist` for the iOS app from the Firebase console and put it in the inner `AuraSpatial/` folder. It is not in this repo on purpose (see `.gitignore`). Without it, the app runs with on-device storage. Full steps: [FIREBASE_SETUP.md](FIREBASE_SETUP.md).
4. **Background audio (one-time):** AuraSpatial target > Signing & Capabilities > + Capability > Background Modes > check **Audio, AirPlay, and Picture in Picture**.
5. Build and run in the Simulator or on a device.

## Folder structure

```
AuraSpatial.xcodeproj/        Xcode project (folder syncing: new files are added automatically)
AuraSpatial/
├── App/                      app entry point
├── Models/                   Codable structs and enums (sounds, nodes, soundscapes, profile, settings, stats, session timer)
├── Repositories/             protocols + local and Firebase implementations; Backend.swift picks one at launch
├── Audio/                    procedural sound synthesis and AVAudioEngine spatial mixing
├── Controllers/              @Observable controllers (auth, canvas, saved layouts, community, settings, routing)
├── Views/                    one SwiftUI view per screen: Auth, Canvas, Library, Saved, Community, Profile, Root
└── Utilities/                theme tokens, button styles, glyphs, mini-map, toast, formatting
Firebase/firestore.rules      Firestore security rules
CHANGES.md                    what changed since the midterm
FIREBASE_SETUP.md             step-by-step Firebase setup
```

## Visual design system — matched to the actual Figma prototype

An earlier draft of this code implemented the prototype's *screens and features* correctly but not its *look* — it used plain system `Form`/`List` styling and generic colors instead of the prototype's actual dark, glowing, color-coded design. That gap was found by re-screenshotting the live prototype and comparing it side-by-side against the code, then closed by building a real design system instead of ad hoc styling:

- **Color tokens** (`Theme.swift`): a near-black background, a dark surface color for cards/sheets, and three accent colors pulled from the prototype — violet (primary/Ambient), teal (Nature), amber (Rhythm) — plus a glow modifier (`.auraGlow(_:radius:)`) used on the listener orb, the floating add button, and selected/playing states.
- **Category color-coding**: every `SoundAsset` now carries a `SoundCategory` (Nature/Ambient/Rhythm), and every node, Sound Library row, and Mixer header colors itself by that category — matching the prototype's teal/violet/amber node rings exactly.
- **The orbit motif** (`OrbitGlyph.swift`): the concentric-rings-with-dots mark from the Welcome screen is a single reusable view, reused again as each Saved Layout's thumbnail — exactly as the prototype does.
- **Waveform art** (`WaveformGlyph.swift`): a real bar-waveform view (not an SF Symbol) used as every node/row's icon, and — scaled up and animated — as the full-width background art on Community cards, genuinely pulsing while a card is playing rather than being static artwork.
- **Auth screens** (`AuraLabeledField.swift`): the dark rounded field with an uppercase caption label, replacing the plain system `Form` the first draft used.
- **Canvas**: faint orbit-guide rings, a glowing listener orb, and a floating circular "+" button (replacing a plain toolbar item) — plus the prototype's actual two-step interaction (tap a node to select it, then tap the "Mix · &lt;name&gt;" bar that appears to open the Mixer), rather than one tap jumping straight there.

### The one advanced technique that's genuinely real now

The first draft's `SoundNodeView` had a comment claiming a `matchedGeometryEffect` hero transition into the Mixer that was never actually implemented — a real discrepancy, caught and called out rather than left in. It's fixed by using `matchedGeometryEffect` for something it can actually do: when you tap a different node, the dashed "selected" ring visually **glides** from the old node to the new one instead of just fading in and out, tagged to a shared `@Namespace` in `CanvasView`. (A `.sheet`, like the Mixer, presents in a separate view hierarchy, so `matchedGeometryEffect` genuinely cannot animate across that boundary — that's a real SwiftUI limitation, not a shortcut taken here.)

## Course-material and advanced-technique traceability

Every screen uses layouts taught in the course modules (`VStack`/`HStack`/`ZStack`, `TextField`, `Toggle`/`Slider`, `.sheet`, `NavigationStack`). Beyond that, this build showcases, per the SRS Section 3.6:

- `@Observable` (Observation framework) instead of `ObservableObject`/`@Published` in every Controller.
- `PhaseAnimator` for the listener's ambient pulse and the animated Community waveform (`CanvasView.swift`, `WaveformGlyph.swift`).
- `matchedGeometryEffect` for the selection ring gliding between canvas nodes (`SoundNodeView.swift`) — see above for why this, specifically, is where it's used.
- Real spatial audio DSP via `AVAudioEngine` + `AVAudioEnvironmentNode` + procedurally generated `AVAudioPCMBuffer`s (`Audio/`), not a bundled sound file.
- `.sensoryFeedback` haptics on node selection and Community play/pause.
- A protocol-oriented repository pattern (`SoundscapeRepository`, `AuthRepository`, `CommunityRepository`) so the finals-phase Firebase swap touches zero View code.
- Custom `ButtonStyle`s (primary pill, secondary pill, floating action button) rather than only system styles.
- Swift Concurrency (`async`/`await`) throughout every Controller-to-Repository call.

## One deliberate difference from the Figma Make prototype

The prototype's "Overwrite" button was found (via QA logged in the SRS Appendix B) to update the on-screen timestamp without persisting it. This Xcode build's `SavedLayoutsView` → `SavedLayoutsController.overwrite(_:with:)` always writes through `SoundscapeRepository` and then re-fetches, so the same bug can't occur here — worth mentioning in your Learning Reflection as something you caught and fixed between the prototype and the real implementation.

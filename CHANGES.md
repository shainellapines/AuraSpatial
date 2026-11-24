# AuraSpatial — update after the midterm

## How to install
1. Close Xcode.
2. Replace your project's `AuraSpatial/` source folder (the one with App, Audio, Controllers, Models…) with the one in this zip. The `.xcodeproj` is unchanged.
3. Open the project. It uses folder syncing, so new files are added to the target automatically — no "Add Files" or target-membership checkboxes needed.
4. Product > Clean Build Folder, then run.
5. Delete the app from the Simulator first if you want a clean start. (Old saved layouts are repaired automatically if you keep them.)

6. **Turn on background audio (one-time, in Xcode):** select the AuraSpatial target > **Signing & Capabilities** > **+ Capability** > **Background Modes** > check **Audio, AirPlay, and Picture in Picture**. Without it, everything still works, but the sound stops when you lock the phone or leave the app.

**Note on accounts:** Log In now checks a real (on-device) account, so after updating, tap Sign Up once to create your account again.

## Bugs fixed
| Bug | What was wrong | Fix |
| --- | --- | --- |
| Saved layouts silent after relaunch | Every sound got a new random id on each launch, so saved layouts pointed at ids that no longer existed | Fixed ids, plus automatic repair of old layouts by sound name |
| 3D audio wasn't really 3D | Players were connected in stereo; AVAudioEnvironmentNode only positions **mono** sources. Screen up/down was mapped to height, not front/back | Mono connections; up = in front, down = behind |
| Drag lag | Node moved ~83% as fast as the finger (two different scales) | One shared layout for drawing and dragging; nodes stay in the circle |
| Pan and Loop did nothing | Not connected to audio | Pan shifts the sound sideways; Loop off plays once, with "Play again" |
| Community Play was silent | Only animated the waveform | Real 3D preview; Canvas mutes while previewing; stops when you leave the tab |
| No way to save a new layout | `saveNewLayout` existed but nothing called it | Canvas ••• menu > Save as Layout, with a duplicate-name check (Replace / Keep both) |
| Log In accepted anything | Any email/password worked and created a new profile | Accounts with hashed passwords; clear error messages |
| "tyty" accepted as email | No validation | Username, email, and password rules with hints under each field |
| "Sign Up" on Log In not tappable | It was plain text | Real link |
| "1 nodes" | No plural handling | "1 sound / 2 sounds" everywhere |
| Industrial Loft had 7 sounds | Canvas max is 6 | Hand-designed, fixed sample layouts (max 6) |
| Opening a saved layout stayed on Saved | No tab switching | Jumps to the Canvas |
| Overwrite / delete without asking | — | Confirmation dialogs |

## New on each screen
- **Canvas:** beams from each sound to you (brightness = how loud you hear it), ripples that pulse faster for louder sounds, soft category-colored glow, Near/Mid/Far rings, Front/Back/L/R labels, live readout ("2.4 m · Front-left · Mid · 31%"), Play/Pause, **Orbit mode** (sounds circle around you), **Session timer** (ring around the listener), empty state, toasts. Tap a selected sound again to open the Mixer.
- **Mixer:** live controls, distance/direction/level tiles, sound description.
- **Session Timer (new screen):** Focus or Sleep, presets 5–90 min, fades out at the end, counts toward stats.
- **Sound Library:** category filters, descriptions, "On canvas" badge, slots left.
- **Saved Layouts:** mini-map of each layout's real arrangement, category dots, "On canvas" marker, empty state.
- **Community:** mini-maps, likes (saved), Fork feedback, "Playing in 3D" badge.
- **Profile (now a tab):** avatar with your color, bio, member since; stats (listening time, layouts, sounds placed, sessions); your sound mix bar; settings for master volume, 3D vs stereo, haptics, sound waves, distance guides, orbit speed, default timer, fade-out length; data & privacy actions; About; Log Out; Delete Account.
- **Edit Profile (new screen):** username, bio, avatar color.
- **Sounds:** all six are new procedural recipes (rain, ocean swells, thunder, chimes, crackling fire, crickets) instead of plain tones.

## Update 2: notifications and background audio
- **Session-end notification:** starting a Focus/Sleep timer schedules a local notification (`UNUserNotificationCenter`, time-interval trigger) for the moment it ends. iOS delivers it even if the app is in the background, locked, or closed. Inside the app you see the Canvas banner instead. Sleep alerts are silent so they can't wake you.
- **Permission:** asked the first time you start a timer or turn on Profile > Sessions > **Session alerts**. If you blocked it, that row says so and links to iOS Settings.
- **Background audio:** the audio session now uses `.playback`, so the soundscape and timer keep going with the screen locked (needs step 6 above). Pausing also pauses the engine, so a finished session doesn't keep the app awake.
- **Debug-only 1-minute preset** on the timer, for demoing the notification quickly. It doesn't appear in Release builds.
- Clear All on the Canvas now also cancels a running timer and its notification.
- New file: `Repositories/SessionNotifier.swift`.

## Update 3: Firebase database
- **Firebase Authentication** for accounts and **Cloud Firestore** for profiles, saved layouts, and the Community Feed. Follow `FIREBASE_SETUP.md` to connect it (about 15 minutes).
- `Backend.swift` picks the storage at launch: Firebase when the SDK and `GoogleService-Info.plist` are present, on-device storage otherwise. Every Firebase file is wrapped in `#if canImport`, so the project builds before the package is added.
- New: **Share to Community** (Saved Layouts > ••• menu), real like and fork counts shared by every user, pull to refresh on Community.
- Layouts saved on the device are uploaded once to the new account.
- Security rules in `Firebase/firestore.rules`: users only see their own layouts; anyone signed in can read the feed but only change the like/fork counts on posts that aren't theirs.
- New files: `Repositories/Backend.swift`, `Repositories/FirebaseAuthStore.swift`, `Repositories/FirestoreStores.swift`, `FIREBASE_SETUP.md`, `Firebase/firestore.rules`.

## Update 4: Forgot and change password
- **Forgot password?** on Log In opens a Reset Password screen. Firebase emails a link, and the new password is set on Firebase's secure page. The confirmation looks the same whether or not the email has an account, so nobody can check who signed up.
- **Profile > Account > Change Password:** current password, new password, and confirm. Firebase re-checks the current password (reauthentication) before changing it. Works on on-device storage too, by checking the saved hash.
- No Firebase setup changes. Optional: customize the email in Firebase console > Authentication > Templates > Password reset. The email may land in Spam at first.
- New files: `Views/Auth/ForgotPasswordView.swift`, `Views/Profile/ChangePasswordView.swift`.

## New files
Models: `AppSettings`, `UsageStats`, `SessionTimer`, `CredentialRules` ·
Controllers: `SettingsController`, `AppRouter` ·
Repositories: `PreferencesStores` ·
Utilities: `Formatting`, `LayoutMiniMap`, `AuraToast` ·
Views: `Canvas/SpatialFieldView`, `Canvas/CanvasControlStrip`, `Canvas/SessionTimerView`, `Profile/ProfileSettingsSections`, `Profile/EditProfileView`

## Test checklist
1. Sign Up with a bad email → hint appears; fix it → account created.
2. Add 3 sounds → beams/ripples appear; drag one far → its beam fades and the readout % drops.
3. Orbit → sounds circle you. Pause → animation and audio stop.
4. Mixer: move Pan (hear it shift), turn Loop off (plays once → "Play again").
5. ••• > Save as Layout → toast → Saved shows a mini-map and "On canvas".
6. Quit and relaunch → open the layout → sounds still play.
7. Community → Play → you hear it; switch tabs → it stops.
8. Timer → 5 min → ring counts down (change Fade-out to 10 s to test the ending faster).
9. Timer → Focus → **1m** → Start → press ⌘⇧H (Home) in the Simulator → the sound keeps playing and a "Focus session complete" notification arrives after a minute.
10. Profile → change Master volume and 3D/Stereo → you hear it right away; stats update.

Remember to retake screenshots for the final PDF — the Profile tab is new, so the tab bar now has four items (update the Figma prototype too if it needs to match).

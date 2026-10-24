# Marwa Crazy Cakes — iOS (SwiftUI)

Native iPhone + iPad app. It is a feature-for-feature port of the React Native app in
[`../CrazyCakesMobile`](../CrazyCakesMobile) (Expo SDK 57 / React Native 0.86.3 / TypeScript),
which in turn mirrors the web app. Same six screens, same SQLite content pack, same design tokens,
same "Sprinkles" assistant, same remote content-pack updates.

The database and media in this project are synced from the React Native project, so copy, gallery
rows, videos, testimonials, event types and social links all come from the one shared source.

## Requirements

- Xcode 16 or newer (the project uses file-system-synchronized groups, objectVersion 77)
- iOS 16.0+ deployment target, iPhone and iPad
- No external packages: SQLite is Apple's system `libsqlite3`; the assistant uses `URLSession`,
  `AVFoundation` and `CryptoKit` only

## Run

1. Open `CrazyCakesApple.xcodeproj` in Xcode.
2. Select a simulator (e.g. iPhone 16 / iPad Pro) or your device. For device runs set your team
   under *Signing & Capabilities*; the bundle id is `com.marwacrazycakes.app`.
3. Press Run.

On first launch the app copies the bundled database into Application Support, then checks the
published content pack in the background. Launch takes the same shape as the React Native app:
splash (1 s minimum) → content, with a "Something went wrong" screen and Retry if bootstrap fails.

## Parity with the React Native app

| React Native source | Native implementation |
| --- | --- |
| `App.tsx` — splash, fonts, DB bootstrap, retry | `MarwaCrazyCakesApp.swift`, `App/SplashView.swift`, `Core/ContentStore.swift` |
| `src/navigation/AppRoot.tsx` — phone tabs / iPad sidebar, watermark, assistant mount | `App/AppRoot.swift` |
| `src/navigation/destinations.ts` | `Core/Destination.swift` |
| `src/theme.ts` — palette, fonts, letter spacing | `Core/Theme.swift` |
| `src/components/ui.tsx` — LocalImage, WatermarkPattern, buttons, footer | `Components/UI.swift` |
| `src/components/media.ts`, `src/components/images.ts` | `Core/MediaLibrary.swift`, `Core/MediaRegistry.swift` |
| `src/db/database.ts` — SQLite cache, gallery, updater | `Core/AppDatabase.swift`, `Core/ContentUpdater.swift`, `Core/ContentSnapshot.swift` |
| `src/screens/HomeScreen.tsx` | `Screens/HomeScreen.swift` |
| `src/screens/AboutScreen.tsx` | `Screens/AboutScreen.swift` |
| `src/screens/GalleryScreen.tsx` | `Screens/GalleryScreen.swift` |
| `src/screens/ReviewsScreen.tsx` | `Screens/ReviewsScreen.swift` |
| `src/screens/PricingScreen.tsx` | `Screens/PricingScreen.swift` |
| `src/screens/ContactScreen.tsx` | `Screens/ContactScreen.swift` |
| `src/assistant/AvatarAssistant.tsx` | `Assistant/AssistantView.swift` |
| `src/assistant/AvatarFace.tsx` | `Assistant/AssistantAvatar.swift` |
| `src/assistant/client.ts` | `Assistant/AssistantClient.swift` |
| `src/assistant/knowledge.ts` | `Assistant/AssistantKnowledge.swift` |
| `src/assistant/shared.ts` (copy, types, moods) | `Assistant/AssistantCopy.swift` |
| `src/assistant/speech.ts` | `Assistant/AssistantSpeech.swift` |
| `src/assistant/voiceRecorder.ts` | `Assistant/VoiceRecorder.swift` |
| `src/assistant/quoteDraft.ts` | `Core/QuoteDraftStore.swift` |

Behaviour that matches one-for-one:

- **Splash / shell** — dark splash with the 140 pt logo circle, script brand, tracked tagline and
  spinner; six screens in a bottom tab bar with 10 pt labels; iPad gets the 240 pt sidebar at width
  ≥ 720; the translucent logo watermark sits behind every screen.
- **Home** — 6.5 s hero autoplay with paging and the same responsive height formula, copy below the
  hero, four teaser cards, CTA and the dark brand footer with social pills from the database.
- **About / Pricing / Reviews** — every string is a database content slot (`about.*`, `pricing.*`,
  `reviews.*`); testimonial cards, star ratings and the Google reviews link behave the same.
- **Gallery** — 6 items per page, category chips, seeded FNV-1a + mulberry32 shuffle so "All" is
  stable per visit, per-tile watermark, 4:3 tiles with the 2 pt foreground border, pagination from
  `gallery.pageStatus`, a "Watch the Craft" video section, and full-screen image/video lightboxes
  with prev/next. Videos play from the published pack and fall back to the bundled file.
- **Contact** — identical validation, event-type bottom sheet, `mailto:` compose (subject and body
  built the same way), success state, error note and the assistant's quote prefill.
- **Content updates** — manifest check on launch and on every return to the foreground; version
  compare, size + SHA-256 verification, `PRAGMA integrity_check` and required-table/category checks
  before a downloaded database is adopted.

## Content pipeline

The app ships `CrazyCakes/Resources/crazy-cakes.db` plus the media pack. The database is the single
source of truth for copy, gallery rows, videos, testimonials, event types and social links.

### Sync from the React Native project

```powershell
node scripts/sync-content.mjs
node scripts/sync-content.mjs --mobile ..\CrazyCakesMobile
```

The script (Node 22.5+, same as the mobile repo's content scripts):

1. packs `data/crazy-cakes.db` with `VACUUM INTO` into `CrazyCakes/Resources/crazy-cakes.db`
   (single file, no `-wal` / `-shm` sidecars),
2. copies `assets/images` and `assets/videos` into `CrazyCakes/Resources/Images` and `Videos`,
3. regenerates `CrazyCakes/Core/MediaRegistry.swift` from `scripts/MediaRegistry.template.swift`,
4. verifies `integrity_check` and that every `images.src` / `videos.src` row has a bundled file.

### Remote content packs

`ContentUpdater` fetches
`https://ashrafkandil.github.io/CrazyCakesMobile/mobile-content/manifest.json`, compares its
`version` with the stored one, downloads the database, verifies size and SHA-256, validates it, then
swaps to the validated copy while keeping the bundled database as the fallback. Images and videos
load from `…/mobile-content/media/...` (cache-busted with the content version) and fall back to the
bundled files when the host is unavailable. Publishing a new pack needs no new app build, exactly
like the React Native app.

## Configuration

`CrazyCakes/Resources/AppConfig.plist` mirrors the `EXPO_PUBLIC_*` values:

| Key | React Native equivalent | Default |
| --- | --- | --- |
| `MobileContentURL` | `EXPO_PUBLIC_MOBILE_CONTENT_URL` | `https://ashrafkandil.github.io/CrazyCakesMobile/mobile-content` |
| `GeminiAPIKey` | `EXPO_PUBLIC_GEMINI_API_KEY` | empty — the assistant explains it is not configured |
| `GeminiModel` | `EXPO_PUBLIC_GEMINI_MODEL` | empty — uses the model fallback chain |
| `GeminiAPIBaseURL` | `EXPO_PUBLIC_GEMINI_API_BASE_URL` | `https://generativelanguage.googleapis.com` |

`NSMicrophoneUsageDescription` is set in the target build settings with the same sentence as
`app.json`, and the app is portrait-only with a light interface style, matching `app.json`.

> Security note: a key stored in `AppConfig.plist` is embedded in the app bundle and can be
> extracted, just like `EXPO_PUBLIC_GEMINI_API_KEY`. Use a restricted key and rotate it if it leaks.

## Assistant ("Sprinkles")

The floating avatar appears after the splash and flies in from the centre of the screen. The chat
panel keeps the React Native layout: header avatar with mood ring, name, status line, language /
mute / reset buttons, message bubbles with "✓ opened …" notes, starter and follow-up chips, a mic
button with a live level meter, a text field and the disclaimer.

- **Avatar** — drawn with SwiftUI shapes from the same SVG geometry, with the blink and talking-mouth
  timers and the four moods (`idle`, `listening`, `thinking`, `speaking`).
- **Voice** — `AVAudioRecorder` records a 16 kHz mono m4a (20 s cap, 400 ms minimum), sends it to
  Gemini as inline audio, transcribes it into the bubble, and speaks the reply with
  `AVSpeechSynthesizer` (`en-US` / `ar-SA`, Arabic detected by script).
- **Model** — same flat JSON schema, same system prompt built from the on-device content, same model
  fallback chain, same safe actions: open a screen, jump to a gallery category, or pre-fill the quote
  form and open Contact.

## Project layout

```
CrazyCakesApple.xcodeproj      Xcode project (file-system-synchronized groups)
CrazyCakes/
  MarwaCrazyCakesApp.swift     app entry, splash gate, foreground content refresh
  App/                         AppRoot (tabs/sidebar) and Splash/Error views
  Assistant/                   Sprinkles: views, avatar, Gemini client, speech, recorder, copy
  Components/UI.swift          shared components (image, watermark, buttons, footer)
  Core/                        theme, database, updater, content store, media, config, quote draft
  Screens/                     Home, About, Gallery, Reviews, Pricing, Contact
  Resources/
    crazy-cakes.db             mobile content database (synced)
    Images/ Videos/            bundled media pack (synced, 66 images + 2 videos)
    Fonts/                     Dancing Script, Crimson Text, Inter
    Assets.xcassets/           app icon
    AppConfig.plist            content URL and Gemini configuration
scripts/sync-content.mjs       re-sync database, media and media registry from CrazyCakesMobile
scripts/MediaRegistry.template.swift
```

## Validation

- `node scripts/sync-content.mjs` runs clean; the packed database is byte-identical to the published
  content pack and passes `PRAGMA integrity_check`.
- Every content slot referenced by the SwiftUI screens exists in the database (93 slots), and every
  `images.src` / `videos.src` row resolves through `MediaRegistry` to a bundled file.
- Build and run verification requires Xcode on macOS:
  ```xcodebuild -project CrazyCakesApple.xcodeproj -scheme CrazyCakes -destination 'platform=iOS Simulator,name=iPhone 16' build```

For iPhone/TestFlight distribution, the EAS flow in the mobile repo's
`IOS-DEVELOPMENT-AND-TESTFLIGHT.md` does not apply to this native target — archive it from Xcode
(*Product → Archive*) with the same bundle identifier and content host instead.

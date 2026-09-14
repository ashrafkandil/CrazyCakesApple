# Marwa Crazy Cakes — iOS (SwiftUI)

Native iPhone + iPad clone of the web app (`../CrazyCakes`), built with SwiftUI and backed by
the **same SQLite database file** (`Resources/crazy-cakes.db`, copied from the web project's
`data/` and refreshed by `npm run db:seed` there).

## Requirements

- Xcode 16 or newer (project uses file-system-synchronized groups, objectVersion 77)
- iOS 16.0+ deployment target
- No external packages — SQLite is Apple's system `libsqlite3` (`import SQLite3`)

## Run

1. Open `CrazyCakesApple.xcodeproj` in Xcode.
2. Select a simulator (e.g. iPhone 16 + iPad Pro) or your device
   (set your team under *Signing & Capabilities* for device runs).
3. Press Run.

## Layout / UX parity

| Web                | iOS                                            |
| ------------------ | ---------------------------------------------- |
| 6 routed pages     | `TabView` bottom tabs (iPhone) / `NavigationSplitView` sidebar + detail (iPad) |
| Navbar logo        | App icon-style branding in views               |
| Gallery grid + lightbox | LazyVGrid + `fullScreenCover` lightbox with prev/next |
| Search-param filters | Category chips → `AppDatabase.gallery(category:page:)` (6 per page) |
| Reviews grid       | Same testimonial cards (★ rating from DB)      |
| Contact form       | Validated SwiftUI form; event types come from `event_types` table |
| Fonts              | Dancing Script / Crimson Text / Inter TTFs embedded and registered at launch |
| Colors             | Same oklch design tokens converted to sRGB     |

## Data flow

`AppDatabase` (repo seam, mirrors the web's `src/lib/data.ts`) copies the bundled read-only
`crazy-cakes.db` into Application Support on first launch, then serves:

- `content()` / `text()` — all Home + About copy (36 slots)
- `gallery(category:page:)` — categories, images, counts (SQLite `categories` + `images`)
- `testimonials()` — published reviews ordered by `sort`
- `eventTypes()` — contact form dropdown

Images in the DB reference web paths (`/assets/crazy/hero-1.jpg`); the app maps the sanitized
basename to bundled files under `Resources/Images/` and loads them via
`UIImage(contentsOfFile:)`, so DB rows can be updated without code changes.

## Updating content

Edit the database in the web workspace (`data/crazy-cakes.db`), then replace
`CrazyCakes/Resources/crazy-cakes.db` and reinstall the app (or delete app data on the
simulator so the copy step re-runs).

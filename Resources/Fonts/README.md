# Fonts

Drop the following font files into this directory before the app can render the
typography committed in `../../../CONCEPT.md` and `../../../SCREENS.md`:

- `Anton-Regular.ttf` — Google Fonts, Apache 2.0. https://fonts.google.com/specimen/Anton
- `BarlowCondensed-Regular.ttf` — Google Fonts, OFL. https://fonts.google.com/specimen/Barlow+Condensed
- `BarlowCondensed-Italic.ttf` — same family.

SF Mono is system-bundled and doesn't need to be shipped — access via
`Font.system(.body, design: .monospaced)`.

The app references these by filename in `Info.plist > UIAppFonts`. Until you drop
them in, custom-font lookups silently fall back to the system font, which means
Anton verbs will render in SF Pro Display instead. The app still runs; the
typography just doesn't match the spec.

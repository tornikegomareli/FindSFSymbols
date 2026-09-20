<p align="center">
  <img src="docs/assets/icon.png" width="96" alt="FindSFSymbols icon" />
  <h1 align="center">FindSFSymbols</h1>
</p>

<h3 align="center">Describe a symbol. The matches float up out of a physics pile.</h3>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6-orange.svg" />
  <img src="https://img.shields.io/badge/macOS-14+-blue.svg" />
  <img src="https://img.shields.io/badge/Universal-arm64%20%7C%20x86__64-lightgrey.svg" />
  <img src="https://img.shields.io/badge/license-MIT-green.svg" />
</p>

## Showcase

<p align="center">
  <img src="docs/assets/search.png" width="90%" alt="The query 'things you can wear' with a jacket, a hat, a t-shirt, sunglasses and shoes floating under the search bar, above a pile of colored symbols" />
</p>


Type "things you can wear" and you get the t-shirt, the shoes and the sunglasses, not only symbols with
"wear" in the name. Click a symbol and its name is on your clipboard.

## How it works

The search has two stages.

1. **On the device.** Every symbol name and keyword has a word vector from Apple's `NaturalLanguage`
   framework. The query is compared with all 3,832 symbols in a few milliseconds, and the best 48 go on.
2. **Jev, optional.** With a [TypeSafe](https://typesafe.ai) API key, one request asks Jev 48 yes-or-no
   questions in parallel: "is this icon a good result for this search?" The probability of each answer is
   the score of the symbol.

The score drives the physics. A sure match floats to the top row and holds still. A weak match hangs
lower, bobs and tilts. A symbol that Jev rejects falls back into the pile.

Without a key the app uses stage 1 only. It works, with more false matches.

## Privacy

The app has no analytics and no account.

- **Without a TypeSafe key** the app makes no network requests.
- **With a key**, each search sends your query text and the names, keywords and categories of the 48
  shortlisted symbols to `api.typesafe.ai`. Nothing else leaves the Mac.
- The key is stored in your login Keychain, never in a file.
- A click writes the symbol name to the clipboard.

## Permissions

The app asks for one permission, one time, and only if you use the hot key paste.

| Permission | When | Why |
|---|---|---|
| Accessibility | The first click after you summon the panel with the hot key | To press ⌘V in the app you came from |

If you say no, the click still copies the name and you paste it yourself. The app does not ask again.
The Keychain does not ask for a password: the app is signed with a Developer ID, and it reads only the
item that it created.

## Requirements

- macOS 14 (Sonoma) or later, Apple Silicon or Intel

## Install

With Homebrew:

```bash
brew install --cask tornikegomareli/tap/findsfsymbols
```

With the install script:

```bash
curl -fsSL https://raw.githubusercontent.com/tornikegomareli/FindSFSymbols/main/install.sh | bash
```

The script downloads the latest release, checks that the publisher signed it, and moves it to
`/Applications`. [Read it](install.sh) first if you want to see what it does.

Or get [**FindSFSymbols.zip**](https://github.com/tornikegomareli/FindSFSymbols/releases/latest/download/FindSFSymbols.zip)
from the latest release. Every release is notarized by Apple.

Build from source (no Xcode project, SwiftPM only):

```bash
git clone https://github.com/tornikegomareli/FindSFSymbols.git
cd FindSFSymbols
Scripts/compile_and_run.sh
```

Run the tests:

```bash
swift test
```

## Using it

| Action | Gesture |
|---|---|
| Search | Type a description: "bad weather", "send a message", "pets" |
| Copy a symbol name | Click the symbol |
| See the name first | Hover the symbol |
| Summon from any app | **⌃ ⌥ Space** |
| Copy and paste into the app you came from | Summon with the hot key, then click a symbol |
| Dismiss the summoned panel | **Esc**, or click another app |
| Throw a symbol | Drag it and let go |
| Move the window | Drag any empty area. The pile has inertia, so a shake tosses it |
| Filter by deployment target | The **Any iOS** menu. Symbols that need a later iOS turn gray and stay low |
| Add or remove the TypeSafe key | The key button in the top right corner |

## Releasing

`Scripts/release.sh` does the whole release from one command:

```bash
Scripts/release.sh patch            # or minor, major, or an exact version such as 0.2.0
Scripts/release.sh patch --dry-run  # build, sign, notarize and verify, but publish nothing
```

It bumps `version.env`, runs the tests, builds a universal app, signs it with the Developer ID, notarizes
and staples it, publishes a GitHub release with the zip, and updates the cask in
[homebrew-tap](https://github.com/tornikegomareli/homebrew-tap).

## Credits

- The hover foil is a port of the shaders in [bpisano/Sticker](https://github.com/bpisano/Sticker) (MIT).
- Ranking by [TypeSafe](https://typesafe.ai) Jev.

SF Symbols is a trademark of Apple Inc. This project is not affiliated with Apple. The app draws symbols
with the system API and ships no symbol artwork. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

[MIT](LICENSE)

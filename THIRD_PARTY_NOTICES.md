# Third-party notices

## Sticker

The hover foil in `Sources/FindSFSymbols/HoloSticker.swift` is a port of `FoilShader.metal` and
`ReflectionShader.metal` from [bpisano/Sticker](https://github.com/bpisano/Sticker).

    MIT License
    
    Copyright (c) 2024 bpisano
    
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

## SF Symbols

SF Symbols is a trademark of Apple Inc. This project is not affiliated with Apple and is not endorsed by Apple.
The app draws symbols with the system API (`NSImage(systemSymbolName:)`) and ships no symbol artwork.
`Sources/FindSFSymbols/Resources/symbols.json` holds symbol names, search keywords, categories and release
versions. `Scripts/build_catalog.py` builds it from the metadata of Apple's SF Symbols app.

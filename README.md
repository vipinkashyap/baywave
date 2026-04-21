# BayWave

Personal macOS + iOS radio app. Plays a hand-curated list of internet radio
streams (Bay Area, New York, India, Los Angeles) and identifies songs in real
time using a Swift port of the [songrec](https://github.com/marin-m/songrec)
fingerprint algorithm — so no ShazamKit entitlement or Apple App ID with
ShazamKit capability is required.

**Not for the App Store.** Build from source.

## What it does

- Streams live internet radio via `AVPlayer`. 83 curated stations across four
  regions; one tap to play, swipe through prev/next within a region.
- Captures the device microphone through `AVAudioEngine`, generates a
  Shazam-format fingerprint on-device (FFT + peak hashing via Accelerate),
  and POSTs it to Shazam's public endpoint to look up the song.
- When a song matches, shows title, artist, and cover art, plus a one-tap
  "Open in Music" button that deep-links into Apple Music.
- Lock-screen / Now Playing controls on both platforms. `MenuBarExtra`
  popover on macOS.
- Weekly GitHub Action pings every stream URL and replaces dead ones with
  fresh URLs from [Radio-Browser](https://www.radio-browser.info/).

## What it doesn't do

- **No Shazam SDK.** Apple's official `SHSession` has a bigger catalog and
  fresher indexing, but it needs an App ID with the ShazamKit capability.
  This app skips that by porting songrec's open reverse-engineered approach.
- **No headphone support for song ID.** Because the fingerprint comes from
  the mic (not a direct tap into the audio stream — `MTAudioProcessingTap`
  doesn't work on HTTP streams), you need the music to be audible in the
  room for song ID to work. Playback itself is fine on headphones.
- **No distribution.** This is a personal build. It's GPL-3 because
  songrec is GPL-3.

## Building

Requires Xcode 15+, macOS 14+, iOS 17+.

1. Clone the repo.
2. Open `BayWave/BayWave.xcodeproj` in Xcode.
3. Target → Signing & Capabilities → pick your Team and set a unique
   bundle ID (e.g. `com.yourname.BayWave`).
4. Build & run on Mac, iPhone, or iOS simulator.

First run will prompt for microphone permission — the mic is only used for
song ID, audio is never recorded or transmitted.

## Layout

```
BayWave/BayWave/
  BayWaveApp.swift          # @main, scenes (MenuBarExtra + Window on macOS, WindowGroup on iOS)
  AppModel.swift            # wires stations + player + recognizer + now-playing
  Theme.swift               # palette, genre tints, fonts
  Info.plist
  Models/
    Station.swift
  Services/
    StationStore.swift      # loads bundled stations.json
    PlayerEngine.swift      # AVPlayer wrapper
    NowPlayingCenter.swift  # MPNowPlayingInfoCenter + remote commands
    RadioBrowserAPI.swift   # fallback fetch
    SongRec/
      HannWindow.swift        # Shazam's 2048-point window
      Signature.swift         # peak structs, binary encoder, CRC32
      SignatureGenerator.swift  # FFT + peak spreading + peak recognition
      ShazamClient.swift        # POST to amp.shazam.com
      SongRecognizer.swift      # mic → resample → signature → lookup
  Views/
    RootView.swift
    NowPlayingCard.swift
    StationListView.swift   # region tabs + list
    LogoMark.swift

scripts/
  refresh-stations.py       # HEAD-check every URL, replace dead via Radio-Browser
  make-icon.py              # generate 1024×1024 AppIcon

.github/workflows/
  refresh-stations.yml      # weekly; commits replacements to main
```

## Acknowledgements

- **[songrec](https://github.com/marin-m/songrec)** by marin-m — the fingerprint
  algorithm and Shazam protocol are ported from its Rust implementation.
- **[Radio-Browser](https://www.radio-browser.info/)** — station directory used
  for discovery and URL refresh.

## License

GPL-3.0 — see [LICENSE](LICENSE). Derivative of songrec (GPL-3.0).

## Disclaimer

The app calls an unofficial Shazam endpoint. Apple could change or shut down
this endpoint at any time, in which case song identification would stop
working until the port is updated. Stream playback is unaffected either way.
Don't use this for anything commercial.

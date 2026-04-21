Build BayWave: a personal macOS + iOS radio app. Not for distribution.

## Requirements

1. Plays internet radio streams from a curated list of Bay Area stations 
   (provided in Resources/stations.json).
2. Uses ShazamKit to continuously identify songs while a station plays.
3. Shows currently-identified song as a card: title, artist, album art.
4. Tap the card → save the song to the user's Shazam library 
   (SHLibrary.default.addItems).
5. Station list with tap-to-play. Remember last station, auto-resume on launch.
6. Fallback: if stations.json is stale, fetch from Radio-Browser.info API 
   filtered by tag=bay-area or state=California.

## Targets

- macOS 14+ (menu bar app + optional window)
- iOS 17+ (standard app, lock screen + Control Center playback controls)
- Share ~90% of code. Use #if os(macOS) only for MenuBarExtra and 
  window scenes.

## Stack (Apple-native only, zero third-party deps)

- SwiftUI, AVFoundation, ShazamKit, MediaPlayer (for Now Playing Info)
- No SPM dependencies
- No analytics, no telemetry

## Design

- Minimal. Dark mode default. Warm amber accent (#E8A33D) on deep navy (#0A1628).
- Typography: New York (serif) for song titles, SF Mono for station call letters.
- One screen on iOS. On macOS: menu bar popover (compact) + optional window.
- Now Playing card: big album art (or station logo if no ID yet), song title, 
  artist, small "saved" heart that fills on tap.
- No technical metadata visible (no bitrate, no codec, no URLs).

## Behavior

- AVPlayer.automaticallyWaitsToMinimizeStalling = true
- Keep one AVPlayer instance alive; swap AVPlayerItem on station change 
  (avoids cold-start hiccup).
- ShazamKit matching runs on a separate AVAudioEngine tap on the player's 
  output. Match attempts every 12 seconds while playing.
- MPNowPlayingInfoCenter updated with station + current song so media keys 
  and lock screen work.
- AVAudioSession .playback category on iOS so audio continues in background.

## Deliverables

1. Xcode project with both macOS and iOS targets, sharing all Swift files.
2. stations.json at Resources/stations.json (the user will provide this — 
   read it as a bundle resource).
3. README.md with: setup steps, signing config, how to enable ShazamKit 
   capability in the target, required Info.plist entries 
   (NSMicrophoneUsageDescription, UIBackgroundModes: audio on iOS).
4. A simple .gitignore for Xcode projects.

## Don't build

- No voice commands
- No ad detection
- No YouTube Music integration
- No discovery feed
- No CloudKit (Shazam library syncs itself)
- No wake word

Ship the core. When done, print `git add . && git commit -m "initial"` commands.
# DeepScan

Identify reef fish instantly. DeepScan is an iOS app for snorkelers and aquarium enthusiasts that uses on-device machine learning to detect and classify reef fish from photos taken with the camera or imported from the photo library.

## Features

- **Fish detection** — locates multiple fish in a single photo and draws bounding boxes (YOLO-World based)
- **Species classification** — identifies 12 reef fish species with confidence scores:
  Atlantic Blue Tang · Ocellaris Clownfish · Guineafowl Pufferfish · Blacktip Reef Shark · Raccoon Butterflyfish · Blue-Green Chromis · Bluespine Unicornfish · Emperor Angelfish · Red Lionfish · Lagoon (Picasso) Triggerfish · Blue-Barred Parrotfish · Moon Wrasse
- **Multi-fish picker** — when several fish are detected, choose which one to identify
- **Camera capture & gallery import** — full-screen camera UI (front/back camera) or pick from Photos
- **Snorkel diary** — save catches with name, confidence, location, notes, and thumbnail (SwiftData persistence)
- **Diary map** — saved catches plotted as pins on a map, geocoded from their location text (MapKit)
- **Species reference cards** — common & scientific name, family, origin, how to spot it, and a fun fact for every species, with a reference illustration shown alongside your photo
- **Ocean-themed UI** — gradient backgrounds, aqua palette, animated bubbles

## Tech stack

- **Language:** Swift 5.0
- **UI:** SwiftUI
- **Persistence:** SwiftData
- **ML:** CoreML + Vision
- **Camera:** AVFoundation
- **Photos:** PhotosUI
- **Maps & geocoding:** MapKit + CoreLocation
- **No third-party dependencies** — pure Apple frameworks. No CocoaPods, SPM packages, or Carthage to set up.

## Requirements

| | Version |
|---|---|
| Xcode | **26.2** or later |
| iOS deployment target | **26.2** |
| macOS | Whatever Xcode 26.2 requires (latest stable macOS recommended) |
| Apple ID | Free Apple ID works for on-device testing; paid Apple Developer account ($99/yr) only needed for App Store distribution |
| Device | iPhone running iOS 26.2 or later (real device required to use the camera; the iOS Simulator has no camera hardware) |

## Project structure

```
DeepScan/
├── App/             # @main entry point (DeepScanApp.swift)
├── Views/           # SwiftUI screens (Home, Camera, PhotoPreview, FishPicker,
│                    #   Results, Diary, DiaryDetail, Map) + Theme & shared SpeciesViews
├── ViewModels/      # Classifier, Detector, Camera view models
├── Models/          # DiaryEntry (SwiftData), FishResult, DetectedFish, ImageCrop,
│                    #   FishSpecies (reference data), Benchmark (perf instrumentation)
├── ML/              # DeepScanClassifier.mlpackage, FishDetector.mlpackage
└── Resources/       # Assets.xcassets
DeepScanTests/       # Unit tests
DeepScanUITests/     # UI tests
```

## Setup

### 1. Install Xcode

1. Open the **Mac App Store** and install **Xcode 26.2** (or later). Alternatively, download from [developer.apple.com/xcode](https://developer.apple.com/xcode/).
2. Launch Xcode once after install so it can finish installing additional components and accept the license agreement.

### 2. Clone the repo

```bash
git clone https://github.com/fish-gang/deepscan-ios.git
cd deepscan-ios
```

### 3. Open the project

```bash
open DeepScan.xcodeproj
```

There are no packages to fetch and no `pod install` step — just open and build.

## Running on the iOS Simulator

Use the simulator for quick UI iteration. Note that the camera will not work — only the photo library flow.

1. In Xcode's toolbar, pick a simulator from the destination menu (e.g. *iPhone 16 Pro*).
2. Press **⌘R** (or the ▶ Run button).

## Running on an iPhone (via USB cable)

### One-time device setup

1. **Connect the iPhone** to your Mac with a USB-C / Lightning cable.
2. On the iPhone, tap **Trust** when prompted to trust the computer, then enter your passcode.
3. On the iPhone, enable Developer Mode: **Settings → Privacy & Security → Developer Mode → On**, then restart when prompted.

### One-time Xcode signing setup

1. In Xcode: **Settings → Accounts → +** and sign in with your Apple ID.
2. Open the project, select the **DeepScan** target → **Signing & Capabilities** tab.
3. Tick **Automatically manage signing**.
4. Set **Team** to your personal team (or your organization's team). The current project is configured for team `355FYVXC7F` — change this to your own.
5. The bundle identifier is `com.fishgang.DeepScan`. If Xcode reports a conflict (someone else has already used it on your Apple ID), change it to something unique like `com.<yourname>.DeepScan`.

### Run it

1. In the destination menu at the top of Xcode, select your iPhone (it appears by name once connected and trusted).
2. Press **⌘R**.
3. **First launch only:** the app will install but iOS will refuse to open it because the developer certificate is untrusted. On the iPhone go to **Settings → General → VPN & Device Management → [your Apple ID] → Trust**. Then launch DeepScan from the home screen.
4. Grant **Camera** and **Photo Library** permission when prompted.

### Wireless debugging (optional)

After running once over cable, you can switch to Wi-Fi: in Xcode open **Window → Devices and Simulators**, select your iPhone, and tick **Connect via network**. The cable is no longer required as long as both devices share a Wi-Fi network.

## Permissions

The app requests the following at runtime:

- **Camera** — to capture photos of fish
- **Photo Library** — to import existing photos

Both are declared in the project's Info settings; iOS will surface the permission prompt the first time each is used.

## Machine learning models

Two CoreML packages ship in `DeepScan/ML/`:

- **`DeepScanClassifier.mlpackage`** — 12 species + 2 sentinel labels (`no_fish`, `unknown_fish`). Labels are scientific (binomial) names, looked up against `FishSpecies` for friendly display. Returns logits; the app applies softmax. Center-crop scaling.
- **`FishDetector.mlpackage`** — YOLO-World detector. Confidence threshold 0.25, aspect-preserving scaling. Returns up to 8 boxes sorted by area (largest first).

Both models load at app launch and run fully on-device — no network calls.

## Troubleshooting

- **"Untrusted Developer" on first launch** — see step 3 of [Run it](#run-it) above.
- **"Failed to register bundle identifier"** — the bundle ID is already taken on your Apple ID. Change it under *Signing & Capabilities*.
- **Device not appearing in Xcode** — unplug and replug the cable, make sure you tapped *Trust* on the iPhone, and verify Developer Mode is on.
- **Camera shows a black screen in the Simulator** — expected; the Simulator has no camera. Use a real device or the photo library flow.

## Version

Current marketing version: **1.0** (build 1).

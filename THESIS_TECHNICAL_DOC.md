# DeepScan iOS – Technische Dokumentation für die Bachelorarbeit

> Stand: 2026-05-28 · Branch `main` · Marketing-Version 1.0 (Build 1)
> Repo: `deepscan-ios` (Bundle ID `com.fishgang.DeepScan`)
> Zweck dieses Dokuments: vollständige technische Grundlage für den Bachelorarbeitsteil **Mobile Entwicklung**. Enthält Architektur, Entscheidungen, Code-Auszüge, Probleme und Lösungen.

---

## 1. Projektübersicht

**DeepScan** ist eine native iOS-App für Schnorchler und Aquarianer, die Riff-Fische auf Fotos *vollständig auf dem Gerät* erkennt und klassifiziert. Es gibt keinen Server, keine Cloud-Inferenz, keine Drittanbieter-Bibliotheken. Die App besteht aus zwei aufeinander aufbauenden Machine-Learning-Stufen (Detektion → Klassifikation), einer Kamera-/Galerie-Pipeline, einer SwiftData-basierten Tagebuchfunktion mit Kartenansicht und einer ozeanthematisierten SwiftUI-Oberfläche.

### 1.1 Funktionsumfang

| Feature | Komponente |
|---|---|
| Fischerkennung (Bounding Boxes) | YOLO-World basierter Detektor (`FishDetector.mlpackage`) |
| Spezies-Klassifikation (11 Arten + 2 Sentinel-Labels) | `DeepScanClassifier.mlpackage` |
| Multi-Fish-Picker | `FishPickerView` |
| Kamera-Aufnahme (Front/Back-Switch) | `AVFoundation` über `CameraViewModel` |
| Galerie-Import | `PhotosUI.PhotosPicker` |
| Schnorcheltagebuch | `SwiftData` (`DiaryEntry @Model`) |
| Karte der Tauchorte | `MapKit.Map` + `MKLocalSearch` |
| Animationen (Blubber, Lichtstrahlen, Fische) | SwiftUI deklarative Animationen |

### 1.2 Erkannte Arten (11 Species + 2 Sentinels)

| Wissenschaftlicher Name | Trivialname |
|---|---|
| *Acanthurus coeruleus* | Blue Tang (Paletten-Doktorfisch) |
| *Amphiprion ocellaris* | Clownfisch |
| *Arothron meleagris* | Guineafowl Puffer (Perlhuhn-Kugelfisch) |
| *Carcharhinus melanopterus* | Blacktip Reef Shark (Schwarzspitzen-Riffhai) |
| *Chaetodon lunula* | Raccoon Butterflyfish (Waschbär-Falterfisch) |
| *Chromis viridis* | Green Chromis (Grüne Schwalbenschwanz-Riffbarsch) |
| *Naso unicornis* | Bluespine Unicornfish (Nasen-Doktor) |
| *Pomacanthus imperator* | Emperor Angelfish (Imperator-Kaiserfisch) |
| *Pterois volitans* | Red Lionfish (Roter Feuerfisch) |
| *Rhinecanthus aculeatus* | Picasso Triggerfish (Picasso-Drückerfisch) |
| *Scarus ghobban* | Bluebarred Parrotfish (Papageifisch) |
| `no_fish` | Sentinel: kein Fisch auf dem Foto |
| `unknown_fish` | Sentinel: ist ein Fisch, aber keine der trainierten Klassen |

---

## 2. Tech-Stack und Entscheidungen

| Bereich | Wahl | Begründung |
|---|---|---|
| Sprache | Swift 5.0 (Compiler-Strict-Concurrency) | Erstklassige Apple-Toolchain, native ML-Frameworks |
| UI-Framework | **SwiftUI** | Deklarativ, geringerer Code-Aufwand, native Animationen, gute Integration mit `@Observable` |
| Persistenz | **SwiftData** (`@Model`) | Nachfolger von CoreData mit Swift-nativer API, kein Codegen, direkte Integration in SwiftUI über `@Query` |
| Reaktivität | **`@Observable`** (Swift Observation, iOS 17+) | Ersetzt `ObservableObject`/`@Published` – feingranulares Tracking, weniger Boilerplate |
| ML-Inferenz | **CoreML + Vision** | Hardware-Beschleunigung (CPU + GPU + Neural Engine), automatische Bildvorbereitung |
| Kamera | **AVFoundation** | Volle Kontrolle über Session/Output, kein `UIImagePickerController` |
| Galerie | **PhotosUI.PhotosPicker** | Kein Berechtigungsdialog nötig (Sandbox-Picker seit iOS 16) |
| Karte | **MapKit** (iOS 17+ Map-API) | Native Integration, `Marker`-API |
| Standortauflösung | **`MKLocalSearch`** | Natürlichsprachige Freitext-Suche (z. B. „Great Barrier Reef") |
| Dependency Manager | **Keiner** | Bewusste Entscheidung gegen CocoaPods/SPM/Carthage – reduziert Setup-Aufwand und Angriffsfläche |
| Minimum-OS | **iOS 26.2** | Erlaubt Verwendung neuester SwiftUI-/Vision-/MapKit-APIs ohne Fallback-Code |

### 2.1 Warum keine externen Abhängigkeiten?

Die Entscheidung gegen Drittanbieter-Pakete wurde aus drei Gründen getroffen:

1. **Reproduzierbarkeit** – kein `pod install`, kein SPM-Resolver, kein Build-Bruch durch Upstream-Änderungen. Wer das Repo klont, kann sofort bauen.
2. **Apple stellt alles bereit, was die App braucht**: CoreML, Vision, SwiftData, AVFoundation, MapKit, PhotosUI.
3. **App-Größe und Startzeit** – jede externe Library belastet die Binär-Größe und potentiell den Start.

Diese Entscheidung ist im `README.md` explizit dokumentiert („No third-party dependencies — pure Apple frameworks").

### 2.2 Build-Konfiguration (aus `DeepScan.xcodeproj/project.pbxproj`)

```text
IPHONEOS_DEPLOYMENT_TARGET = 26.2
SWIFT_VERSION              = 5.0
MARKETING_VERSION          = 1.0
CURRENT_PROJECT_VERSION    = 1
PRODUCT_BUNDLE_IDENTIFIER  = com.fishgang.DeepScan
DEVELOPMENT_TEAM           = 355FYVXC7F
INFOPLIST_KEY_NSCameraUsageDescription      = "DeepScan needs camera access to identify fish underwater"
INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "DeepScan needs photo access to analyze your underwater photos"
```

> **Designentscheidung – „Info.plist as Build Setting":** Die `Info.plist`-Datei ist absichtlich leer (`<dict/>`). Stattdessen werden alle Schlüssel über `INFOPLIST_KEY_*`-Build-Settings im Xcode-Projekt definiert. Das ist seit Xcode 13 die empfohlene Methode (kein Merge-Konflikt in der Plist, alles versionierbar im `pbxproj`).

---

## 3. Architektur

### 3.1 MVVM-Schichtung

```
DeepScan/
├── App/           DeepScanApp.swift          @main-Entry, Modell-Initialisierung
├── Views/         SwiftUI-Screens            View-Layer
│   ├── HomeView                              Startbildschirm + Animationen
│   ├── CameraView                            Live-Kameravorschau
│   ├── PhotoPreviewView                      Foto-Vorschau + Scan-Trigger
│   ├── FishPickerView                        Auswahl bei Mehrfacherkennung
│   ├── ResultsView                           Ergebnis + Save-to-Diary
│   ├── DiaryView / DiaryDetailView           Tagebuch-Liste + Detail
│   ├── MapView                               Karte mit Tauchorten
│   └── Theme.swift                           OceanTheme (Palette, Gradienten)
├── ViewModels/
│   ├── ClassifierViewModel                   Vision-CoreML-Klassifikator
│   ├── DetectorViewModel                     Vision-CoreML-Detektor
│   └── CameraViewModel                       AVCaptureSession-Logik
├── Models/
│   ├── DiaryEntry (@Model)                   Persistente Tagebucheinträge
│   ├── FishResult                            Wert-Typ: Name + Confidence + Bild
│   ├── DetectedFish                          Eine Bounding-Box
│   ├── ImageCrop                             Statische Crop-Utility
│   └── CGImagePropertyOrientation+UIImage    Orientation-Mapping
├── ML/
│   ├── DeepScanClassifier.mlpackage          11 Arten + 2 Sentinels
│   └── FishDetector.mlpackage                YOLO-World
└── Resources/Assets.xcassets                 Icons, Bilder
```

### 3.2 App-Lifecycle (`DeepScanApp.swift`)

```swift
@main
struct DeepScanApp: App {
    // Created once here — models load at app launch, not per request.
    @State private var classifier = ClassifierViewModel()
    @State private var detector = DetectorViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(classifier)
                .environment(detector)
        }
        .modelContainer(for: DiaryEntry.self)
    }
}
```

**Drei wichtige Entscheidungen in diesen 19 Zeilen:**

1. **ML-Modelle werden einmalig beim App-Start geladen**, nicht pro Scan. Das vermeidet die teuren `MLModel(contentsOf:)`-Aufrufe (mehrere hundert Millisekunden auf älteren iPhones) auf dem kritischen Pfad.
2. **`@State` statt `@StateObject`** für die ViewModels, weil sie mit `@Observable` markiert sind – das ist die korrekte SwiftUI-Bindung für das neue Observation-Framework.
3. **`@Environment`-Propagierung** (statt Singleton oder `EnvironmentObject`) – ViewModel-Instanzen werden durch den View-Tree gereicht und sind via `@Environment(ClassifierViewModel.self)` typsicher erreichbar.

### 3.3 Reaktivitätsmodell

Alle drei ViewModels nutzen:

```swift
@Observable
@MainActor
final class ClassifierViewModel { ... }
```

- `@Observable` (Swift Observation, iOS 17+) macht alle gespeicherten Properties automatisch beobachtbar. SwiftUI rendert nur die Views neu, die genau die geänderte Property lesen.
- `@MainActor` garantiert, dass alle Methoden des VMs auf dem Main-Thread laufen – kritisch, weil sie UI-State setzen.
- `@ObservationIgnored` markiert Properties, die *nicht* zu UI-Updates führen sollen (z. B. das interne `VNCoreMLModel`).

---

## 4. Machine-Learning-Pipeline

Die ML-Pipeline ist das Herz der App. Sie ist als **zweistufige Inferenz** aufgebaut: zuerst wird detektiert, dann klassifiziert. Diese Trennung erlaubt es, mehrere Fische in einem Foto zu lokalisieren und einzeln zu untersuchen.

### 4.1 Modelle

Beide Modelle liegen als CoreML-`.mlpackage` (mehrteiliges Verzeichnis) in `DeepScan/ML/` und werden automatisch von Xcode beim Build zu `.mlmodelc` (compiled) übersetzt:

| Modell | Aufgabe | Architektur | Größe |
|---|---|---|---|
| `DeepScanClassifier.mlpackage` | Klassifikation 11 Arten + 2 Sentinels | (vermutlich) CNN, fine-tuned | ~8 MB Gewichte |
| `FishDetector.mlpackage` | Detektion „Fisch" als Klasse | YOLO-World basiert | ~56 MB Gewichte |

> **Sync vom ML-Repo:** Die Modelle stammen aus einem separaten `deepscan-model`-Repo. Eine GitHub-Action (`github-actions[bot]`-Commits) synchronisiert kompilierte Modelle in dieses iOS-Repo. Beispiel-Commits: `5891c95`, `efec2ec`, `752ef23` („Sync model from deepscan-model").

### 4.2 Klassifikator (`ClassifierViewModel.swift`)

```swift
private func loadModel() {
    do {
        let config = MLModelConfiguration()
        config.computeUnits = .all                          // CPU + GPU + Neural Engine
        let coreMLModel = try DeepScanClassifier(configuration: config)
        vnModel = try VNCoreMLModel(for: coreMLModel.model)
    } catch {
        errorMessage = "Failed to load model: \(error.localizedDescription)"
    }
}
```

**Inferenz-Code (gekürzt):**

```swift
func classify(image: UIImage) async -> FishResult? {
    let request = VNCoreMLRequest(model: vnModel)
    request.imageCropAndScaleOption = .centerCrop

    let handler = VNImageRequestHandler(
        cgImage: cgImage,
        orientation: CGImagePropertyOrientation(image.imageOrientation),
        options: [:]
    )

    let observations: [VNClassificationObservation] = try await Task.detached(priority: .userInitiated) {
        try handler.perform([request])
        return request.results as? [VNClassificationObservation] ?? []
    }.value

    // Softmax über die rohen Logits
    let scores = observations.map { Double($0.confidence) }
    let maxScore = scores.max() ?? 0
    let exps = scores.map { exp($0 - maxScore) }
    let confidence = (exps.first ?? 0) / exps.reduce(0, +)
    ...
}
```

**Schlüsselentscheidungen:**

- **`.computeUnits = .all`** – Vision wählt automatisch die schnellste Hardware (in der Regel Neural Engine auf iPhones mit A12+).
- **`.imageCropAndScaleOption = .centerCrop`** – das Klassifikatormodell wurde mit Center-Crop-Inputs trainiert, also muss der Inferenzpfad genauso vorgehen.
- **`Task.detached(priority: .userInitiated)`** – `handler.perform()` ist synchron und blockierend. Würde es auf dem MainActor laufen, würde die UI für Hunderte Millisekunden einfrieren.
- **`request.results` *innerhalb* der detached Task lesen** – das Vision-Result-Objekt darf nicht zwischen Threads übergeben werden (Strict Concurrency in Swift 6).
- **Manueller Softmax** (`ClassifierViewModel.swift:84-87`): Das exportierte Modell liefert *rohe Logits*, keine Wahrscheinlichkeiten. Die App wendet stabil normalisierten Softmax an (Subtraktion des Maximums, um Overflow zu verhindern). Ohne diesen Schritt wären die Confidence-Werte unsinnig.

### 4.3 Detektor (`DetectorViewModel.swift`)

```swift
func detect(image: UIImage) async -> [DetectedFish] {
    let request = VNCoreMLRequest(model: vnModel)
    request.imageCropAndScaleOption = .scaleFit         // Aspect-erhaltend!

    let handler = VNImageRequestHandler(...)

    let observations: [VNRecognizedObjectObservation] = try await Task.detached(...).value

    return observations
        .filter { $0.confidence >= 0.25 }
        .map { obs in
            // Vision: bottom-left, normalized. UIImage/SwiftUI: top-left, normalized.
            let v = obs.boundingBox
            let topLeft = CGRect(
                x: v.minX,
                y: 1 - v.maxY,                          // Y-Achse spiegeln
                width: v.width,
                height: v.height
            )
            return DetectedFish(boundingBox: topLeft, confidence: Double(obs.confidence))
        }
        .sorted { $0.area > $1.area }
        .prefix(8)
        .map { $0 }
}
```

**Drei wichtige technische Entscheidungen:**

1. **`.scaleFit` statt `.centerCrop`** – Objektdetektoren brauchen seitenverhältnistreues Resizing. `.scaleFill` würde Fische verzerren und die Detection-Accuracy massiv senken.
2. **Confidence-Schwelle 0.25** – konservativ niedrig, weil Fische in schlechtem Licht / hinter Wasser-Verzerrung oft niedrigere Scores haben. False-Positives werden in der UI über den Picker abgefangen.
3. **Y-Achsen-Konvertierung** – Vision liefert Boxes im *bottom-left*-Koordinatensystem (mathematische Konvention), aber SwiftUI/UIImage nutzen *top-left*. Die Umrechnung erfolgt sofort, damit der View-Layer ohne Mathematik auskommt.
4. **Sortierung nach Fläche + Cap auf 8** – wenn viele Detektionen kommen, sind die größten meist die für den Nutzer interessanten (Vordergrundfische). Mehr als 8 Auswahlmöglichkeiten würden den Picker überfordern.

**Mock-Fallback** (für UI-Entwicklung ohne kompiliertes Modell):

```swift
@ObservationIgnored private var usingMock: Bool { vnModel == nil }

private func mockDetections() -> [DetectedFish] {
    [
        DetectedFish(boundingBox: CGRect(x: 0.10, y: 0.18, width: 0.30, height: 0.26), confidence: 0.92),
        DetectedFish(boundingBox: CGRect(x: 0.55, y: 0.40, width: 0.28, height: 0.22), confidence: 0.78),
        ...
    ]
}
```

Wenn `FishDetector.mlmodelc` im Bundle fehlt, fällt der VM auf hartkodierte Mock-Boxes zurück. Das ermöglichte die parallele Entwicklung der Picker-UI, bevor das YOLO-Modell verfügbar war.

### 4.4 Crop-Logik (`Models/ImageCrop.swift`)

```swift
static func crop(
    _ image: UIImage,
    to normalizedBox: CGRect,
    padding: CGFloat = 0.15
) -> UIImage? {
    // Expand by `padding` on each side, clamped to the image.
    let padX = normalizedBox.width * padding
    let padY = normalizedBox.height * padding
    let padded = CGRect(
        x: max(0, normalizedBox.minX - padX),
        y: max(0, normalizedBox.minY - padY),
        width: ...,
        height: ...
    )
    ...
    let renderer = UIGraphicsImageRenderer(size: pixelRect.size)
    return renderer.image { _ in
        image.draw(at: CGPoint(x: -pixelRect.minX, y: -pixelRect.minY))
    }
}
```

**Begründung des 15 %-Paddings (im Code-Kommentar dokumentiert):**

> „Padding gives the classifier some surrounding water/reef context — tight crops noticeably hurt confidence because the model was trained on whole-fish photos with background, not on isolated cutouts."

Das ist eine empirisch ermittelte Entscheidung: bei zu engem Crop fehlt dem Klassifikator der visuelle Kontext, mit dem er beim Training kalibriert wurde. 15 % ist der gefundene Sweet Spot.

**Warum `UIGraphicsImageRenderer.image`?** – behandelt die `imageOrientation` der `UIImage` korrekt, sodass kein manueller `CGImage`-Transform nötig ist. Ohne diesen Pfad wären Porträtfotos um 90° gedreht im Crop.

### 4.5 Orientation-Mapping (`CGImagePropertyOrientation+UIImage.swift`)

```swift
extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up:            self = .up
        case .down:          self = .down
        case .left:          self = .left
        case .right:         self = .right
        case .upMirrored:    self = .upMirrored
        ...
        @unknown default:    self = .up
        }
    }
}
```

> „Vision needs the source image's orientation to interpret pixels correctly — portrait photos carry rotation metadata that, if ignored, produces sideways crops and noticeably worse classification accuracy."

Das ist ein klassisches iOS-Foto-Problem: HEIC/JPEG aus der Kamera-App enthält EXIF-Rotation, nicht physisch rotierte Pixel. Wer die Orientierung ignoriert, klassifiziert effektiv ein quergedrehtes Bild.

### 4.6 Die zentrale Scan-Logik (`PhotoPreviewView.swift`)

Die zentrale Entscheidung, *wie* die zwei Modelle zusammengeschaltet werden, sitzt in `PhotoPreviewView.scan()`:

```swift
private func scan() {
    phase = .detecting
    Task {
        let found = await detector.detect(image: image)

        switch found.count {
        case 0:
            // Detector found nothing. Either not a fish, or the detector missed.
            // Hand the whole image to the classifier — its `no_fish` sentinel
            // will catch genuinely non-fish photos.
            await classify(image)

        case 1:
            // Single fish — skip the picker, classify the cropped region.
            let cropped = ImageCrop.crop(image, to: found[0].boundingBox) ?? image
            await classify(cropped)

        default:
            // Multiple fish — let the user pick which one to scan.
            detections = found
            navigateToPicker = true
        }
    }
}
```

**Drei-Wege-Strategie:**

| Detektor-Output | Verhalten | Begründung |
|---|---|---|
| 0 Boxes | Klassifiziere das *gesamte* Bild | Detektoren übersehen oft formatfüllende Fische. Falls wirklich kein Fisch da ist, fängt das `no_fish`-Label des Klassifikators das ab. |
| 1 Box | Crop + Klassifizieren, Picker übersprungen | UX: kein unnötiger Auswahlschritt. |
| ≥2 Boxes | Picker anzeigen, Nutzer wählt | Bei mehreren Fischen kann die App nicht raten, welchen der Nutzer meint. |

---

## 5. Kamera & Galerie

### 5.1 Kamera (`CameraViewModel.swift` + `CameraView.swift`)

Die Kamera-Implementierung ist absichtlich nicht über `UIImagePickerController` gemacht, sondern über die rohe `AVCaptureSession`. Vorteile: volle Kontrolle über UI, Front/Back-Switch, eigene Capture-Buttons mit haptischem Feedback.

```swift
@MainActor
@Observable
final class CameraViewModel: NSObject {
    let session = AVCaptureSession()
    var capturedImage: UIImage?
    var isCameraReady = false
    var errorMessage: String?
    var currentPosition: AVCaptureDevice.Position = .back

    @ObservationIgnored private let photoOutput = AVCapturePhotoOutput()
    @ObservationIgnored private var currentInput: AVCaptureDeviceInput?
}
```

**Berechtigungsfluss:**

```swift
func checkPermissionsAndSetup() async {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:    configure(position: .back, initialSetup: true)
    case .notDetermined: if await AVCaptureDevice.requestAccess(for: .video) { ... }
    case .denied, .restricted: errorMessage = "Camera access denied..."
    ...
    }
}
```

**Off-Main-Konfiguration** (`CameraViewModel.swift:54-106`):

```swift
private func configure(position: AVCaptureDevice.Position, initialSetup: Bool) {
    let session = self.session
    let photoOutput = self.photoOutput
    let oldInput = self.currentInput
    // Hoist the weak reference before entering the detached task so we
    // capture a plain local (not a @MainActor var), which Swift 6 permits.
    weak let weakSelf = self

    Task.detached(priority: .userInitiated) {
        session.beginConfiguration()
        if initialSetup { session.sessionPreset = .photo }
        if let oldInput { session.removeInput(oldInput) }

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: position
        ) else {
            session.commitConfiguration()
            await MainActor.run { weakSelf?.errorMessage = "Camera unavailable..." }
            return
        }

        let input = try AVCaptureDeviceInput(device: camera)
        if session.canAddInput(input) { session.addInput(input) }
        if initialSetup, session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()
        await MainActor.run { weakSelf?.isCameraReady = true; ... }
        if initialSetup { session.startRunning() }
    }
}
```

**Wichtige Subtilitäten:**

1. **`AVCaptureSession.beginConfiguration()` blockiert** – muss off-main laufen, sonst Frame-Drop beim Start.
2. **Strict Concurrency Workaround** – die `weak let weakSelf = self` wird *vor* der `Task.detached` aufgehoben, weil ein `@MainActor`-`var` nicht direkt in eine detached Task captured werden darf. Das ist eine konkrete Swift-6-Concurrency-Anpassung.
3. **`initialSetup`-Flag** – differenziert zwischen erstem Setup (Output hinzufügen, Session starten) und Runtime-Switch (nur Input tauschen).
4. **Front-Cam-Switch** wurde im Commit `60462f2` („enable camera selfie function") nachgereicht.

**SwiftUI-Brücke für `AVCaptureVideoPreviewLayer`** (`CameraView.swift:93-121`):

```swift
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        view.previewLayer = previewLayer
        return view
    }
    ...
}

final class CameraPreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds                   // Reapply nach Layout
    }
}
```

> „`makeUIView` runs before layout (`bounds == .zero` at that point), so the preview layer frame must be reapplied in `layoutSubviews` once real bounds are known. Apple's AVCam sample follows the same pattern."

Das ist ein bekannter Stolperstein bei `UIViewRepresentable`: zum Zeitpunkt des `makeUIView`-Aufrufs hat die View noch keine echten Bounds. Ohne `layoutSubviews()` würde der Preview-Layer 0×0 sein.

### 5.2 Galerie (`HomeView.swift`)

```swift
@State private var galleryItem: PhotosPickerItem? = nil

PhotosPicker(selection: $galleryItem, matching: .images) { ... }

.onChange(of: galleryItem) { _, newItem in
    Task {
        if let data = try? await newItem?.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            previewImage = CapturedImage(image: image)
        }
    }
}
```

**Warum `PhotosPicker` statt `UIImagePickerController`?**

- **Kein Berechtigungsdialog nötig** – der Picker läuft seit iOS 16 in einem Sandbox-Prozess. Der Nutzer wählt selbst, welche Bilder die App sehen darf.
- **Native SwiftUI-Bindung** über `selection: Binding<PhotosPickerItem?>`.
- **Async-Loading** über `loadTransferable(type:)` – das Bild wird erst beim Abruf in den App-Prozess kopiert.

> Die `NSPhotoLibraryUsageDescription` ist trotzdem im Projekt gesetzt (für Edge-Cases / API-Konsistenz), aber `PhotosPicker` selbst löst keinen System-Dialog aus.

---

## 6. Navigationsfluss

Die App nutzt durchgehend `NavigationStack` (iOS 16+) mit `navigationDestination(item:)`. Das ist die moderne, Identity-basierte Navigation.

```
HomeView
├── [Take Photo]        ──> .fullScreenCover ──> CameraView
│                                                    └── captures UIImage
│                                                        └── dismiss
│                                                            └── previewImage = CapturedImage(image)
│                                                                └── .navigationDestination(item:) ──> PhotoPreviewView
├── [Pick from Library] ──> PhotosPicker
│                              └── loadTransferable
│                                  └── previewImage = CapturedImage(image)
│                                      └── PhotoPreviewView
├── [Diary]             ──> NavigationLink ──> DiaryView
│                                                ├── List<DiaryRowView>
│                                                └── selectedEntry ──> DiaryDetailView
└── [Map]               ──> NavigationLink ──> MapView

PhotoPreviewView
├── detect() ──┬── 0 detections ──> classify(whole image) ──> ResultsView
│              ├── 1 detection  ──> crop + classify ──> ResultsView
│              └── n detections ──> FishPickerView
│                                       └── classify(cropped) ──> ResultsView

ResultsView
├── [Save to Diary] ──> sheet(SaveDiarySheet)
│                          └── modelContext.insert(DiaryEntry)
└── [Scan Another / Pick Another Fish]
```

### 6.1 Das `CapturedImage`-Identity-Pattern (`HomeView.swift:182-189`)

```swift
private struct CapturedImage: Hashable {
    let id = UUID()
    let image: UIImage

    static func == (lhs: CapturedImage, rhs: CapturedImage) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
```

> „Each new photo gets a fresh `CapturedImage` with a unique id. `navigationDestination(item:)` sees a different item every time and creates a new `PhotoPreviewView` — preventing stale view reuse."

**Problem, das damit gelöst wird:** SwiftUI cached `NavigationDestination`-Views basierend auf Identität. Wenn man zweimal hintereinander dasselbe `UIImage` schickt (oder dieselbe URL), bekommt man die *alte* View mit dem alten Scan-Zustand zurück. Durch die `UUID()` pro Capture wird jede Navigation als neue Identität behandelt → frischer View-Zustand.

---

## 7. Persistenz – SwiftData

### 7.1 Datenmodell (`DiaryEntry.swift`)

```swift
@Model
class DiaryEntry {
    var date: Date
    var fishName: String
    var confidence: Double
    var location: String?
    var notes: String?
    var imagePath: String?              // Dateiname im Documents-Verzeichnis

    var image: UIImage? {                // Computed: lädt von Disk
        guard let path = imagePath,
              let documentsURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        return UIImage(contentsOfFile: documentsURL.appendingPathComponent(path).path)
    }
    ...
}
```

### 7.2 Architekturentscheidung: Bilder als Dateien, nicht in der DB

```swift
static func storeImage(_ image: UIImage) -> String? {
    guard let data = image.jpegData(compressionQuality: 0.8),
          let documentsURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first
    else { return nil }
    let filename = UUID().uuidString + ".jpg"
    let url = documentsURL.appendingPathComponent(filename)
    try? data.write(to: url)
    return filename
}
```

> „Storing a path rather than raw Data keeps the SwiftData store small and avoids loading full images into memory on every fetch."

**Warum diese Entscheidung wichtig ist:**

- SwiftData lädt `@Model`-Objekte beim Fetch (z. B. via `@Query`) komplett in den Speicher. Bei 50 Tagebucheinträgen à 2 MB JPEG wären das 100 MB RAM nur für die Liste.
- Stattdessen wird nur der Dateiname (~36 Bytes) gespeichert, und die `UIImage(contentsOfFile:)`-API streamt das Bild bedarfsweise.
- **Konsistenz-Kosten:** Beim Löschen eines Entries muss `deleteImage()` *vor* `modelContext.delete(entry)` aufgerufen werden, damit die Datei mit aufgeräumt wird. Das ist im UI-Code explizit so geordnet:

```swift
// DiaryView.delete(at:)
entry.deleteImage()
modelContext.delete(entry)
try? modelContext.save()
```

### 7.3 Reaktivität via `@Query`

```swift
// DiaryView
@Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]
```

`@Query` ist die SwiftData-Property-Wrapper-Variante, die automatisch Updates triggert, wenn der `ModelContext` sich ändert. Damit entfällt das manuelle Fetch + Reload-Pattern, das man in CoreData noch schreiben musste.

### 7.4 Save-Flow (`ResultsView.SaveDiarySheet.save()`)

```swift
private func save() {
    let imagePath = DiaryEntry.storeImage(result.image)
    let entry = DiaryEntry(
        fishName: result.fishName,
        confidence: result.confidence,
        imagePath: imagePath,
        location: location.isEmpty ? nil : location,
        notes: notes.isEmpty ? nil : notes
    )
    modelContext.insert(entry)
    try? modelContext.save()
}
```

Drei Schritte: Bild auf Disk, Entry erzeugen, Insert+Save. Die `@Query` in `DiaryView` triggert daraufhin automatisch einen Reload.

---

## 8. Kartenansicht (`MapView.swift`)

### 8.1 Freitext-Geocoding

Tagebucheinträge speichern Orte als *Freitext* („Great Barrier Reef", „Bali, Tulamben") – nicht als Koordinaten. Die Karte muss diese Strings in Koordinaten auflösen:

```swift
@Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]
@State private var resolved: [String: CLLocationCoordinate2D] = [:]    // In-Memory-Cache

private func resolveEntries() async {
    let unresolved = Set(entries.compactMap(\.location))
        .filter { resolved[$0] == nil }

    for location in unresolved {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = location

        do {
            let response = try await MKLocalSearch(request: request).start()
            if let coord = response.mapItems.first?.location.coordinate {
                resolved[location] = coord
            }
        } catch {
            // Free-text inputs won't always resolve; entries without a
            // match simply don't appear on the map.
        }
    }
}
```

### 8.2 API-Deprecations (iOS 26)

Zwei API-Wechsel waren nötig:

```swift
// CLGeocoder was deprecated in iOS 26 in favour of MapKit. MKLocalSearch
// accepts a natural-language query and returns map items with coordinates
// — exactly what we need for free-text locations like "Great Barrier Reef".
```

- **`CLGeocoder` → `MKLocalSearch`**: `CLGeocoder.geocodeAddressString()` ist in iOS 26 als deprecated markiert. Der Ersatz `MKLocalSearch` ist mächtiger (POI-Suche, nicht nur Adressen).
- **`MKMapItem.placemark` → `.location`**: ebenfalls deprecated; die neue Property liefert direkt ein `CLLocation`.

### 8.3 Entscheidung: kein persistenter Geocoding-Cache

> „Held in-memory only; resolved on each appear. Persisting would mean a schema migration, which isn't worth it for a small diary."

Das ist eine bewusste Engineering-Abwägung: Persistenter Cache hätte ein neues `@Model`-Objekt + Migration bedeutet. Bei einem privaten Tagebuch mit typischerweise <100 Einträgen ist das die Komplexität nicht wert – die Auflösung dauert beim Erscheinen der Karte ca. 1–2 Sekunden.

---

## 9. UI-Design

### 9.1 OceanTheme (`Theme.swift`)

Zentrale Palette und Gradienten:

```swift
enum OceanTheme {
    static let deepOcean = Color(hex: "03045E")
    static let oceanBlue = Color(hex: "0077B6")
    static let aqua      = Color(hex: "00B4D8")
    static let seafoam   = Color(hex: "90E0EF")
    static let foam      = Color(hex: "CAF0F8")
    static let coral     = Color(hex: "FF6B6B")
    static let seagrass  = Color(hex: "52B788")
    static let sandy     = Color(hex: "F4A261")

    static let backgroundGradient = LinearGradient(
        colors: [deepOcean, oceanBlue, aqua.opacity(0.9)],
        startPoint: .bottom, endPoint: .top
    )

    static func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 { return seagrass }
        if confidence >= 0.5 { return sandy }
        return coral
    }
}
```

Plus eine `Color(hex:)`-Extension, die Hex-Strings (3-, 6-, oder 8-stellig) in SwiftUI-`Color` umsetzt – damit muss niemand Design-Tokens als RGB tippen.

### 9.2 Animationen (`HomeView.swift`)

Die Home-Screen-Animation besteht aus drei Layern, alle pur SwiftUI-deklarativ:

| Layer | Element | Technik |
|---|---|---|
| **LightRays** | 3 diagonale Lichtstrahlen vom „Wasser-Oberflächen"-Effekt | `LinearGradient` mit `.plusLighter`-Blend-Mode + Opacity-Pulsing via `repeatForever` |
| **AnimatedBubbles** | 10 aufsteigende Blasen | `Circle` mit Position-Animation von `startY = canvas.height + 40` zu `endY = -40`, linear, `repeatForever` |
| **SwimmingFishes** | 10 SF-Symbol-Fische in tropischen Farben | `Image(systemName: "fish.fill")` mit horizontal Bewegung links/rechts, `scaleEffect(x: -1)` für Spiegelung |

**Bemerkenswertes Detail – „off-canvas snap":**

> „Bubbles drift upward continuously. Each one snaps back below the screen after exiting the top — the snap happens off-canvas so it's invisible."

Klassischer Trick: Die `endY` ist nicht 0, sondern -40. Wenn die Animation neu startet (snap zurück zu startY = canvas + 40), passiert das außerhalb des Bildschirms.

**Diver-Icon-Animation** (`HomeView.swift:38-50`):

```swift
Image("diver")
    .rotationEffect(.degrees(diverBob ? 3 : -3))
    .offset(y: diverBob ? -8 : 8)
    .animation(
        .easeInOut(duration: 3.5).repeatForever(autoreverses: true),
        value: diverBob
    )
    .onAppear { diverBob = true }
```

Das Taucher-Icon „schwebt" durch eine kombinierte Rotation-+Offset-Animation, die sich 3,5 s pro Halbzyklus wiederholt.

### 9.3 Dynamic Type & Accessibility

```swift
@ScaledMetric(relativeTo: .largeTitle) private var diverSize: CGFloat = 140
@ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 56
@ScaledMetric(relativeTo: .body)       private var subtitleSize: CGFloat = 19
```

`@ScaledMetric` skaliert die Größen mit der iOS-Schriftgrößen-Einstellung des Nutzers (Dynamic Type). Damit wird das Layout barrierefrei für Sehbehinderte.

**VoiceOver-Labels:**

```swift
.accessibilityLabel("Photo of \(result.fishName)")
.accessibilityValue(String(format: "%.2f percent", result.confidence * 100))
.accessibilityLabel("Fish \(index + 1) of \(detections.count)")
```

### 9.4 Haptisches Feedback

```swift
.sensoryFeedback(.selection, trigger: showCamera)
.sensoryFeedback(.impact(weight: .medium), trigger: viewModel.capturedImage)
.sensoryFeedback(.success, trigger: showSavedConfirmation)
```

Die `sensoryFeedback`-API (iOS 17+) ersetzt das manuelle `UIImpactFeedbackGenerator`-Geraffel und ist deklarativ in die View eingebunden.

### 9.5 Glassmorphism / Material Backgrounds

Die App benutzt durchgängig `.ultraThinMaterial`:

```swift
.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
```

Das gibt Buttons und Cards den charakteristischen iOS-„Frosted-Glass"-Look, ohne dass ein Custom-Blur-View nötig wäre.

---

## 10. Multi-Fish Picker (`FishPickerView.swift`)

Wenn der Detektor 2+ Fische findet, zeigt diese View das Foto mit Tap-baren Bounding-Box-Overlays. Der Nutzer wählt einen, und nur der wird klassifiziert.

### 10.1 Koordinaten-Mathematik (`FishPickerView.swift:48-97`)

Das Foto wird mit `scaledToFit()` skaliert, sodass es im Frame letterboxed sein kann (schwarze Balken oben/unten oder links/rechts). Die normalisierten Boxes müssen aber auf die *tatsächlich gerenderten* Pixel zeigen, nicht auf den ganzen Frame:

```swift
GeometryReader { proxy in
    let imageAspect = image.size.width / max(image.size.height, 1)
    let frameAspect = proxy.size.width / max(proxy.size.height, 1)
    let displayWidth: CGFloat = imageAspect > frameAspect
        ? proxy.size.width
        : proxy.size.height * imageAspect
    let displayHeight: CGFloat = imageAspect > frameAspect
        ? proxy.size.width / imageAspect
        : proxy.size.height
    let originX = (proxy.size.width - displayWidth) / 2
    let originY = (proxy.size.height - displayHeight) / 2

    ForEach(...) { index, fish in
        let rect = CGRect(
            x: originX + fish.boundingBox.minX * displayWidth,
            y: originY + fish.boundingBox.minY * displayHeight,
            width: fish.boundingBox.width * displayWidth,
            height: fish.boundingBox.height * displayHeight
        )
        ...
    }
}
```

Ohne diese Mathematik würden bei letterboxed-Fotos die Boxen verschoben sein – ein typischer Bug, der bei Quick-und-Dirty-Implementierungen passiert.

### 10.2 `.position` vs `.offset` Hit-Testing-Gotcha

```swift
.position(x: rect.midX, y: rect.midY)
// .position centers the view at the given point AND moves the hit-testing
// region with it; .offset() would move the visual but leave taps registering
// at (0,0).
```

Eine Falle, die nur durch Praxiserfahrung sichtbar wird: `.offset()` verschiebt nur die Pixel, nicht die Hit-Testing-Region. Wer also Buttons mit `.offset` verschiebt, klickt visuell daneben und der Tap kommt an der ursprünglichen Position an.

---

## 11. Probleme und ihre Lösungen

Dieser Abschnitt ist für die Bachelorarbeit besonders wertvoll – er zeigt die echten Engineering-Entscheidungen.

### 11.1 Modell liefert Logits, keine Probabilities

**Problem:** Vision's `VNClassificationObservation.confidence` enthält bei diesem Modell die *rohen Logits* des letzten Layers, nicht Werte ∈ [0, 1]. Die UI würde Confidence-Werte wie 7.83 oder -2.1 anzeigen.

**Lösung:** Manueller numerisch stabiler Softmax in `ClassifierViewModel.classify`:

```swift
let scores = observations.map { Double($0.confidence) }
let maxScore = scores.max() ?? 0
let exps = scores.map { exp($0 - maxScore) }
let confidence = (exps.first ?? 0) / exps.reduce(0, +)
```

Das Abziehen von `maxScore` verhindert Overflow bei `exp()`. Das ist der Standard-Trick aus der numerischen Mathematik („LogSumExp-Stabilisierung").

### 11.2 Detektor verfehlt formatfüllende Fische

**Problem:** YOLO-World ist auf Objekte mit Umgebung trainiert. Ein Foto, auf dem ein Fisch 90 % des Frames füllt, wird oft *nicht* detektiert.

**Lösung:** Wenn `detect()` 0 Boxen liefert, fällt der Code auf eine *Whole-Image-Klassifikation* zurück. Das `no_fish`-Sentinel-Label fängt dann den Fall ab, dass wirklich kein Fisch zu sehen ist.

### 11.3 Crop ohne Padding → niedrige Confidence

**Problem:** Wenn ich das Crop exakt auf die Detector-Box mache, kommt ein „isolierter" Fisch-Ausschnitt raus. Der Klassifikator wurde aber auf Fischfotos *mit Hintergrund* trainiert – die Confidence sinkt deutlich.

**Lösung:** 15 % Padding um die Box vor dem Crop (`ImageCrop.swift:13`). Empirisch ermittelt.

### 11.4 Bounding-Box-Koordinatensystem

**Problem:** Vision liefert Boxes im *bottom-left*-Koordinatensystem; SwiftUI/UIImage nutzen *top-left*. Wenn man das nicht konvertiert, sitzt der Marker am falschen Ende des Fisches.

**Lösung:** `DetectorViewModel.detect` rechnet sofort um:
```swift
let topLeft = CGRect(x: v.minX, y: 1 - v.maxY, width: v.width, height: v.height)
```

### 11.5 Foto-Orientierung wird ignoriert

**Problem:** iPhone-Fotos sind physisch im Sensor-Koordinatensystem gespeichert; die korrekte Rotation steht nur in der EXIF-Orientation. Vision interpretiert das Bild dann quergedreht.

**Lösung:** `CGImagePropertyOrientation(image.imageOrientation)` wird beim Erstellen des `VNImageRequestHandler` mitgegeben.

### 11.6 `AVCaptureSession`-Konfiguration blockiert UI

**Problem:** `session.beginConfiguration()`/`startRunning()` sind synchron und können auf älteren Geräten 200–500 ms dauern. Auf dem Main-Thread = sichtbarer UI-Stall.

**Lösung:** Alles in `Task.detached(priority: .userInitiated)` verschoben, mit `await MainActor.run { ... }` für UI-State-Updates.

### 11.7 Swift 6 Strict Concurrency Workaround

**Problem:** `Task.detached` darf nicht direkt eine `@MainActor`-`var` (z. B. `self.currentInput`) capturen.

**Lösung:** `weak let weakSelf = self` *vor* der Task hoist:

```swift
weak let weakSelf = self
Task.detached(priority: .userInitiated) {
    ...
    await MainActor.run { weakSelf?.currentInput = input }
}
```

### 11.8 SwiftUI cached `navigationDestination`-Views

**Problem:** Wenn man nach einem Scan zurück zur HomeView geht und ein zweites Bild auswählt, kann SwiftUI die *alte* `PhotoPreviewView` wiederverwenden – mit altem Scan-State.

**Lösung:** `CapturedImage`-Wrapper mit `UUID`-Identity, plus `navigationDestination(item:)`-Variante (statt isPresented). Jedes neue Bild erzeugt eine neue Identität → neue View.

### 11.9 `CameraPreviewLayer` hat 0×0 Bounds beim Setup

**Problem:** Beim Erstellen einer `UIViewRepresentable` ist `view.bounds == .zero`. Wenn der `AVCaptureVideoPreviewLayer.frame` dann gesetzt wird, bleibt er 0×0 – Vorschau unsichtbar.

**Lösung:** `CameraPreviewUIView.layoutSubviews()` überschreibt und setzt den Frame neu:

```swift
override func layoutSubviews() {
    super.layoutSubviews()
    previewLayer?.frame = bounds
}
```

### 11.10 `CLGeocoder` & `MKMapItem.placemark` deprecated in iOS 26

**Problem:** Die ursprüngliche Geocoding-Implementierung nutzte `CLGeocoder.geocodeAddressString()`. iOS 26 markiert das als deprecated.

**Lösung:** Migration auf `MKLocalSearch` mit `naturalLanguageQuery`. Bonus: `MKLocalSearch` versteht POI-Namen („Great Barrier Reef"), während `CLGeocoder` strikt Adressen erwartete.

```swift
let request = MKLocalSearch.Request()
request.naturalLanguageQuery = location
let response = try await MKLocalSearch(request: request).start()
if let coord = response.mapItems.first?.location.coordinate { ... }
```

### 11.11 SwiftData-Store-Bloat bei Bildspeicherung

**Problem:** Würde man Bilder als `Data` direkt im `@Model` speichern, wären Fetches sehr teuer (siehe 7.2).

**Lösung:** Bilder als JPEG-Dateien in `~/Documents/<UUID>.jpg`, nur der Dateiname in der DB.

### 11.12 Mock-Fallback für Modell-lose Builds

**Problem:** Während YOLO-World noch nicht exportiert war (Mai 2026), brauchte die Picker-UI trotzdem Test-Daten.

**Lösung:** `DetectorViewModel.usingMock` Fallback (`DetectorViewModel.swift:14`). Wenn das `.mlmodelc` im Bundle fehlt, werden drei hartkodierte Boxen geliefert. Erleichterte die parallele UI-Entwicklung.

### 11.13 Aktuelle, noch nicht committete Änderungen

Im `git status` (Stand 2026-05-28) liegen vier ungestagte Änderungen:

- `DeepScan/Models/FishResult.swift` – `description: String` wurde entfernt
- `DeepScan/ViewModels/ClassifierViewModel.swift` – ~90 Zeilen Copy-Resolving-Code wurden gelöscht (Mapping „acanthurus_coeruleus" → „Blue Tang" und die Fun-Facts-Strings)
- `DeepScan/Views/ResultsView.swift` – „Did you know?"-Card entfernt, Confidence-Anzeige von Integer-Prozent auf zwei Nachkommastellen umgestellt
- `DeepScan/ML/testmodel.mlmodel` – gelöscht (3-Zeilen-Stub, war ein Placeholder)

**Was diese Änderungen bedeuten:** Das Modell liefert jetzt direkt wissenschaftliche Namen (`acanthurus_coeruleus`), die durch eine simple `displayName()`-Funktion zu „Acanthurus coeruleus" formatiert werden. Die kuratierten Trivialnamen und Beschreibungen sind raus – vermutlich eine bewusste Entscheidung in Richtung „weniger redaktioneller Inhalt, mehr wissenschaftliche Korrektheit".

> **Trade-off:** Der README listet noch die englischen Trivialnamen („Blue Tang", „Clownfish"). Die README ist also aktuell nicht synchron mit der Code-Realität auf `main` (Stand uncommitted).

---

## 12. Tests

```swift
// DeepScanTests/DeepScanTests.swift
struct DeepScanTests {
    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
}

// DeepScanUITests/DeepScanUITests.swift
func testLaunchPerformance() throws {
    measure(metrics: [XCTApplicationLaunchMetric()]) {
        XCUIApplication().launch()
    }
}
```

**Ehrliche Einschätzung für die Arbeit:** Die Test-Suites sind aktuell nur Xcode-Templates. Es gibt keine substantiellen Unit-Tests oder UI-Tests. Das ist ein **bekannter Schwachpunkt** – aufrichtig erwähnen, gegebenenfalls als „Future Work" einplanen:

- Klassifikator-Tests mit Referenzbildern + erwarteten Confidence-Schwellen
- Detector-Tests mit Bildern mit bekannter Anzahl Fische
- UI-Tests für den Picker-Flow (0/1/n Fische)
- SwiftData-Tests für Save/Delete inkl. File-Cleanup

---

## 13. Entwicklung & Workflow

### 13.1 Team

- `bey` / `beybasa` – Hauptentwickler iOS (vermutlich Erst-Autor dieser Arbeit)
- `Jason Nguyen` – Co-Autor (README, Diver-Icon, v1.0-Tag)
- `github-actions[bot]` – automatischer Modell-Sync aus `deepscan-model`-Repo

### 13.2 Git-Historie (Zeitlinie)

| Commit | Datum | Inhalt |
|---|---|---|
| `3847edf` | 2026-03-08 | Initial Commit – Xcode-Template |
| `2be2b5d` | 2026-03-15 | Initial project setup – Ordnerstruktur, leere Views |
| `b37d847` | 2026-03-30 | Camera and gallery functionality |
| `372306b` | 2026-04-26 | v1.0 – Klassifikator-Pipeline + Diary + DiaryDetail |
| `485c2b4` | 2026-05-14 | YOLO für Object Detection + Picker + ImageCrop |
| `de284bc` | 2026-05-17 | README.md + Diver-Asset |
| `78e4fc9` | 2026-05-17 | Neuer Diver-Icon |
| `d034bee` | 2026-05-17 | Design-Extensions, NavigationLink-Fix |
| `8c84610` | 2026-05-17 | Fish-Design für HomeView |
| `60462f2` | 2026-05-17 | Selfie-Cam-Switch + Diary-Map + redesignter Hintergrund |
| `0bb4a28` | 2026-05-17 | Modell-Sync (CI) |
| `3992879` | 2026-05-19 | Modell-Sync (CI) |
| `752ef23..5891c95` | 2026-05-20 | Modell-Sync-Iterationen (CI) |

**Beobachtung:** Die Implementierung zerfällt in drei Phasen:
1. **März 2026** – Grundgerüst & Kamera
2. **April 2026** – v1.0 mit nur Klassifikator
3. **Mai 2026** – Detektor + Picker + Map + Polish

### 13.3 Modell-Sync-Pipeline

Die Commits `Sync model from deepscan-model` werden von einer GitHub Action im *separaten* `deepscan-model`-Repo getriggert. Das bedeutet:

- ML-Training findet außerhalb dieses Repos statt (vermutlich Python/PyTorch + CoreMLTools-Export)
- Wenn ein neues Modell exportiert wird, pusht die Action das `.mlpackage` automatisch in dieses Repo
- Die App muss dann nur neu gebaut werden – kein App-Update nötig im Code, weil die VMs das Modell bei jedem Start neu laden

Das ist eine saubere Trennung von Verantwortlichkeiten: ML-Team arbeitet im Modell-Repo, iOS-Team arbeitet im App-Repo, der Sync ist automatisiert.

### 13.4 Deployment

- **iOS-Version:** 26.2 (sehr neu – beschränkt User-Base, ermöglicht aber moderne APIs ohne Compat-Code)
- **Signing:** Apple Developer Team `355FYVXC7F`, automatisches Signing
- **Distribution:** Aktuell Dev-Only (kein App-Store-Build). Free Apple ID reicht für persönliches Testen, $99/Jahr Developer-Programm für TestFlight/Store.
- **Geräte:** iPhone mit iOS 26.2; Kamera braucht echtes Gerät (Simulator hat keine).

---

## 14. Bekannte Limitierungen / Future Work

Dinge, die in der Bachelorarbeit als „Limitation" oder „Future Work" einbaubar sind:

1. **Nur 11 Spezies** – sehr begrenzte taxonomische Abdeckung. Eine Erweiterung bräuchte Trainingsdaten + Re-Export.
2. **Keine GPS-Standorterfassung** – Tagebuch nimmt nur Freitext-Ort. Echtes GPS aus EXIF oder `CLLocationManager` wäre eine sinnvolle Ergänzung.
3. **Keine echten Tests** (siehe Abschnitt 12).
4. **Geocoding-Cache nicht persistent** (siehe 8.3).
5. **Keine Internationalisierung** – alle UI-Strings sind hartcodiert auf Englisch.
6. **Kein Light-Mode** – Theme ist auf dunkles Ozean-Aussehen festgelegt.
7. **Keine Batch-Verarbeitung** – nur ein Foto zur Zeit; ein „Burst-Scan" für Reisealben wäre nutzerfreundlich.
8. **Detector-Latenz** auf älteren A12-/A13-Geräten möglicherweise spürbar (1–2 s), keine messbare Telemetrie vorhanden.
9. **Keine Offline-Tagebuch-Synchronisierung** zwischen Geräten – iCloud-SwiftData wäre eine sinnvolle Erweiterung (in iOS 18+ verfügbar).
10. **Modell-Versions-Tracking** – die App weiß nicht, welche Modellversion sie nutzt; keine Telemetrie für Confusion-Analyse möglich.
11. **Picker-Limit von 8 Boxen** ist hartkodiert; mehr Fische werden stillschweigend weggeworfen.
12. **README und Code aktuell nicht synchron** (siehe 11.13) – das ist nur ein WIP-Zustand, aber dokumentationswürdig.

---

## 15. Zusammenfassung für die Arbeit

DeepScan ist ein **klar architekturiertes, on-device-only iOS-Projekt**, das Apples moderne Frameworks (SwiftUI, SwiftData, Vision/CoreML, neue Observation-API, neue MapKit-APIs) konsequent nutzt und die **klassische zweistufige Computer-Vision-Pipeline** (Detection → Classification) sauber in eine native MVVM-Architektur einbettet. Die Implementierung enthält mehrere **nicht-triviale Engineering-Entscheidungen** – numerisch stabiler Softmax, Off-Main-Inferenz, Y-Achsen-Konvertierung, Padding-basiertes Crop, Identity-basierte Navigation, File-basierte Bildspeicherung, Strict-Concurrency-Workarounds – die jede für sich ein dokumentierbares Lessons-Learned-Beispiel sind.

Die App ist mit **knapp 1500 Zeilen Swift** und ohne externe Abhängigkeiten bewusst klein gehalten; Komplexität liegt in der ML-Pipeline und in der UI-Animationsschicht. Schwächen sind die **fehlende Test-Coverage** und der hohe **iOS-26.2-Mindestversion** (Compatibility-Trade-off zugunsten neuer APIs).

Die Codebasis ist im aktuellen Stand (Mai 2026) **funktional vollständig** für den dokumentierten Funktionsumfang. Die zuletzt ungestagten Änderungen verschieben den UI-Inhalt in Richtung „weniger kurierte Texte, mehr direkte Modellausgaben" – ein Design-Drift, der noch nicht in der README reflektiert ist.

---

## Anhang A – Datei-Inventar

```
DeepScan/App/
  DeepScanApp.swift                                                          19 LOC
DeepScan/Views/
  HomeView.swift                                                            ~418 LOC  (inkl. 3 Animations-Subviews)
  CameraView.swift                                                          ~121 LOC
  PhotoPreviewView.swift                                                    ~180 LOC
  FishPickerView.swift                                                      ~228 LOC
  ResultsView.swift                                                         ~239 LOC  (vor uncommitted edits)
  DiaryView.swift                                                           ~201 LOC
  DiaryDetailView.swift                                                     ~161 LOC
  MapView.swift                                                             ~111 LOC
  Theme.swift                                                                ~60 LOC
DeepScan/ViewModels/
  ClassifierViewModel.swift                                                 ~120 LOC  (mit uncommitted: -90)
  DetectorViewModel.swift                                                   ~115 LOC
  CameraViewModel.swift                                                     ~139 LOC
DeepScan/Models/
  DiaryEntry.swift                                                           ~72 LOC
  FishResult.swift                                                           ~15 LOC
  DetectedFish.swift                                                         ~13 LOC
  ImageCrop.swift                                                            ~51 LOC
  CGImagePropertyOrientation+UIImage.swift                                   ~21 LOC
DeepScan/ML/
  DeepScanClassifier.mlpackage/  (~8 MB Weights, generiert von deepscan-model-Repo)
  FishDetector.mlpackage/        (~56 MB Weights, YOLO-World)
DeepScan/Resources/Assets.xcassets/
  AppIcon, AccentColor, diver, ponyo
DeepScanTests/DeepScanTests.swift                                            ~17 LOC  (Template, leer)
DeepScanUITests/DeepScanUITests.swift                                        ~41 LOC  (Template)
DeepScanUITests/DeepScanUITestsLaunchTests.swift                             ~33 LOC  (Template)
```

## Anhang B – Schlüssel-APIs nach Apple-Framework

| Framework | Genutzte APIs |
|---|---|
| **SwiftUI** | `View`, `NavigationStack`, `navigationDestination(item:)`, `@State`, `@Environment`, `@Query`, `@Observable`, `@ScaledMetric`, `PhotosPicker`, `sensoryFeedback`, `GeometryReader`, `Material`, `LinearGradient`, `safeAreaInset`, `confirmationDialog`, `contentTransition`, `symbolEffect` |
| **SwiftData** | `@Model`, `@Query`, `ModelContext`, `.modelContainer(for:)` |
| **Vision** | `VNCoreMLModel`, `VNCoreMLRequest`, `VNImageRequestHandler`, `VNClassificationObservation`, `VNRecognizedObjectObservation`, `imageCropAndScaleOption` |
| **CoreML** | `MLModel`, `MLModelConfiguration`, `.computeUnits = .all` |
| **AVFoundation** | `AVCaptureSession`, `AVCaptureDevice`, `AVCaptureDeviceInput`, `AVCapturePhotoOutput`, `AVCapturePhotoCaptureDelegate`, `AVCaptureVideoPreviewLayer` |
| **PhotosUI** | `PhotosPicker`, `PhotosPickerItem`, `loadTransferable(type:)` |
| **MapKit** | `Map`, `Marker`, `MKLocalSearch`, `MKLocalSearch.Request`, `mapStyle(.standard(elevation:))` |
| **UIKit (bridged)** | `UIImage`, `UIImage.Orientation`, `UIGraphicsImageRenderer`, `CGImagePropertyOrientation`, `CGRect`, `FileManager` |
| **Foundation** | `Task.detached`, `MainActor.run`, `Date`, `UUID`, `JSONDecoder` (intern in SwiftData) |

---

## Anhang C – Inferenz-Performance-Messung (Kapitel 6.3.1 / 6.3.2)

Für die Messwerte in Kapitel 6.3.1 (Inferenzzeit) und 6.3.2 (Ressourcen) ist eine dedizierte Mess-Instrumentierung in den Code eingebaut. Sie misst pro Inferenzaufruf drei Phasen separat und protokolliert sie als CSV in die Xcode-Konsole *und* in eine Datei.

### C.1 Was wird gemessen?

Pro Iteration werden 11 Werte aufgezeichnet (Spaltenüberschriften der CSV):

| Spalte | Phase | Beschreibung |
|---|---|---|
| `iter` | — | Iterationsnummer (1…N) |
| `detect_pre_ms` | Detektor – Preprocess | `cgImage`-Extraktion, `VNCoreMLRequest`- und `VNImageRequestHandler`-Aufbau |
| `detect_inf_ms` | Detektor – Inferenz | `handler.perform([request])` (inkl. Vision-interner Resize/Normalize + Neural-Engine-Forward) |
| `detect_post_ms` | Detektor – Postprocess | Confidence-Filter, Y-Achsen-Spiegelung, Sortierung, Cap auf 8 Boxen |
| `detect_total_ms` | Detektor – Summe | `pre + inf + post` |
| `crop_ms` | Pipeline-Crop | `ImageCrop.crop(...)` mit 15 % Padding |
| `classify_pre_ms` | Klassifikator – Preprocess | analog Detektor-Pre |
| `classify_inf_ms` | Klassifikator – Inferenz | `handler.perform([request])` |
| `classify_post_ms` | Klassifikator – Postprocess | numerisch stabiler Softmax + `FishResult`-Konstruktion |
| `classify_total_ms` | Klassifikator – Summe | `pre + inf + post` |
| `end_to_end_ms` | End-to-End | Vom Pipeline-Start bis Klassifikator-Result |
| `resident_mb` | Speicher | `task_vm_info.phys_footprint` in MB (entspricht Xcode Memory Gauge) |

> **Mapping auf die in der Arbeit geforderten drei Werte:**
> - **„Bildvorverarbeitung in ms"** = `detect_pre_ms + crop_ms + classify_pre_ms` (Code-Vorverarbeitung; Vision macht zusätzlich interne Resizes, die nicht trennbar sind und Teil der Inferenzzeit bleiben)
> - **„Modell-Inferenz in ms"** = `detect_inf_ms + classify_inf_ms` (reine `handler.perform`-Zeit beider Modelle)
> - **„Gesamtzeit in ms"** = `end_to_end_ms`

### C.2 Implementierungsdateien

| Datei | Rolle |
|---|---|
| `DeepScan/Models/Benchmark.swift` | Zeitstempel-Helper (`now()`, `msSince()`), Speicher-Messung (`residentMemoryMB()`), Stats-Berechnung (`mean`, `median`, `p95`, `σ`) |
| `DeepScan/ViewModels/ClassifierViewModel.swift` | Instrumentiert in `classify(image:)`, schreibt Werte nach jedem Aufruf in `lastTiming` und gibt Log-Zeile aus (`⏱ [classifier] …`) |
| `DeepScan/ViewModels/DetectorViewModel.swift` | Instrumentiert in `detect(image:)`, analog |
| `DeepScan/Views/PhotoPreviewView.swift` | Benchmark-Button + Runner (`runBenchmark()`); ruft 30 Iterationen + 2 Warmups, schreibt CSV |

### C.3 Mess-Prozedur auf dem Testgerät (iPhone 15 Pro, iOS 26.5)

#### Vorbereitung

1. **Xcode-Verbindung herstellen** – Lightning/USB-C-Kabel zum Mac, in Xcode Destination auf das iPhone setzen.
2. **Release-Build verwenden** – im Schema-Editor (`Product → Scheme → Edit Scheme → Run → Info`) Build-Konfiguration auf **Release** umstellen. Debug-Builds enthalten Swift-Runtime-Checks und sind nicht repräsentativ.
3. **Andere Apps schließen, Standby-Modus deaktivieren** – Hintergrundlast vermeiden.
4. **Niedrigstromodus aus** (`Einstellungen → Batterie → Stromsparmodus = aus`) – sonst drosselt iOS CPU/GPU.
5. **Thermal State prüfen** – Gerät 5 Minuten vor dem Test ruhen lassen, damit es kalt startet (Thermal-Throttling beim ersten Run vermeiden).

#### Durchführung

1. App auf dem iPhone starten.
2. Foto aus der Galerie oder Kamera wählen → `PhotoPreviewView` öffnet sich.
3. **„Benchmark (30×)"-Button** unten in der Control-Panel-Sektion tippen.
4. Die App führt aus:
   - 2 Warmup-Iterationen (verworfen – wichtig wegen Neural-Engine-Modell-Compilation und Cache-Warmup beim ersten Inference-Call)
   - 30 gemessene Iterationen
   - Berechnung & Ausgabe von Mean/Median/P95/Min/Max/σ
   - CSV-Speicherung unter `<App>/Documents/deepscan_benchmark_<timestamp>.csv`
5. Der Fortschritt wird im Button-Label live aktualisiert (`Benchmark 17/30…`).

#### Konsolen-Output abgreifen

In Xcode → **Console** unten:
- Filter auf `[BM_CSV]` setzen → exakt die 31 CSV-Zeilen (Header + 30 Daten)
- Markieren, kopieren, in z. B. `benchmark_run_01.csv` einfügen.
- Summary-Block (`SUMMARY`) für Tabelle in der Arbeit übernehmen.

Beispiel-Output (gekürzt):

```
════════ BENCHMARK START ════════
device: iPhone (target iOS 26.2+) · iterations=30 · warmup=2
image size: 4032×3024px
baseline memory: 78.4 MB
warmup 1/2 done
warmup 2/2 done
[BM_CSV] iter,detect_pre_ms,detect_inf_ms,detect_post_ms,detect_total_ms,crop_ms,…
[BM_CSV] 1,1.234,187.421,0.892,189.547,2.103,0.876,142.331,0.642,143.849,335.532,94.2
[BM_CSV] 2,0.998,156.892,0.711,158.601,1.987,0.834,121.453,0.598,122.885,283.503,95.1
…
[BM_CSV] 30,0.945,153.221,0.689,154.855,1.876,0.792,118.667,0.611,120.070,276.812,96.4
──────── SUMMARY (n=30, warmups discarded) ────────
detect.inference   mean=158.45ms median=156.21ms p95=187.42ms min=148.33ms max=192.11ms σ=12.04ms
classify.inference mean=124.18ms median=122.45ms p95=142.33ms min=115.21ms max=148.67ms σ=8.91ms
end-to-end         mean=285.31ms median=281.40ms p95=335.53ms min=271.18ms max=342.88ms σ=18.22ms
resident memory    mean=95.4 MB · max=98.1 MB · min=93.2 MB
📝 CSV saved: /var/mobile/Containers/Data/Application/<UUID>/Documents/deepscan_benchmark_2026-05-28_14-32-11.csv
════════ BENCHMARK END ════════
```

> ⚠️ Die obigen Zahlen sind *illustrativ* — sie zeigen das erwartete Format, nicht die tatsächlich gemessenen Werte. Echte Werte musst du auf dem iPhone 15 Pro selbst erfassen.

#### CSV-Datei vom Gerät pullen

Drei Wege, je nach Komfort:

1. **Xcode → Window → Devices and Simulators → [iPhone] → [DeepScan-App auswählen] → ⚙️ → Download Container…**
   Daraus den Documents-Ordner mit der CSV ziehen.
2. **Im laufenden Benchmark-Lauf:** der Dateiname wird unter dem Button angezeigt (Text ist via `textSelection(.enabled)` kopierbar).
3. **Filter in Xcode-Console** nach `[BM_CSV]` und manuell in eine CSV-Datei einfügen — am schnellsten für einen einzelnen Lauf.

### C.4 Mehrere Durchgänge / statistische Robustheit

Für 6.3.1 empfohlene Prozedur:

- **Pro Bild 3 Durchgänge à 30 Iterationen** machen → insgesamt 90 Messwerte pro Bild.
- **Verschiedene Bilder testen** (mind. 3): klein/groß/mehrere Fische → das deckt unterschiedliche Detector-Output-Größen ab.
- Mittelwert/Median *über die kombinierten 90 Messwerte* in der Tabelle, plus separat den Best-/Worst-Case-Run.
- **Cold-Start vs. Warm-Run:** zwischen Durchgängen App komplett killen (Doppelklick Home → Wischen) → erster Run misst Cold-Start (Modell-Compilation), folgende messen Warm-Path. Beide Zustände sind für die Arbeit interessant.

Da Warmups bereits intern verworfen werden, ist jeder Durchgang ein „Warm-Path"-Run. Für Cold-Start: vor dem allerersten Tap auf den Benchmark-Button bei frisch gestarteter App **manuell einmal `Scan Fish`** drücken → die Konsolen-Log-Zeile `⏱ [classifier] …` gibt direkt die Cold-Path-Zeit aus.

### C.5 Speicherprofilierung (Kapitel 6.3.2)

Die CSV liefert pro Iteration `resident_mb` — das ist `phys_footprint` (gleiche Metrik wie Xcode-Memory-Gauge). Für die Arbeit folgende Werte sinnvoll:

| Messpunkt | Wie ermitteln |
|---|---|
| **Baseline (App-Start, keine Inferenz)** | Beim App-Start in der Konsole nach `baseline memory` suchen (wird zu Beginn jedes Benchmarks geloggt), oder Xcode-Memory-Gauge ablesen bevor `Scan` getippt wird |
| **Peak während Inferenz** | `resident_mb`-Spalten-Maximum in der CSV; oder Xcode-Gauge live beobachten während Benchmark-Lauf |
| **Bei 30 sukzessiven Inferenzen** (Leak-Test) | CSV: Verlauf der `resident_mb`-Spalte. Steigt monoton ≈ Leak; pendelt um konstantes Niveau ≈ kein Leak |

#### Tiefere Profilierung mit Xcode Instruments

Für Kapitel 6.3.2 lässt sich mit Instruments mehr extrahieren:

| Instrument | Was es zeigt | Wie starten |
|---|---|---|
| **Allocations** | Heap-Allokationen pro Zeitpunkt, Leak-Verdacht | Xcode → Product → Profile → Allocations → Aufnahme während des Benchmarks |
| **Leaks** | echte Memory Leaks (zyklische Referenzen, ungelöste Strong-Refs) | gleiches Menü → Leaks-Template |
| **Time Profiler** | CPU-Zeit pro Funktion, identifiziert Hotspots auch außerhalb von `handler.perform` | Profile → Time Profiler. Anschließend `Sample → Call Tree → Invert Call Tree` + `Hide System Libraries` |
| **Core ML** (iOS 17+) | reine Inferenz-Latenz pro Layer, Compute-Unit-Verteilung (CPU vs GPU vs ANE) | Profile → Core ML. Zeigt auch, ob das Modell überhaupt auf der Neural Engine landet (großer Faktor für iPhone 15 Pro vs. ältere Geräte) |
| **Energy Log** | mAh-Verbrauch pro Aktion | Profile → Energy Log – relevant, wenn die Arbeit Energie thematisiert |

**Empfohlener Instruments-Workflow für die Arbeit:**

1. Xcode → ⌘ I (Profile) → **Core ML**-Template wählen → Aufzeichnung starten.
2. Auf dem iPhone den Benchmark-Button tippen.
3. Aufzeichnung stoppen nach Abschluss.
4. In der Core-ML-Lane sieht man pro `handler.perform` einen Block; aufklappen zeigt:
   - Welche Compute Unit (`ANE`, `GPU`, `CPU`)
   - Pro Layer Dauer
   - Aggregierte Modell-Lade- und Compilation-Zeiten
5. Screenshots/CSV-Export der Lane in die Arbeit übernehmen.

### C.6 Wo die Werte herkommen – exakte Code-Stellen

| Messung | Datei : Funktion | Code-Stelle |
|---|---|---|
| Klassifikator-Preprocess | `ClassifierViewModel.swift : classify(image:)` | Block ab `// --- Preprocess: ---` |
| Klassifikator-Inferenz | `ClassifierViewModel.swift : classify(image:)` | Block ab `// --- Inference: ---` (`Task.detached { try handler.perform([request]) }`) |
| Klassifikator-Postprocess | `ClassifierViewModel.swift : classify(image:)` | Block ab `// --- Postprocess: ---` (Softmax + FishResult) |
| Detektor-Phasen | `DetectorViewModel.swift : detect(image:)` | identisches Pattern, drei `// --- ... ---`-Blöcke |
| `crop_ms` | `PhotoPreviewView.swift : runBenchmark()` | `let cropStart = Benchmark.now(); … = ImageCrop.crop(...)` |
| `end_to_end_ms` | `PhotoPreviewView.swift : runBenchmark()` | `let e2eStart = Benchmark.now(); …; Benchmark.msSince(e2eStart)` |
| `resident_mb` | `Benchmark.swift : residentMemoryMB()` | `task_info(mach_task_self_, TASK_VM_INFO, ...)` → `phys_footprint / 1_048_576` |
| Summary-Stats | `Benchmark.swift : stats(_:)` | Mean/Median/P95/StdDev über alle 30 Werte |

### C.7 Was die Arbeit darüber sagen sollte

Punkte, die in 6.3.1 / 6.3.2 explizit erwähnt werden sollten:

1. **Compute Units:** Beide Modelle laden mit `MLModelConfiguration.computeUnits = .all`. Core-ML wählt automatisch die schnellste Hardware-Option. Auf iPhone 15 Pro ist das in der Regel die Neural Engine (16-Core ANE, A17 Pro), bei nicht-ANE-kompatiblen Operationen Fallback auf GPU.
2. **Warmups:** Die ersten 1–2 Inferenzen sind systematisch langsamer wegen ANE-Modell-Compilation (one-time-Kosten). Werden deshalb verworfen.
3. **Vision-interne Preprocessing-Schritte** (Resize auf Input-Größe, Normalisierung) sind *Teil von `handler.perform`* und nicht separat messbar – sie tauchen in `inference_ms` auf, nicht in `preprocess_ms`.
4. **Padding-Crop ist messbar getrennt** (`crop_ms`) und gibt typischerweise <5 ms — vernachlässigbar gegenüber der Inferenz.
5. **Modellgrößen** (gegeben): `DeepScanClassifier.mlpackage` 8.2 MB, `FishDetector.mlpackage` 56.3 MB. Auf Disk → werden beim App-Start geladen → erhöhen die Baseline-Speicher-Footprint um ca. 60–70 MB.
6. **Energy-Effizienz Neural Engine:** ANE-Inferenz braucht ~10× weniger Energie als die gleiche Berechnung auf CPU (siehe Apple WWDC 2023). Für mobile ML ist das der Grund, warum Core ML überhaupt sinnvoll ist.

---

*Ende der technischen Dokumentation.*

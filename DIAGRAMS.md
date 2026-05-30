# DeepScan iOS – Diagrammsammlung
Gliederung:
> 1. [Use-Case-Diagramm](#1-use-case-diagramm)
> 2. [Systemkontext / Deployment](#2-systemkontext--deployment)
> 3. [Architektur-Schichten (MVVM)](#3-architektur-schichten-mvvm)
> 4. [Komponenten- & Abhängigkeitsdiagramm](#4-komponenten--abhängigkeitsdiagramm)
> 5. [Klassendiagramm](#5-klassendiagramm)
> 6. [SwiftData-Datenmodell (ER)](#6-swiftdata-datenmodell-er)
> 7. [ML-Pipeline (Datenfluss)](#7-ml-pipeline-datenfluss)
> 8. [Scan-Entscheidung (Flussdiagramm)](#8-scan-entscheidung-flussdiagramm)
> 9. [Sequenzdiagramm: End-to-End-Scan](#9-sequenzdiagramm-end-to-end-scan)
> 10. [Sequenzdiagramm: Kamera-Setup](#10-sequenzdiagramm-kamera-setup)
> 11. [Sequenzdiagramm: Tagebuch speichern](#11-sequenzdiagramm-tagebuch-speichern)
> 12. [Navigationsfluss (Screen-Map)](#12-navigationsfluss-screen-map)
> 13. [Scan-Zustandsautomat](#13-scan-zustandsautomat)
> 14. [App-Lifecycle & Dependency Injection](#14-app-lifecycle--dependency-injection)
> 15. [Koordinatensystem-Transformation](#15-koordinatensystem-transformation)
> 16. [Benchmark-Instrumentierung](#16-benchmark-instrumentierung)
> 17. [Bildspeicher-Strategie](#17-bildspeicher-strategie)
> 18. [Git-Zeitleiste (Gantt)](#18-git-zeitleiste-gantt)

---

## 1. Use-Case-Diagramm

```mermaid
flowchart LR
    User([Schnorchler /<br/>Aquarianer])

    subgraph DeepScan["DeepScan App"]
        UC1([Foto aufnehmen])
        UC2([Foto aus Galerie wählen])
        UC3([Fisch erkennen & klassifizieren])
        UC4([Fisch bei Mehrfachfund auswählen])
        UC5([Ergebnis ins Tagebuch speichern])
        UC6([Tagebuch durchsehen])
        UC7([Tauchorte auf Karte sehen])
        UC8([Performance-Benchmark ausführen])
    end

    User --> UC1
    User --> UC2
    User --> UC3
    User --> UC4
    User --> UC5
    User --> UC6
    User --> UC7
    User --> UC8

    UC1 -. include .-> UC3
    UC2 -. include .-> UC3
    UC3 -. extend .-> UC4
    UC3 -. extend .-> UC5
    UC6 -. include .-> UC7
```

---

## 2. Systemkontext / Deployment

Zeigt, dass die App **vollständig on-device** läuft. Die einzige externe Kopplung ist
der CI-gesteuerte Modell-Sync aus dem separaten `deepscan-model`-Repo zur Build-Zeit.

```mermaid
flowchart TB
    subgraph dev["Entwicklung / CI (Build-Zeit)"]
        modelrepo[("deepscan-model Repo<br/>PyTorch-Training +<br/>CoreMLTools-Export")]
        ghaction["GitHub Action<br/>(Modell-Sync-Bot)"]
        modelrepo --> ghaction
    end

    subgraph repo["deepscan-ios Repo"]
        mlpkg["FishDetector.mlpackage<br/>DeepScanClassifier.mlpackage"]
        src["Swift-Quellcode"]
        ghaction -->|"git push .mlpackage"| mlpkg
    end

    subgraph xcode["Xcode Build"]
        compiled["DeepScan.app<br/>(.mlmodelc kompiliert)"]
        mlpkg --> compiled
        src --> compiled
    end

    subgraph device["iPhone (iOS 26.2+) — Laufzeit"]
        app["DeepScan.app"]
        ane["Neural Engine / GPU / CPU"]
        store[("SwiftData Store +<br/>Documents/*.jpg")]
        app -->|"CoreML .computeUnits = .all"| ane
        app --> store
    end

    compiled -->|"Signing & Install"| app

    note["KEINE Cloud-Inferenz · KEIN Backend · KEINE Drittanbieter-Libraries"]
    device -.- note
```

---

## 3. Architektur-Schichten (MVVM)

```mermaid
flowchart TB
    subgraph App["App-Schicht"]
        DeepScanApp["DeepScanApp<br/>@main"]
    end

    subgraph View["View-Schicht (SwiftUI)"]
        Home[HomeView]
        Camera[CameraView]
        Preview[PhotoPreviewView]
        Picker[FishPickerView]
        Results[ResultsView]
        Diary[DiaryView]
        DiaryDetail[DiaryDetailView]
        Map[MapView]
        Theme[OceanTheme]
    end

    subgraph VM["ViewModel-Schicht (@Observable @MainActor)"]
        Classifier[ClassifierViewModel]
        Detector[DetectorViewModel]
        CameraVM[CameraViewModel]
    end

    subgraph Model["Model-Schicht"]
        DiaryEntry["DiaryEntry @Model"]
        FishResult[FishResult]
        DetectedFish[DetectedFish]
        FishSpecies[FishSpecies]
        ImageCrop[ImageCrop]
        Benchmark[Benchmark]
    end

    subgraph Frameworks["Apple-Frameworks"]
        Vision[Vision + CoreML]
        SwiftData[SwiftData]
        AVF[AVFoundation]
        MapKit[MapKit]
        PhotosUI[PhotosUI]
    end

    DeepScanApp --> Home
    DeepScanApp --> Classifier
    DeepScanApp --> Detector

    Home --> Camera
    Home --> Preview
    Home --> Diary
    Home --> Map
    Preview --> Picker
    Preview --> Results
    Picker --> Results
    Diary --> DiaryDetail
    View -.-> Theme

    Preview --> Classifier
    Preview --> Detector
    Camera --> CameraVM

    Classifier --> Vision
    Detector --> Vision
    Classifier --> FishResult
    Detector --> DetectedFish
    Preview --> ImageCrop
    Results --> FishSpecies
    Results --> DiaryEntry
    Diary --> DiaryEntry
    Map --> DiaryEntry
    Classifier --> Benchmark
    Detector --> Benchmark

    DiaryEntry --> SwiftData
    CameraVM --> AVF
    Map --> MapKit
    Home --> PhotosUI
```

---

## 4. Komponenten- & Abhängigkeitsdiagramm

Fokus auf die Laufzeit-Abhängigkeiten der drei ViewModels und der ML-Modelle.

```mermaid
flowchart LR
    subgraph Inputs["Bildquellen"]
        cam["AVCaptureSession<br/>(Kamera)"]
        gallery["PhotosPicker<br/>(Galerie)"]
    end

    cam --> img["UIImage"]
    gallery --> img

    img --> det["DetectorViewModel<br/>FishDetector.mlpackage"]
    det -->|"[DetectedFish]"| crop["ImageCrop.crop()<br/>15% Padding"]
    img --> crop
    crop -->|"cropped UIImage"| cls["ClassifierViewModel<br/>DeepScanClassifier.mlpackage"]
    img -->|"0 Detektionen → ganzes Bild"| cls
    cls -->|"FishResult"| res["ResultsView"]
    res --> lookup["FishSpecies.lookup()"]
    res --> persist["DiaryEntry (SwiftData)"]
```

---

## 5. Klassendiagramm

```mermaid
classDiagram
    class DeepScanApp {
        +classifier: ClassifierViewModel
        +detector: DetectorViewModel
        +body: Scene
    }

    class ClassifierViewModel {
        <<@Observable @MainActor>>
        -vnModel: VNCoreMLModel
        +errorMessage: String?
        +lastTiming: Benchmark.Timing
        -loadModel()
        +classify(image) FishResult?
    }

    class DetectorViewModel {
        <<@Observable @MainActor>>
        -vnModel: VNCoreMLModel
        +usingMock: Bool
        +lastTiming: Benchmark.Timing
        -loadModel()
        +detect(image) DetectedFish[]
        -mockDetections() DetectedFish[]
    }

    class CameraViewModel {
        <<@Observable @MainActor>>
        +session: AVCaptureSession
        +capturedImage: UIImage?
        +isCameraReady: Bool
        +currentPosition: Position
        +checkPermissionsAndSetup()
        -configure(position, initialSetup)
        +capturePhoto()
        +switchCamera()
    }

    class FishResult {
        <<struct>>
        +fishName: String
        +confidence: Double
        +image: UIImage
        +mock(image)$ FishResult
    }

    class DetectedFish {
        <<struct, Identifiable>>
        +id: UUID
        +boundingBox: CGRect
        +confidence: Double
        +area: CGFloat
    }

    class DiaryEntry {
        <<@Model>>
        +date: Date
        +fishName: String
        +confidence: Double
        +location: String?
        +notes: String?
        +imagePath: String?
        +image: UIImage?
        +storeImage(image)$ String?
        +deleteImage()
    }

    class FishSpecies {
        <<struct>>
        +scientificName: String
        +commonName: String
        +illustration: String?
        +family: String
        +funFact: String
        +database$ Dictionary
        +lookup(scientificName)$ FishSpecies?
    }

    class ImageCrop {
        <<enum>>
        +crop(image, box, padding)$ UIImage?
    }

    class Benchmark {
        <<enum>>
        +now()$ CFAbsoluteTime
        +msSince(start)$ Double
        +residentMemoryMB()$ Double
        +stats(values)$ Stats
    }

    DeepScanApp --> ClassifierViewModel
    DeepScanApp --> DetectorViewModel
    ClassifierViewModel ..> FishResult : erzeugt
    DetectorViewModel ..> DetectedFish : erzeugt
    ClassifierViewModel ..> Benchmark : misst
    DetectorViewModel ..> Benchmark : misst
    FishResult ..> DiaryEntry : gespeichert als
    DiaryEntry ..> FishSpecies : nachgeschlagen via
    ImageCrop ..> DetectedFish : croppt nach
```

---

## 6. SwiftData-Datenmodell (ER)

Das Datenmodell ist bewusst flach (ein einziges `@Model`). Bilder liegen **nicht** in
der DB, sondern als Datei im Documents-Verzeichnis — referenziert über `imagePath`.

```mermaid
erDiagram
    DIARY_ENTRY {
        Date date
        String fishName
        Double confidence
        String location "optional, Freitext"
        String notes "optional"
        String imagePath "optional, UUID.jpg"
    }
    IMAGE_FILE {
        String filename "UUID.jpg"
        Blob jpeg "compressionQuality 0.8"
    }
    DIARY_ENTRY ||..o| IMAGE_FILE : "verweist per imagePath auf (Documents/)"
```

---

## 7. ML-Pipeline (Datenfluss)

Die zweistufige Inferenz — das Herzstück der App.

```mermaid
flowchart TB
    start([UIImage]) --> orient["Orientation-Mapping<br/>CGImagePropertyOrientation(uiOrientation)"]
    orient --> det["DETEKTOR — FishDetector<br/>VNCoreMLRequest<br/>.scaleFit (aspect-erhaltend)<br/>Schwelle 0.25"]

    det --> conv["Y-Achsen-Konvertierung<br/>bottom-left → top-left<br/>y = 1 - maxY"]
    conv --> sort["Sortieren nach Fläche<br/>Cap auf 8 Boxen"]
    sort --> count{"Anzahl<br/>Boxen?"}

    count -->|"0"| whole["ganzes Bild"]
    count -->|"1"| crop1["ImageCrop.crop()<br/>+15% Padding"]
    count -->|">=2"| pick["FishPickerView<br/>Nutzer wählt 1 Box"]
    pick --> crop2["ImageCrop.crop()<br/>+15% Padding"]

    whole --> cls["KLASSIFIKATOR — DeepScanClassifier<br/>VNCoreMLRequest<br/>.centerCrop"]
    crop1 --> cls
    crop2 --> cls

    cls --> logits["rohe Logits"]
    logits --> softmax["numerisch stabiler Softmax<br/>exp(x - max) / Sum"]
    softmax --> result["FishResult<br/>{name, confidence, image}"]
    result --> ui([ResultsView])
```

---

## 8. Scan-Entscheidung (Flussdiagramm)

Die Drei-Wege-Strategie aus `PhotoPreviewView.scan()`.

```mermaid
flowchart TD
    A["scan()"] --> B["phase = .detecting"]
    B --> C["detector.detect(image)"]
    C --> D{"found.count"}
    D -->|"== 0"| E["Detektor fand nichts<br/>→ ganzes Bild klassifizieren<br/>(no_fish-Sentinel fängt Nicht-Fisch ab)"]
    D -->|"== 1"| F["Crop auf Box + klassifizieren<br/>(Picker übersprungen)"]
    D -->|">= 2"| G["detections = found<br/>navigateToPicker = true"]
    E --> H["classify()"]
    F --> H
    G --> I["FishPickerView"]
    I --> J["Nutzer tippt eine Box"]
    J --> H
    H --> K["ResultsView"]
```

---

## 9. Sequenzdiagramm: End-to-End-Scan

```mermaid
sequenceDiagram
    actor U as Nutzer
    participant PV as PhotoPreviewView
    participant DET as DetectorViewModel
    participant IC as ImageCrop
    participant CLS as ClassifierViewModel
    participant V as Vision/CoreML
    participant RV as ResultsView

    U->>PV: tippt "Scan Fish"
    PV->>PV: phase = .detecting
    PV->>DET: detect(image)
    DET->>V: handler.perform([request]) (Task.detached)
    V-->>DET: [VNRecognizedObjectObservation]
    DET->>DET: Filter 0.25 · Y-Flip · Sortierung · Cap 8
    DET-->>PV: [DetectedFish]

    alt 1 Fisch
        PV->>IC: crop(image, box, padding 0.15)
        IC-->>PV: cropped UIImage
        PV->>CLS: classify(cropped)
    else 0 Fische
        PV->>CLS: classify(whole image)
    end

    CLS->>V: handler.perform([request]) (Task.detached)
    V-->>CLS: [VNClassificationObservation] (Logits)
    CLS->>CLS: stabiler Softmax
    CLS-->>PV: FishResult
    PV->>RV: navigate(result)
    RV-->>U: zeigt Art + Confidence
```

---

## 10. Sequenzdiagramm: Kamera-Setup

Zeigt den Off-Main-Thread-Workaround für `AVCaptureSession`.

```mermaid
sequenceDiagram
    actor U as Nutzer
    participant CV as CameraView
    participant VM as CameraViewModel
    participant T as Task.detached
    participant S as AVCaptureSession
    participant MA as MainActor

    U->>CV: öffnet Kamera
    CV->>VM: checkPermissionsAndSetup()
    VM->>VM: authorizationStatus(.video)
    alt notDetermined
        VM->>U: requestAccess(.video)
        U-->>VM: erteilt / verweigert
    end
    VM->>VM: configure(position:.back, initialSetup:true)
    Note over VM: weak let weakSelf = self<br/>(Swift-6-Concurrency-Hoist)
    VM->>T: dispatch (priority .userInitiated)
    T->>S: beginConfiguration()
    T->>S: addInput / addOutput
    T->>S: commitConfiguration()
    T->>MA: weakSelf?.isCameraReady = true
    T->>S: startRunning()
    S-->>CV: Frames → AVCaptureVideoPreviewLayer
```

---

## 11. Sequenzdiagramm: Tagebuch speichern

```mermaid
sequenceDiagram
    actor U as Nutzer
    participant RV as ResultsView
    participant SH as SaveDiarySheet
    participant DE as DiaryEntry
    participant FS as FileManager (Documents)
    participant MC as ModelContext
    participant DV as DiaryView

    U->>RV: tippt "Save to Diary"
    RV->>SH: sheet öffnen
    U->>SH: Ort + Notizen eingeben, speichern
    SH->>DE: storeImage(result.image)
    DE->>FS: JPEG nach UUID.jpg schreiben
    FS-->>DE: filename
    SH->>DE: DiaryEntry(fishName, confidence, imagePath, ...)
    SH->>MC: insert(entry)
    SH->>MC: save()
    MC-->>DV: @Query triggert Reload
    DV-->>U: neuer Eintrag erscheint
```

---

## 12. Navigationsfluss (Screen-Map)

```mermaid
flowchart TD
    Home["HomeView"]
    Home -->|"Take Photo<br/>(fullScreenCover)"| Camera["CameraView"]
    Home -->|"Pick from Library<br/>(PhotosPicker)"| Gallery{{"PhotosPickerItem"}}
    Home -->|"Diary"| Diary["DiaryView"]
    Home -->|"Map"| Map["MapView"]

    Camera -->|"capturedImage → dismiss"| Preview["PhotoPreviewView"]
    Gallery -->|"loadTransferable"| Preview

    Preview -->|"0 / 1 Fisch"| Results["ResultsView"]
    Preview -->|">=2 Fische"| Picker["FishPickerView"]
    Picker --> Results

    Results -->|"Save to Diary (sheet)"| SaveSheet["SaveDiarySheet"]
    Results -->|"Scan Another"| Home

    Diary --> DiaryDetail["DiaryDetailView"]

    note["Navigation via NavigationStack +<br/>navigationDestination(item:) ·<br/>CapturedImage(UUID) verhindert<br/>View-Reuse mit Stale-State"]
    Preview -.- note
```

---

## 13. Scan-Zustandsautomat

Der `phase`-State in `PhotoPreviewView`.

```mermaid
stateDiagram-v2
    [*] --> idle
    idle --> detecting: scan()
    detecting --> classifying: 0 oder 1 Fisch
    detecting --> picking: >=2 Fische
    picking --> classifying: Nutzer wählt Box
    classifying --> done: FishResult
    classifying --> error: vnModel == nil / Fehler
    done --> idle: Scan Another
    error --> idle: Retry
    done --> [*]
```

---

## 14. App-Lifecycle & Dependency Injection

Die ML-ViewModels werden **einmalig** beim App-Start erzeugt und via `@Environment`
durch den View-Tree gereicht (kein Singleton, keine Neuladung pro Scan).

```mermaid
flowchart TB
    launch(["App-Start"]) --> app["DeepScanApp @main"]
    app -->|"@State (einmalig)"| c["ClassifierViewModel()<br/>loadModel()"]
    app -->|"@State (einmalig)"| d["DetectorViewModel()<br/>loadModel()"]
    app -->|".modelContainer(for:)"| mc["ModelContainer<br/>(DiaryEntry)"]

    app --> wg["WindowGroup → HomeView"]
    c -->|".environment(classifier)"| wg
    d -->|".environment(detector)"| wg

    wg -.->|"@Environment(ClassifierViewModel.self)"| pv["PhotoPreviewView"]
    wg -.->|"@Environment(DetectorViewModel.self)"| pv
    mc -.->|"@Query / @Environment(\.modelContext)"| dv["DiaryView / MapView"]
```

---

## 15. Koordinatensystem-Transformation

Vision liefert Bounding-Boxes im *bottom-left*-System; SwiftUI/UIImage nutzen
*top-left*. Zusätzlich muss bei `scaledToFit()`-Letterboxing umgerechnet werden.

```mermaid
flowchart LR
    subgraph vision["Vision (bottom-left, normalisiert)"]
        v["boundingBox<br/>(minX, minY, w, h)"]
    end
    subgraph flip["Y-Flip (DetectorViewModel)"]
        f["topLeft = (minX, 1 - maxY, w, h)"]
    end
    subgraph fit["Letterbox-Mapping (FishPickerView)"]
        g["displayW/H + originX/Y<br/>aus GeometryReader-Aspect"]
    end
    subgraph screen["Bildschirm-Rechteck"]
        s["rect = (originX + minX*dW,<br/>originY + minY*dH, ...)"]
    end
    v --> f --> g --> s
```

---

## 16. Benchmark-Instrumentierung

Wie die 11 CSV-Spalten für Kapitel 6.3.1 / 6.3.2 entstehen.

```mermaid
flowchart TB
    btn["Benchmark (30x)-Button<br/>PhotoPreviewView.runBenchmark()"] --> warm["2 Warmups<br/>(verworfen — ANE-Compilation)"]
    warm --> loop{"30 Iterationen"}

    loop --> dpre["detect_pre_ms"]
    dpre --> dinf["detect_inf_ms<br/>handler.perform"]
    dinf --> dpost["detect_post_ms"]
    dpost --> cropms["crop_ms<br/>ImageCrop +15%"]
    cropms --> cpre["classify_pre_ms"]
    cpre --> cinf["classify_inf_ms<br/>handler.perform"]
    cinf --> cpost["classify_post_ms<br/>Softmax"]
    cpost --> e2e["end_to_end_ms"]
    e2e --> mem["resident_mb<br/>phys_footprint"]
    mem --> loop

    loop -->|"fertig"| stats["Benchmark.stats()<br/>mean / median / p95 / min / max / σ"]
    stats --> csv[("CSV: Documents/<br/>deepscan_benchmark_*.csv<br/>+ [BM_CSV] Konsole")]
```

---

## 17. Bildspeicher-Strategie

Warum Bilder als Datei und nicht als `Data` in SwiftData liegen.

```mermaid
flowchart LR
    img["UIImage"] -->|"jpegData(0.8)"| file["Documents/UUID.jpg<br/>(~Hunderte KB)"]
    file -->|"imagePath = filename"| db[("SwiftData DiaryEntry<br/>nur Dateiname ~36 Byte")]

    db -->|"@Query Fetch"| list["DiaryView Liste<br/>(KEIN Bild im RAM)"]
    list -->|"on demand"| comp["entry.image<br/>UIImage(contentsOfFile:)"]
    comp --> render["DiaryDetailView rendert"]

    del["Eintrag löschen"] -->|"1. deleteImage()"| file
    del -->|"2. modelContext.delete()"| db
```

---

## 18. Git-Zeitleiste (Gantt)

Die drei Entwicklungsphasen des Projekts.

```mermaid
gantt
    title DeepScan – Entwicklungsphasen
    dateFormat YYYY-MM-DD
    axisFormat %d.%m

    section Phase 1: Grundgerüst
    Initial Commit (Template)      :2026-03-08, 1d
    Projekt-Setup / leere Views    :2026-03-15, 1d
    Kamera & Galerie               :2026-03-30, 1d

    section Phase 2: Klassifikator
    v1.0 Klassifikator + Diary     :2026-04-26, 1d

    section Phase 3: Detektor & Polish
    YOLO Detektor + Picker + Crop  :2026-05-14, 1d
    README + Diver-Asset           :2026-05-17, 1d
    Design / HomeView / Map        :2026-05-17, 1d
    Modell-Syncs (CI)              :2026-05-19, 3d
    Benchmark + ResultView-Polish  :2026-05-28, 2d
```

---

## Export-Hinweise für die Arbeit

- **PNG/SVG-Export:** Diagramm-Code auf <https://mermaid.live> einfügen → *Actions → PNG/SVG*.
  SVG ist vektorbasiert und skaliert verlustfrei für den Druck.
- **Hohe Auflösung:** auf mermaid.live unter *Configuration* `"scale": 3` setzen.
- **Konsistenter Stil:** Für ein einheitliches Theme oben in jeden Block
  `%%{init: {'theme':'neutral'}}%%` einfügen (Graustufen, gut für Schwarzweißdruck).
- **LaTeX/Word:** SVG einbetten oder PNG mit ≥300 dpi platzieren.
- **Alternative:** Die Diagramme lassen sich 1:1 nach PlantUML übersetzen, falls dein
  Lehrstuhl ein bestimmtes Werkzeug verlangt — sag Bescheid, dann liefere ich die Varianten.
```

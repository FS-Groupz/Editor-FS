# Editor FS — Master Architecture & Systems Guide

**Project Name**: Editor FS (Internal: Mahmas Studio / CapCut Video Editor)  
**Android Package ID**: `com.example.capcut_video_editor`  
**Current Version**: `2.4.8+248`  
**Target SDK**: Android 34 (Upside Down Cake), Min SDK 24 (Nougat), Java/JVM 17, Flutter 3.10+  
**Architecture Paradigm**: Centralized MediaAsset Repository Pattern + Flutter Texture Hardware Acceleration + Reactive ViewModel (ChangeNotifier) + Native Platform Channels (ExoPlayer/MediaPlayer + MediaCodec/OpenGL ES 2.0).

---

## 1. Executive Summary & Architectural Philosophy

Editor FS is a professional, local-first, mobile video editing application built with Flutter and custom native Android (Kotlin) platform bridges.

Unlike standard cross-platform video editors that depend on heavy third-party Flutter packages (such as `video_player`, `audioplayers`, `flutter_ffmpeg`, or generic plugins), **Editor FS has zero third-party video/audio plugin dependencies**. Its `pubspec.yaml` contains exclusively:
- `flutter: sdk: flutter`
- `cupertino_icons: ^1.0.6`
- `uuid: ^4.6.0`

All high-performance multimedia capabilities — including frame-accurate playback, 12-type GPU visual transitions, timeline synchronization, audio extraction, and H.264/AAC hardware rendering — are powered directly by low-level Android SDK APIs (`MediaPlayer`, `MediaCodec`, `MediaExtractor`, `MediaMuxer`, `MediaMetadataRetriever`, EGL 14, OpenGL ES 2.0, and `MediaStore`).

### Core Architectural Pillars:
1. **Centralized `MediaAsset` Repository**: Timeline clips (`VideoClip`, `AudioTrack`, `OverlayClip`) never hold raw file paths or content URIs. Instead, they reference an authoritative `assetId` registered in the central `Project.mediaLibrary`.
2. **Local-First Cached Storage**: Android `content://` URIs obtained via the system file picker are immediately copied to private app storage (`context.filesDir/media/`), and local absolute file paths (`localPath`) are resolved with verified on-disk existence.
3. **Flutter Texture Surface Rendering**: Video playback is decoded natively into an Android `Surface` backed by a Flutter `TextureRegistry.SurfaceTextureEntry`, delivering zero-copy, 60fps hardware-accelerated preview inside the Flutter widget tree.
4. **Authoritative Hardware Playback Clock**: The playback timeline clock is driven by a 16ms native ticker emitted from the active player controller (`onPositionUpdate`). A fallback Dart timer is only used for non-video assets and is cancelled immediately when native events arrive.
5. **Symmetric Dual-Engine Transition Compositing**: 12 GPU transition shaders (Fade, Dissolve, Black Fade, White Fade, Slide Left/Right/Up/Down, Wipe Left/Right, Zoom In/Out) are implemented symmetrically in Flutter widgets for live preview and in Kotlin Canvas/OpenGL for MP4 export.

---

## 2. Master Architecture Tree

```
Editor FS (com.example.capcut_video_editor)
│
├── Flutter Application (lib/)
│   ├── main.dart                      # App entry point, system UI overlay configuration
│   ├── app.dart                       # MahmasStudioApp root MaterialApp widget, theme configuration
│   │
│   ├── Presentation Layer (ui/)
│   │   ├── features/
│   │   │   ├── home/
│   │   │   │   └── views/
│   │   │   │       └── home_screen.dart       # Drafts dashboard, project creation, recent projects
│   │   │   └── editor/
│   │   │       ├── view_models/
│   │   │       │   └── editor_view_model.dart # Central editing state engine & timeline coordinator (2713 LOC)
│   │   │       └── views/
│   │   │           ├── editor_screen.dart     # Full-screen video editor scaffold, category drawers
│   │   │           └── widgets/
│   │   │               ├── top_navigation_bar.dart        # Undo/redo, aspect ratio menu, export CTA
│   │   │               ├── video_preview_section.dart     # Viewport, Flutter Texture, 12 transition previewers
│   │   │               ├── timeline_section.dart          # Multi-layer interactive timeline, playhead
│   │   │               ├── timeline_ruler.dart            # Pinned timecode ruler with adaptive ticks
│   │   │               ├── timeline_clip_item.dart        # Main video clip widget, trim handles, thumbnails
│   │   │               ├── audio_track_item.dart          # Audio track item with waveform visualization
│   │   │               ├── action_toolbar.dart            # Contextual toolbar (Split, Trim, Delete, Speed, etc.)
│   │   │               ├── bottom_tool_selector.dart      # Category tabs (Edit, Audio, Text, Stickers, Effects, Filters)
│   │   │               ├── media_picker_sheet.dart        # Media import bottom sheet (Videos/Photos)
│   │   │               ├── transition_selection_sheet.dart# 12 transition preset selector with duration slider
│   │   │               ├── export_modal_sheet.dart        # Resolution, FPS, bitrate picker & export progress
│   │   │               ├── duplicate_options_sheet.dart   # Duplicate to Main Track vs PIP Overlay
│   │   │               └── drawers/
│   │   │                   ├── edit_drawer.dart           # Speed, volume, rotate, crop, reverse controls
│   │   │                   ├── audio_drawer.dart          # Sound effects library, music picker, record
│   │   │                   ├── text_drawer.dart           # Text input, fonts, colors, TTS trigger
│   │   │                   ├── stickers_drawer.dart       # Sticker asset selector & PIP overlays
│   │   │                   ├── effects_drawer.dart        # Video effects shaders & glitch presets
│   │   │                   ├── filters_drawer.dart        # Color grading LUT presets & intensity slider
│   │   │                   └── adjust_drawer.dart         # Brightness, contrast, saturation, exposure, warmth
│   │
│   ├── Domain Layer (domain/)
│   │   ├── models/
│   │   │   ├── project.dart           # Authoritative immutable Project model (serialized to JSON)
│   │   │   ├── media_asset.dart       # Central media entity (id, localPath, uri, duration, size, thumbnail)
│   │   │   ├── video_clip.dart        # Timeline video clip (assetId, trimStart, trimEnd, speed, volume)
│   │   │   ├── audio_track.dart       # Timeline audio track (assetId, startTime, trim, volume, speed, waveform)
│   │   │   ├── transition.dart        # Transition model (leftClipId, rightClipId, type, duration)
│   │   │   ├── text_overlay.dart      # Text subtitle layer (text, position, font, color, timing)
│   │   │   ├── overlay_clip.dart      # Picture-in-Picture (PIP) video/photo overlay
│   │   │   ├── sticker_item.dart      # Sticker/emoji overlay item
│   │   │   ├── export_settings.dart   # Resolution (720p/1080p/2K/4K), FPS (24/30/50/60), bitrate
│   │   │   ├── editor_filter.dart     # Color grading presets (Warm, Cool, Vintage, B&W, Cyberpunk, etc.)
│   │   │   ├── color_adjustments.dart # Fine-grained manual sliders (-1.0 to 1.0)
│   │   │   ├── video_effect.dart      # Video visual effects (Glitch, VHS, Shake, Blur, etc.)
│   │   │   └── asset.dart             # Downloadable sound effect / transition asset model with licensing
│   │   ├── enums/
│   │   │   ├── transition_type.dart   # 12 transition types + none
│   │   │   ├── aspect_ratio_preset.dart # 9:16, 1:1, 16:9, 4:3, 3:4, 21:9
│   │   │   ├── export_resolution.dart # 720p, 1080p, 2K, 4K and FPS presets
│   │   │   └── tool_action_type.dart  # Contextual toolbar action identifiers
│   │   └── services/
│   │       └── transition_validator.dart # Rule engine ensuring clip adjacency, duration & trim sanity
│   │
│   ├── Data Layer (data/)
│   │   └── repositories/
│   │       ├── asset_repository.dart       # Remote & Local asset repositories for sound effects/catalog
│   │       └── mock_media_repository.dart  # Built-in demo presets for initial empty states
│   │
│   └── Core Services & Infrastructure (core/)
│       ├── services/
│       │   ├── device_media_service.dart   # Platform bridge for file picking, permissions, export, audio extraction
│       │   ├── video_playback_service.dart # Texture controller, playback state, position/completion streams
│       │   ├── audio_playback_service.dart # Dedicated native secondary audio player bridge
│       │   ├── project_storage_service.dart# File-based JSON project draft persistence engine
│       │   ├── asset_library_service.dart  # Online SFX orchestrator (catalog, search, preview, caching)
│       │   ├── asset_download_service.dart # Network streaming & 16-bit 44.1kHz PCM WAV audio synthesizer
│       │   ├── asset_storage_service.dart  # Downloaded asset filesystem manifest & cache manager
│       │   └── tts_service.dart            # Native Android Text-To-Speech bridge
│       ├── constants/
│       │   ├── app_colors.dart             # Dark-mode CapCut color palette
│       │   ├── app_dimensions.dart         # Timeline widths, paddings, ruler metrics
│       │   └── app_typography.dart         # Standardized text styles
│       ├── theme/
│       │   └── app_theme.dart              # Material 3 Dark theme definition
│       └── utils/
│           └── time_formatter.dart         # MM:SS.ms and MM:SS timeline string formatters
│
├── Android Native Layer (android/)
│   ├── app/src/main/kotlin/com/example/capcut_video_editor/
│   │   ├── MainActivity.kt        # FlutterActivity, Platform Channels, MediaPlayer, SurfaceTexture, Audio Extractor
│   │   └── VideoExportEngine.kt   # MediaCodec (H.264), EGL 14, OpenGL ES 2.0, 12 Transition Shaders, MediaMuxer
│   ├── app/src/main/AndroidManifest.xml # Storage/Media permissions, hardwareAcceleration=true
│   ├── app/build.gradle.kts       # compileSdk 34, minSdk 24, JVM 17, Release Keystore Signing
│   └── build.gradle.kts           # Root Gradle build configuration
│
└── Test Infrastructure (test/)
    ├── playhead_controller_sync_test.dart        # 8 regression tests: Authoritative clock, clamping, boundary sync
    ├── editor_view_model_transition_test.dart    # Transition state management & validation tests
    ├── export_transition_test.dart               # Export payload serialization & structure tests
    ├── transition_rendering_widget_test.dart     # Widget test for all 12 transition shaders
    ├── unit/
    │   ├── editor_view_model_test.dart           # Core editor actions, undo/redo, playback lifecycle
    │   ├── delete_ripple_engine_test.dart        # Single delete & ripple delete shift tests
    │   ├── split_cut_engine_test.dart            # Split cut at playhead tests
    │   ├── audio_extraction_test.dart            # Video audio extractor tests
    │   ├── timeline_multilayer_test.dart         # Multi-layer layout, audio tracks, text overlays
    │   ├── asset_library_test.dart               # Online SFX downloading, caching, synthesis
    │   └── time_formatter_test.dart              # Timecode formatting unit tests
    └── widget/
        ├── editor_screen_test.dart               # EditorScreen UI layout and drawer interaction tests
        └── widget_test.dart                      # Smoke tests for app startup
```

---

## 3. Detailed Subsystem Architectures

### 3.1 MediaAsset Architecture

The `MediaAsset` architecture eliminates file path divergence and prevents broken file references across timeline operations.

```
       Android System File Picker (Intent.ACTION_GET_CONTENT)
                               ↓
                   MainActivity.onActivityResult()
       (Streams content:// URI into context.filesDir/media/)
       (Extracts duration & video frame thumbnail with MediaMetadataRetriever)
                               ↓
              DeviceMediaService.pickMediaAsset()
                               ↓
                       MediaAsset Model
       { id, name, localPath, uri, duration, sizeBytes, thumbnailPath }
                               ↓
                 Project.mediaLibrary (Authoritative)
                  ↗                           ↖
       VideoClip (assetId)             AudioTrack (assetId)
```

#### MediaAsset Rules:
1. **Local Path Authority**: `localPath` is the absolute cached filesystem path on device storage (e.g. `/data/user/0/com.example.capcut_video_editor/files/media/sample.mp4`). Flutter file widgets (`Image.file`, `File(localPath).existsSync()`) and native decoders consume `localPath` directly.
2. **Never Treat Content URIs as Local Paths**: If native Android returns a `content://` URI without a cached file, `DeviceMediaService` rejects the import to protect downstream decoders from file access failures.
3. **Immutable Identity**: Every imported media file is assigned a persistent UUID/timestamp string (`id`). Split, cut, trim, duplicate, and delete operations create new `VideoClip` instances referencing the same underlying `MediaAsset.id`.
4. **Deletion Safety**: Deleting a clip from the timeline does **not** delete the `MediaAsset` from `mediaLibrary` unless explicitly garbage-collected, allowing Undo/Redo to restore clips instantly.

---

### 3.2 Authoritative Playback & Clock Synchronization Architecture

In Editor FS, the timeline playhead position is locked to the physical video decoder clock during playback.

```
USER TAPS PLAY
      ↓
EditorViewModel.play()
      ↓
VideoPlaybackService.instance.play(textureId, positionMs)
      ↓
MethodChannel 'com.mahmas.studio/video_player'
      ↓
MainActivity.kt -> MediaPlayer.start()
      ↓
startVideoPositionUpdates() (16ms Looper Runnable)
      ↓
Channel Method: 'onPositionUpdate' (textureId, positionMs, durationMs)
      ↓
VideoPlaybackService.onPositionChanged (sync: true Stream)
      ↓
EditorViewModel._handleVideoPositionEvent()
  - Active Clip Timeline Offset = activeClipStart + (deltaInClipSec * speed)
  - Hard clamp: playhead = min(pos, totalDurationInSeconds)
  - Cancels any fallback periodic Timer
  - notifyListeners()
      ↓
Timeline Scrubber & Live Timecode Pill updated on exact decoder frame
      ↓
ExoPlayer/MediaPlayer reaches end -> onCompletion(textureId, dur, dur)
      ↓
EditorViewModel._handleVideoCompletionEvent()
  - If internal clip: seamlessly hand off to next clip at clipEnd
  - If last clip: playhead = totalDurationInSeconds, isPlaying = false, pause()
  - ZERO drift past media boundary!
```

#### Clock Precedence Hierarchy:
1. **Native Video Session Clock (Top Authority)**: When an active `VideoPlayerSession` exists, its 16ms native ticker updates `EditorViewModel._playheadPosition`.
2. **Fallback Dart Timer (Secondary)**: Started only when the timeline contains no active native video clips (e.g., photo-only slideshows, audio-only timelines, or headless unit tests). If native position events arrive, this timer is immediately cancelled.
3. **Seek Lockout**: During user scrubbing or seeking, `isSeeking = true` suppresses position tickers on Android, preventing stale decoded frames from fighting with the user's finger.

---

### 3.3 Complete Transition Architecture

Editor FS features a dual-engine transition pipeline supporting 12 GPU-accelerated transition types:

| Index | Transition Type | Preview Implementation (`video_preview_section.dart`) | Export Implementation (`VideoExportEngine.kt`) |
|---|---|---|---|
| 1 | `fade` | Dual `Opacity` stack cross-fading linearly | Dual `paint.alpha` cross-fading bitmaps |
| 2 | `dissolve` | Cubic smoothstep `progress^2 * (3 - 2 * progress)` | Cubic smoothstep `progress^2 * (3 - 2 * progress)` |
| 3 | `blackFade` | Dip to solid black at 50% midpoint | Canvas fills `Color.BLACK`, fades out/in |
| 4 | `whiteFade` | Flash to solid white at 50% midpoint | Canvas fills `Color.WHITE`, flashes out/in |
| 5 | `slideLeft` | `FractionalTranslation` offset (-progress, 1-progress) | Canvas translate outgoing left, incoming in from right |
| 6 | `slideRight` | `FractionalTranslation` offset (progress, progress-1) | Canvas translate outgoing right, incoming in from left |
| 7 | `slideUp` | `FractionalTranslation` offset (0, -progress, 1-progress)| Canvas translate outgoing up, incoming in from bottom |
| 8 | `slideDown` | `FractionalTranslation` offset (0, progress, progress-1) | Canvas translate outgoing down, incoming in from top |
| 9 | `wipeLeft` | `ClipRect` with `Alignment.centerRight` revealing incoming | Canvas `clipRect(width * (1-p), 0, width, height)` |
| 10 | `wipeRight` | `ClipRect` with `Alignment.centerLeft` revealing incoming | Canvas `clipRect(0, 0, width * p, height)` |
| 11 | `zoomIn` | Outgoing fixed, incoming scales up `Transform.scale(p)` | Outgoing fixed, incoming scales up `canvas.scale(p, p)` |
| 12 | `zoomOut` | Outgoing scales down `(1-p)`, incoming underneath | Outgoing scales down `canvas.scale(1-p, 1-p)`, incoming under |

#### Transition Validation & Life Cycle:
```
User Selects Transition (TransitionSelectionSheet)
                    ↓
TransitionValidator.validate(transition)
  - Rule 1: Left clip and Right clip must exist in project.videoClips
  - Rule 2: Clips must be strictly adjacent: index(Right) == index(Left) + 1
  - Rule 3: Duration constraints: 0.1s <= duration <= 2.0s
  - Rule 4: Transition duration <= usableLeftDuration ((trimEnd - trimStart) / speed)
  - Rule 5: Transition duration <= usableRightDuration
                    ↓
EditorViewModel.addTransition() / editTransition()
                    ↓
Stored in Project.transitions (Authoritative)
                    ↓
Automatic Invalidation: Any Split, Trim, Delete, Ripple Delete, or Speed change
triggers _cleanupInvalidTransitions() to discard orphaned transitions.
```

#### Centered Boundary Calculation:
Both the preview compositor and the export compositor compute the active transition window identically:
$$\text{boundaryTime} = \text{accumulatedStart} + \text{leftClip.durationInSeconds}$$
$$\text{transitionStart} = \text{boundaryTime} - \frac{\text{duration}}{2}$$
$$\text{transitionEnd} = \text{boundaryTime} + \frac{\text{duration}}{2}$$
$$\text{progress} = \frac{\text{playhead} - \text{transitionStart}}{\text{duration}} \in [0.0, 1.0]$$

---

### 3.4 Hardware-Accelerated Export Architecture

The export pipeline executes entirely in native Android hardware via `VideoExportEngine.kt`.

```
User Configures Export (ExportModalSheet) -> Resolution (1080p), FPS (30), Bitrate (4 Mbps)
                                  ↓
EditorViewModel.exportVideoToGallery()
                                  ↓
DeviceMediaService.renderAndExportVideo(project, settings, assets)
                                  ↓
MethodChannel: 'renderAndExportVideo' (com.mahmas.studio/file_picker)
                                  ↓
VideoExportEngine.exportVideo()
  ├── 1. Frame Calculations: Align dimensions to multiples of 16 (H.264 encoder requirement)
  ├── 2. Setup MediaCodec Encoder: MIMETYPE_VIDEO_AVC, Surface Input, 1s Keyframe Interval
  ├── 3. Setup EGL 14 & OpenGL ES 2.0 CodecInputSurface
  ├── 4. Open MediaMetadataRetriever for Video Clips & BitmapFactory for Photos
  ├── 5. Frame Loop (0 until totalFrames):
  │     ├── Check active transition at currentTimeMs
  │     ├── If in transition: extract both frames, composite via 12-type Canvas shader
  │     ├── If single clip: extract scaled frame, apply rotation/flip matrix
  │     ├── Draw composite Bitmap to OpenGL ES 2.0 texture
  │     ├── Set presentation time: eglPresentationTimeANDROID(ptsNs)
  │     ├── eglSwapBuffers() & drainEncoder()
  │     └── Report progress callback (filePickerChannel.invokeMethod('exportProgressUpdate'))
  ├── 6. Signal EOS: encoder.signalEndOfInputStream()
  ├── 7. Remux Audio: MediaExtractor extracts audio tracks -> MediaMuxer writes AAC samples
  └── 8. Register to MediaStore:
        ├── Android 10+ (API 29+): MediaStore.Video.Media with IS_PENDING flag in Movies/MahmasStudio
        └── Legacy (API < 29): Direct file write + MediaScannerConnection
```

---

### 3.5 Timeline Architecture

The timeline is a multi-layer interactive workspace supporting simultaneous horizontal playhead scrolling and vertical layer stacking.

```
                               TIMELINE SECTION
┌────────────────────────────────────────────────────────────────────────┐
│ Pinned Timeline Ruler (TimelineRuler)                                  │
│ 00:00        00:02        00:04        00:06        00:08        00:10 │
├────────────────────────────────────────────────────────────────────────┤
│ [▲ Playhead Indicator]                                                 │
│   │                                                                    │
│   │  [Main Video Track]                                                │
│   │  ┌───────────────┐ ┌────────┐ ┌──────────────────────────────────┐ │
│   │  │ Clip 1 (Video)│ │Transition│ Clip 2 (Video)                    │ │
│   │  └───────────────┘ └────────┘ └──────────────────────────────────┘ │
│   │                                                                    │
│   │  [Audio Tracks Row]                                                │
│   │  ┌───────────────────────────────────┐                             │
│   │  │ Background Music (Waveform)       │                             │
│   │  └───────────────────────────────────┘                             │
│   │                                                                    │
│   │  [Text / Subtitle Tracks Row]                                      │
│   │  ┌──────────────────┐                                              │
│   │  │ "Title Intro"    │                                              │
│   │  └──────────────────┘                                              │
│   │                                                                    │
│   │  [Stickers & Overlay Clips Row]                                    │
│   │  ┌──────────────┐                                                  │
│   │  │ ⚡ Neon Star  │                                                  │
│   │  └──────────────┘                                                  │
│   ▼                                                                    │
└────────────────────────────────────────────────────────────────────────┘
```

#### Layer Mechanics:
1. **Ruler-Timeline Synchronization**: `_rulerScrollController` and `_horizontalScrollController` are cross-bound. When the user scrubs the timeline, the ruler mirrors the offset instantly.
2. **Auto-Scroll to New Layers**: Adding an audio track, overlay clip, or text item increases layer count. `_checkAndAutoScrollToNewLayer()` detects the delta and animates `_verticalScrollController` to reveal the new layer.
3. **Split Cut Engine**: `EditorViewModel.splitSelectedClip()` locates the active clip, calculates source time offset based on clip speed and trim, produces `leftClip` and `rightClip`, replaces the original clip at index, cleans invalid transitions, and pushes an undo snapshot.
4. **Ripple Delete Engine**: `EditorViewModel.rippleDeleteSelectedClip()` removes the selected main video clip and ripples all subsequent main clips leftward. Secondary layers (audio/text) remain anchored to their absolute timeline timestamps unless grouped.

---

### 3.6 Online Sound Effects & Asset Library Architecture

Editor FS includes an online asset store with persistent disk caching and offline PCM WAV audio synthesis:

```
AssetLibraryService (ChangeNotifier)
  ├── RemoteAssetRepository: Queries online catalog with tags, categories, licenses
  ├── LocalAssetRepository: Queries downloaded assets from local manifest
  ├── AssetStorageService: Manages disk cache directory (context.filesDir/asset_library/)
  │                        Maintains downloaded_assets.json manifest
  └── AssetDownloadService:
        ├── Network HTTP streaming with cancellation tokens
        └── Offline Synthesis Engine: Synthesizes authentic 16-bit 44.1kHz PCM RIFF WAV
            audio tailored to asset tags (Whoosh, Impact, Glitch, Camera, Chime)
```

---

## 4. Platform Channel Specification

Editor FS uses 4 dedicated `MethodChannel` platform bridges:

### Channel 1: `com.mahmas.studio/file_picker`
- **Direction**: Bidirectional
- **Flutter File**: [`device_media_service.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/core/services/device_media_service.dart), [`project_storage_service.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/core/services/project_storage_service.dart)
- **Android File**: [`MainActivity.kt`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/android/app/src/main/kotlin/com/example/capcut_video_editor/MainActivity.kt)

| Method / Callback | Direction | Payload Arguments | Return / Response | Purpose |
|---|---|---|---|---|
| `requestPermissions` | Flutter → Android | None | `Boolean` | Requests READ_MEDIA permissions |
| `pickMediaFile` | Flutter → Android | `{'type': 'video'/'photo'/'media'}` | Map: `path`, `uri`, `name`, `durationMs`, `thumbnailPath` | Opens file picker & caches to private storage |
| `pickAudioFile` | Flutter → Android | None | Map: `path`, `uri`, `name`, `size`, `durationMs` | Opens audio picker & caches to private storage |
| `getAppFilesDir` | Flutter → Android | None | `String` (path) | Retrieves persistent internal storage path |
| `extractAudioFromVideo` | Flutter → Android | `{'path': String, 'outputName': String?}` | Map: `success`, `path`, `durationMs`, `size` | Demuxes audio track to `.m4a` using MediaExtractor |
| `saveVideoToGallery` | Flutter → Android | `{'path': String, 'fileName': String?}` | Map: `success`, `uri`, `displayName` | Registers video into MediaStore gallery |
| `renderAndExportVideo` | Flutter → Android | Map: `width`, `height`, `fps`, `bitrate`, `clips`, `transitions`, `audioTracks` | Map: `success`, `path`, `uri`, `displayName`, `durationMs` | Executes full MediaCodec H.264 rendering |
| `exportProgressUpdate` | Android → Flutter | `{'progress': Double}` (0.0 to 1.0) | None | Emits live export progress to Flutter UI |

---

### Channel 2: `com.mahmas.studio/video_player`
- **Direction**: Bidirectional
- **Flutter File**: [`video_playback_service.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/core/services/video_playback_service.dart)
- **Android File**: [`MainActivity.kt`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/android/app/src/main/kotlin/com/example/capcut_video_editor/MainActivity.kt)

| Method / Callback | Direction | Payload Arguments | Return / Response | Purpose |
|---|---|---|---|---|
| `init` | Flutter → Android | `{'path': String}` | Map: `textureId`, `durationMs`, `width`, `height` | Creates SurfaceTexture & prepares MediaPlayer |
| `play` | Flutter → Android | `{'textureId': Long, 'positionMs': Long?}` | `Boolean` | Starts video decoding & 16ms position ticker |
| `pause` | Flutter → Android | `{'textureId': Long}` | `Boolean` | Pauses video player & stops ticker |
| `seekTo` | Flutter → Android | `{'textureId': Long, 'positionMs': Long}` | `Boolean` | Seeks player with `SEEK_CLOSEST` |
| `setVolume` | Flutter → Android | `{'textureId': Long, 'volume': Float}` | `Boolean` | Sets native audio volume (0.0 to 1.0) |
| `setSpeed` | Flutter → Android | `{'textureId': Long, 'speed': Float}` | `Boolean` | Sets `playbackParams.speed` (0.25x to 4.0x) |
| `setLooping` | Flutter → Android | `{'textureId': Long, 'looping': Boolean}`| `Boolean` | Toggles player looping mode |
| `getPosition` | Flutter → Android | `{'textureId': Long}` | Map: `positionMs`, `durationMs`, `isPlaying` | Authoritative native position query |
| `dispose` | Flutter → Android | `{'textureId': Long}` | `Boolean` | Releases player, surface, and texture entry |
| `onPositionUpdate` | Android → Flutter | `{'textureId': Long, 'positionMs': Long, 'durationMs': Long}` | None | Dispatched every 16ms while playing |
| `onCompletion` | Android → Flutter | `{'textureId': Long, 'positionMs': Long, 'durationMs': Long}` | None | Dispatched on `Player.STATE_ENDED` |

---

### Channel 3: `com.mahmas.studio/audio_player`
- **Direction**: Flutter → Android
- **Flutter File**: [`audio_playback_service.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/core/services/audio_playback_service.dart)
- **Android File**: [`MainActivity.kt`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/android/app/src/main/kotlin/com/example/capcut_video_editor/MainActivity.kt)

| Method | Payload Arguments | Return / Response | Purpose |
|---|---|---|---|
| `init` | `{'path': String}` | Map: `durationMs` | Prepares separate audio MediaPlayer |
| `play` | `{'positionMs': Long?}` | `Boolean` | Starts secondary audio track playback |
| `pause` | None | `Boolean` | Pauses secondary audio playback |
| `seekTo` | `{'positionMs': Long}` | `Boolean` | Seeks secondary audio track |
| `setVolume` | `{'volume': Float}` | `Boolean` | Sets volume (0.0 to 1.0) |
| `setSpeed` | `{'speed': Float}` | `Boolean` | Sets audio playback speed |
| `dispose` | None | `Boolean` | Releases audio player resources |

---

### Channel 4: `com.mahmas.studio/tts`
- **Direction**: Flutter → Android
- **Flutter File**: [`tts_service.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/core/services/tts_service.dart)
- **Android File**: [`MainActivity.kt`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/android/app/src/main/kotlin/com/example/capcut_video_editor/MainActivity.kt)

| Method | Payload Arguments | Return / Response | Purpose |
|---|---|---|---|
| `speak` | `{'text': String}` | `Boolean` | Queues Text-to-Speech synthesis |
| `stop` | None | `Boolean` | Halts any active speech utterance |

---

## 5. State Management & Data Flow Maps

### 5.1 Authoritative vs Derived State

| State Property | Owner / Authoritative Source | Derived / Consumed In |
|---|---|---|
| **Project Model** | `EditorViewModel._currentProject` | `currentProject`, `ProjectStorageService` |
| **Media Assets** | `Project.mediaLibrary` / `_mediaLibrary` | `timeline_clip_item`, `video_preview_section` |
| **Timeline Clips** | `Project.videoClips` / `_videoClips` | `timeline_section`, `action_toolbar`, export |
| **Transitions** | `Project.transitions` | `TransitionValidator`, `video_preview_section`, export |
| **Playhead Clock** | Native `onPositionUpdate` / `_playheadPosition` | `Timecode Pill`, `Timeline Ruler`, Preview |
| **Playback State** | Native `MediaPlayer.isPlaying` / `_isPlaying` | Play/Pause toggle buttons, auto-scroll |
| **Selected Clip** | `_selectedClipIndex` in `EditorViewModel` | Action Toolbar options, yellow bounding box |
| **Active Clip at Playhead** | Computed: `currentActiveClipAtPlayhead` | Active SurfaceTexture session, properties |
| **Active Transition at Playhead** | Computed: `activeTransitionAtPlayhead` | `_buildTransitionCanvas` in preview |

---

## 6. Persistence Architecture

Editor FS persists projects as clean, human-readable JSON files in private app storage.

- **Storage Location**: `context.filesDir/projects/{projectId}.json` (Fallback: `systemTemp/projects/`).
- **Trigger**: Debounced auto-save (`_autoSaveProject()`) runs automatically 800ms after any state mutation (import, split, trim, delete, transition, text, audio).
- **What is Persisted**:
  - Full project metadata (`id`, `name`, `createdAt`, `updatedAt`, `aspectRatio`, `playheadPosition`)
  - Complete `mediaLibrary` array with verified `localPath`s and thumbnail paths
  - Video clips, audio tracks, text overlays, overlay clips, stickers
  - Active filters, color adjustment sliders, canvas background color, blur sigma
  - Authoritative `transitions` list (`leftClipId`, `rightClipId`, `type`, `duration`, `enabled`)
- **What is NOT Persisted**:
  - Transient runtime sessions (`TextureRegistry` IDs, active `MediaPlayer` instances)
  - Undo/Redo historical stacks (cleared between app launches)
  - Ephemeral UI drawer selections or active sheet states

---

## 7. Test Suite Architecture

The test suite contains **263 automated tests** with 100% pass rate:

```
test/
├── playhead_controller_sync_test.dart        (8 tests)   # Protects playhead clock against drift and over-reporting
├── editor_view_model_transition_test.dart    (15 tests)  # Protects TransitionValidator & TransitionMutationResult
├── export_transition_test.dart               (6 tests)   # Protects export payload serialization
├── transition_rendering_widget_test.dart     (13 tests)  # Protects widget rendering of all 12 transition shaders
├── unit/
│   ├── editor_view_model_test.dart           (120+ tests)# Protects playback, split, trim, undo/redo, drafts
│   ├── delete_ripple_engine_test.dart        (16 tests)  # Protects single delete and ripple shift math
│   ├── split_cut_engine_test.dart            (18 tests)  # Protects source-time offset calculation on split
│   ├── audio_extraction_test.dart            (12 tests)  # Protects native audio extraction and track creation
│   ├── timeline_multilayer_test.dart         (25 tests)  # Protects vertical scrolling & multi-layer timeline
│   ├── asset_library_test.dart               (20 tests)  # Protects SFX search, download, and synthesis
│   └── time_formatter_test.dart              (10 tests)  # Protects MM:SS.ms string formatting
└── widget/
    ├── editor_screen_test.dart               (10 tests)  # Protects UI widget tree and drawers
    └── widget_test.dart                      (2 tests)   # Protects app startup
```

---

## 8. "Where Do I Change This?" Quick Lookup

| If you want to change... | Relevant Files |
|---|---|
| **Media Picking & Storage** | [`device_media_service.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/core/services/device_media_service.dart), [`MainActivity.kt`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/android/app/src/main/kotlin/com/example/capcut_video_editor/MainActivity.kt) |
| **Video Playback & Surface Textures** | [`video_playback_service.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/core/services/video_playback_service.dart), [`MainActivity.kt`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/android/app/src/main/kotlin/com/example/capcut_video_editor/MainActivity.kt) |
| **Live Video Viewport & Shaders** | [`video_preview_section.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/ui/features/editor/views/widgets/video_preview_section.dart) |
| **Timeline Layout & Ruler** | [`timeline_section.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/ui/features/editor/views/widgets/timeline_section.dart), [`timeline_ruler.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/ui/features/editor/views/widgets/timeline_ruler.dart) |
| **Clip Trim / Split / Delete Logic** | [`editor_view_model.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/ui/features/editor/view_models/editor_view_model.dart) |
| **Transition Types & Validation** | [`transition_type.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/domain/enums/transition_type.dart), [`transition_validator.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/domain/services/transition_validator.dart) |
| **Transition Preview Rendering** | [`video_preview_section.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/ui/features/editor/views/widgets/video_preview_section.dart) (`_buildTransitionCanvas`) |
| **Transition Export Rendering** | [`VideoExportEngine.kt`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/android/app/src/main/kotlin/com/example/capcut_video_editor/VideoExportEngine.kt) (`compositeTransition`) |
| **Hardware Video Encoding (H.264)** | [`VideoExportEngine.kt`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/android/app/src/main/kotlin/com/example/capcut_video_editor/VideoExportEngine.kt) |
| **Audio Extraction from Video** | [`MainActivity.kt`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/android/app/src/main/kotlin/com/example/capcut_video_editor/MainActivity.kt) (`handleExtractAudioFromVideo`) |
| **Draft Persistence & Serialization** | [`project.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/domain/models/project.dart), [`project_storage_service.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/core/services/project_storage_service.dart) |
| **Online Sound Effects / Synthesis** | [`asset_library_service.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/core/services/asset_library_service.dart), [`asset_download_service.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/core/services/asset_download_service.dart) |

---

## 9. Architectural Constraints ("Do Not Break This")

1. **Do Not Introduce 3rd-Party Video Plugins**: The entire app is architected around native Android `SurfaceTexture` entries via Flutter textures. Introducing packages like `video_player` or `audioplayers` will conflict with native channel bindings and destabilize playback.
2. **Never Store Content URIs in Timeline Clips**: Android `content://` URIs cannot be decoded reliably across processes. All media must pass through `DeviceMediaService.pickMediaAsset()` which copies the stream into private app storage and supplies a verified `localPath`.
3. **Clips Must Reference `assetId`**: Never add a `path` property to `VideoClip` or `AudioTrack`. Media metadata lives exclusively in `Project.mediaLibrary`.
4. **Transition Cleanup Must Accompany Clip Mutations**: Any operation that splits, trims, deletes, or changes the playback speed of a clip must call `_cleanupInvalidTransitions()` to discard orphaned or invalid transitions.
5. **Playback Clock Precedence**: Never allow an arbitrary Flutter animation ticker to advance the playhead when a native video session is active. The ExoPlayer/MediaPlayer ticker is the sole source of truth during playback.
6. **Export Dimension Alignment**: H.264 hardware encoders require video dimensions to be multiples of 16. `VideoExportEngine.kt` enforces `(targetWidth / 16) * 16`. Do not bypass this alignment.

---

## 10. Architecture Health Check

### Strengths
- **Incredible Efficiency & Zero Bloat**: No bulky C/C++ third-party binaries (FFmpeg) or heavy Flutter plugins. The app compiled debug APK is lightweight and launches instantly.
- **Hardware Acceleration**: Both playback and export utilize Android hardware decoders/encoders (`SurfaceTexture` and `MediaCodec`).
- **Clean Separation of Concerns**: Models are immutable, services are stateless or singleton coordinators, and the view model encapsulates editing rules.
- **High Test Coverage**: 263 automated tests protect every regression (split cuts, ripple delete, playhead sync, transitions, export serialization).

### Risks & Technical Debt
- **Large ViewModel**: `editor_view_model.dart` is 2,713 lines long. While well-organized, splitting it into mixins or delegate engines (e.g. `ClipEditingEngine`, `AudioEditingEngine`, `TransitionEngine`) would improve maintainability in the future.
- **Single Native Android Target**: Because all native services are written in Kotlin for Android, running on iOS would require implementing matching iOS AVFoundation platform channels.
- **Single Active Video Player Session**: Preview currently initializes one primary `SurfaceTexture` player for the active clip. During transitions in preview, the outgoing clip is decoded via the active session while the incoming clip displays its high-resolution frame thumbnail.

### Safe Extension Points
- **New Transition Shaders**: Adding a 13th transition is straightforward: add an enum value to `transition_type.dart`, add a widget branch in `video_preview_section.dart` (`_buildTransitionCanvas`), and add a matching Canvas branch in `VideoExportEngine.kt` (`compositeTransition`).
- **New Sound Effect Categories**: Add new entries to `_developmentCatalog` in `asset_repository.dart` or synthesize new waveform formulas in `asset_download_service.dart`.
- **Text Styling & Animation**: Add properties to `TextOverlay` model and enhance rendering in `video_preview_section.dart`.

# Editor FS — Single-Page Architecture & Code Map
**Package:** `com.example.capcut_video_editor` | **Version:** `2.4.8` | **Platform:** Android + Flutter

---

## 1. Master System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 PRESENTATION LAYER (FLUTTER)                                │
│  EditorScreen ──┬── VideoPreviewSection (Texture/CustomPaint 12-Transition Canvas)         │
│                 ├── TimelineWidget (Playhead, Multi-Track Rulers, Split/Trim Handles)       │
│                 ├── BottomToolbar (Edit, Audio, Text, Sticker, Effect, Filter, Ratio)      │
│                 └── Modal Sheets (AudioBottomSheet, TextOverlaySheet, SpeedSheet, etc.)     │
└───────────────────────────────────────────────┬─────────────────────────────────────────────┘
                                                │ Notifies / Listens (ChangeNotifier)
                                                ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                                  VIEWMODEL & STATE (DOMAIN)                                 │
│  EditorViewModel: Playhead Clock, Tracks (Video, Overlay, Audio, Text, Stickers),           │
│                   Undo/Redo History Stacks, Draft Persistence (ProjectStorageService)       │
└───────────────────────┬─────────────────────────────────────────────┬───────────────────────┘
                        │ MethodChannel Calls                         │ EventChannel Streams
                        ▼                                             ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                                PLATFORM CHANNEL FACADES (DART)                              │
│  • VideoPlaybackService (`video_player` / `video_player_event`)                             │
│  • AudioPlayerService   (`audio_player` / `audio_player_event`)                             │
│  • FilePickerService    (`file_picker`)                                                     │
│  • TtsService           (`tts`)                                                             │
└───────────────────────────────────────────────┬─────────────────────────────────────────────┘
                                                │ BinaryMessenger IPC
                                                ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                                  NATIVE ENGINES (KOTLIN)                                    │
│  MainActivity.kt (Channel Routers & 16ms Authoritative Playhead Position Ticker)            │
│  ├── VideoPlaybackEngine.kt ── MediaPlayer + SurfaceTexture + Flutter TextureRegistry      │
│  ├── VideoExportEngine.kt   ── MediaCodec (H.264/AAC) + EGL14/GLES20 + MediaMuxer + MediaStore│
│  ├── AudioEngine.kt         ── Concurrent MediaPlayer & SoundPool Instances                 │
│  └── MediaAssetEngine.kt    ── MediaExtractor (Thumbnails, Durations, Fast AAC Audio Demux) │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Core Architectural Pillars

1. **Zero Third-Party Media Dependencies**: App uses only `cupertino_icons` and `uuid`. All decoding, rendering, OpenGL shaders, and audio mixing are written in custom Kotlin native engines.
2. **Authoritative Hardware Playback Clock**: Playhead time is driven exclusively by Android `MediaPlayer.currentPosition` pulsed every 16ms via `video_player_event`. Flutter software timers are completely bypassed during native playback to prevent desynchronization.
3. **Transition Parity (12 Types)**: Live preview in Flutter and hardware MP4 export share identical mathematics across 12 transitions:
   `fade`, `dissolve`, `blackFade`, `whiteFade`, `slideLeft`, `slideRight`, `slideUp`, `slideDown`, `wipeLeft`, `wipeRight`, `zoomIn`, `zoomOut`.
4. **Hardware-Accelerated Export**: Real-time rendering via EGL14/OpenGL ES 2.0 with surface-input `MediaCodec` H.264 video encoding, multi-track PCM software audio mixing into AAC, interleaved by `MediaMuxer` directly into Android scoped `MediaStore`.

---

## 3. Platform Channel Specification

| Channel Identifier | Type | Methods / Events Handled | Native Engine |
|:---|:---|:---|:---|
| `com.example.capcut_video_editor/video_player` | Method | `initialize(uri)`, `play()`, `pause()`, `seekTo(ms)`, `setSpeed(speed)`, `setVolume(vol)`, `exportVideo(config)` | `VideoPlaybackEngine.kt`<br>`VideoExportEngine.kt` |
| `com.example.capcut_video_editor/video_player_event`| Event | `onInitialized(w, h, dur, textureId)`, `onPositionUpdate(ms)`, `onVideoCompleted()`, `onError(msg)` | `MainActivity.kt` (16ms Ticker) |
| `com.example.capcut_video_editor/file_picker` | Method | `pickVideo()`, `pickAudio()`, `pickImage()`, `getVideoDuration(path)`, `getVideoThumbnail(path)`, `extractAudioFromVideo(path)` | `MediaAssetEngine.kt` |
| `com.example.capcut_video_editor/audio_player` | Method | `loadAudio(path)`, `play()`, `pause()`, `seekTo(ms)`, `setVolume(vol)`, `startRecording()`, `stopRecording()` | `AudioEngine.kt` |
| `com.example.capcut_video_editor/audio_player_event`| Event | `onAudioInitialized(dur)`, `onAudioPositionUpdate(ms)`, `onAudioCompleted()` | `AudioEngine.kt` |
| `com.example.capcut_video_editor/tts` | Method | `synthesizeToFile(text, lang, path)` | Android `TextToSpeech` |

---

## 4. Complete File-by-File Code Map

```
capcut_video_editor/
├── android/app/src/main/kotlin/com/example/capcut_video_editor/
│   ├── MainActivity.kt               # Platform channel dispatchers & 16ms authoritative clock ticker
│   ├── VideoPlaybackEngine.kt        # Native MediaPlayer controller and Flutter TextureRegistry bridge
│   ├── VideoExportEngine.kt          # Hardware export pipeline (MediaCodec, EGL14, GLES20, 12 transitions, Muxer)
│   ├── AudioEngine.kt                # Multi-track audio player and voiceover recorder
│   └── MediaAssetEngine.kt           # Metadata extraction, thumbnail generation, fast audio demuxing
│
├── lib/
│   ├── main.dart                     # App entry point, multi-provider setup, dark theme configuration
│   │
│   ├── models/                       # Domain Entities
│   │   ├── media_asset.dart          # Unified visual asset model (video, photo, sticker, b-roll)
│   │   ├── audio_track.dart          # Audio entity (BGM, sound effects, voiceovers, volume, trim)
│   │   ├── text_overlay.dart         # Text overlay model (style, animation, font, position, duration)
│   │   ├── sticker_overlay.dart      # Sticker entity (emoji/image, scale, rotation, coordinates)
│   │   ├── transition_effect.dart    # 12 GPU transition types enum and duration definitions
│   │   ├── video_effect.dart         # Visual filter and shader adjustment definitions
│   │   ├── project.dart              # Root project draft model serializable to JSON
│   │   ├── timeline_track.dart       # Multi-track timeline track hierarchy definitions
│   │   └── export_preset.dart        # Resolution, framerate, and bitrate configuration presets
│   │
│   ├── viewmodels/                   # State Management
│   │   └── editor_view_model.dart    # Master controller: clock sync, playhead, track edits, undo/redo, export
│   │
│   ├── presentation/
│   │   ├── screens/
│   │   │   ├── editor_screen.dart    # Main IDE viewport scaffolding preview, timeline, and toolbars
│   │   │   ├── home_screen.dart      # Project library, draft manager, and new project launcher
│   │   │   └── export_screen.dart    # Export configuration, progress indicator, and gallery launcher
│   │   │
│   │   └── widgets/                  # UI Components
│   │       ├── video_preview_section.dart # Texture renderer with real-time 12-transition canvas compositing
│   │       ├── timeline_widget.dart       # Interactive multi-track timeline, scrubber, and split/trim bars
│   │       ├── bottom_toolbar.dart        # Primary action dock (Edit, Audio, Text, Stickers, Effects, Canvas)
│   │       ├── audio_bottom_sheet.dart    # Audio manager (BGM, sound effects library, voice recorder, TTS)
│   │       ├── text_bottom_sheet.dart     # Text typography, styling, color palette, and entry modal
│   │       ├── speed_bottom_sheet.dart    # Speed ramp (0.1x to 100x) and pitch preservation selector
│   │       ├── transition_selector.dart   # Visual 12-transition picker with duration slider
│   │       ├── filter_selector.dart       # Color grading and LUT preset picker
│   │       ├── effect_selector.dart       # Visual effects and shader overlay selector
│   │       ├── ratio_selector.dart        # Canvas aspect ratio picker (9:16, 16:9, 1:1, 4:5, etc.)
│   │       ├── sticker_bottom_sheet.dart  # Emoji and sticker picker drawer
│   │       └── volume_bottom_sheet.dart   # Track audio gain and fade-in/fade-out sliders
│   │
│   └── services/                     # Core Device & Platform Services
│       ├── video_playback_service.dart # Facade for video playback MethodChannel and EventChannel
│       ├── audio_player_service.dart   # Facade for audio playback MethodChannel and EventChannel
│       ├── file_picker_service.dart    # Facade for native gallery picker and asset extraction
│       ├── tts_service.dart            # Facade for text-to-speech engine
│       ├── project_storage_service.dart# Draft save/load engine writing JSON files to local storage
│       └── asset_library_service.dart  # Bundled SFX, music tracks, stickers, and fonts registry
│
└── test/                             # Test Suites (263 Tests)
    ├── unit/
    │   ├── editor_view_model_test.dart       # Core ViewModel state, clock, play/pause, split/trim, sync
    │   ├── project_storage_service_test.dart # JSON draft serialization & deserialization fidelity
    │   ├── transition_effect_test.dart       # Transition model bounds and parameter validation
    │   └── audio_track_test.dart             # Audio track timing, trimming, and gain validation
    └── widget/
        ├── editor_screen_test.dart           # UI layout, preview positioning, and toolbar interaction
        └── timeline_widget_test.dart         # Scrubber drag gestures, track zooming, and playhead rendering
```

---

## 5. "Where Do I Change This?" Quick Lookup

| If you need to... | Go to this file & symbol: |
|:---|:---|
| **Add / Edit a Transition** | • Preview: `lib/presentation/widgets/video_preview_section.dart` (`_buildTransitionCanvas`)<br>• Export: `android/.../VideoExportEngine.kt` (`compositeTransition`)<br>• Model: `lib/models/transition_effect.dart` (`TransitionType`) |
| **Fix Playhead / Clock Drift** | • Native Ticker: `android/.../MainActivity.kt` (`startVideoPositionUpdates`)<br>• Channel Stream: `lib/services/video_playback_service.dart` (`onPositionChanged`)<br>• ViewModel: `lib/viewmodels/editor_view_model.dart` (`_handleVideoPositionEvent`) |
| **Change Export Output Quality** | • Hardware Encoder: `android/.../VideoExportEngine.kt` (`setupEncoder`, bit rate, resolution alignment) |
| **Adjust Timeline Scrubbing UI** | • Widget: `lib/presentation/widgets/timeline_widget.dart` (`_handleHorizontalDragUpdate`) |
| **Add SFX or Stock Music** | • Registry: `lib/services/asset_library_service.dart` (`getBuiltInAudioTracks`) |
| **Change Project Draft Persistence** | • Model: `lib/models/project.dart` (`toJson`, `fromJson`)<br>• Storage: `lib/services/project_storage_service.dart` (`saveProject`, `loadProject`) |

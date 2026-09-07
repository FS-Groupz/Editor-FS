# Editor FS — Complete File-by-File Code Map & Inventory

This document provides a comprehensive, developer-readable reference for all source files in the **Editor FS** project.

---

## 1. Application Entry & Presentation Layer (UI)

### `lib/main.dart`
- **LAYER**: Presentation / Bootstrap
- **PURPOSE**: Application entrypoint. Configures system chrome UI overlays (transparent status bar, dark navigation bar) and mounts the root widget.
- **MAIN CLASSES**: None (top-level `void main()`)
- **IMPORTANT FUNCTIONS**: `main()`
- **INPUTS**: Engine bootstrap
- **OUTPUTS**: Invokes `runApp(const CapCutVideoEditorApp())`
- **DEPENDS ON**: [`app.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/app.dart)
- **USED BY**: Flutter engine
- **DO NOT MODIFY WITHOUT UNDERSTANDING**: Modifying status bar settings affects edge-to-edge rendering on Android 14+.

---

### `lib/app.dart`
- **LAYER**: Presentation / Shell
- **PURPOSE**: Top-level `MaterialApp` declaration, applying `AppTheme.darkTheme` and hosting `HomeScreen`.
- **MAIN CLASSES**: `MahmasStudioApp`, `CapCutVideoEditorApp` (type alias)
- **IMPORTANT FUNCTIONS**: `build()`
- **INPUTS**: None
- **OUTPUTS**: `MaterialApp` widget tree
- **DEPENDS ON**: [`app_theme.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/core/theme/app_theme.dart), [`home_screen.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/ui/features/home/views/home_screen.dart)
- **USED BY**: [`main.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/main.dart), test suites
- **DO NOT MODIFY WITHOUT UNDERSTANDING**: Preserves `CapCutVideoEditorApp` typedef for widget test compatibility.

---

### `lib/ui/features/home/views/home_screen.dart`
- **LAYER**: Presentation / Screen
- **PURPOSE**: Drafts dashboard and project management. Lists all saved projects from disk with video thumbnails, clip counts, and durations.
- **MAIN CLASSES**: `HomeScreen`, `_HomeScreenState`
- **IMPORTANT FUNCTIONS**: `_loadProjects()`, `_handleCreateNewProject()`, `_handleOpenProject()`, `_handleDeleteProject()`
- **INPUTS**: None
- **OUTPUTS**: Renders hero "New Project" button and recent projects list
- **DEPENDS ON**: [`project_storage_service.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/core/services/project_storage_service.dart), [`editor_screen.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/ui/features/editor/views/editor_screen.dart)
- **USED BY**: [`app.dart`](file:///C:/Users/almas/.gemini/antigravity/scratch/capcut_video_editor/lib/app.dart)
- **DO NOT MODIFY WITHOUT UNDERSTANDING**: Deleting a project removes its `{id}.json` file from disk via `ProjectStorageService.deleteProject()`.

---

### `lib/ui/features/editor/view_models/editor_view_model.dart`
- **LAYER**: State / Domain Engine (2,713 lines)
- **PURPOSE**: Central editing state engine, timeline controller, and coordinator for all media, playback, transitions, and export operations.
- **MAIN CLASSES**: `EditorViewModel`, `TransitionMutationResult`, `ActiveTransitionState`, `_EditorSnapshot`
- **IMPORTANT FUNCTIONS**:
  - Playback: `play()`, `pause()`, `seekTo()`, `seekBy()`, `_handleVideoPositionEvent()`, `_handleVideoCompletionEvent()`
  - Clip Editing: `addMediaAssetToTimeline()`, `splitSelectedClip()`, `trimSelectedClipStart()`, `trimSelectedClipEnd()`, `trimLeftAtPlayhead()`, `trimRightAtPlayhead()`
  - Delete: `deleteSelectedClip()`, `rippleDeleteSelectedClip()`, `deleteClipAt()`
  - Audio: `addAudioTrack()`, `splitAudioTrack()`, `trimAudioTrack()`, `setAudioVolume()`, `extractAudioFromSelectedClip()`
  - Transitions: `addTransition()`, `editTransition()`, `removeTransition()`, `_cleanupInvalidTransitions()`
  - State & History: `undo()`, `redo()`, `_recordSnapshot()`, `_autoSaveProject()`
  - Export: `exportVideoToGallery()`, `cancelExport()`
- **INPUTS**: User gestures from UI widgets, stream events from `VideoPlaybackService`
- **OUTPUTS**: Notifies listeners (`ChangeNotifier`), updates `currentProject`, auto-saves to disk
- **DEPENDS ON**: `Project`, `MediaAsset`, `VideoClip`, `AudioTrack`, `Transition`, `TransitionValidator`, `VideoPlaybackService`, `AudioPlaybackService`, `DeviceMediaService`, `ProjectStorageService`
- **USED BY**: `EditorScreen`, `VideoPreviewSection`, `TimelineSection`, `ActionToolbar`, `BottomToolSelector`, all drawer widgets
- **DO NOT MODIFY WITHOUT UNDERSTANDING**:
  - `Project.mediaLibrary` is the authoritative source for media assets.
  - Video playback position updates arriving via `_handleVideoPositionEvent` are the authoritative timeline clock.
  - Clip mutations must call `_cleanupInvalidTransitions()`.

---

### `lib/ui/features/editor/views/editor_screen.dart`
- **LAYER**: Presentation / Screen
- **PURPOSE**: Full-screen video editor layout. Hosts the preview viewport, action toolbar, multi-layer timeline, bottom tool selector, and category drawers.
- **MAIN CLASSES**: `EditorScreen`, `_EditorScreenState`
- **IMPORTANT FUNCTIONS**: `_initViewModel()`, `_buildActiveDrawer()`
- **INPUTS**: `Project initialProject`
- **OUTPUTS**: Scaffold with dark theme and editor layout
- **DEPENDS ON**: `EditorViewModel`, `TopNavigationBar`, `VideoPreviewSection`, `TimelineSection`, `ActionToolbar`, `BottomToolSelector`, drawer widgets
- **USED BY**: `HomeScreen`
- **DO NOT MODIFY WITHOUT UNDERSTANDING**: Initializes `EditorViewModel(project: widget.initialProject)` and disposes it on exit.

---

### `lib/ui/features/editor/views/widgets/video_preview_section.dart`
- **LAYER**: Presentation / Widget
- **PURPOSE**: Live video canvas, aspect-ratio viewport, Flutter Texture surface rendering, color grading LUTs, adjustments, PIP overlays, subtitles, and 12-type transition compositing.
- **MAIN CLASSES**: `VideoPreviewSection`, `_VideoPreviewSectionState`
- **IMPORTANT FUNCTIONS**:
  - `_syncPlayerWithModel()`: Manages `VideoPlayerSession` creation, play, pause, seek, speed, and volume.
  - `_buildTransitionCanvas()`: Renders 12 transition types (`fade`, `dissolve`, `blackFade`, `whiteFade`, `slideLeft`, `slideRight`, `slideUp`, `slideDown`, `wipeLeft`, `wipeRight`, `zoomIn`, `zoomOut`).
  - `_buildSingleClipVisual()`: Renders Flutter `Texture(textureId)` for active video, image file for photo, or cached frame thumbnail.
- **INPUTS**: `EditorViewModel viewModel`
- **OUTPUTS**: Interactive video viewport with play/pause touch overlays and timecode pill
- **DEPENDS ON**: `VideoPlaybackService`, `VideoPlayerSession`, `EditorViewModel`, `ActiveTransitionState`, `TimeFormatter`
- **USED BY**: `EditorScreen`
- **DO NOT MODIFY WITHOUT UNDERSTANDING**: Split clips on the same media file trigger `seekTo` even while playing to seamlessly transition sub-clips.

---

### `lib/ui/features/editor/views/widgets/timeline_section.dart`
- **LAYER**: Presentation / Widget
- **PURPOSE**: CapCut-style multi-layer interactive timeline with universal vertical scrolling, pinned horizontal ruler, dynamic layer rows, and playhead indicator.
- **MAIN CLASSES**: `TimelineSection`, `_TimelineSectionState`
- **IMPORTANT FUNCTIONS**: `_syncRulerScroll()`, `_onViewModelChanged()`, `_checkAndAutoScrollToNewLayer()`
- **INPUTS**: `EditorViewModel viewModel`
- **OUTPUTS**: Vertically scrollable timeline tracks (Video, Audio, Text, Stickers, Overlays)
- **DEPENDS ON**: `TimelineRuler`, `TimelineClipItem`, `AudioTrackItem`, `TransitionSelectionSheet`, `MediaPickerSheet`
- **USED BY**: `EditorScreen`
- **DO NOT MODIFY WITHOUT UNDERSTANDING**: Ruler scroll controller and horizontal timeline scroll controller are synchronized bidirectionally.

---

### `lib/ui/features/editor/views/widgets/timeline_ruler.dart`
- **LAYER**: Presentation / Widget
- **PURPOSE**: Pinned timecode ruler rendering second markings (`00:00`, `00:02`, `00:04`) and adaptive subdivision tick marks.
- **MAIN CLASSES**: `TimelineRuler`, `_RulerPainter`
- **IMPORTANT FUNCTIONS**: `paint()`
- **INPUTS**: `totalDurationInSeconds`, `pixelsPerSecond`, `ScrollController`
- **OUTPUTS**: CustomPaint canvas ruler
- **DEPENDS ON**: `AppColors`, `TimeFormatter`
- **USED BY**: `TimelineSection`

---

### `lib/ui/features/editor/views/widgets/timeline_clip_item.dart`
- **LAYER**: Presentation / Widget
- **PURPOSE**: Visual representation of a video/photo clip on the main timeline track. Renders yellow selection border, trim handles, title pill, and cached frame thumbnail.
- **MAIN CLASSES**: `TimelineClipItem`
- **IMPORTANT FUNCTIONS**: `build()`, drag handle gesture listeners
- **INPUTS**: `VideoClip clip`, `MediaAsset? asset`, `isSelected`, `pixelsPerSecond`
- **OUTPUTS**: Timeline clip container with gesture detectors
- **DEPENDS ON**: `VideoClip`, `MediaAsset`, `AppColors`
- **USED BY**: `TimelineSection`

---

### `lib/ui/features/editor/views/widgets/audio_track_item.dart`
- **LAYER**: Presentation / Widget
- **PURPOSE**: Audio track container on the timeline rendering audio title, duration, volume state, and normalized waveform visualization bars.
- **MAIN CLASSES**: `AudioTrackItem`, `_WaveformPainter`
- **IMPORTANT FUNCTIONS**: `build()`, `paint()`
- **INPUTS**: `AudioTrack track`, `isSelected`, `pixelsPerSecond`
- **OUTPUTS**: Colored audio bar with waveform graphics
- **DEPENDS ON**: `AudioTrack`, `AppColors`
- **USED BY**: `TimelineSection`

---

### `lib/ui/features/editor/views/widgets/action_toolbar.dart`
- **LAYER**: Presentation / Widget
- **PURPOSE**: Contextual editing toolbar. Dynamically adapts buttons based on selection: Play/Pause, Split, Trim Left/Right, Delete, Ripple Delete, Extract Audio, Speed, Volume, Duplicate.
- **MAIN CLASSES**: `ActionToolbar`
- **IMPORTANT FUNCTIONS**: `build()`
- **INPUTS**: `EditorViewModel viewModel`
- **OUTPUTS**: Horizontal icon button toolbar
- **DEPENDS ON**: `EditorViewModel`, `ToolActionType`
- **USED BY**: `EditorScreen`

---

### `lib/ui/features/editor/views/widgets/bottom_tool_selector.dart`
- **LAYER**: Presentation / Widget
- **PURPOSE**: Bottom category navigation bar (Edit, Audio, Text, Stickers, Effects, Filters, Adjust).
- **MAIN CLASSES**: `BottomToolSelector`
- **IMPORTANT FUNCTIONS**: `build()`
- **INPUTS**: `EditorViewModel viewModel`
- **OUTPUTS**: Bottom category tab strip
- **DEPENDS ON**: `EditorViewModel`, `EditorCategory`
- **USED BY**: `EditorScreen`

---

### `lib/ui/features/editor/views/widgets/transition_selection_sheet.dart`
- **LAYER**: Presentation / Modal
- **PURPOSE**: Modal bottom sheet for browsing and selecting from 12 transition types. Includes live duration slider (0.1s – 2.0s), real-time validation error messaging, and "Apply to All" option.
- **MAIN CLASSES**: `TransitionSelectionSheet`
- **IMPORTANT FUNCTIONS**: `_applyTransition()`, `_validate()`
- **INPUTS**: `EditorViewModel viewModel`, `String leftClipId`, `String rightClipId`
- **OUTPUTS**: Calls `viewModel.addTransition()` or `editTransition()`
- **DEPENDS ON**: `Transition`, `TransitionType`, `TransitionValidator`, `EditorViewModel`
- **USED BY**: `TimelineSection` (tapping transition icon between clips)

---

### `lib/ui/features/editor/views/widgets/export_modal_sheet.dart`
- **LAYER**: Presentation / Modal
- **PURPOSE**: Video export configuration modal. Allows selection of resolution (720p, 1080p, 2K, 4K), frame rate (24, 30, 50, 60 fps), and displays real-time export progress.
- **MAIN CLASSES**: `ExportModalSheet`
- **IMPORTANT FUNCTIONS**: `_startExport()`, `_openGallery()`
- **INPUTS**: `EditorViewModel viewModel`
- **OUTPUTS**: Invokes `viewModel.exportVideoToGallery()`
- **DEPENDS ON**: `ExportSettings`, `ExportResolution`, `EditorViewModel`
- **USED BY**: `TopNavigationBar`

---

### `lib/ui/features/editor/views/widgets/media_picker_sheet.dart`
- **LAYER**: Presentation / Modal
- **PURPOSE**: Media selection sheet. Displays device photo/video selection buttons that invoke the native Android Photo Picker.
- **MAIN CLASSES**: `MediaPickerSheet`
- **IMPORTANT FUNCTIONS**: `_pickMedia()`
- **INPUTS**: `EditorViewModel viewModel`
- **OUTPUTS**: Invokes `DeviceMediaService.pickMediaAsset()`
- **DEPENDS ON**: `DeviceMediaService`, `EditorViewModel`
- **USED BY**: `TimelineSection`, `ActionToolbar`

---

### `lib/ui/features/editor/views/widgets/duplicate_options_sheet.dart`
- **LAYER**: Presentation / Modal
- **PURPOSE**: Options dialog when duplicating a clip: Duplicate to Main Track vs Duplicate to Picture-in-Picture (PIP) Overlay.
- **MAIN CLASSES**: `DuplicateOptionsSheet`
- **INPUTS**: `EditorViewModel viewModel`, `VideoClip clip`
- **OUTPUTS**: Calls `viewModel.duplicateClipToMainTimeline()` or `duplicateClipToOverlay()`
- **DEPENDS ON**: `EditorViewModel`, `VideoClip`
- **USED BY**: `ActionToolbar`

---

### `lib/ui/features/editor/views/widgets/drawers/`
- **`edit_drawer.dart`**: Sub-panel for speed scaling (0.25x – 4.0x), volume slider (0% – 100%), rotation (90° increments), and horizontal/vertical flipping.
- **`audio_drawer.dart`**: Tabbed sound effects browser (Whoosh, Impact, Glitch, Camera, Chime), music picker, and volume controls.
- **`text_drawer.dart`**: Text input field, color swatches, font size slider, and Text-To-Speech (TTS) voice generation button.
- **`stickers_drawer.dart`**: Emoji and sticker overlay library selector.
- **`effects_drawer.dart`**: Video effect presets (Glitch, VHS, Shake, Blur, RGB Split).
- **`filters_drawer.dart`**: Color grading presets (Warm, Cool, Vintage, Cyberpunk, B&W) with intensity slider.
- **`adjust_drawer.dart`**: Manual color sliders (Brightness, Contrast, Saturation, Exposure, Warmth).

---

## 2. Domain Models & Enums

### `lib/domain/models/project.dart`
- **LAYER**: Domain / Model
- **PURPOSE**: Top-level immutable entity representing a complete video editing project. Contains all clips, tracks, transitions, filters, settings, and the canonical `mediaLibrary`.
- **MAIN CLASSES**: `Project`
- **IMPORTANT FUNCTIONS**: `toJson()`, `fromJson()`, `copyWith()`, `durationInSeconds`
- **DEPENDS ON**: `VideoClip`, `AudioTrack`, `Transition`, `MediaAsset`, `TextOverlay`, `OverlayClip`, `EditorFilter`, `ColorAdjustments`
- **USED BY**: `EditorViewModel`, `ProjectStorageService`, `HomeScreen`
- **DO NOT MODIFY WITHOUT UNDERSTANDING**: `Project` is the primary serialization root for JSON draft persistence.

---

### `lib/domain/models/media_asset.dart`
- **LAYER**: Domain / Model
- **PURPOSE**: Immutable entity representing an imported media file (Video, Photo, or Audio).
- **FIELDS**: `id`, `type` (`video`/`photo`/`audio`), `name`, `uri`, `localPath`, `duration`, `sizeBytes`, `thumbnailPath`, `createdAt`
- **IMPORTANT FUNCTIONS**: `toJson()`, `fromJson()`, `copyWith()`
- **USED BY**: `Project.mediaLibrary`, `VideoClip`, `AudioTrack`, `DeviceMediaService`, `EditorViewModel`
- **DO NOT MODIFY WITHOUT UNDERSTANDING**: `localPath` must always point to a verified file in app private storage (`filesDir/media/`).

---

### `lib/domain/models/video_clip.dart`
- **LAYER**: Domain / Model
- **PURPOSE**: Represents a segment on the main video track. References `assetId` in `mediaLibrary`.
- **FIELDS**: `id`, `assetId`, `title`, `originalDuration`, `trimStart`, `trimEnd`, `speed`, `volume`, `rotationDegrees`, `flipHorizontal`, `flipVertical`
- **IMPORTANT FUNCTIONS**: `activeDuration`, `durationInSeconds` (computes `(trimEnd - trimStart) / speed`)
- **USED BY**: `Project.videoClips`, `TimelineClipItem`, `VideoExportEngine`

---

### `lib/domain/models/audio_track.dart`
- **LAYER**: Domain / Model
- **PURPOSE**: Represents an independent audio track on the timeline. References `assetId` in `mediaLibrary`.
- **FIELDS**: `id`, `assetId`, `name`, `artist`, `startTime`, `duration`, `trimStart`, `trimEnd`, `volume`, `speed`, `isMuted`, `waveformPoints`
- **IMPORTANT FUNCTIONS**: `effectiveDuration`, `durationInSeconds`, `endTimeInSeconds`
- **USED BY**: `Project.audioTracks`, `AudioTrackItem`, `VideoExportEngine`

---

### `lib/domain/models/transition.dart`
- **LAYER**: Domain / Model
- **PURPOSE**: Represents a visual transition effect between two adjacent video clips.
- **FIELDS**: `id`, `type` (`TransitionType`), `duration` (seconds, double), `leftClipId`, `rightClipId`, `enabled`
- **IMPORTANT FUNCTIONS**: `toJson()`, `fromJson()`, `copyWith()`
- **USED BY**: `Project.transitions`, `TransitionValidator`, `TransitionSelectionSheet`, `VideoPreviewSection`, `VideoExportEngine`

---

### `lib/domain/services/transition_validator.dart`
- **LAYER**: Domain / Business Rules Service
- **PURPOSE**: Validates transitions against project state to ensure clip adjacency, duration limits (0.1s to 2.0s), and trim bounds.
- **MAIN CLASSES**: `TransitionValidator`
- **IMPORTANT FUNCTIONS**: `validate(Transition)`, `validateAll(List<Transition>)`, `_usableDuration(VideoClip)`
- **RULES ENFORCED**:
  1. Left clip and Right clip must exist.
  2. `rightIndex == leftIndex + 1` (strict timeline adjacency).
  3. `0.1 <= duration <= 2.0`.
  4. `duration <= usableLeftDuration` and `duration <= usableRightDuration`.
- **USED BY**: `EditorViewModel`, `TransitionSelectionSheet`

---

### `lib/domain/models/asset.dart`
- **LAYER**: Domain / Model
- **PURPOSE**: Entity for downloadable sound effects and transition assets with licensing, download URLs, and download lifecycle states.
- **MAIN CLASSES**: `Asset`, `AssetLicense`, `DownloadProgress`, `AssetType`, `DownloadState`
- **USED BY**: `AssetLibraryService`, `AssetDownloadService`, `AssetStorageService`, `AssetRepository`

---

### `lib/domain/enums/`
- **`transition_type.dart`**: `enum TransitionType { none, fade, dissolve, blackFade, whiteFade, slideLeft, slideRight, slideUp, slideDown, wipeLeft, wipeRight, zoomIn, zoomOut }`
- **`aspect_ratio_preset.dart`**: `ratio9x16`, `ratio1x1`, `ratio16x9`, `ratio4x3`, `ratio3x4`, `ratio21x9`
- **`export_resolution.dart`**: `res720p`, `res1080p`, `res2k`, `res4k`; `ExportFps` (24, 30, 50, 60)
- **`tool_action_type.dart`**: Actions for contextual toolbars

---

## 3. Core Services & Platform Bridges

### `lib/core/services/device_media_service.dart`
- **LAYER**: Core / Platform Bridge
- **PURPOSE**: Platform channel bridge (`com.mahmas.studio/file_picker`) for media picking, permissions, audio extraction, and video export.
- **IMPORTANT FUNCTIONS**:
  - `pickMediaAsset({String type})`: Launches native picker and returns `MediaAsset` with cached `localPath`.
  - `pickAudioAsset()`: Launches audio picker and returns `MediaAsset`.
  - `extractAudioFromVideo({required String videoPath, String? outputName})`: Extracts native audio track to `.m4a`.
  - `renderAndExportVideo({required Project project, required ExportSettings settings, ...})`: Serializes timeline payload and calls native `VideoExportEngine`.
  - `saveVideoToGallery({required String filePath, String? fileName})`: Saves exported MP4 into Android MediaStore.
- **DEPENDS ON**: `MethodChannel('com.mahmas.studio/file_picker')`
- **USED BY**: `EditorViewModel`, `MediaPickerSheet`, `AudioDrawer`

---

### `lib/core/services/video_playback_service.dart`
- **LAYER**: Core / Media Service
- **PURPOSE**: Central service controlling native hardware video decoding via Flutter `Texture` and platform channel `com.mahmas.studio/video_player`.
- **IMPORTANT FUNCTIONS**:
  - `createSession(String localPath)`: Calls native `init`, creates `SurfaceTextureEntry`, returns `VideoPlayerSession`.
  - `play(int textureId, {Duration? position})`: Starts playback and position ticker.
  - `pause(int textureId)`: Pauses decoder.
  - `seekTo(int textureId, Duration position)`: Seeks decoder.
  - `setVolume()`, `setSpeed()`, `setLooping()`: Adjusts native player parameters.
  - `disposeSession(int textureId)`: Frees native player and texture entry.
- **STREAMS**:
  - `onPositionChanged`: Synchronous broadcast stream (`StreamController.broadcast(sync: true)`) emitting `VideoPositionEvent`.
  - `onCompletion`: Synchronous broadcast stream emitting on `Player.STATE_ENDED`.
- **USED BY**: `EditorViewModel`, `VideoPreviewSection`

---

### `lib/core/services/audio_playback_service.dart`
- **LAYER**: Core / Media Service
- **PURPOSE**: Service controlling separate background audio playback via `com.mahmas.studio/audio_player`.
- **IMPORTANT FUNCTIONS**: `initialize()`, `play()`, `pause()`, `seekTo()`, `setVolume()`, `setSpeed()`, `dispose()`
- **USED BY**: `EditorViewModel`, `AssetLibraryService`

---

### `lib/core/services/project_storage_service.dart`
- **LAYER**: Core / Persistence Service
- **PURPOSE**: Manages JSON draft persistence in app private storage (`context.filesDir/projects/{id}.json`).
- **IMPORTANT FUNCTIONS**: `getAllProjects()`, `getProjectById()`, `saveProject()`, `deleteProject()`, `createNewProject()`
- **USED BY**: `HomeScreen`, `EditorViewModel`

---

### `lib/core/services/asset_library_service.dart`
- **LAYER**: Core / Asset Management Service
- **PURPOSE**: Coordinates sound effects browsing, searching, preview playback, and downloading.
- **IMPORTANT FUNCTIONS**: `initialize()`, `refresh()`, `downloadAsset()`, `cancelDownload()`, `deleteAsset()`, `playPreview()`, `stopPreview()`
- **USED BY**: `AudioDrawer`

---

### `lib/core/services/asset_download_service.dart`
- **LAYER**: Core / Network & Audio Synthesis Service
- **PURPOSE**: Manages asset downloads with progress streaming and incorporates an **offline 16-bit 44.1kHz PCM RIFF WAV synthesizer** for generating authentic audio waveforms when offline.
- **IMPORTANT FUNCTIONS**: `downloadAsset()`, `cancelDownload()`, `_synthesizeAssetAudio()`, `_encodePcmWav()`
- **USED BY**: `AssetLibraryService`

---

### `lib/core/services/asset_storage_service.dart`
- **LAYER**: Core / Storage Service
- **PURPOSE**: Persistent disk registry and manifest manager for downloaded sound effects (`context.filesDir/asset_library/downloaded_assets.json`).
- **IMPORTANT FUNCTIONS**: `initialize()`, `getAllDownloadedAssets()`, `isAssetDownloaded()`, `saveDownloadedAsset()`, `deleteDownloadedAsset()`
- **USED BY**: `AssetLibraryService`, `AssetDownloadService`

---

### `lib/core/services/tts_service.dart`
- **LAYER**: Core / Accessibility & Speech Service
- **PURPOSE**: Platform channel bridge (`com.mahmas.studio/tts`) for Android native `TextToSpeech` voice announcements and subtitle synthesis.
- **IMPORTANT FUNCTIONS**: `speak(String text)`, `stop()`, `toggle()`, `announce()`
- **USED BY**: `TextDrawer`, `EditorViewModel`

---

## 4. Native Android Layer (Kotlin)

### `android/app/src/main/kotlin/com/example/capcut_video_editor/MainActivity.kt`
- **LAYER**: Platform / Native Host (1,226 lines)
- **PURPOSE**: Main Android activity hosting the Flutter engine, platform channels, ExoPlayer/MediaPlayer surface textures, media picking, and audio extraction.
- **KEY COMPONENTS**:
  - `VideoPlayerHolder`: Holds `MediaPlayer`, `TextureRegistry.SurfaceTextureEntry`, `Surface`, and `positionRunnable`.
  - `startVideoPositionUpdates()`: 16ms Looper Runnable emitting `onPositionUpdate` events to Flutter while playing.
  - `setOnSeekCompleteListener`: Handles seeking with `MediaPlayer.SEEK_CLOSEST` and notifies Flutter.
  - `setOnCompletionListener`: Dispatches `onCompletion` event to Flutter.
  - `handlePickMedia()`: Opens system picker, streams URI to `filesDir/media/`, extracts frame thumbnails with `MediaMetadataRetriever`.
  - `handleExtractAudioFromVideo()`: Demuxes audio tracks to standalone `.m4a` files using `MediaExtractor` and `MediaMuxer`.
  - `handleSaveVideoToGallery()`: Registers MP4 into `MediaStore.Video.Media` (API 29+) or scans via `MediaScannerConnection`.
  - `handleRenderAndExportVideo()`: Deserializes export payload and launches `VideoExportEngine`.

---

### `android/app/src/main/kotlin/com/example/capcut_video_editor/VideoExportEngine.kt`
- **LAYER**: Platform / Hardware Video Export Engine (888 lines)
- **PURPOSE**: Hardware-accelerated video rendering engine using Android `MediaCodec` (H.264), EGL 14, OpenGL ES 2.0 `CodecInputSurface`, and Canvas-based transition compositing.
- **KEY COMPONENTS**:
  - `CodecInputSurface`: Wraps `MediaCodec.createInputSurface()`, creates EGL display, context, and window surface, compiles vertex/fragment shaders.
  - `exportVideo()`: Main export pipeline: computes frames, encodes frames at specified resolution/FPS/bitrate, composites transitions, muxes audio, and registers to MediaStore.
  - `compositeTransition()`: Implements all 12 transition types (`fade`, `dissolve`, `blackFade`, `whiteFade`, `slideLeft`, `slideRight`, `slideUp`, `slideDown`, `wipeLeft`, `wipeRight`, `zoomIn`, `zoomOut`) on Android `Canvas`.
  - `registerToMediaStore()`: Places exported video into `Movies/MahmasStudio`.

---

## 5. Test Infrastructure Map

| Test File | Layer | What It Validates & Protects |
|---|---|---|
| `playhead_controller_sync_test.dart` | Unit / Sync | Authoritative controller clock, fallback timer cancellation, exact completion clamping, boundary overshoot prevention, multi-clip handoff. |
| `editor_view_model_transition_test.dart` | Unit / Transitions | Transition validator, clip adjacency constraints, duration bounds, `TransitionMutationResult`. |
| `export_transition_test.dart` | Unit / Export | Export payload structure, transition duration conversion, trim and speed calculations. |
| `transition_rendering_widget_test.dart` | Widget / Transitions | Live widget rendering of all 12 transition shaders inside `video_preview_section.dart`. |
| `unit/delete_ripple_engine_test.dart` | Unit / Editing | Single clip delete, ripple delete leftward clip shifting, secondary layer anchoring. |
| `unit/split_cut_engine_test.dart` | Unit / Editing | Split cut at playhead, source-time offset calculation, adjacent transition cleanup. |
| `unit/audio_extraction_test.dart` | Unit / Audio | Audio extraction result parsing, automatic `AudioTrack` generation on timeline. |
| `unit/timeline_multilayer_test.dart` | Unit / Timeline | Multi-layer layout, audio tracks, text overlays, auto-scroll triggers. |
| `unit/asset_library_test.dart` | Unit / Assets | Sound effects search, downloading, manifest persistence, PCM WAV synthesis. |
| `unit/editor_view_model_test.dart` | Unit / ViewModel | State actions, undo/redo stacks, project loading, end of playback lifecycle. |
| `unit/time_formatter_test.dart` | Unit / Utility | Formats seconds into `MM:SS` and `MM:SS.ms` timecode strings. |
| `widget/editor_screen_test.dart` | Widget / Screen | EditorScreen UI widget tree, toolbar interaction, drawer visibility. |
| `widget_test.dart` | Widget / App | Smoke test ensuring clean application launch. |

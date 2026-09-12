import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:capcut_video_editor/domain/enums/aspect_ratio_preset.dart';
import 'package:capcut_video_editor/domain/enums/export_resolution.dart';
import 'package:capcut_video_editor/domain/models/export_settings.dart';
import 'package:capcut_video_editor/domain/models/project.dart';
import 'package:capcut_video_editor/domain/models/video_clip.dart';
import 'package:capcut_video_editor/core/services/device_media_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 7.1 - Export FPS Metadata & Resolution Tests', () {
    test('ExportFps enum exposes correct integer fpsNumber', () {
      expect(ExportFps.fps24.fpsNumber, 24);
      expect(ExportFps.fps30.fpsNumber, 30);
      expect(ExportFps.fps50.fpsNumber, 50);
      expect(ExportFps.fps60.fpsNumber, 60);
    });

    test('DeviceMediaService.renderAndExportVideo preserves 1080x1920 portrait dimensions without 16-px clipping', () async {
      const clip = VideoClip(
        id: 'clip_p71_1',
        assetId: 'asset_p71_1',
        title: 'Test Clip',
        originalDuration: Duration(seconds: 5),
        trimStart: Duration.zero,
        trimEnd: Duration(seconds: 5),
        speed: 1.0,
        previewGradient: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
      );

      final project = Project(
        id: 'proj_p71_1',
        name: 'Phase 7.1 Test',
        videoClips: [clip],
        aspectRatio: AspectRatioPreset.ratio9x16,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const settings30 = ExportSettings(
        resolution: ExportResolution.res1080p,
        fps: ExportFps.fps30,
      );

      final result30 = await DeviceMediaService.renderAndExportVideo(
        project: project,
        settings: settings30,
        assets: [],
      );

      expect(result30['success'], isTrue);
      expect(result30['fps'], 30);
      expect(result30['width'], 1080);
      expect(result30['height'], 1920);
      expect(result30['codec'], 'H.264 / AVC');

      const settings60 = ExportSettings(
        resolution: ExportResolution.res1080p,
        fps: ExportFps.fps60,
      );

      final result60 = await DeviceMediaService.renderAndExportVideo(
        project: project,
        settings: settings60,
        assets: [],
      );

      expect(result60['success'], isTrue);
      expect(result60['fps'], 60);
      expect(result60['width'], 1080);
      expect(result60['height'], 1920);
    });

    test('DeviceMediaService.renderAndExportVideo respects 720p 24fps and 4k 60fps configurations', () async {
      const clip = VideoClip(
        id: 'clip_p71_2',
        assetId: 'asset_p71_2',
        title: 'Test Clip 2',
        originalDuration: Duration(seconds: 3),
        trimStart: Duration.zero,
        trimEnd: Duration(seconds: 3),
        speed: 1.0,
        previewGradient: [Color(0xFFFC466B), Color(0xFF3F5EFB)],
      );

      final project = Project(
        id: 'proj_p71_2',
        name: 'Phase 7.1 Test 2',
        videoClips: [clip],
        aspectRatio: AspectRatioPreset.ratio16x9,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const settings720p24 = ExportSettings(
        resolution: ExportResolution.res720p,
        fps: ExportFps.fps24,
      );

      final res720 = await DeviceMediaService.renderAndExportVideo(
        project: project,
        settings: settings720p24,
        assets: [],
      );

      expect(res720['width'], 1280);
      expect(res720['height'], 720);
      expect(res720['fps'], 24);

      const settings4k60 = ExportSettings(
        resolution: ExportResolution.res4k,
        fps: ExportFps.fps60,
      );

      final res4k = await DeviceMediaService.renderAndExportVideo(
        project: project,
        settings: settings4k60,
        assets: [],
      );

      expect(res4k['width'], 3840);
      expect(res4k['height'], 2160);
      expect(res4k['fps'], 60);
    });
  });
}

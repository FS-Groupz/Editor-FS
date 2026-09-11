import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:capcut_video_editor/core/theme/app_theme.dart';
import 'package:capcut_video_editor/ui/features/home/views/home_screen.dart';

/// Root application widget
class EditorFSApp extends StatelessWidget {
  const EditorFSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Editor FS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}

// Backward compatibility aliases for existing test runners and entry points
typedef MahmasStudioApp = EditorFSApp;
typedef CapCutVideoEditorApp = EditorFSApp;

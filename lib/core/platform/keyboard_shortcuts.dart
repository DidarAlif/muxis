import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class NextTrackIntent extends Intent {
  const NextTrackIntent();
}

class PreviousTrackIntent extends Intent {
  const PreviousTrackIntent();
}

class VolumeUpIntent extends Intent {
  const VolumeUpIntent();
}

class VolumeDownIntent extends Intent {
  const VolumeDownIntent();
}

class CommandPaletteIntent extends Intent {
  const CommandPaletteIntent();
}

class SearchIntent extends Intent {
  const SearchIntent();
}

class OpenLibraryIntent extends Intent {
  const OpenLibraryIntent();
}

class MuxisShortcuts {
  MuxisShortcuts._();

  static final Map<ShortcutActivator, Intent> desktopShortcuts = {
    const SingleActivator(LogicalKeyboardKey.space): const PlayPauseIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
        const NextTrackIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
        const PreviousTrackIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowUp, control: true):
        const VolumeUpIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowDown, control: true):
        const VolumeDownIntent(),
    const SingleActivator(LogicalKeyboardKey.keyK, control: true):
        const CommandPaletteIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF, control: true):
        const SearchIntent(),
    const SingleActivator(LogicalKeyboardKey.keyL, control: true):
        const OpenLibraryIntent(),
  };
}

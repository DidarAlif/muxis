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
    const SingleActivator(LogicalKey.space): const PlayPauseIntent(),
    const SingleActivator(LogicalKey.arrowRight, control: true):
        const NextTrackIntent(),
    const SingleActivator(LogicalKey.arrowLeft, control: true):
        const PreviousTrackIntent(),
    const SingleActivator(LogicalKey.arrowUp, control: true):
        const VolumeUpIntent(),
    const SingleActivator(LogicalKey.arrowDown, control: true):
        const VolumeDownIntent(),
    const SingleActivator(LogicalKey.keyK, control: true):
        const CommandPaletteIntent(),
    const SingleActivator(LogicalKey.keyF, control: true): const SearchIntent(),
    const SingleActivator(LogicalKey.keyL, control: true):
        const OpenLibraryIntent(),
  };
}

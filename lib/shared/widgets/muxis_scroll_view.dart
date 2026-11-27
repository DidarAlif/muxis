import 'dart:ui';

import 'package:flutter/material.dart';

/// App-wide desktop/mobile scroll behavior supporting mouse drag, trackpad,
/// mouse wheel, stylus, and touch scrolling seamlessly.
class MuxisScrollBehavior extends MaterialScrollBehavior {
  const MuxisScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };
}

/// Standardized vertical scroll container with its own ScrollController,
/// interactive desktop scrollbar, and smooth ClampingScrollPhysics so vertical
/// scrolling never stalls across views or conflicts with nested children.
class MuxisScrollView extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const MuxisScrollView({super.key, required this.child, this.padding});

  @override
  State<MuxisScrollView> createState() => _MuxisScrollViewState();
}

class _MuxisScrollViewState extends State<MuxisScrollView> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 768;
    final effectivePadding =
        widget.padding ??
        (isMobile
            ? const EdgeInsets.fromLTRB(16, 14, 16, 20)
            : const EdgeInsets.symmetric(horizontal: 32, vertical: 24));
    final physics = isMobile
        ? const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())
        : const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics());

    return Scrollbar(
      controller: _controller,
      interactive: !isMobile,
      thickness: isMobile ? 3.5 : 6,
      radius: const Radius.circular(8),
      child: SingleChildScrollView(
        controller: _controller,
        primary: false,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: effectivePadding,
        physics: physics,
        child: widget.child,
      ),
    );
  }
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CarouselSlider extends StatefulWidget {
  const CarouselSlider({
    super.key,
    required this.itemCount,
    required this.index,
    required this.itemBuilder,
    this.onIndexChanged,
  });

  final int itemCount;

  final int index;

  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onIndexChanged;

  @override
  State<CarouselSlider> createState() => _CarouselSliderState();
}

class _CarouselSliderState extends State<CarouselSlider> {
  late final PageController _controller;

  /// Ignore tiny wheel ticks so trackpads/mice do not spam pages.
  static const double _wheelThreshold = 20;

  /// Guard against overlapping animateToPage calls from rapid wheel events.
  bool _paging = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.index.clamp(0, _lastPage));
  }

  @override
  void didUpdateWidget(covariant CarouselSlider old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _syncTo(widget.index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _lastPage => widget.itemCount > 0 ? widget.itemCount - 1 : 0;

  void _syncTo(int page) {
    final target = page.clamp(0, _lastPage);
    void jump() {
      if (!mounted || !_controller.hasClients) return;
      if (_controller.page?.round() != target) _controller.jumpToPage(target);
    }

    if (_controller.hasClients) {
      jump();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => jump());
    }
  }

  void _onPage(int i) {
    if (i == widget.index) return;
    widget.onIndexChanged?.call(i);
  }

  bool get _altHeld {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.altLeft) ||
        keys.contains(LogicalKeyboardKey.altRight);
  }

  /// Page by one step from [delta]. Positive → next, negative → previous.
  Future<void> _pageBy(double delta) async {
    if (_paging || !_controller.hasClients) return;
    final page = _controller.page ?? widget.index.toDouble();
    final target = delta > 0
        ? (page.round() + 1).clamp(0, _lastPage)
        : (page.round() - 1).clamp(0, _lastPage);
    if (target == page.round()) return;

    _paging = true;
    try {
      await _controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } finally {
      if (mounted) _paging = false;
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_controller.hasClients || _paging) return;

    final dx = event.scrollDelta.dx;
    final dy = event.scrollDelta.dy;
    final alt = _altHeld;

    // Axis policy (Alt swaps the action type):
    //
    //   No Alt  → only horizontal intent pages months.
    //             Vertical wheel is left alone so a parent ListView can scroll.
    //   Alt     → vertical wheel is remapped to horizontal paging (axes swapped).
    //             Horizontal delta is ignored while Alt is held to avoid double action.
    //
    double? delta;
    if (alt) {
      // Swap: use vertical (or dominant) delta for horizontal paging.
      if (dy.abs() >= _wheelThreshold || dx.abs() >= _wheelThreshold) {
        delta = dy.abs() >= dx.abs() ? dy : dx;
      }
    } else {
      // Default: only clear horizontal scroll drives paging.
      if (dx.abs() > dy.abs() && dx.abs() >= _wheelThreshold) {
        delta = dx;
      }
    }

    if (delta == null) return;
    _pageBy(delta);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
        ),
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.itemCount,
          onPageChanged: _onPage,
          itemBuilder: widget.itemBuilder,
        ),
      ),
    );
  }
}

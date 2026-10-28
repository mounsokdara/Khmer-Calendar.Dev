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

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_controller.hasClients) return;

    // Prefer the dominant axis so both vertical wheel and horizontal trackpad work.
    final dx = event.scrollDelta.dx;
    final dy = event.scrollDelta.dy;
    var delta = dy.abs() >= dx.abs() ? dy : dx;

    // Alt changes scroll action type: reverse direction.
    if (_altHeld) delta = -delta;

    if (delta.abs() < _wheelThreshold) return;

    final page = _controller.page ?? widget.index.toDouble();
    if (delta > 0) {
      // Scroll down / right → next month
      final next = (page.floor() + 1).clamp(0, _lastPage);
      if (next > page.round() || (page - page.round()).abs() < 0.01 && next != page.round()) {
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      // Scroll up / left → previous month
      final prev = (page.ceil() - 1).clamp(0, _lastPage);
      if (prev < page.round() || (page - page.round()).abs() < 0.01 && prev != page.round()) {
        _controller.animateToPage(
          prev,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    }
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

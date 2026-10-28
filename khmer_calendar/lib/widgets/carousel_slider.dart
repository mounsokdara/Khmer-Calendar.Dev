import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  /// True if a vertical scrollable ancestor can still move in the direction of [dy].
  ///
  /// Positive [dy] = scroll down (increase offset); negative = scroll up.
  /// Walks ancestors from this widget outward, so the horizontal PageView
  /// (a descendant) is never considered.
  bool _verticalParentCanScroll(double dy) {
    if (dy == 0) return false;

    ScrollableState? vertical;
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        final dir = state.axisDirection;
        if (dir == AxisDirection.down || dir == AxisDirection.up) {
          vertical = state;
          return false; // stop at nearest vertical scrollable
        }
      }
      return true;
    });

    final pos = vertical?.position;
    if (pos == null || !pos.hasPixels || !pos.hasContentDimensions) {
      return false;
    }

    // dy > 0 → user scrolled down → needs room below (pixels < max)
    // dy < 0 → user scrolled up   → needs room above (pixels > min)
    if (dy > 0) {
      return pos.pixels < pos.maxScrollExtent - 0.5;
    }
    return pos.pixels > pos.minScrollExtent + 0.5;
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

    // Decide whether this wheel event should drive horizontal month paging.
    //
    //   Alt held  → always claim the signal for horizontal paging and block
    //               the parent vertical ListView (PointerSignalResolver).
    //   No Alt    → horizontal delta pages months;
    //               vertical delta pages months only when the vertical parent
    //               cannot scroll further (or there is none).
    //
    double? delta;

    if (alt) {
      if (dy.abs() >= _wheelThreshold || dx.abs() >= _wheelThreshold) {
        delta = dy.abs() >= dx.abs() ? dy : dx;
      }
    } else if (dx.abs() > dy.abs() && dx.abs() >= _wheelThreshold) {
      delta = dx;
    } else if (dy.abs() >= _wheelThreshold && !_verticalParentCanScroll(dy)) {
      delta = dy;
    }

    if (delta == null) return;

    final useDelta = delta;

    // Claim exclusive handling so Scrollable ancestors do not also apply the
    // delta. Required when Alt is held (block vertical) and when we steal a
    // vertical wheel that the parent cannot use.
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      _pageBy(useDelta);
    });
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../haptics.dart';
import '../sounds.dart';
import '../widgets/dialog_actions.dart';

const double scrollPickerItemExtent = 42;
const double scrollPickerVisibleItems = 7;
const double scrollPickerDiameterRatio = 2.2;
const double scrollPickerPerspective = 0.003;
const double scrollPickerSqueeze = 1.1;
const BoxConstraints scrollPickerDialogConstraints =
    BoxConstraints(minWidth: 280, maxWidth: 400);

typedef ScrollPickerMatcher = int? Function(String query, List<String> labels);

enum ScrollPickerHighlight { pill, lines, none }

class ScrollPickerMatchers {
  ScrollPickerMatchers._();

  static String asciiDigits(String raw) {
    const km = '០១២៣៤៥៦៧៨៩';
    final b = StringBuffer();
    for (final r in raw.trim().runes) {
      final i = km.indexOf(String.fromCharCode(r));
      b.write(i >= 0 ? '$i' : String.fromCharCode(r));
    }
    return b.toString();
  }

  static int? label(String query, List<String> labels) {
    final raw = query.trim();
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    var i = labels.indexWhere((l) => l.toLowerCase() == lower);
    if (i >= 0) return i;
    i = labels.indexWhere((l) => l.toLowerCase().startsWith(lower));
    if (i >= 0) return i;
    final q = asciiDigits(raw);
    if (q.isNotEmpty) {
      i = labels.indexWhere((l) => asciiDigits(l) == q);
      if (i >= 0) return i;
    }
    return null;
  }

  static int? number(String query, List<String> labels) {
    final raw = query.trim();
    if (raw.isEmpty) return null;
    final q = asciiDigits(raw);
    var i = labels.indexWhere((l) => l == q);
    if (i >= 0) return i;
    final n = int.tryParse(q);
    if (n != null) {
      i = labels.indexWhere((l) => l == '$n');
      if (i >= 0) return i;
    }
    i = labels.indexWhere((l) => l.startsWith(q));
    if (i >= 0) return i;
    return null;
  }
}

class ScrollPickerColumnSpec {
  const ScrollPickerColumnSpec({
    required this.labels,
    this.flex = 1,
    this.matcher = ScrollPickerMatchers.label,
    this.keyboardType = TextInputType.text,
    this.maxTypedLength = 8,
  });

  final List<String> labels;
  final int flex;
  final ScrollPickerMatcher matcher;
  final TextInputType keyboardType;
  final int maxTypedLength;
}

class ScrollPicker extends StatelessWidget {
  ScrollPicker({
    super.key,
    required this.columns,
    required this.indices,
    required this.onChanged,
    this.itemExtent = scrollPickerItemExtent,
    this.visibleItems = scrollPickerVisibleItems,
    this.highlight = ScrollPickerHighlight.lines,
    this.diameterRatio = scrollPickerDiameterRatio,
    this.perspective = scrollPickerPerspective,
    this.squeeze = scrollPickerSqueeze,
    this.textStyle,
    this.enableTyping = true,
    this.feedback = true,
  }) : assert(columns.length == indices.length);

  final List<ScrollPickerColumnSpec> columns;
  final List<int> indices;
  final void Function(int column, int index) onChanged;
  final double itemExtent;
  final double visibleItems;
  final ScrollPickerHighlight highlight;
  final double diameterRatio;
  final double perspective;
  final double squeeze;
  final TextStyle? textStyle;
  final bool enableTyping;
  final bool feedback;

  Widget _globalHighlight(ColorScheme cs) {
    if (highlight != ScrollPickerHighlight.lines) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: double.infinity,
          height: itemExtent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: cs.outlineVariant),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: itemExtent * visibleItems,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              for (var i = 0; i < columns.length; i++)
                Expanded(
                  flex: columns[i].flex,
                  child: ScrollPickerColumn(
                    labels: columns[i].labels,
                    index: indices[i],
                    onIndex: (v) => onChanged(i, v),
                    matcher: columns[i].matcher,
                    keyboardType: columns[i].keyboardType,
                    maxTypedLength: columns[i].maxTypedLength,
                    itemExtent: itemExtent,
                    visibleItems: visibleItems,
                    highlight: highlight == ScrollPickerHighlight.lines
                        ? ScrollPickerHighlight.none
                        : highlight,
                    diameterRatio: diameterRatio,
                    perspective: perspective,
                    squeeze: squeeze,
                    textStyle: textStyle,
                    enableTyping: enableTyping,
                    feedback: feedback,
                  ),
                ),
            ],
          ),
          _globalHighlight(cs),
        ],
      ),
    );
  }
}

class ScrollPickerColumn extends StatefulWidget {
  const ScrollPickerColumn({
    super.key,
    required this.labels,
    required this.index,
    required this.onIndex,
    this.matcher = ScrollPickerMatchers.label,
    this.keyboardType = TextInputType.text,
    this.maxTypedLength = 8,
    this.itemExtent = scrollPickerItemExtent,
    this.visibleItems = scrollPickerVisibleItems,
    this.highlight = ScrollPickerHighlight.lines,
    this.diameterRatio = scrollPickerDiameterRatio,
    this.perspective = scrollPickerPerspective,
    this.squeeze = scrollPickerSqueeze,
    this.textStyle,
    this.enableTyping = true,
    this.feedback = true,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onIndex;
  final ScrollPickerMatcher matcher;
  final TextInputType keyboardType;
  final int maxTypedLength;
  final double itemExtent;
  final double visibleItems;
  final ScrollPickerHighlight highlight;
  final double diameterRatio;
  final double perspective;
  final double squeeze;
  final TextStyle? textStyle;
  final bool enableTyping;
  final bool feedback;

  @override
  State<ScrollPickerColumn> createState() => _ScrollPickerColumnState();
}

class _ScrollPickerColumnState extends State<ScrollPickerColumn> {
  late final FixedExtentScrollController _ctrl;
  late final FocusNode _focus;
  final TextEditingController _type = TextEditingController();
  bool _typing = false;
  bool _committing = false;
  bool _jumping = false;
  double? _downY;

  int get _maxIndex => widget.labels.isEmpty ? 0 : widget.labels.length - 1;

  @override
  void initState() {
    super.initState();
    _ctrl = FixedExtentScrollController(
      initialItem: widget.index.clamp(0, _maxIndex),
    );
    _focus = FocusNode();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant ScrollPickerColumn old) {
    super.didUpdateWidget(old);
    final changed =
        old.index != widget.index || old.labels.length != widget.labels.length;
    if (!changed) return;
    final target = widget.index.clamp(0, _maxIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_ctrl.hasClients || _ctrl.selectedItem == target) return;
      _jump(target);
    });
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _ctrl.dispose();
    _type.dispose();
    super.dispose();
  }

  void _jump(int i) {
    _jumping = true;
    _ctrl.jumpToItem(i);
    _jumping = false;
  }

  void _onFocus() {
    if (_typing && !_focus.hasFocus) _commitType();
  }

  void _commitType() {
    if (_committing || !_typing) return;
    _committing = true;
    final n = widget.matcher(_type.text, widget.labels);
    setState(() => _typing = false);
    if (n != null && n >= 0 && n < widget.labels.length) {
      widget.onIndex(n);
      if (_ctrl.hasClients) _jump(n);
    }
    _committing = false;
  }

  void _startType() {
    if (_typing || !widget.enableTyping || widget.labels.isEmpty) return;
    final i = (_ctrl.hasClients ? _ctrl.selectedItem : widget.index)
        .clamp(0, _maxIndex);
    _type.text = widget.labels[i];
    _type.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _type.text.length,
    );
    setState(() => _typing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _onPointerDown(PointerDownEvent e) => _downY = e.position.dy;

  void _onPointerUp(PointerUpEvent e) {
    if (_typing || _downY == null) return;
    final dy = (e.position.dy - _downY!).abs();
    _downY = null;
    if (dy > 10) return;
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final local = box.globalToLocal(e.position);
    final mid = box.size.height / 2;
    if ((local.dy - mid).abs() <= widget.itemExtent / 2) _startType();
  }

  Widget _highlight(ColorScheme cs) {
    switch (widget.highlight) {
      case ScrollPickerHighlight.pill:
        return IgnorePointer(
          child: Container(
            height: widget.itemExtent - 4,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.outlineVariant, width: 1.4),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
            ),
          ),
        );
      case ScrollPickerHighlight.lines:
        return const SizedBox.shrink();
      case ScrollPickerHighlight.none:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = widget.textStyle ??
        TextStyle(fontSize: 16, color: cs.onSurface);
    final selected =
        (_ctrl.hasClients ? _ctrl.selectedItem : widget.index).clamp(0, _maxIndex);
    return SizedBox(
      height: widget.itemExtent * widget.visibleItems,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _highlight(cs),
          Listener(
            onPointerDown: _onPointerDown,
            onPointerUp: _onPointerUp,
            onPointerCancel: (_) => _downY = null,
            child: IgnorePointer(
              ignoring: _typing,
              child: ShaderMask(
                shaderCallback: (rect) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00FFFFFF),
                      Color(0xFFFFFFFF),
                      Color(0xFFFFFFFF),
                      Color(0x00FFFFFF),
                    ],
                    stops: [0.0, 0.28, 0.72, 1.0],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: ListWheelScrollView.useDelegate(
                  controller: _ctrl,
                  itemExtent: widget.itemExtent,
                  diameterRatio: widget.diameterRatio,
                  perspective: widget.perspective,
                  squeeze: widget.squeeze,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (i) {
                    if (_jumping) return;
                    if (widget.feedback) {
                      AppSounds.instance.playWheel();
                      Haptics.instance.tick();
                    }
                    widget.onIndex(i);
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: widget.labels.length,
                    builder: (_, i) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!_ctrl.hasClients || _ctrl.selectedItem == i) return;
                        _ctrl.animateToItem(
                          i,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: Center(
                        child: Text(
                          widget.labels[i],
                          textAlign: TextAlign.center,
                          style: base.copyWith(
                            fontWeight: i == selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_typing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _type,
                focusNode: _focus,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: widget.keyboardType,
                textInputAction: TextInputAction.done,
                style: Theme.of(context).textTheme.titleMedium,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(widget.maxTypedLength),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onSubmitted: (_) => _commitType(),
              ),
            ),
        ],
      ),
    );
  }
}

Future<List<int>?> showScrollPickerDialog(
  BuildContext context, {
  required Widget title,
  required List<int> initialIndices,
  required List<ScrollPickerColumnSpec> Function(List<int> indices)
      columnsBuilder,
  required String confirmLabel,
  String? cancelLabel,
  double width = 400,
  BoxConstraints constraints = scrollPickerDialogConstraints,
  double itemExtent = scrollPickerItemExtent,
  double visibleItems = scrollPickerVisibleItems,
  ScrollPickerHighlight highlight = ScrollPickerHighlight.lines,
  double diameterRatio = scrollPickerDiameterRatio,
  double perspective = scrollPickerPerspective,
  double squeeze = scrollPickerSqueeze,
  TextStyle? textStyle,
}) {
  return showDialog<List<int>>(
    context: context,
    builder: (ctx) => _ScrollPickerDialog(
      title: title,
      initialIndices: initialIndices,
      columnsBuilder: columnsBuilder,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      width: width,
      constraints: constraints,
      itemExtent: itemExtent,
      visibleItems: visibleItems,
      highlight: highlight,
      diameterRatio: diameterRatio,
      perspective: perspective,
      squeeze: squeeze,
      textStyle: textStyle,
    ),
  );
}

class _ScrollPickerDialog extends StatefulWidget {
  const _ScrollPickerDialog({
    required this.title,
    required this.initialIndices,
    required this.columnsBuilder,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.width,
    required this.constraints,
    required this.itemExtent,
    required this.visibleItems,
    required this.highlight,
    required this.diameterRatio,
    required this.perspective,
    required this.squeeze,
    required this.textStyle,
  });

  final Widget title;
  final List<int> initialIndices;
  final List<ScrollPickerColumnSpec> Function(List<int> indices) columnsBuilder;
  final String confirmLabel;
  final String? cancelLabel;
  final double width;
  final BoxConstraints constraints;
  final double itemExtent;
  final double visibleItems;
  final ScrollPickerHighlight highlight;
  final double diameterRatio;
  final double perspective;
  final double squeeze;
  final TextStyle? textStyle;

  @override
  State<_ScrollPickerDialog> createState() => _ScrollPickerDialogState();
}

class _ScrollPickerDialogState extends State<_ScrollPickerDialog> {
  late List<int> _indices = List<int>.of(widget.initialIndices);

  @override
  Widget build(BuildContext context) {
    final columns = widget.columnsBuilder(_indices);
    for (var i = 0; i < _indices.length && i < columns.length; i++) {
      final max = columns[i].labels.isEmpty
          ? 0
          : columns[i].labels.length - 1;
      _indices[i] = _indices[i].clamp(0, max);
    }
    return AlertDialog(
      constraints: widget.constraints,
      title: widget.title,
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      content: SizedBox(
        width: widget.width,
        child: ScrollPicker(
          columns: columns,
          indices: _indices,
          onChanged: (column, index) =>
              setState(() => _indices[column] = index),
          itemExtent: widget.itemExtent,
          visibleItems: widget.visibleItems,
          highlight: widget.highlight,
          diameterRatio: widget.diameterRatio,
          perspective: widget.perspective,
          squeeze: widget.squeeze,
          textStyle: widget.textStyle,
        ),
      ),
      actions: equalDialogActions([
        if (widget.cancelLabel != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: dialogBtnStyle(
              foreground: Theme.of(context).colorScheme.primary,
            ),
            child: dlgLabel(widget.cancelLabel!),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(List<int>.of(_indices)),
          style: dialogBtnStyle(
            background: Theme.of(context).colorScheme.primary,
            foreground: Theme.of(context).colorScheme.onPrimary,
          ),
          child: dlgLabel(widget.confirmLabel),
        ),
      ]),
    );
  }
}

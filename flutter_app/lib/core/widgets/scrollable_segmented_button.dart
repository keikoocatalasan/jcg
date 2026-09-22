import 'package:flutter/material.dart';

/// A [SegmentedButton] that never overflows: when the segments are wider than
/// the available space it scrolls horizontally instead of painting the
/// "overflowed by N pixels" error banner on narrow devices.
class ScrollableSegmented<T extends Object> extends StatelessWidget {
  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>>? onSelectionChanged;
  final ButtonStyle? style;
  final bool showSelectedIcon;
  final bool multiSelectionEnabled;
  final bool emptySelectionAllowed;

  const ScrollableSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.style,
    this.showSelectedIcon = false,
    this.multiSelectionEnabled = false,
    this.emptySelectionAllowed = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<T>(
        segments: segments,
        selected: selected,
        onSelectionChanged: onSelectionChanged,
        style: style,
        showSelectedIcon: showSelectedIcon,
        multiSelectionEnabled: multiSelectionEnabled,
        emptySelectionAllowed: emptySelectionAllowed,
      ),
    );
  }
}

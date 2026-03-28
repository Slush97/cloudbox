import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A Google Photos-style date scroller overlay.
///
/// Wraps a [CustomScrollView] and shows:
/// - A floating date chip while scrolling
/// - A draggable fast-scroll rail on the right edge
class DateScroller extends StatefulWidget {
  const DateScroller({
    required this.controller,
    required this.sectionKeys,
    required this.child,
    super.key,
  });

  /// Scroll controller shared with the inner scroll view.
  final ScrollController controller;

  /// Ordered list of (label, globalItemIndex) for each date section.
  /// Used to map scroll position → date label.
  final List<DateSection> sectionKeys;

  final Widget child;

  @override
  State<DateScroller> createState() => _DateScrollerState();
}

class DateSection {
  const DateSection({required this.label, required this.scrollFraction});
  final String label;

  /// Fraction of total scroll extent where this section starts (0.0–1.0).
  final double scrollFraction;
}

class _DateScrollerState extends State<DateScroller> {
  bool _showBubble = false;
  String _currentLabel = '';
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final label = _labelForPosition(widget.controller.position.pixels);
    if (label != _currentLabel) {
      setState(() => _currentLabel = label);
    }
    if (!_dragging) {
      setState(() => _showBubble = true);
      _hideBubbleAfterDelay();
    }
  }

  int _hideCounter = 0;

  void _hideBubbleAfterDelay() {
    final myCount = ++_hideCounter;
    Future.delayed(const Duration(seconds: 1), () {
      if (_hideCounter == myCount && mounted && !_dragging) {
        setState(() => _showBubble = false);
      }
    });
  }

  String _labelForPosition(double pixels) {
    if (widget.sectionKeys.isEmpty) return '';
    if (!widget.controller.hasClients) return '';

    final maxExtent = widget.controller.position.maxScrollExtent;
    if (maxExtent <= 0) return widget.sectionKeys.first.label;

    final fraction = (pixels / maxExtent).clamp(0.0, 1.0);

    // Find the last section whose scrollFraction <= current fraction
    var label = widget.sectionKeys.first.label;
    for (final section in widget.sectionKeys) {
      if (section.scrollFraction <= fraction) {
        label = section.label;
      } else {
        break;
      }
    }
    return label;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final localY = details.localPosition.dy;
    final fraction = (localY / box.size.height).clamp(0.0, 1.0);

    if (widget.controller.hasClients) {
      final maxExtent = widget.controller.position.maxScrollExtent;
      widget.controller.jumpTo(fraction * maxExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Floating date bubble
        if (_showBubble && _currentLabel.isNotEmpty)
          Positioned(
            right: 40,
            top: 8,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showBubble ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.inverseSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _currentLabel,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Fast scroll rail
        if (widget.sectionKeys.length > 1)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 32,
            child: GestureDetector(
              onVerticalDragStart: (_) =>
                  setState(() {
                    _dragging = true;
                    _showBubble = true;
                  }),
              onVerticalDragUpdate: _onVerticalDragUpdate,
              onVerticalDragEnd: (_) {
                setState(() => _dragging = false);
                _hideBubbleAfterDelay();
              },
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
      ],
    );
  }
}

/// Groups items by month and returns (label, items) pairs in order.
///
/// [dateOf] extracts the date from each item.
/// Returns newest-first by default.
List<(String label, List<T> items)> groupByMonth<T>(
  List<T> items,
  DateTime Function(T) dateOf,
) {
  final format = DateFormat.yMMMM();
  final groups = <String, List<T>>{};
  final order = <String>[];

  for (final item in items) {
    final label = format.format(dateOf(item));
    if (!groups.containsKey(label)) {
      groups[label] = [];
      order.add(label);
    }
    groups[label]!.add(item);
  }

  return [for (final key in order) (key, groups[key]!)];
}

/// Builds a list of [DateSection] from grouped data for the [DateScroller].
///
/// [groups] is a list of (label, items) pairs.
/// Returns sections with scroll fractions proportional to item count.
List<DateSection> buildSections<T>(List<(String, List<T>)> groups) {
  if (groups.isEmpty) return [];

  final totalItems =
      groups.fold<int>(0, (sum, g) => sum + g.$2.length);
  if (totalItems == 0) return [];

  final sections = <DateSection>[];
  var runningCount = 0;

  for (final (label, items) in groups) {
    sections.add(DateSection(
      label: label,
      scrollFraction: runningCount / totalItems,
    ));
    runningCount += items.length;
  }

  return sections;
}

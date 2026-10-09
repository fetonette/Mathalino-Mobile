import 'package:flutter/material.dart';

import '../../core/theme/mathalino_tokens.dart';
import '../level_node.dart';

/// Data for one node of the map (presentation only).
class LevelMapEntry {
  final int level;
  final LevelNodeKind kind;
  const LevelMapEntry(this.level, this.kind);
}

/// Pure layout of the zigzag map: node centers, total height and the dotted
/// connector path. Everything (nodes, connector, auto-scroll) is derived from
/// these computed centers — nothing is hard-coded per level.
class LevelMapLayout {
  /// Horizontal position of node `i` as a fraction of the width.
  static const List<double> xFractions = [0.20, 0.50, 0.76, 0.40];

  static const double _gap = 22;
  static const double _completedLabelExtra = 14;
  static const double _currentTagExtra = 14;
  static const double topPadding = 16;
  static const double bottomPadding = 24;
  static const double sidePadding = 4;

  final double width;
  final List<LevelMapEntry> entries;
  final List<Offset> centers;
  final double contentHeight;

  LevelMapLayout._(
    this.width,
    this.entries,
    this.centers,
    this.contentHeight,
  );

  factory LevelMapLayout.compute({
    required double width,
    required List<LevelMapEntry> entries,
  }) {
    final centers = <Offset>[];
    double y = topPadding;
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final r = e.kind.diameter / 2;
      if (i == 0) {
        y += r + (e.kind == LevelNodeKind.current ? 40 : 0);
      } else {
        final prev = entries[i - 1];
        final pr = prev.kind.diameter / 2;
        y += pr + _gap + r;
        if (prev.kind == LevelNodeKind.completed) y += _completedLabelExtra;
        if (e.kind == LevelNodeKind.current) y += _currentTagExtra;
      }
      final frac = xFractions[(e.level - 1) % xFractions.length];
      final x = (frac * width).clamp(
        r + sidePadding,
        width - r - sidePadding,
      );
      centers.add(Offset(x, y));
    }
    final last = entries.isEmpty ? 0.0 : entries.last.kind.diameter / 2;
    final h = (centers.isEmpty ? 0 : centers.last.dy) + last + bottomPadding + 24;
    return LevelMapLayout._(width, entries, centers, h);
  }

  bool sameShape(double w, List<LevelMapEntry> other) {
    if (w != width || other.length != entries.length) return false;
    for (var i = 0; i < other.length; i++) {
      if (other[i].level != entries[i].level || other[i].kind != entries[i].kind) {
        return false;
      }
    }
    return true;
  }

  /// Smooth Catmull-Rom curve through all node centers.
  Path get smoothPath {
    final path = Path();
    if (centers.isEmpty) return path;
    path.moveTo(centers.first.dx, centers.first.dy);
    for (var i = 0; i < centers.length - 1; i++) {
      final p0 = i == 0 ? centers[i] : centers[i - 1];
      final p1 = centers[i];
      final p2 = centers[i + 1];
      final p3 = i + 2 < centers.length ? centers[i + 2] : centers[i + 1];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(
        c1.dx.clamp(0.0, width),
        c1.dy,
        c2.dx.clamp(0.0, width),
        c2.dy,
        p2.dx,
        p2.dy,
      );
    }
    return path;
  }

  /// The smooth curve cut into round-capped dashes (2 on / 14 off).
  Path get dottedPath {
    final out = Path();
    for (final metric in smoothPath.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        out.addPath(metric.extractPath(d, d + 2 > metric.length ? metric.length : d + 2), Offset.zero);
        d += 16;
      }
    }
    return out;
  }

  /// Scroll offset that puts the node at [index] at [localY] inside a viewport.
  double offsetFor(int index, double localY) =>
      (centers[index].dy - localY).clamp(0.0, double.infinity);
}

class _ConnectorPainter extends CustomPainter {
  final Path dotted;
  _ConnectorPainter(this.dotted);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      dotted,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = AppTokens.lockedBorder
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter old) => old.dotted != dotted;
}

/// The scrollable zigzag map.
class LevelMapView extends StatefulWidget {
  final ScrollController controller;
  final LevelMapLayout layout;
  final Widget Function(LevelMapEntry entry) nodeBuilder;
  final double extraBottom;
  final bool Function(ScrollNotification) onScrollNotification;

  const LevelMapView({
    super.key,
    required this.controller,
    required this.layout,
    required this.nodeBuilder,
    required this.extraBottom,
    required this.onScrollNotification,
  });

  @override
  State<LevelMapView> createState() => _LevelMapViewState();
}

class _LevelMapViewState extends State<LevelMapView> {
  late Path _dotted;

  @override
  void initState() {
    super.initState();
    _dotted = widget.layout.dottedPath;
  }

  @override
  void didUpdateWidget(covariant LevelMapView old) {
    super.didUpdateWidget(old);
    if (!identical(old.layout, widget.layout)) {
      _dotted = widget.layout.dottedPath;
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final children = <Widget>[
      // Connector, behind every node. Purely decorative.
      Positioned.fill(
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _ConnectorPainter(_dotted)),
            ),
          ),
        ),
      ),
    ];

    for (var i = 0; i < layout.entries.length; i++) {
      final e = layout.entries[i];
      final c = layout.centers[i];
      final d = e.kind.diameter;
      children.add(
        Positioned(
          key: ValueKey('level-${e.level}'),
          left: c.dx - d / 2,
          top: c.dy - d / 2,
          width: d,
          height: d,
          child: widget.nodeBuilder(e),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: widget.onScrollNotification,
      child: SingleChildScrollView(
        controller: widget.controller,
        child: SizedBox(
          width: layout.width,
          height: layout.contentHeight + widget.extraBottom,
          child: Stack(clipBehavior: Clip.none, children: children),
        ),
      ),
    );
  }
}


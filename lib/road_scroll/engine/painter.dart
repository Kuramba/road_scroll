import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/level_status.dart';
import '../../models/level_ui_item.dart';
import '../../models/long_distance_target_ui_item.dart';
import '../../models/map_generator.dart';
import '../../models/side_ui_item.dart';

/// Pure pseudo-3D projection: maps a depth (`relativeZ`, levels ahead of or
/// behind the camera) and a horizontal offset (`xOffsetDelta`, already
/// relative to the camera's own xOffset) to a screen point + scale.
class RoadProjection {
  final Size size;
  final double focalLength;
  final double horizonY;

  /// Constant pixel offset from the very bottom edge for the closest
  /// (relativeZ == 0) point, instead of a fraction of screen height.
  final double nearBottomOffset;

  final double lateralSpread;

  const RoadProjection({required this.size, this.focalLength = 6.0, this.horizonY = 0.30, this.nearBottomOffset = 10.0, this.lateralSpread = 0.32});

  double scaleForDepth(double relativeZ) {
    final z = relativeZ.clamp(-3.0, 60.0);
    return (focalLength / (focalLength + z)).clamp(0.04, 1.4);
  }

  Offset project(double relativeZ, double xOffsetDelta) {
    final scale = scaleForDepth(relativeZ);
    final nearAnchorY = size.height - nearBottomOffset;
    double y;
    if (relativeZ >= 0) {
      final depthT = (1.0 - scale).clamp(0.0, 1.0);
      y = nearAnchorY - depthT * (nearAnchorY - size.height * horizonY);
    } else {
      // Overshoot well past the bottom edge so items visibly exit the
      // screen before they leave the ViewModel's render window, instead
      // of popping out right at the fold.
      const exitBeyondBottom = 0.45;
      final behindT = (-relativeZ).clamp(0.0, 3.0) / 3.0;
      final maxBehindY = size.height * (1.0 + exitBeyondBottom);
      y = nearAnchorY + behindT * (maxBehindY - nearAnchorY);
    }
    final x = size.width / 2 + xOffsetDelta * scale * size.width * lateralSpread;
    return Offset(x, y);
  }
}

class Road3DPainter extends CustomPainter {
  /// How many levels behind/ahead of the camera the road ribbon extends —
  /// mirrors RoadScrollViewModel.behindWindow/aheadWindow (duplicated here,
  /// rather than imported, to keep the rendering engine decoupled from the
  /// viewmodel; keep these in sync if either changes).
  static const double roadRenderBehindWindow = -3.0;
  static const double roadRenderAheadWindow = 10.0;

  /// Multiplies every projected depth so consecutive levels sit 3x farther
  /// apart visually along the road, without changing how many raw levels
  /// are considered "ahead/behind" for windowing or close-up zoom.
  static const double levelSpacingMultiplier = 3.0;

  final List<LevelUiItem> levels;
  final List<SideUiItem> sideItems;
  final LongDistanceTargetUiItem target;
  final double cameraProgress;
  final double cameraXOffset;
  final double pulsePhase;

  Road3DPainter({required this.levels, required this.sideItems, required this.target, required this.cameraProgress, required this.cameraXOffset, required this.pulsePhase});

  @override
  void paint(Canvas canvas, Size size) {
    final projection = RoadProjection(size: size);
    _paintBackground(canvas, size, projection);
    _paintRoad(canvas, projection);
    // Always drawn first (farthest), so every 3D object in front of it
    // — the road, discs, side items — paints on top as it approaches.
    _paintTarget(canvas, projection);

    final entries = <_DepthEntry>[
      for (final item in sideItems) _DepthEntry(relativeZ: _levelDepthOfSideItem(item) - cameraProgress, paint: (c) => _paintSideItem(c, projection, item)),
      for (final level in levels) _DepthEntry(relativeZ: level.number - cameraProgress, paint: (c) => _paintLevel(c, projection, level)),
    ]..sort((a, b) => b.relativeZ.compareTo(a.relativeZ));

    for (final entry in entries) {
      entry.paint(canvas);
    }
  }

  double _levelDepthOfSideItem(SideUiItem item) => (item.minLevelSeen + item.maxLevelSeen) / 2;

  void _paintBackground(Canvas canvas, Size size, RoadProjection projection) {
    // Ground fills up to the road's vanishing point (horizonY) instead of
    // a fixed half-screen split, so it extends all the way to where the
    // road visually ends in the distance.
    final horizonSplit = size.height * projection.horizonY;
    final skyRect = Rect.fromLTWH(0, 0, size.width, horizonSplit);
    final groundRect = Rect.fromLTWH(0, horizonSplit, size.width, size.height - horizonSplit);
    canvas.drawRect(skyRect, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFEAF2FA), Color(0xFFF7FAFD)]).createShader(skyRect));
    canvas.drawRect(groundRect, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFDDE8E4), Color(0xFFCBDCD6)]).createShader(groundRect));

    // Slim line marking the sky/ground boundary.
    canvas.drawLine(
      Offset(0, horizonSplit),
      Offset(size.width, horizonSplit),
      Paint()
        ..color = const Color(0xFFB9C7BE)
        ..strokeWidth = 2.0,
    );
  }

  void _paintRoad(Canvas canvas, RoadProjection projection) {
    const halfWidthAtCamera = 34.0;
    const step = 0.25;

    final leftPoints = <Offset>[];
    final rightPoints = <Offset>[];
    for (double z = roadRenderBehindWindow; z <= roadRenderAheadWindow; z += step) {
      final levelPosition = cameraProgress + z;
      final xOffsetDelta = MapGenerator.waveXOffsetForPosition(levelPosition) - cameraXOffset;
      final projectedZ = z * levelSpacingMultiplier;
      final scale = projection.scaleForDepth(projectedZ);
      final halfWidth = halfWidthAtCamera * scale;
      final center = projection.project(projectedZ, xOffsetDelta);
      leftPoints.add(Offset(center.dx - halfWidth, center.dy));
      rightPoints.add(Offset(center.dx + halfWidth, center.dy));
    }

    final path = Path()..moveTo(leftPoints.first.dx, leftPoints.first.dy);
    for (final p in leftPoints.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in rightPoints.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();

    canvas.drawPath(path, Paint()..color = const Color(0xFFE3D9C6));
  }

  /// 0 at 3+ levels away in either direction, ramping up to 1 exactly at
  /// the camera (relativeZ == 0). Drives both the close-up zoom and the
  /// front-of-screen offset below, so they grow in lockstep with no pop.
  double _proximity(double relativeZ) {
    const closeRange = 3.0;
    return 1.0 - (relativeZ.abs().clamp(0.0, closeRange) / closeRange);
  }

  /// How much extra to blow up a level disc as it nears the camera,
  /// peaking at 3x right at the camera and tapering back to 1x (no
  /// boost) by 3 levels away in either direction.
  double _closeUpScale(double relativeZ) {
    const maxBoost = 3.0;
    return 1.0 + _proximity(relativeZ) * (maxBoost - 1.0);
  }

  void _paintLevel(Canvas canvas, RoadProjection projection, LevelUiItem level) {
    final rawRelativeZ = level.number - cameraProgress;
    final relativeZ = rawRelativeZ * levelSpacingMultiplier;
    final projected = projection.project(relativeZ, level.xOffset - cameraXOffset);
    // Blended continuously by proximity (the same curve driving the
    // close-up zoom) instead of a hard switch at rawRelativeZ == 0 — that
    // caused a one-frame pop in position while size was already near its
    // peak. This keeps position and size growing together smoothly.
    const frontOffset = -50.0;
    final center = projected.translate(0, frontOffset * _proximity(rawRelativeZ));
    final baseScale = projection.scaleForDepth(relativeZ);
    final scale = baseScale * _closeUpScale(rawRelativeZ);
    final radius = 26.0 * scale;
    final baseRadius = 26.0 * baseScale;

    final color = switch (level.status) {
      LevelStatus.notPassed => const Color(0xFFB6C0C6),
      LevelStatus.inProgress => const Color(0xFF57C25E),
      LevelStatus.passed => const Color(0xFF3E9BE0),
    };

    canvas.drawOval(Rect.fromCenter(center: center.translate(0, 6 * scale), width: radius * 2, height: radius * 0.9), Paint()..color = Colors.black.withValues(alpha: 0.15));
    canvas.drawOval(Rect.fromCenter(center: center, width: radius * 2, height: radius * 1.1), Paint()..color = color);

    if (level.status == LevelStatus.inProgress) {
      for (final ringScale in [1.4, 1.7]) {
        final ringRadius = radius * (ringScale + 0.3 * sin(pulsePhase * 2 * pi));
        canvas.drawOval(
          Rect.fromCenter(center: center, width: ringRadius * 2, height: ringRadius * 1.1),
          Paint()
            ..color = color.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * scale,
        );
      }
    }

    if (level.status == LevelStatus.passed) {
      // Sized from baseRadius/baseScale (perspective only, no close-up
      // boost) so the checkmark doesn't grow along with the disc's zoom.
      final checkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * baseScale
        ..strokeCap = StrokeCap.round;
      final checkPath = Path()
        ..moveTo(center.dx - baseRadius * 0.35, center.dy)
        ..lineTo(center.dx - baseRadius * 0.1, center.dy + baseRadius * 0.25)
        ..lineTo(center.dx + baseRadius * 0.35, center.dy - baseRadius * 0.25);
      canvas.drawPath(checkPath, checkPaint);
    }
  }

  void _paintSideItem(Canvas canvas, RoadProjection projection, SideUiItem item) {
    final rawRelativeZ = _levelDepthOfSideItem(item) - cameraProgress;
    final relativeZ = rawRelativeZ * levelSpacingMultiplier;
    final bob = sin(pulsePhase * 2 * pi) * 4;
    // 2x xOffset so side items sit farther from the road than modeled.
    final xOffsetDelta = item.xOffset * 2.0 - cameraXOffset;
    final center = projection.project(relativeZ, xOffsetDelta).translate(0, bob);
    final baseScale = projection.scaleForDepth(relativeZ);
    // Same close-up growth curve as level discs, so side items also
    // swell as they near the bottom of the screen.
    final scale = baseScale * _closeUpScale(rawRelativeZ);
    final half = 16.0 * scale;

    final paint = Paint()..color = item.color;
    switch (item.shape) {
      case SideItemShape.sphere:
        canvas.drawCircle(center, half, paint);
      case SideItemShape.cube:
        canvas.drawRect(Rect.fromCenter(center: center, width: half * 2, height: half * 2), paint);
      case SideItemShape.pyramid:
        final path = Path()
          ..moveTo(center.dx, center.dy - half)
          ..lineTo(center.dx + half, center.dy + half)
          ..lineTo(center.dx - half, center.dy + half)
          ..close();
        canvas.drawPath(path, paint);
    }
  }

  /// Always visible, at a constant size, anchored just above the horizon
  /// (the top of the green ground) — a distant, ever-present goal marker
  /// rather than a depth-projected object that pops in and out of range.
  void _paintTarget(Canvas canvas, RoadProjection projection) {
    const constantSize = 24.0;
    const aboveHorizon = 18.0;

    final horizonYPixels = projection.size.height * projection.horizonY;
    final xOffsetDelta = target.xOffset - cameraXOffset;
    final center = Offset(projection.size.width / 2 + xOffsetDelta * projection.size.width * 0.12, horizonYPixels - aboveHorizon);

    final glowRadius = constantSize * 1.25 * (1.1 + 0.2 * sin(pulsePhase * 2 * pi));
    canvas.drawCircle(center, glowRadius, Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.3));
    canvas.drawRect(Rect.fromCenter(center: center, width: constantSize, height: constantSize * 0.83), Paint()..color = const Color(0xFFFFC107));
  }

  @override
  bool shouldRepaint(covariant Road3DPainter oldDelegate) => oldDelegate.cameraProgress != cameraProgress || oldDelegate.cameraXOffset != cameraXOffset || oldDelegate.pulsePhase != pulsePhase || oldDelegate.levels != levels || oldDelegate.sideItems != sideItems || oldDelegate.target != target;
}

class _DepthEntry {
  final double relativeZ;
  final void Function(Canvas canvas) paint;

  _DepthEntry({required this.relativeZ, required this.paint});
}

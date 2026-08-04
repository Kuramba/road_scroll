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
  final double baseY;
  final double lateralSpread;

  const RoadProjection({
    required this.size,
    this.focalLength = 6.0,
    this.horizonY = 0.12,
    this.baseY = 0.82,
    this.lateralSpread = 0.32,
  });

  double scaleForDepth(double relativeZ) {
    final z = relativeZ.clamp(-3.0, 60.0);
    return (focalLength / (focalLength + z)).clamp(0.04, 1.4);
  }

  Offset project(double relativeZ, double xOffsetDelta) {
    final scale = scaleForDepth(relativeZ);
    double y;
    if (relativeZ >= 0) {
      final depthT = (1.0 - scale).clamp(0.0, 1.0);
      y = size.height * baseY - depthT * size.height * (baseY - horizonY);
    } else {
      final behindT = (-relativeZ).clamp(0.0, 3.0) / 3.0;
      y = size.height * baseY + behindT * size.height * (1.0 - baseY);
    }
    final x = size.width / 2 + xOffsetDelta * scale * size.width * lateralSpread;
    return Offset(x, y);
  }
}

class Road3DPainter extends CustomPainter {
  final List<LevelUiItem> levels;
  final List<SideUiItem> sideItems;
  final LongDistanceTargetUiItem target;
  final bool isTargetVisible;
  final double cameraProgress;
  final double cameraXOffset;
  final double pulsePhase;

  Road3DPainter({
    required this.levels,
    required this.sideItems,
    required this.target,
    required this.isTargetVisible,
    required this.cameraProgress,
    required this.cameraXOffset,
    required this.pulsePhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final projection = RoadProjection(size: size);
    _paintBackground(canvas, size);
    _paintRoad(canvas, projection);

    final entries = <_DepthEntry>[
      for (final item in sideItems)
        _DepthEntry(
          relativeZ: _levelDepthOfSideItem(item) - cameraProgress,
          paint: (c) => _paintSideItem(c, projection, item),
        ),
      if (isTargetVisible)
        _DepthEntry(
          relativeZ: target.levelPosition - cameraProgress,
          paint: (c) => _paintTarget(c, projection),
        ),
      for (final level in levels)
        _DepthEntry(
          relativeZ: level.number - cameraProgress,
          paint: (c) => _paintLevel(c, projection, level),
        ),
    ]..sort((a, b) => b.relativeZ.compareTo(a.relativeZ));

    for (final entry in entries) {
      entry.paint(canvas);
    }
  }

  double _levelDepthOfSideItem(SideUiItem item) =>
      (item.minLevelSeen + item.maxLevelSeen) / 2;

  void _paintBackground(Canvas canvas, Size size) {
    final skyRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.5);
    final groundRect = Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5);
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF2FA), Color(0xFFF7FAFD)],
        ).createShader(skyRect),
    );
    canvas.drawRect(
      groundRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDDE8E4), Color(0xFFCBDCD6)],
        ).createShader(groundRect),
    );
  }

  void _paintRoad(Canvas canvas, RoadProjection projection) {
    const halfWidthAtCamera = 34.0;
    const step = 0.25;
    const startZ = -3.0;
    const endZ = 15.0;

    final leftPoints = <Offset>[];
    final rightPoints = <Offset>[];
    for (double z = startZ; z <= endZ; z += step) {
      final levelPosition = cameraProgress + z;
      final xOffsetDelta =
          MapGenerator.waveXOffsetForPosition(levelPosition) - cameraXOffset;
      final scale = projection.scaleForDepth(z);
      final halfWidth = halfWidthAtCamera * scale;
      final center = projection.project(z, xOffsetDelta);
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

  void _paintLevel(Canvas canvas, RoadProjection projection, LevelUiItem level) {
    final relativeZ = level.number - cameraProgress;
    final center = projection.project(relativeZ, level.xOffset - cameraXOffset);
    final scale = projection.scaleForDepth(relativeZ);
    final radius = 26.0 * scale;

    final color = switch (level.status) {
      LevelStatus.notPassed => const Color(0xFFB6C0C6),
      LevelStatus.inProgress => const Color(0xFF57C25E),
      LevelStatus.passed => const Color(0xFF3E9BE0),
    };

    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 6 * scale), width: radius * 2, height: radius * 0.9),
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 1.1),
      Paint()..color = color,
    );

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
      final checkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * scale
        ..strokeCap = StrokeCap.round;
      final checkPath = Path()
        ..moveTo(center.dx - radius * 0.35, center.dy)
        ..lineTo(center.dx - radius * 0.1, center.dy + radius * 0.25)
        ..lineTo(center.dx + radius * 0.35, center.dy - radius * 0.25);
      canvas.drawPath(checkPath, checkPaint);
    }
  }

  void _paintSideItem(Canvas canvas, RoadProjection projection, SideUiItem item) {
    final relativeZ = _levelDepthOfSideItem(item) - cameraProgress;
    final bob = sin(pulsePhase * 2 * pi) * 4;
    final center = projection.project(relativeZ, item.xOffset - cameraXOffset).translate(0, bob);
    final scale = projection.scaleForDepth(relativeZ);
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

  void _paintTarget(Canvas canvas, RoadProjection projection) {
    final relativeZ = target.levelPosition - cameraProgress;
    final center = projection.project(relativeZ, target.xOffset - cameraXOffset);
    final scale = projection.scaleForDepth(relativeZ);
    final glowRadius = 30.0 * scale * (1.1 + 0.2 * sin(pulsePhase * 2 * pi));

    canvas.drawCircle(center, glowRadius, Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.3));
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 24 * scale, height: 20 * scale),
      Paint()..color = const Color(0xFFFFC107),
    );
  }

  @override
  bool shouldRepaint(covariant Road3DPainter oldDelegate) =>
      oldDelegate.cameraProgress != cameraProgress ||
      oldDelegate.cameraXOffset != cameraXOffset ||
      oldDelegate.pulsePhase != pulsePhase ||
      oldDelegate.levels != levels ||
      oldDelegate.sideItems != sideItems ||
      oldDelegate.target != target ||
      oldDelegate.isTargetVisible != isTargetVisible;
}

class _DepthEntry {
  final double relativeZ;
  final void Function(Canvas canvas) paint;

  _DepthEntry({required this.relativeZ, required this.paint});
}

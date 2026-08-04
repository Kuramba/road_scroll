import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_scroll/road_scroll/engine/painter.dart';

void main() {
  group('RoadProjection', () {
    const size = Size(400, 800);
    const projection = RoadProjection(size: size);

    test('farther relativeZ produces a smaller scale', () {
      final near = projection.scaleForDepth(0.0);
      final far = projection.scaleForDepth(10.0);
      expect(far, lessThan(near));
    });

    test('xOffsetDelta of 0 always projects to horizontal screen center', () {
      final p0 = projection.project(0.0, 0.0);
      final p5 = projection.project(5.0, 0.0);
      expect(p0.dx, closeTo(size.width / 2, 0.01));
      expect(p5.dx, closeTo(size.width / 2, 0.01));
    });

    test('larger relativeZ moves the projected point higher on screen (smaller dy)', () {
      final near = projection.project(0.0, 0.0);
      final far = projection.project(20.0, 0.0);
      expect(far.dy, lessThan(near.dy));
    });

    test('positive xOffsetDelta projects to the right of center, negative to the left', () {
      final right = projection.project(2.0, 0.5);
      final left = projection.project(2.0, -0.5);
      final center = size.width / 2;
      expect(right.dx, greaterThan(center));
      expect(left.dx, lessThan(center));
    });

    test('behind-camera relativeZ slides the projected point further down, not fixed at one row', () {
      final atCamera = projection.project(0.0, 0.0);
      final slightlyBehind = projection.project(-1.0, 0.0);
      final farBehind = projection.project(-3.0, 0.0);
      expect(slightlyBehind.dy, greaterThan(atCamera.dy));
      expect(farBehind.dy, greaterThan(slightlyBehind.dy));
    });
  });
}

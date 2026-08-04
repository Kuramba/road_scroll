import 'package:flutter_test/flutter_test.dart';
import 'package:road_scroll/models/map_generator.dart';
import 'package:road_scroll/road_scroll/road_scroll_viewmodel.dart';

void main() {
  group('RoadScrollViewModel camera and drag', () {
    test('starts at level 1', () {
      final vm = RoadScrollViewModel();
      expect(vm.cameraProgress, 1.0);
    });

    test('dragging up (negative dy) advances cameraProgress', () {
      final vm = RoadScrollViewModel();
      vm.onDragUpdate(-120.0); // one "pixelsPerLevel" worth, up
      expect(vm.cameraProgress, greaterThan(1.0));
    });

    test('dragging down (positive dy) decreases cameraProgress, clamped at 1', () {
      final vm = RoadScrollViewModel();
      vm.onDragUpdate(500.0);
      expect(vm.cameraProgress, 1.0);
    });

    test('cameraProgress clamps at 100 when dragged far past the end', () {
      final vm = RoadScrollViewModel();
      vm.onDragUpdate(-100000.0);
      expect(vm.cameraProgress, 100.0);
    });

    test('cameraXOffset always matches the wave function at cameraProgress', () {
      final vm = RoadScrollViewModel();
      vm.onDragUpdate(-360.0);
      expect(
        vm.cameraXOffset,
        closeTo(MapGenerator.waveXOffsetForPosition(vm.cameraProgress), 0.0001),
      );
    });

    test('notifies listeners on drag', () {
      final vm = RoadScrollViewModel();
      var notified = false;
      vm.addListener(() => notified = true);
      vm.onDragUpdate(-10.0);
      expect(notified, isTrue);
    });
  });

  group('RoadScrollViewModel fling and pulse', () {
    test('onDragEnd with velocity above threshold starts flinging', () {
      final vm = RoadScrollViewModel();
      vm.onDragEnd(-1000.0); // upward fling
      expect(vm.isFlinging, isTrue);
    });

    test('onDragEnd with tiny velocity does not start flinging', () {
      final vm = RoadScrollViewModel();
      vm.onDragEnd(-0.5);
      expect(vm.isFlinging, isFalse);
    });

    test('onFrame advances cameraProgress while flinging, then settles', () {
      final vm = RoadScrollViewModel();
      vm.onDragEnd(-1200.0);
      final start = vm.cameraProgress;
      for (var i = 0; i < 300 && vm.isFlinging; i++) {
        vm.onFrame(const Duration(milliseconds: 16));
      }
      expect(vm.isFlinging, isFalse);
      expect(vm.cameraProgress, greaterThan(start));
    });

    test('onFrame advances pulsePhase and wraps within [0, 1)', () {
      final vm = RoadScrollViewModel();
      for (var i = 0; i < 200; i++) {
        vm.onFrame(const Duration(milliseconds: 16));
        expect(vm.pulsePhase, inInclusiveRange(0.0, 1.0));
      }
    });

    test('onDragUpdate cancels an active fling', () {
      final vm = RoadScrollViewModel();
      vm.onDragEnd(-1200.0);
      expect(vm.isFlinging, isTrue);
      vm.onDragUpdate(-1.0);
      expect(vm.isFlinging, isFalse);
    });

    test('onDragStart cancels an active fling', () {
      final vm = RoadScrollViewModel();
      vm.onDragEnd(-1200.0);
      expect(vm.isFlinging, isTrue);
      vm.onDragStart();
      expect(vm.isFlinging, isFalse);
    });
  });

  group('RoadScrollViewModel visible-window getters', () {
    test('visibleLevels only includes levels near cameraProgress', () {
      final vm = RoadScrollViewModel();
      vm.onDragUpdate(-50 * RoadScrollViewModel.pixelsPerLevel); // jump to level ~51
      final numbers = vm.visibleLevels.map((l) => l.number).toList();
      expect(numbers, isNotEmpty);
      for (final n in numbers) {
        expect(n, greaterThanOrEqualTo(vm.cameraProgress - 3));
        expect(n, lessThanOrEqualTo(vm.cameraProgress + 15));
      }
    });

    test('visibleSideItems excludes items whose range is far from cameraProgress, includes those near it', () {
      final vm = RoadScrollViewModel();
      final firstItem = vm.map.sideItems.first;

      expect(vm.visibleSideItems.contains(firstItem), isTrue);

      vm.onDragUpdate(-99 * RoadScrollViewModel.pixelsPerLevel);
      expect(vm.cameraProgress, 100.0);
      expect(vm.visibleSideItems.contains(firstItem), isFalse);

      vm.onDragUpdate(92 * RoadScrollViewModel.pixelsPerLevel);
      expect(vm.visibleSideItems.contains(firstItem), isTrue);
    });

    test('isTargetVisible is true near the target and false far from it', () {
      final vm = RoadScrollViewModel();
      final targetLevel = vm.map.target.levelPosition.toDouble();
      vm.onDragUpdate(-(targetLevel - 1) * RoadScrollViewModel.pixelsPerLevel);
      expect(vm.isTargetVisible, isTrue);

      vm.onDragUpdate(1000000.0); // drag hard back toward level 1
      expect(vm.isTargetVisible, isFalse);
    });
  });
}

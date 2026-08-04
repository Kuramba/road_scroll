import 'package:flutter_test/flutter_test.dart';
import 'package:road_scroll/models/level_status.dart';
import 'package:road_scroll/models/map_generator.dart';

void main() {
  group('MapGenerator.waveXOffsetForPosition', () {
    test('stays within [-1, 1] across the whole route', () {
      for (double p = 1.0; p <= 100.0; p += 0.5) {
        final v = MapGenerator.waveXOffsetForPosition(p);
        expect(v, inInclusiveRange(-1.0001, 1.0001));
      }
    });

    test('hits the expected extremes every 5 levels', () {
      expect(MapGenerator.waveXOffsetForPosition(1), closeTo(-1.0, 0.01));
      expect(MapGenerator.waveXOffsetForPosition(6), closeTo(1.0, 0.01));
      expect(MapGenerator.waveXOffsetForPosition(11), closeTo(-1.0, 0.01));
      expect(MapGenerator.waveXOffsetForPosition(16), closeTo(1.0, 0.01));
    });

    test('is continuous across direction-change boundaries', () {
      const boundary = 6.0;
      final before = MapGenerator.waveXOffsetForPosition(boundary - 0.01);
      final at = MapGenerator.waveXOffsetForPosition(boundary);
      final after = MapGenerator.waveXOffsetForPosition(boundary + 0.01);
      expect((before - at).abs(), lessThan(0.05));
      expect((after - at).abs(), lessThan(0.05));
    });
  });

  group('MapGenerator.generateMap levels', () {
    final map = MapGenerator().generateMap();

    test('produces exactly 100 sequential levels', () {
      expect(map.levels.length, 100);
      for (var i = 0; i < 100; i++) {
        expect(map.levels[i].number, i + 1);
      }
    });

    test('first 20 levels are passed, level 21 is inProgress, rest notPassed', () {
      for (var i = 0; i < 20; i++) {
        expect(map.levels[i].status, LevelStatus.passed);
      }
      expect(map.levels[20].status, LevelStatus.inProgress);
      for (var i = 21; i < 100; i++) {
        expect(map.levels[i].status, LevelStatus.notPassed);
      }
    });

    test('each level xOffset matches the wave function', () {
      for (final level in map.levels) {
        expect(
          level.xOffset,
          closeTo(MapGenerator.waveXOffsetForPosition(level.number.toDouble()), 0.0001),
        );
      }
    });
  });

  group('MapGenerator.generateMap side items and target', () {
    final map = MapGenerator().generateMap();

    test('produces the configured number of side items, each with a valid range', () {
      expect(map.sideItems.length, MapGenerator.sideItemCount);
      for (final item in map.sideItems) {
        expect(item.minLevelSeen, lessThanOrEqualTo(item.maxLevelSeen));
        expect(item.minLevelSeen, greaterThanOrEqualTo(1));
        expect(item.maxLevelSeen, lessThanOrEqualTo(MapGenerator.totalLevels));
        expect(item.xOffset.abs(), greaterThan(1.0));
      }
    });

    test('places the target at the configured level position', () {
      expect(map.target.levelPosition, MapGenerator.targetLevelPosition);
    });
  });
}

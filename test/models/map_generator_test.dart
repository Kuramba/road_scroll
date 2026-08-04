import 'package:flutter_test/flutter_test.dart';
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

}

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/level_ui_item.dart';
import '../models/map_generator.dart';
import '../models/road_map.dart';
import '../models/side_ui_item.dart';

class RoadScrollViewModel extends ChangeNotifier {
  RoadScrollViewModel({MapGenerator? generator})
      : _map = (generator ?? MapGenerator()).generateMap();

  static const double minProgress = 1.0;
  static const double maxProgress = 100.0;
  static const double pixelsPerLevel = 120.0;
  static const double behindWindow = 3.0;
  static const double aheadWindow = 15.0;
  static const double targetVisibilityRange = 25.0;
  static const double flingDecayRate = 4.0;
  static const double flingStopThreshold = 0.02;
  static const double pulsePeriodSeconds = 1.6;

  final RoadMap _map;
  double _cameraProgress = minProgress;
  double _flingVelocity = 0.0;
  bool _isFlinging = false;
  double _pulsePhase = 0.0;

  RoadMap get map => _map;
  double get cameraProgress => _cameraProgress;
  double get cameraXOffset => MapGenerator.waveXOffsetForPosition(_cameraProgress);
  double get pulsePhase => _pulsePhase;
  bool get isFlinging => _isFlinging;

  List<LevelUiItem> get visibleLevels => _map.levels
      .where((l) =>
          l.number >= _cameraProgress - behindWindow &&
          l.number <= _cameraProgress + aheadWindow)
      .toList();

  List<SideUiItem> get visibleSideItems => _map.sideItems
      .where((s) =>
          s.maxLevelSeen >= _cameraProgress - behindWindow &&
          s.minLevelSeen <= _cameraProgress + aheadWindow)
      .toList();

  bool get isTargetVisible =>
      (_map.target.levelPosition - _cameraProgress).abs() <= targetVisibilityRange;

  void onDragStart() {
    _isFlinging = false;
    _flingVelocity = 0.0;
  }

  void onDragUpdate(double dyPixels) {
    _isFlinging = false;
    _flingVelocity = 0.0;
    _cameraProgress = (_cameraProgress - dyPixels / pixelsPerLevel)
        .clamp(minProgress, maxProgress);
    notifyListeners();
  }

  void onDragEnd(double primaryVelocityPixelsPerSecond) {
    final levelsPerSecond = -primaryVelocityPixelsPerSecond / pixelsPerLevel;
    if (levelsPerSecond.abs() < flingStopThreshold) return;
    _flingVelocity = levelsPerSecond;
    _isFlinging = true;
  }

  void onFrame(Duration elapsed) {
    final dt = elapsed.inMicroseconds / 1e6;
    _pulsePhase = (_pulsePhase + dt / pulsePeriodSeconds) % 1.0;

    if (_isFlinging) {
      _flingVelocity *= exp(-flingDecayRate * dt);
      final next = _cameraProgress + _flingVelocity * dt;
      if (next <= minProgress || next >= maxProgress) {
        _cameraProgress = next.clamp(minProgress, maxProgress);
        _isFlinging = false;
        _flingVelocity = 0.0;
      } else {
        _cameraProgress = next;
      }
      if (_flingVelocity.abs() < flingStopThreshold) {
        _isFlinging = false;
        _flingVelocity = 0.0;
      }
    }

    notifyListeners();
  }
}

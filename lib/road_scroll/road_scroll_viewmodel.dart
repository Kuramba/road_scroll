import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/level_ui_item.dart';
import '../models/map_generator.dart';
import '../models/road_map.dart';
import '../models/side_ui_item.dart';

class RoadScrollViewModel extends ChangeNotifier {
  RoadScrollViewModel({MapGenerator? generator}) : _map = (generator ?? MapGenerator()).generateMap() {
    _cameraXOffset = _targetXOffset;
  }

  static const double minProgress = 1.0;
  static const double maxProgress = 100.0;
  static const double pixelsPerLevel = 120.0;
  static const double behindWindow = 3.0;
  static const double aheadWindow = 10.0;
  static const double flingDecayRate = 4.0;
  static const double flingStopThreshold = 0.02;
  static const double pulsePeriodSeconds = 1.6;
  static const double cameraXOffsetSmoothingRate = 6.0;
  static const double progressSnapRate = 6.0;
  static const double progressSnapStopThreshold = 0.01;

  final RoadMap _map;
  double _cameraProgress = minProgress;
  double _cameraXOffset = 0.0;
  double _flingVelocity = 0.0;
  bool _isFlinging = false;
  bool _isSnapping = false;
  double _snapTargetProgress = minProgress;
  double _pulsePhase = 0.0;

  RoadMap get map => _map;
  double get cameraProgress => _cameraProgress;

  /// The target the camera's horizontal offset eases toward: the nearest
  /// level's xOffset, snapped rather than interpolated continuously.
  double get _targetXOffset => MapGenerator.waveXOffsetForPosition(_cameraProgress.roundToDouble());

  /// Eases smoothly toward [_targetXOffset] every frame instead of
  /// teleporting to it, so crossing a level boundary glides rather than jumps.
  double get cameraXOffset => _cameraXOffset;
  double get pulsePhase => _pulsePhase;
  bool get isFlinging => _isFlinging;

  List<LevelUiItem> get visibleLevels => _map.levels.where((l) => l.number >= _cameraProgress - behindWindow && l.number <= _cameraProgress + aheadWindow).toList();

  List<SideUiItem> get visibleSideItems => _map.sideItems.where((s) => s.maxLevelSeen >= _cameraProgress - behindWindow && s.minLevelSeen <= _cameraProgress + aheadWindow).toList();

  /// The level number closest to the current camera position.
  int pickNearestLevel() => _cameraProgress.round().clamp(
    minProgress.toInt(),
    maxProgress.toInt(),
  );

  /// Brings the nearest level to front: starts an eased animation of
  /// cameraProgress toward it, rather than snapping instantly.
  void _bringNearestLevelToFront() {
    _isSnapping = true;
    _snapTargetProgress = pickNearestLevel().toDouble();
  }

  void onDragStart() {
    _isFlinging = false;
    _flingVelocity = 0.0;
    _isSnapping = false;
  }

  void onDragUpdate(double dyPixels) {
    _isFlinging = false;
    _flingVelocity = 0.0;
    _isSnapping = false;
    _cameraProgress = (_cameraProgress - dyPixels / pixelsPerLevel).clamp(minProgress, maxProgress);
    notifyListeners();
  }

  void onDragEnd(double primaryVelocityPixelsPerSecond) {
    final levelsPerSecond = -primaryVelocityPixelsPerSecond / pixelsPerLevel;
    if (levelsPerSecond.abs() < flingStopThreshold) {
      _bringNearestLevelToFront();
      return;
    }
    _flingVelocity = levelsPerSecond;
    _isFlinging = true;
  }

  void onFrame(Duration elapsed) {
    final dt = elapsed.inMicroseconds / 1e6;
    _pulsePhase = (_pulsePhase + dt / pulsePeriodSeconds) % 1.0;

    final smoothing = 1.0 - exp(-cameraXOffsetSmoothingRate * dt);
    _cameraXOffset += (_targetXOffset - _cameraXOffset) * smoothing;

    if (_isFlinging) {
      _flingVelocity *= exp(-flingDecayRate * dt);
      final next = _cameraProgress + _flingVelocity * dt;
      final hitBound = next <= minProgress || next >= maxProgress;
      _cameraProgress = hitBound ? next.clamp(minProgress, maxProgress) : next;

      if (hitBound || _flingVelocity.abs() < flingStopThreshold) {
        _isFlinging = false;
        _flingVelocity = 0.0;
        _bringNearestLevelToFront();
      }
    } else if (_isSnapping) {
      final diff = _snapTargetProgress - _cameraProgress;
      final snapSmoothing = 1.0 - exp(-progressSnapRate * dt);
      _cameraProgress += diff * snapSmoothing;
      if (diff.abs() < progressSnapStopThreshold) {
        _cameraProgress = _snapTargetProgress;
        _isSnapping = false;
      }
    }

    notifyListeners();
  }
}

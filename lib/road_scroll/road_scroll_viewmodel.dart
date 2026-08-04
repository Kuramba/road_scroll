import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/level_ui_item.dart';
import '../models/long_distance_target_ui_item.dart';
import '../models/map_generator.dart';
import '../models/side_ui_item.dart';

class RoadScrollViewModel extends ChangeNotifier {
  RoadScrollViewModel() {
    _cameraXOffset = _targetXOffset;
    _lastActiveLevel = pickNearestLevel();
  }

  static const double minProgress = 1.0;
  static const double maxProgress = double.infinity;
  static const double pixelsPerLevel = 120.0;
  static const double behindWindow = 3.0;
  static const double aheadWindow = 10.0;
  static const double flingDecayRate = 4.0;
  static const double flingStopThreshold = 0.02;
  static const double pulsePeriodSeconds = 1.6;
  static const double cameraXOffsetSmoothingRate = 6.0;
  static const double progressSnapRate = 18.0;
  static const double progressSnapStopThreshold = 0.01;
  static const double activeIndicatorHopDurationSeconds = 0.35;
  static const double activeIndicatorHopHeight = 42.0;

  double _cameraProgress = minProgress;
  double _cameraXOffset = 0.0;
  double _flingVelocity = 0.0;
  bool _isFlinging = false;
  bool _isSnapping = false;
  double _snapTargetProgress = minProgress;
  double _pulsePhase = 0.0;
  late int _lastActiveLevel;
  double _hopPhase = 1.0;
  int _levelUpCount = 0;

  double get cameraProgress => _cameraProgress;
  LongDistanceTargetUiItem get target => MapGenerator.target;
  int get levelUpCount => _levelUpCount;

  /// Increments the level-up counter shown, with a flashy pop animation,
  /// in the app bar.
  void levelUp() {
    _levelUpCount++;
    notifyListeners();
  }

  /// The target the camera's horizontal offset eases toward: the nearest
  /// level's xOffset, snapped rather than interpolated continuously.
  double get _targetXOffset => MapGenerator.waveXOffsetForPosition(_cameraProgress.roundToDouble());

  /// Eases smoothly toward [_targetXOffset] every frame instead of
  /// teleporting to it, so crossing a level boundary glides rather than jumps.
  double get cameraXOffset => _cameraXOffset;
  double get pulsePhase => _pulsePhase;
  bool get isFlinging => _isFlinging;

  /// Vertical offset for the active-level indicator: 0 at rest (landed on
  /// the item), bouncing up and back down whenever the active level changes.
  double get activeIndicatorBounce => _hopPhase >= 1.0 ? 0.0 : -activeIndicatorHopHeight * sin(_hopPhase * pi);

  /// Levels are infinite, so this window is generated on demand
  List<LevelUiItem> get visibleLevels {
    final start = max((_cameraProgress - behindWindow).ceil(), minProgress.toInt());
    final end = (_cameraProgress + aheadWindow).floor();
    return [for (var number = start; number <= end; number++) MapGenerator.levelAt(number)];
  }

  List<SideUiItem> get visibleSideItems => MapGenerator.sideItemsInRange(_cameraProgress - behindWindow, _cameraProgress + aheadWindow);

  /// The level number closest to the current camera position.
  int pickNearestLevel() => max(_cameraProgress.round(), minProgress.toInt());

  /// Brings the nearest level to front: starts an eased animation of
  /// cameraProgress toward it, rather than snapping instantly.
  void _bringNearestLevelToFront() {
    _isSnapping = true;
    _snapTargetProgress = pickNearestLevel().toDouble();
  }

  /// Animates the camera back to the very first level.
  void returnToStart() {
    _isFlinging = false;
    _flingVelocity = 0.0;
    _isSnapping = true;
    _snapTargetProgress = minProgress;
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

    final nearest = pickNearestLevel();
    if (nearest != _lastActiveLevel) {
      _lastActiveLevel = nearest;
      _hopPhase = 0.0;
    }
    if (_hopPhase < 1.0) {
      _hopPhase = (_hopPhase + dt / activeIndicatorHopDurationSeconds).clamp(0.0, 1.0);
    }

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
